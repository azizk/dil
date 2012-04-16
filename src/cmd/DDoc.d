/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module cmd.DDoc;

import cmd.Command;
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
import util.Path;
import SettingsLoader;
import Settings;
import common;

import tango.text.Ascii : toUpper;
import tango.text.Regex : Regex;
import tango.time.Clock : Clock;
import tango.io.device.File;

/// The ddoc command.
class DDocCommand : Command
{
  cstring destDirPath;  /// Destination directory.
  cstring[] macroPaths; /// Macro file paths.
  cstring[] filePaths;  /// Module file paths.
  cstring modsTxtPath;  /// Write list of modules to this file if specified.
  cstring outFileExtension;  /// The extension of the output files.
  Regex[] regexps; /// Regular expressions.
  bool includeUndocumented; /// Whether to include undocumented symbols.
  bool includePrivate; /// Whether to include private symbols.
  bool writeReport;  /// Whether to write a problem report.
  bool useKandil;    /// Whether to use kandil.
  bool writeXML;     /// Whether to write XML instead of HTML docs.
  bool writeHLFiles; /// Whether to write syntax highlighted files.
  bool rawOutput;    /// Whether to expand macros or not.

  CompilationContext context; /// Environment variables of the compilation.
  Diagnostics diag;           /// Collects error messages.
  Diagnostics reportDiag;     /// Collects problem messages.
  Highlighter hl; /// For highlighting source files or DDoc code sections.
  /// For managing loaded modules and getting a sorted list of them.
  ModuleManager mm;

  /// Executes the doc generation command.
  void run()
  {
    context.addVersionId("D_Ddoc"); // Define D_Ddoc version identifier.

    auto destDirPath = Path(destDirPath);
    destDirPath.exists || destDirPath.createFolder();

    if (useKandil)
      if (auto symDir = destDirPath/"symbols")
        symDir.exists || symDir.createFolder();

    if (writeHLFiles)
      if (auto srcDir = destDirPath/"htmlsrc")
        srcDir.exists || srcDir.createFolder();

    if (useKandil && writeXML)
      return cast(void)
        Stdout("Error: kandil uses only HTML at the moment.").newline;

    // Prepare macro files:
    // Get file paths from the config file.
    cstring[] macroPaths = GlobalSettings.ddocFilePaths.dup;

    if (useKandil)
      macroPaths ~=
        (Path(GlobalSettings.kandilDir) /= "kandil.ddoc").toString();
    macroPaths ~= this.macroPaths; // Add files from the cmd line arguments.

    // Parse macro files and build macro table hierarchy.
    MacroTable mtable;
    foreach (macroPath; macroPaths)
    {
      auto macros = MacroParser.parse(loadMacroFile(macroPath, diag));
      mtable = new MacroTable(mtable);
      mtable.insert(macros);
    }

    if (writeReport)
      reportDiag = new Diagnostics();

    // For Ddoc code sections.
    auto mapFilePath = GlobalSettings.htmlMapFile;
    if (writeXML)
      mapFilePath = GlobalSettings.xmlMapFile;
    auto map = TagMapLoader(context, diag).load(mapFilePath);
    auto tags = new TagMap(map);

    hl = new Highlighter(tags, null, context);

    outFileExtension = writeXML ? ".xml" : ".html";

    mm = new ModuleManager(context);

    // Process D files.
    foreach (filePath; filePaths)
    {
      auto mod = new Module(filePath, context);

      // Only parse if the file is not a "Ddoc"-file.
      if (!DDocEmitter.isDDocFile(mod))
      {
        if (mm.moduleByPath(mod.filePath()))
          continue; // The same file path was already loaded. TODO: warning?

        lzy(log("Parsing: {}", mod.filePath()));

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
        mod.setFQN(Path(filePath).name());

      // Write the documentation file.
      writeDocumentationFile(mod, mtable);
    }

    if (useKandil || writeReport)
      mm.sortPackageTree();
    if (useKandil || modsTxtPath.length)
      writeModuleLists();
    if (writeReport)
      writeDDocReport();
    lzy({if (diag.hasInfo()) log("\nDdoc diagnostic messages:");}());
  }

  /// Writes a syntax highlighted file for mod.
  void writeSyntaxHighlightedFile(Module mod)
  {
    auto filePath = Path(destDirPath);
    (filePath /= "htmlsrc") /= mod.getFQN();
    filePath ~= outFileExtension;
    lzy(log("hl > {}", filePath.toString()));
    auto file = new File(filePath.toString(), File.WriteCreate);
    auto print = hl.print; // Save.
    hl.print = new FormatOut(Format, file); // New print object.
    hl.highlightSyntax(mod, !writeXML, true);
    hl.print = print; // Restore.
    file.close();
  }

  /// Writes the documentation for a module to the disk.
  /// Params:
  ///   mod = The module to be processed.
  ///   mtable = The main macro environment.
  void writeDocumentationFile(Module mod, MacroTable mtable)
  {
    // Build destination file path.
    auto destPath = Path(destDirPath);
    (destPath /= mod.getFQN()) ~= outFileExtension;

    // TODO: create a setting for this format string in dilconf.d?
    lzy(log("ddoc > {}", destPath));

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
        includePrivate, getReportDiag(modFQN), hl);
    else
      ddocEmitter = new DDocHTMLEmitter(mod, mtable, includeUndocumented,
        includePrivate, getReportDiag(modFQN), hl);
    // Start the emitter.
    auto ddocText = ddocEmitter.emit();
    // Set the BODY macro to the text produced by the emitter.
    mtable.insert("BODY", ddocText);
    // Do the macro expansion pass.
    auto dg = verbose ? this.diag : null;
    cstring DDOC = "$(DDOC)";
    if (auto ddocMacro = mtable.search("DDOC"))
      DDOC = ddocMacro.text;
    auto fileText = rawOutput ? ddocText :
      MacroExpander.expand(mtable, DDOC, mod.filePath, dg);

    // Finally write the XML/XHTML file out to the harddisk.
    auto file = new File(destPath.toString(), File.WriteCreate);
    file.write(fileText);
    file.close();

    // Write the documented symbols in this module to a json file.
    if (ddocEmitter.symbolTree.length && useKandil)
    {
      auto filePath = Path(destDirPath);
      ((filePath /= "symbols") /= modFQN) ~= ".json";
      file = new File(filePath.toString(), File.WriteCreate);
      char[] text;
      file.write(symbolsToJSON(ddocEmitter.symbolTree[0], text));
      file.close();
    }
  }

