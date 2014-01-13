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
       dil.Time,
       dil.Array;
import util.Path;
import SettingsLoader;
import Settings;
import common;

import std.file,
       std.regex;
import tango.time.Clock : Clock;

/// The ddoc command.
class DDocCommand : Command
{
  cstring destDirPath;  /// Destination directory.
  cstring[] macroPaths; /// Macro file paths.
  cstring[] filePaths;  /// Module file paths.
  cstring modsTxtPath;  /// Write list of modules to this file if specified.
  cstring outFileExtension;  /// The extension of the output files.
  Regex!char[] regexps; /// Regular expressions.
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
  override void run()
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

    hl = new Highlighter(tags, context);

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
    auto filePath = (((Path(destDirPath) /= "htmlsrc") /= mod.getFQN())
      ~= outFileExtension).toString();
    lzy(log("hl > {}", filePath));
    hl.highlightSyntax(mod, !writeXML, true);
    filePath.write(hl.takeText());
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
    auto timeStr = Time.now();
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
    destPath.toString().write(fileText);

    // Write the documented symbols in this module to a json file.
    if (ddocEmitter.symbolTree.length && useKandil)
    {
      auto filePath = ((Path(destDirPath) /= "symbols") /= modFQN) ~= ".json";
      CharArray text;
      symbolsToJSON(ddocEmitter.symbolTree[0], text);
      filePath.toString().write(text[]);
    }
  }

  /// Writes the list of processed modules to the disk.
  /// Also writes DEST/js/modules.js if kandil is used.
  /// Params:
  ///   mm = Has the list of modules.
  void writeModuleLists()
  {
    CharArray buffer;

    auto write = (cstring s) => buffer ~= s;

    if (modsTxtPath.length)
    {
      foreach (modul; mm.loadedModules)
        buffer.put(modul.filePath(), ", ", modul.getFQN(), "\n");
      modsTxtPath.write(buffer.take());
    }

    if (!useKandil)
      return;

    copyKandilFiles();

    auto filePath = ((Path(destDirPath) /= "js") /= "modules.js").toString();

    write("var g_moduleList = [\n "); // Write a flat list of FQNs.
    size_t max_line_len = 80;
    size_t line_len;
    foreach (modul; mm.loadedModules)
    {
      auto fragment = ` "` ~ modul.getFQN() ~ `",`;
      line_len += fragment.length;
      if (line_len >= max_line_len) // See if we have to start a new line.
      {
        line_len = fragment.length + 1; // +1 for the space in "\n ".
        write("\n ");
      }
      write(fragment);
    }
    write("\n];\n\n"); // Closing ].

    write("var g_packageTree = new PackageTree(P('', [\n");
    writePackage(buffer, mm.rootPackage);
    write("])\n);\n");

    // Write a timestamp. Checked by kandil to clear old storage.
    auto stamp = Clock().now().unix().seconds();
    write(Format("\nvar g_creationTime = {};\n", stamp));

    filePath.write(buffer[]);
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
  static void writePackage(ref CharArray a, Package pckg, uint_t indent = 2)
  {
    void writeIndented(Args...)(Args args)
    {
      a.len = a.len + indent; // Reserve.
      a[Neg(indent)..Neg(0)][] = ' '; // Write spaces.
      a.put(args);
    }
    foreach (p; pckg.packages)
    {
      writeIndented("P('", p.getFQN(), "',[\n");
      writePackage(a, p, indent + 2);
      writeIndented("]),\n");
    }
    foreach (m; pckg.modules)
      writeIndented("M('", m.getFQN(), "'),\n");
  }

  /// Converts the symbol tree into JSON.
  static char[] symbolsToJSON(DocSymbol symbol, ref CharArray text)
  {
    auto locbeg = symbol.begin.lineNum, locend = symbol.end.lineNum;
    text.put(`["`, symbol.name, `",`, symbol.kind.itoa, ",",
      symbol.formatAttrsAsIDs(), ",[", locbeg.itoa, ",", locend.itoa, "],[");
    foreach (s; symbol.members)
    {
      text ~= '\n';
      symbolsToJSON(s, text);
      text ~= ',';
    }
    if (text[Neg(1)] == ',')
      text.cur--; // Remove last comma.
    text ~= "]]";
    return text[];
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
      if (!matchFirst(moduleName, rx).empty)
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
    CharArray buffer;

    auto filePath = (Path(destDirPath) /= "report.txt").toString();

    lzy(log("Writing report to ‘{}’.", filePath));

    auto titles = ["Undocumented symbols", "Empty comments",
                   "No params section", "Undocumented parameters"];

    // Sort problems.
    uint kind1Total, kind2Total, kind3Total, kind4Total;
    foreach (info; reportDiag.info)
    {
      auto p = cast(DDocProblem)info;
      auto mod = ModuleData.get(p.filePath);
      final switch (p.kind) with (DDocProblem.Kind)
      {
      case UndocumentedSymbol: kind1Total++; mod.kind1 ~= p; break;
      case EmptyComment:       kind2Total++; mod.kind2 ~= p; break;
      case NoParamsSection:    kind3Total++; mod.kind3 ~= p; break;
      case UndocumentedParam:  kind4Total++; mod.kind4 ~= p; break;
      }
    }

    ModuleData.sort(mm);

    // Write the legend.
    buffer.put("US = ", titles[0], "\nEC = ", titles[1],
             "\nNP = ", titles[2], "\nUP = ", titles[3], "\n");

    // Calculate the maximum module name length.
    size_t maxNameLength;
    foreach (mod; ModuleData.sortedList)
      if (maxNameLength < mod.name.length)
        maxNameLength = mod.name.length;

    auto rowFormat = "{,-"~maxNameLength.itoa()~"} | {,6} {,6} {,6} {,6}\n";
    // Write the headers.
    buffer.put(Format(rowFormat, "Module", "US", "EC", "NP", "UP"));
    auto ruler = new char[maxNameLength+2+4*7];
    ruler[] = '-';
    buffer.put(ruler, "\n");
    // Write the table rows.
    foreach (mod; ModuleData.sortedList)
      buffer ~= Format(rowFormat, mod.name,
        mod.kind1.length, mod.kind2.length, mod.kind3.length, mod.kind4.length
      );
    buffer.put(ruler, "\n");
    // Write the totals.
    buffer ~= Format(rowFormat, "Totals",
      kind1Total, kind2Total, kind3Total, kind4Total);

    // Write the list of locations.
    buffer ~= "\nList of locations:\n";
    foreach (i, title; titles)
    {
      buffer.put("\n***** ", title, " ******\n");
      foreach (mod; ModuleData.sortedList)
      {
        // Print list of locations.
        auto kind = ([mod.kind1, mod.kind2, mod.kind3, mod.kind4])[i];
        if (!kind.length)
          continue; // Nothing to print for this module.
        buffer.put(mod.name, ":\n"); // Module name:
        char[] line;
        foreach (p; kind)
        { // (x,y) (x,y) etc.
          line ~= p.location.str("({},{}) ");
          if (line.length > 80)
            buffer.put("  ", line[0..$-1], "\n"), (line = null);
        }
        if (line.length)
          buffer.put("  ", line[0..$-1], "\n");
      }
    }

    filePath.write(buffer[]);
  }
}
