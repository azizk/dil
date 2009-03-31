/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module cmd.DDoc;

import dil.doc.DDocEmitter,
       dil.doc.DDocHTML,
       dil.doc.DDocXML,
       dil.doc.Parser,
       dil.doc.Macro,
       dil.doc.Doc;
import dil.lexer.Token,
       dil.lexer.Funcs;
import dil.semantic.Module,
       dil.semantic.Package,
       dil.semantic.Pass1,
       dil.semantic.Symbol,
       dil.semantic.Symbols;
import dil.ModuleManager,
       dil.Highlighter,
       dil.Compilation,
       dil.Diagnostics,
       dil.Converter,
       dil.SourceText,
       dil.Enums,
       dil.Time;
import SettingsLoader;
import Settings;
import common;

import tango.text.Ascii : toUpper;
import tango.text.Regex : Regex;
import tango.io.FilePath,
       tango.io.device.File;

/// The ddoc command.
struct DDocCommand
{
  string destDirPath;  /// Destination directory.
  string[] macroPaths; /// Macro file paths.
  string[] filePaths;  /// Module file paths.
  string modsTxtPath;  /// Write list of modules to this file if specified.
  string outFileExtension;  /// The extension of the output files.
  Regex[] regexps; /// Regular expressions.
  bool includeUndocumented; /// Whether to include undocumented symbols.
  bool writeReport;  /// Whether to write a problem report.
  bool useKandil;    /// Whether to use kandil.
  bool writeXML;     /// Whether to write XML instead of HTML docs.
  bool writeHLFiles; /// Whether to write syntax highlighted files.
  bool rawOutput;    /// Whether to expand macros or not.
  bool verbose;      /// Whether to be verbose.

  CompilationContext context; /// Environment variables of the compilation.
  Diagnostics diag;           /// Collects error messages.
  Diagnostics reportDiag;     /// Collectr problem messages.
  Highlighter hl; /// For highlighting source files or DDoc code sections.
  /// For managing loaded modules and getting a sorted list of them.
  ModuleManager mm;

  /// Executes the doc generation command.
  void run()
  {
    context.addVersionId("D_Ddoc"); // Define D_Ddoc version identifier.

    auto destDirPath = new FilePath(destDirPath);
    destDirPath.exists || destDirPath.createFolder();

    if (useKandil && writeXML)
      return Stdout("Error: kandil uses only HTML at the moment.").newline;

    // Parse macro files and build macro table hierarchy.
    MacroTable mtable;
    MacroParser mparser;
    foreach (macroPath; macroPaths)
    {
      auto macros = mparser.parse(loadMacroFile(macroPath, diag));
      mtable = new MacroTable(mtable);
      mtable.insert(macros);
    }

    if (writeReport)
      reportDiag = new Diagnostics();

    // For Ddoc code sections.
    string mapFilePath = GlobalSettings.htmlMapFile;
    if (writeXML)
      mapFilePath = GlobalSettings.xmlMapFile;
    auto map = TagMapLoader(diag).load(mapFilePath);
    auto tags = new TagMap(map);

    hl = new Highlighter(tags, null, diag);

    outFileExtension = writeXML ? ".xml" : ".html";

    mm = new ModuleManager(null, diag);

    // Process D files.
    foreach (filePath; filePaths)
    {
      auto mod = new Module(filePath, diag);

      // Only parse if the file is not a "Ddoc"-file.
      if (!DDocEmitter.isDDocFile(mod))
      {
        if (mm.moduleByPath(mod.filePath()))
          continue; // The same file path was already loaded. TODO: warning?
        mod.parse();
        if (mm.moduleByFQN(mod.getFQNPath()))
          continue; // Same FQN, but different file path. TODO: error?
        if (mod.hasErrors)
          continue; // No documentation for erroneous source files.
        // Add the module to the manager.
        mm.addModule(mod);
        // Write highlighted files before SA, since it mutates the tree.
        if (writeHLFiles)
          writeSyntaxHighlightedFile(mod);
        // Start semantic analysis.
        auto pass1 = new SemanticPass1(mod, context);
        pass1.run();
      }
      else // Normally done in mod.parse().
        mod.setFQN((new FilePath(filePath)).name());

      // Write the documentation file.
      writeDocumentationFile(mod, mtable);
    }

    if (useKandil || writeReport)
      mm.sortPackageTree();
    if (useKandil)
      writeModuleLists();
    if (writeReport)
      writeDDocReport();
  }

  /// Writes a syntax highlighted file for mod.
  void writeSyntaxHighlightedFile(Module mod)
  {
    auto filePath = new FilePath(destDirPath);
    filePath.append("htmlsrc");
    filePath.append(mod.getFQN());
    filePath.cat(outFileExtension);
    if (verbose)
      Stdout.formatln("hl {} > {}", mod.filePath(), filePath.toString());
    auto file = new File(filePath.toString(), File.WriteCreate);
    auto print = hl.print; // Save.
    hl.print = new FormatOut(Format, file); // New print object.
    hl.highlightSyntax(mod, !writeXML, true);
    hl.print = print; // Restore.
    file.close();
  }

