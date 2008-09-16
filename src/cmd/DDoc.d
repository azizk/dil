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
  string fileExtension; /// The extension of the output files.
  bool includeUndocumented; /// Whether to include undocumented symbols.
  bool writeXML; /// Whether to write XML instead of HTML docs.
  bool verbose; /// Whether to be verbose.

  CompilationContext context;
  InfoManager infoMan;
  TokenHighlighter tokenHL; /// For highlighting tokens DDoc code sections.

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
    fileExtension = writeXML ? ".xml" : ".html";

    // Process D files.
    foreach (filePath; filePaths)
    {
      auto mod = new Module(filePath, infoMan);
      if (isDDocFile(mod))
      { // TODO: parse the whole file as a ddoc comment.
        continue;
      }

      // Parse the file.
      mod.parse();
      if (mod.hasErrors)
        continue;

      // Start semantic analysis.
      auto pass1 = new SemanticPass1(mod, context);
      pass1.run();

      // Build destination file path.
      auto destPath = new FilePath(destDirPath);
      destPath.append(mod.getFQN() ~ fileExtension);

      if (verbose)
        Stdout.formatln("{} > {}", mod.filePath, destPath);

      // Write the document file.
      writeDocFile(destPath.toString(), mod, mtable);
    }
  }

  void writeDocFile(string destPath, Module mod, MacroTable mtable)
  {
    // Create this module's own macro environment.
    mtable = new MacroTable(mtable);
    // Define runtime macros.
    // MODPATH is an extension by dil.
    mtable.insert("MODPATH", mod.getFQNPath() ~ "." ~ mod.fileExtension());
    mtable.insert("TITLE", mod.getFQN());
    mtable.insert("DOCFILENAME", mod.getFQN() ~ fileExtension);
    auto timeStr = Time.toString();
    mtable.insert("DATETIME", timeStr);
    mtable.insert("YEAR", Time.year(timeStr));

    DDocEmitter ddocEmitter;
    if (writeXML)
      ddocEmitter = new DDocXMLEmitter(mod, mtable, includeUndocumented, tokenHL);
    else
      ddocEmitter = new DDocHTMLEmitter(mod, mtable, includeUndocumented, tokenHL);
    auto ddocText = ddocEmitter.emit();

    // Set BODY macro to the text produced by the emitter.
    mtable.insert("BODY", ddocText);
    // Do the macro expansion pass.
    auto fileText = MacroExpander.expand(mtable, "$(DDOC)",
                                         mod.filePath,
                                         verbose ? infoMan : null);
    // debug fileText ~= "\n<pre>\n" ~ doc.text ~ "\n</pre>";

    // Finally write the file out to the harddisk.
    scope file = new File(destPath);
    file.write(fileText);
  }

  /// Returns true if the source text starts with "Ddoc\n" (ignores letter case.)
  bool isDDocFile(Module mod)
  {
    auto data = mod.sourceText.data;
    const ddoc = "ddoc";
    // -1 due to '\0' and +1 due to newline.
    if (data.length - 1 >= /+ddoc.length+/ 4 + 1 && // Check minimum length.
        icompare(data[0..4], ddoc) && // Check first four characters.
        isNewline(data.ptr + 4)) // Check newline.
      return true;
    return false;
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
