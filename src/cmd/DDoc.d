/// Author: Aziz Köksal
/// License: GPL3
module cmd.DDoc;

import cmd.DDocEmitter,
       cmd.DDocHTML,
       cmd.DDocXML,
       cmd.Highlight;
import dil.doc.Parser,
       dil.doc.Macro,
       dil.doc.Doc;
import dil.lexer.Token,
       dil.lexer.Funcs;
import dil.semantic.Module,
       dil.semantic.Pass1,
       dil.semantic.Symbol,
       dil.semantic.Symbols;
import dil.Compilation;
import dil.Information;
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
  string destDirPath;   /// Destination directory.
  string[] macroPaths;  /// Macro file paths.
  string[] filePaths;   /// Module file paths.
  string outFileExtension;  /// The extension of the output files.
  bool includeUndocumented; /// Whether to include undocumented symbols.
  bool writeXML; /// Whether to write XML instead of HTML docs.
  bool verbose;  /// Whether to be verbose.

  CompilationContext context; /// Environment variables of the compilation.
  InfoManager infoMan;        /// Collects error messages.
  TokenHighlighter tokenHL;   /// For highlighting tokens DDoc code sections.

  /// Executes the doc generation command.
  void run()
  {
    // Parse macro files and build macro table hierarchy.
    MacroTable mtable;
    MacroParser mparser;
    foreach (macroPath; macroPaths)
    {
      auto macros = mparser.parse(loadMacroFile(macroPath, infoMan));
      mtable = new MacroTable(mtable);
      mtable.insert(macros);
    }

    // For DDoc code sections.
    tokenHL = new TokenHighlighter(infoMan, writeXML == false);
    outFileExtension = writeXML ? ".xml" : ".html";

    // Process D files.
    foreach (filePath; filePaths)
    {
      auto mod = new Module(filePath, infoMan);

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
      }
      else // Normally done in mod.parse().
        mod.setFQN((new FilePath(filePath)).name());

      // Write the documentation file.
      writeDocumentationFile(mod, mtable);
    }
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
    // MODPATH is an extension by dil.
    mtable.insert("MODPATH", mod.getFQNPath() ~ "." ~ mod.fileExtension());
    mtable.insert("TITLE", mod.getFQN());
    mtable.insert("DOCFILENAME", mod.getFQN() ~ outFileExtension);
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
    auto fileText = MacroExpander.expand(mtable, "$(DDOC)",
                                         mod.filePath,
                                         verbose ? infoMan : null);
    // debug fileText ~= "\n<pre>\n" ~ doc.text ~ "\n</pre>";

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

  /// Loads a macro file. Converts any Unicode encoding to UTF-8.
  static string loadMacroFile(string filePath, InfoManager infoMan)
  {
    auto src = new SourceText(filePath);
    src.load(infoMan);
    auto text = src.data[0..$-1]; // Exclude '\0'.
    return sanitizeText(text);
  }
}