  /// Writes the documentation for a module to the disk.
  /// Params:
  ///   mod = the module to be processed.
  ///   mtable = the main macro environment.
  void writeDocumentationFile(Module mod, MacroTable mtable)
  {
    // Build destination file path.
    auto destPath = new FilePath(destDirPath);
    destPath.append(mod.getFQN() ~ outFileExtension);
    // Verbose output of activity.
    if (verbose) // TODO: create a setting for this format string in dilconf.d?
      Stdout.formatln("ddoc {} > {}", mod.filePath(), destPath);

    // Create an own macro environment for this module.
    mtable = new MacroTable(mtable);
    // Define runtime macros.
    auto modFQN = mod.getFQN();
    mtable.insert("DIL_MODPATH", mod.getFQNPath() ~ "." ~ mod.fileExtension());
    mtable.insert("DIL_MODFQN", modFQN);
    mtable.insert("DIL_DOCFILENAME", modFQN ~ outFileExtension);
    mtable.insert("TITLE", modFQN);
    auto timeStr = Time.toString();
    mtable.insert("DATETIME", timeStr);
    mtable.insert("YEAR", Time.year(timeStr));

    // Create the appropriate DDocEmitter.
    DDocEmitter ddocEmitter;
    if (writeXML)
      ddocEmitter = new DDocXMLEmitter(mod, mtable, includeUndocumented,
        getReportDiag(modFQN), hl);
    else
      ddocEmitter = new DDocHTMLEmitter(mod, mtable, includeUndocumented,
        getReportDiag(modFQN), hl);
    // Start the emitter.
    auto ddocText = ddocEmitter.emit();
    // Set the BODY macro to the text produced by the emitter.
    mtable.insert("BODY", ddocText);
    // Do the macro expansion pass.
    auto dg = verbose ? this.diag : null;
    auto fileText = rawOutput ? ddocText :
      MacroExpander.expand(mtable, "$(DDOC)", mod.filePath, dg);
    // Finally write the file out to the harddisk.
    scope file = new File(destPath.toString(), File.WriteCreate);
    file.write(fileText);
  }

  /// Writes the list of processed modules to the disk.
  /// Also writes DEST/js/modules.js if kandil is used.
  /// Params:
  ///   mm = has the list of modules.
  void writeModuleLists()
  {
    if (modsTxtPath.length)
    {
      scope file = new File(modsTxtPath, File.WriteCreate);
      foreach (modul; mm.loadedModules)
        file.write(modul.filePath() ~ ", " ~ modul.getFQN() ~ \n);
    }

    if (!useKandil)
      return;

    copyKandilFiles();

    auto filePath = new FilePath(destDirPath);
    filePath.append("js").append("modules.js");
    scope file = new File(filePath.toString(), File.WriteCreate);

    file.write("var g_moduleList = [\n "); // Write a flat list of FQNs.
    uint max_line_len = 80;
    uint line_len;
    foreach (modul; mm.loadedModules)
    {
      auto fragment = ` "` ~ modul.getFQN() ~ `",`;
      line_len += fragment.length;
      if (line_len >= max_line_len) // See if we have to start a new line.
      {
        line_len = fragment.length + 1; // +1 for the space in "\n ".
        fragment = "\n " ~ fragment;
      }
      file.write(fragment);
    }
    file.write("\n];\n\n"); // Closing ].

    file.write("var g_packageTree = new PackageTree(P('', [\n");
    writePackage(file, mm.rootPackage);
    file.write("])\n);\n");
  }

  /// Creates sub-folders and copies kandil's files into them.
  void copyKandilFiles()
  { // Create folders if they do not exist yet.
    FilePath destDir = new FilePath(destDirPath);
    auto dir = destDir.dup;
    foreach (path; ["css", "js", "img"])
      dir.set(destDir.dup.append(path)).exists() || dir.createFolder();
    // Copy kandil files.
    auto kandil = new FilePath("kandil");
    destDir.dup.append("css").append("style.css")
           .copy(kandil.dup.append("css").append("style.css"));
    foreach (file; ["navigation.js", "jquery.js", "quicksearch.js"])
      destDir.dup.append("js").append(file)
             .copy(kandil.dup.append("js").append(file));
    foreach (file; ["alias", "class", "enummem", "enum", "function",
                    "interface", "module", "package", "struct", "template",
                    "typedef", "union", "variable"])
    {
      file = "icon_" ~ file ~ ".png";
      destDir.dup.append("img").append(file)
             .copy(kandil.dup.append("img").append(file));
    }
    destDir.dup.append("img").append("loading.gif")
           .copy(kandil.dup.append("img").append("loading.gif"));
  }

