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
import tango.io.stream.FileStream,
       tango.io.FilePath,
       tango.io.Print,
       tango.io.File;

/// The ddoc command.
struct DDocCommand
{
  string destDirPath;  /// Destination directory.
  string[] macroPaths; /// Macro file paths.
  string[] filePaths;  /// Module file paths.
  string modsTxtPath;  /// Write list of modules to this file if specified.
  string outFileExtension;  /// The extension of the output files.
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

  /// Executes the doc generation command.
  void run()
  {
    // auto destDirPath = new FilePath(destDirPath);
    // destDirPath.exists() || destDirPath.createFolder();

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

    auto moduleManager = new ModuleManager(null, diag);

    // Process D files.
    foreach (filePath; filePaths)
    {
      auto mod = new Module(filePath, diag);

      // Only parse if the file is not a "Ddoc"-file.
      if (!DDocEmitter.isDDocFile(mod))
      {
        if (moduleManager.moduleByPath(mod.filePath()))
          continue; // The same file path was already loaded. TODO: warning?
        mod.parse();
        if (moduleManager.moduleByFQN(mod.getFQNPath()))
          continue; // Same FQN, but different file path. TODO: error?
        if (mod.hasErrors)
          continue; // No documentation for erroneous source files.
        // Add the module to the manager.
        moduleManager.addModule(mod);
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

    if (useKandil)
      writeModuleLists(moduleManager);
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
    auto file = new FileOutput(filePath.toString());
    auto print = hl.print; // Save.
    hl.print = new Print!(char)(Format, file); // New print object.
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
        reportDiag, hl);
    else
      ddocEmitter = new DDocHTMLEmitter(mod, mtable, includeUndocumented,
        reportDiag, hl);
    // Start the emitter.
    auto ddocText = ddocEmitter.emit();
    // Set the BODY macro to the text produced by the emitter.
    mtable.insert("BODY", ddocText);
    // Do the macro expansion pass.
    auto dg = verbose ? this.diag : null;
    auto fileText = rawOutput ? ddocText :
      MacroExpander.expand(mtable, "$(DDOC)", mod.filePath, dg);
    // Finally write the file out to the harddisk.
    scope file = new File(destPath.toString());
    file.write(fileText);
  }

  /// Writes the list of processed modules to the disk.
  /// Also writes DEST/js/modules.js if kandil is used.
  /// Params:
  ///   mm = has the list of modules.
  void writeModuleLists(ModuleManager mm)
  {
    if (modsTxtPath.length)
    {
      scope file = new File(modsTxtPath);
      foreach (modul; mm.loadedModules)
        file.append(modul.filePath()).append(", ")
            .append(modul.getFQN()).append(\n);
    }

    if (!useKandil)
      return;

    mm.sortPackageTree();
    auto filePath = new FilePath(destDirPath);
    filePath.append("js").append("modules.js");
    scope file = new File(filePath.toString());

    file.write("var g_modulesList = [\n "); // Write a flat list of FQNs.
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
      file.append(fragment);
    }
    file.append("\n];\n\n"); // Closing ].

    file.append(
      "function M(name, fqn, sub)\n{\n"
      "  sub = sub ? sub : [];\n"
      "  return {\n"
      "    name: name, fqn: fqn, sub: sub,\n"
      "    kind : (sub && sub.length == 0) ? \"module\" : \"package\"\n"
      "  };\n"
      "}\nvar P = M;\n\n"
    );

    file.append("var g_moduleObjects = [\n");
    writePackage(file, mm.rootPackage);
    file.append("];");
  }

  /// Writes the sub-packages and sub-modules of a package to the disk.
  static void writePackage(File f, Package pckg, string indent = "  ")
  {
    foreach (p; pckg.packages)
    {
      f.append(Format("{}P('{}','{}',[\n", indent, p.name.str, p.getFQN()));
      writePackage(f, p, indent~"  ");
      f.append(indent~"]),\n");
    }
    foreach (m; pckg.modules)
      f.append(Format("{}M('{}','{}'),\n", indent, m.name.str, m.getFQN()));
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

  /// Used for collecting data for the report.
  class ModuleData
  {
    string name; /// Module name.
    DDocProblem[] kind1, kind2, kind3, kind4;

    static ModuleData[string] table;
    static ModuleData get(string name)
    {
      auto mod = name in table;
      if (mod)
        return *mod;
      auto md = new ModuleData();
      md.name = name;
      table[name] = md;
      return md;
    }
  }

  /// Writes the DDoc report.
  void writeDDocReport()
  {
    assert(writeReport);
    auto filePath = new FilePath(destDirPath);
    filePath.append("report.txt");
    scope file = new File(filePath.toString());

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
    // Write the legend.
    file.append(Format("A = {}\nB = {}\nC = {}\nD = {}\n",
      titles[0], titles[1], titles[2], titles[3]
    ));

    // Calculate the maximum module name length.
    uint maxNameLength;
    foreach (name; ModuleData.table.keys)
      if (maxNameLength < name.length)
        maxNameLength = name.length;

    auto rowFormat = "{,-"~Format("{}",maxNameLength)~
                     "} {,6} {,6} {,6} {,6}\n";
    // Write the headers.
    file.append(Format(rowFormat, "Module", "A", "B", "C", "D"));
    // Write the table rows.
    foreach (name, mod; ModuleData.table)
    {
      file.append(Format(rowFormat, name,
        mod.kind1.length, mod.kind2.length, mod.kind3.length, mod.kind4.length
      ));
    }
    // Write the totals.
    file.append(Format(rowFormat, "Totals",
      kind1Total, kind2Total, kind3Total, kind4Total
    ));

    // Write the list of locations.
    file.append("\nList of locations:\n");
    foreach (i, title; titles)
    {
      file.append("\n***** "~title~" ******\n");
      foreach (name, mod; ModuleData.table)
      {
        // Print list of locations.
        auto kind = ([mod.kind1, mod.kind2, mod.kind3, mod.kind4])[i];
        if (!kind.length)
          continue; // Nothing to print for this module.
        file.append(name ~ ":\n"); // Module name:
        char[] line;
        foreach (p; kind)
        { // (x,y) (x,y) etc.
          line ~= Format("({},{}) ", p.loc, p.col);
          if (line.length > 80)
            file.append("  "~line[0..$-1]~\n), (line = "");
        }
        if (line.length)
          file.append("  "~line[0..$-1]~\n);
      }
    }
  }
}