  /// Writes the list of processed modules to the disk.
  /// Also writes DEST/js/modules.js if kandil is used.
  /// Params:
  ///   mm = Has the list of modules.
  void writeModuleLists()
  {
    if (modsTxtPath.length)
    {
      scope file = new File(modsTxtPath, File.WriteCreate);
      foreach (modul; mm.loadedModules)
        file.write(modul.filePath() ~ ", " ~ modul.getFQN() ~ "\n");
    }

    if (!useKandil)
      return;

    copyKandilFiles();

    auto filePath = Path(destDirPath);
    (filePath /= "js") /= "modules.js";
    scope file = new File(filePath.toString(), File.WriteCreate);

    file.write("var g_moduleList = [\n "); // Write a flat list of FQNs.
    size_t max_line_len = 80;
    size_t line_len;
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

    // Write a timestamp. Checked by kandil to clear old storage.
    auto stamp = Clock().now().unix().seconds();
    file.write(Format("\nvar g_creationTime = {};\n", stamp));
  }

  /// Creates sub-folders and copies kandil's files into them.
  void copyKandilFiles()
  { // Create folders if they do not exist yet.
    auto destDir = Path(destDirPath);
    auto dir = destDir.dup;
    foreach (path; ["css", "js", "img"])
      dir.set(destDir / path).exists() || dir.createFolder();
    // Copy kandil files.
    auto kandil = Path(GlobalSettings.kandilDir);
    auto data = Path(GlobalSettings.dataDir);
    (destDir / "css" /= "style.css").copy(kandil / "css" /= "style.css");
    if (writeHLFiles)
      (destDir / "htmlsrc" /= "html.css").copy(data / "html.css");
    foreach (js_file; ["navigation.js", "jquery.js", "quicksearch.js",
                       "symbols.js", "treeview.js", "utilities.js"])
      (destDir / "js" /= js_file).copy(kandil / "js" /= js_file);
    foreach (file; ["alias", "class", "enummem", "enum", "function",
                    "interface", "module", "package", "struct", "template",
                    "typedef", "union", "variable",
                    "tv_dot", "tv_minus", "tv_plus", "magnifier"])
    {
      file = "icon_" ~ file ~ ".png";
      (destDir / "img" /= file).copy(kandil / "img" /= file);
    }
    (destDir / "img" /= "loading.gif").copy(kandil / "img" /= "loading.gif");
  }