  /// Writes the sub-packages and sub-modules of a package to the disk.
  static void writePackage(File f, Package pckg, string indent = "  ")
  {
    foreach (p; pckg.packages)
    {
      f.write(Format("{}P('{}',[\n", indent, p.getFQN()));
      writePackage(f, p, indent~"  ");
      f.write(indent~"]),\n");
    }
    foreach (m; pckg.modules)
      f.write(Format("{}M('{}'),\n", indent, m.getFQN()));
  }

  /// Loads a macro file. Converts any Unicode encoding to UTF-8.
  /// Params:
  ///   filePath = path to the macro file.
  ///   diag  = for error messages.
  static string loadMacroFile(string filePath, Diagnostics diag)
  {
    auto src = new SourceText(filePath);
    src.load(diag);
    auto text = src.data[0..$-1]; // Exclude '\0'.
    return sanitizeText(text);
  }

  // Report functions:

  /// Returns the reportDiag for moduleName if it is not filtered
  /// by the -rx=REGEXP option.
  Diagnostics getReportDiag(string moduleName)
  {
    foreach (rx; regexps)
      if (rx.test(moduleName))
        return null;
    return reportDiag;
  }

  /// Used for collecting data for the report.
  class ModuleData
  {
    string name; /// Module name.
    DDocProblem[] kind1, kind2, kind3, kind4;

  static:
    ModuleData[string] table;
    ModuleData[] sortedList;
    /// Returns a ModuleData for name.
    /// Inserts a new instance into the table if not present.
    ModuleData get(string name)
    {
      auto mod = name in table;
      if (mod)
        return *mod;
      auto md = new ModuleData();
      md.name = name;
      table[name] = md;
      return md;
    }
    /// Uses mm to set the member sortedList.
    void sort(ModuleManager mm)
    {
      auto allModules = mm.rootPackage.getModuleList();
      foreach (mod; allModules)
        if (auto data = mod.getFQN() in table)
          sortedList ~= *data;
    }
  }

  /// Writes the DDoc report.
  void writeDDocReport()
  {
    assert(writeReport);
    auto filePath = new FilePath(destDirPath);
    filePath.append("report.txt");
    scope file = new File(filePath.toString(), File.WriteCreate);
    file.write("");

    Stdout.formatln("Writing report to '{}'.", filePath.toString());

    auto titles = ["Undocumented symbols"[], "Empty comments",
                   "No params section", "Undocumented parameters"];

    // Sort problems.
    uint kind1Total, kind2Total, kind3Total, kind4Total;
    foreach (info; reportDiag.info)
    {
      auto p = cast(DDocProblem)info;
      auto mod = ModuleData.get(p.filePath);
      switch (p.kind)
      { alias DDocProblem P;
      case P.Kind.UndocumentedSymbol:
        kind1Total++; mod.kind1 ~= p; break;
      case P.Kind.EmptyComment:
        kind2Total++; mod.kind2 ~= p; break;
      case P.Kind.NoParamsSection:
        kind3Total++; mod.kind3 ~= p; break;
      case P.Kind.UndocumentedParam:
        kind4Total++; mod.kind4 ~= p; break;
      }
    }

    ModuleData.sort(mm);

    // Write the legend.
    file.write(Format("US = {}\nEC = {}\nNP = {}\nUP = {}\n",
      titles[0], titles[1], titles[2], titles[3]
    ));

    // Calculate the maximum module name length.
    uint maxNameLength;
    foreach (mod; ModuleData.sortedList)
      if (maxNameLength < mod.name.length)
        maxNameLength = mod.name.length;

    auto maxStr = Format("{}", maxNameLength);
    auto rowFormat = "{,-"~maxStr~"} | {,6} {,6} {,6} {,6}\n";
    // Write the headers.
    file.write(Format(rowFormat, "Module", "US", "EC", "NP", "UP"));
    auto ruler = new char[maxNameLength+2+4*7];
    foreach (ref c; ruler)
      c = '-';
    file.write(ruler~\n);
    // Write the table rows.
    foreach (mod; ModuleData.sortedList)
      file.write(Format(rowFormat, mod.name,
        mod.kind1.length, mod.kind2.length, mod.kind3.length, mod.kind4.length
      ));
    file.write(ruler~\n);
    // Write the totals.
    file.write(Format(rowFormat, "Totals",
      kind1Total, kind2Total, kind3Total, kind4Total
    ));

    // Write the list of locations.
    file.write("\nList of locations:\n");
    foreach (i, title; titles)
    {
      file.write("\n***** "~title~" ******\n");
      foreach (mod; ModuleData.sortedList)
      {
        // Print list of locations.
        auto kind = ([mod.kind1, mod.kind2, mod.kind3, mod.kind4])[i];
        if (!kind.length)
          continue; // Nothing to print for this module.
        file.write(mod.name ~ ":\n"); // Module name:
        char[] line;
        foreach (p; kind)
        { // (x,y) (x,y) etc.
          line ~= p.location.str("({},{}) ");
          if (line.length > 80)
            file.write("  "~line[0..$-1]~\n), (line = "");
        }
        if (line.length)
          file.write("  "~line[0..$-1]~\n);
      }
    }
  }
}
