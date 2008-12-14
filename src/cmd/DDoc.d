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
       dil.semantic.Pass1,
       dil.semantic.Symbol,
       dil.semantic.Symbols;
import dil.Highlighter;
import dil.Compilation;
import dil.Diagnostics;
import dil.Converter;
import dil.SourceText;
import dil.Enums;
import dil.Time;
import common;

import tango.text.Ascii : toUpper;
import tango.io.File;
import tango.io.FilePath;

/// The ddoc command.
struct DDocCommand
{
  string destDirPath;  /// Destination directory.
  string[] macroPaths; /// Macro file paths.
  string[] filePaths;  /// Module file paths.
  string modsTxtPath;  /// Write list of modules to this file if specified.
  string outFileExtension;  /// The extension of the output files.
  bool includeUndocumented; /// Whether to include undocumented symbols.
  bool writeXML;  /// Whether to write XML instead of HTML docs.
  bool rawOutput; /// Whether to expand macros or not.
  bool verbose;   /// Whether to be verbose.

  CompilationContext context; /// Environment variables of the compilation.
  Diagnostics diag;           /// Collects error messages.
  TokenHighlighter tokenHL;   /// For highlighting tokens DDoc code sections.

  /// Executes the doc generation command.
  void run()
  {
    // Parse macro files and build macro table hierarchy.
    MacroTable mtable;
    MacroParser mparser;
    foreach (macroPath; macroPaths)
    {
      auto macros = mparser.parse(loadMacroFile(macroPath, diag));
      mtable = new MacroTable(mtable);
      mtable.insert(macros);
    }

    // For DDoc code sections.
    tokenHL = new TokenHighlighter(diag, writeXML == false);
    outFileExtension = writeXML ? ".xml" : ".html";

    string[][] modFQNs; // List of tuples (filePath, moduleFQN).
    bool generateModulesTextFile = modsTxtPath !is null;

    // Process D files.
    foreach (filePath; filePaths)
    {
      auto mod = new Module(filePath, diag);

      // Only parse if the file is not a "DDoc"-file.
      if (!DDocEmitter.isDDocFile(mod))
      {
        mod.parse();
        // No documentation for erroneous source files.
        if (mod.hasErrors)
          continue;
        // Start semantic analysis.
        auto pass1 = new SemanticPass1(mod, context);
        pass1.run();

        if (generateModulesTextFile)
          modFQNs ~= [filePath, mod.getFQN()];
      }
      else // Normally done in mod.parse().
        mod.setFQN((new FilePath(filePath)).name());

      // Write the documentation file.
      writeDocumentationFile(mod, mtable);
    }

    if (generateModulesTextFile)
      writeModulesTextFile(modFQNs);
  }

  /// Writes the documentation for a module to the disk.
  /// Params:
  ///   mod = the module to be processed.
  ///   mtable = the main macro environment.
  void writeDocumentationFile(Module mod, MacroTable mtable)
  {
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
    // Build destination file path.
    auto destPath = new FilePath(destDirPath);
    destPath.append(mod.getFQN() ~ outFileExtension);
    // Verbose output of activity.
    if (verbose) // TODO: create a setting for this format string in dilconf.d?
      Stdout.formatln("ddoc {} > {}", mod.filePath, destPath);
    // Finally write the file out to the harddisk.
    scope file = new File(destPath.toString());
    file.write(fileText);
  }

  /// Writes the list of processed modules to the disk.
  /// Params:
  ///   moduleList = the list of modules.
  void writeModulesTextFile(string[][] moduleList)
  {
    char[] text;
    foreach (mod; moduleList)
      text ~= mod[0] ~ ", " ~ mod[1] ~ \n;
    scope file = new File(modsTxtPath);
    file.write(text);
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