  /// Writes the sub-packages and sub-modules of a package to the disk.
  static void writePackage(File f, Package pckg, cstring indent = "  ")
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

  /// Converts the symbol tree into JSON.
  static char[] symbolsToJSON(DocSymbol symbol, ref char[] text)
  {
    auto locbeg = symbol.begin.lineNum, locend = symbol.end.lineNum;
    text ~= Format(`["{}",{},{},[{},{}],[`,
      symbol.name, symbol.kind,
      symbol.formatAttrsAsIDs(), locbeg, locend);
    foreach (s; symbol.members)
    {
      text ~= "\n";
      symbolsToJSON(s, text);
      text ~= ",";
    }
    if (text[$-1] == ',')
      text = text[0..$-1]; // Remove last comma.
    text ~= "]]";
    return text;
  }

version(unused)
{
  /// Converts the symbol tree into JSON.
  static char[] symbolsToJSON(DocSymbol symbol, cstring indent = "\t")
  {
    char[] text;
    auto locbeg = symbol.begin.lineNum, locend = symbol.end.lineNum;
    text ~= Format(
      "{{\n"`{}"name":"{}","fqn":"{}","kind":"{}","loc":[{},{}],`"\n",
      indent, symbol.name, symbol.fqn, symbol.kind, locbeg, locend);
    text ~= indent~`"sub":[`;
    foreach (s; symbol.members)
    {
      text ~= symbolsToJSON(s, indent~"\t");
      text ~= ",";
    }
    if (text[$-1] == ',')
      text = text[0..$-1]; // Remove last comma.
    text ~= "]\n"~indent[0..$-1]~"}";
    return text;
  }
}

  /// Loads a macro file. Converts any Unicode encoding to UTF-8.
  /// Params:
  ///   filePath = Path to the macro file.
  ///   diag  = For error messages.
  static char[] loadMacroFile(cstring filePath, Diagnostics diag)
  {
    auto src = new SourceText(filePath);
    src.load(diag);
    // Casting away const is okay here.
    return sanitizeText(cast(char[])src.text());
  }

  // Report functions:

  /// Returns the reportDiag for moduleName if it is not filtered
  /// by the -rx=REGEXP option.
  Diagnostics getReportDiag(cstring moduleName)
  {
    foreach (rx; regexps)
      if (rx.test(moduleName))
        return null;
    return reportDiag;
  }

  /// Used for collecting data for the report.
  static class ModuleData
  {
    cstring name; /// Module name.
    DDocProblem[] kind1, kind2, kind3, kind4;

  static:
    ModuleData[hash_t] table;
    ModuleData[] sortedList;
    /// Returns a ModuleData for name.
    /// Inserts a new instance into the table if not present.
    ModuleData get(cstring name)
    {
      auto hash = hashOf(name);
      auto mod = hash in table;
      if (mod)
        return *mod;
      auto md = new ModuleData();
      md.name = name;
      table[hash] = md;
      return md;
    }
    /// Uses mm to set the member sortedList.
    void sort(ModuleManager mm)
    {
      auto allModules = mm.rootPackage.getModuleList();
      foreach (mod; allModules)
        if (auto data = hashOf(mod.getFQN()) in table)
          sortedList ~= *data;
    }
  }

  /// Writes the DDoc report.
  void writeDDocReport()
  {
    assert(writeReport);
    auto filePath = Path(destDirPath);
    filePath /= "report.txt";
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
      final switch (p.kind)
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
    size_t maxNameLength;
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
    file.write(ruler~"\n");
    // Write the table rows.
    foreach (mod; ModuleData.sortedList)
      file.write(Format(rowFormat, mod.name,
        mod.kind1.length, mod.kind2.length, mod.kind3.length, mod.kind4.length
      ));
    file.write(ruler~"\n");
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
            file.write("  "~line[0..$-1]~"\n"), (line = null);
        }
        if (line.length)
          file.write("  "~line[0..$-1]~"\n");
      }
    }
  }
}
