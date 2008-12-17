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
  bool useKandil;    /// Whether to use kandil.
  bool writeXML;     /// Whether to write XML instead of HTML docs.
  bool writeHLFiles; /// Whether to write syntax highlighted files.
  bool rawOutput;    /// Whether to expand macros or not.
  bool verbose;      /// Whether to be verbose.

  CompilationContext context; /// Environment variables of the compilation.
  Diagnostics diag;           /// Collects error messages.
  TokenHighlighter tokenHL;   /// For highlighting tokens DDoc code sections.

  /// Executes the doc generation command.
  void run()
  {
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

    // For Ddoc code sections.
    string mapFilePath = GlobalSettings.htmlMapFile;
    if (writeXML)
      mapFilePath = GlobalSettings.xmlMapFile;
    auto map = TagMapLoader(diag).load(mapFilePath);
    auto tags = new TagMap(map);
    tokenHL = new TokenHighlighter(diag, tags);

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
          writeSyntaxHighlightedFile(mod, tags);
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
  }

  /// Writes a syntax highlighted file for mod.
  void writeSyntaxHighlightedFile(Module mod, TagMap tags)
  {
    auto filePath = new FilePath(destDirPath);
    filePath.append("htmlsrc");
    filePath.append(mod.getFQN());
    filePath.cat(outFileExtension);
    if (verbose)
      Stdout.formatln("hl {} > {}", mod.filePath(), filePath.toString());
    auto file = new FileOutput(filePath.toString());
    auto print = new Print!(char)(Format, file);
    highlightSyntax(mod, tags, print, !writeXML, true);
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
      ddocEmitter = new DDocXMLEmitter(mod, mtable, includeUndocumented, tokenHL);
    else
      ddocEmitter = new DDocHTMLEmitter(mod, mtable, includeUndocumented, tokenHL);
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
}
