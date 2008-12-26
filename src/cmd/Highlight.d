/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module cmd.Highlight;

import dil.ast.DefaultVisitor,
       dil.ast.Node,
       dil.ast.Declaration,
       dil.ast.Statement,
       dil.ast.Expression,
       dil.ast.Types;
import dil.lexer.Lexer;
import dil.parser.Parser;
import dil.semantic.Module;
import dil.Highlighter;
import dil.SourceText;
import dil.Diagnostics;
import SettingsLoader;
import Settings;
import common;

import tango.io.Buffer;
import tango.io.Print;
import tango.io.FilePath;

/// The highlight command.
struct HighlightCommand
{
  /// Options for the command.
  enum Option
  {
    None        = 0,
    Tokens      = 1,
    Syntax      = 1<<1,
    HTML        = 1<<2,
    XML         = 1<<3,
    PrintLines  = 1<<4
  }
  alias Option Options;

  Options options; /// Command options.
  string filePath; /// File path to the module to be highlighted.
  Diagnostics diag;

  /// Adds o to the options.
  void add(Option o)
  {
    options |= o;
  }

  /// Executes the command.
  void run()
  {
    add(HighlightCommand.Option.Tokens);
    if (!(options & (Option.XML | Option.HTML)))
      add(Option.XML); // Default to XML.

    auto mapFilePath = options & Option.HTML ? GlobalSettings.htmlMapFile
                                             : GlobalSettings.xmlMapFile;
    auto map = TagMapLoader(diag).load(mapFilePath);
    auto tags = new TagMap(map);

    if (diag.hasInfo)
      return;

    auto hl = new Highlighter(tags, Stdout, diag);

    bool printLines = (options & Option.PrintLines) != 0;
    bool printHTML = (options & Option.HTML) != 0;
    if (options & Option.Syntax)
      hl.highlightSyntax(filePath, printHTML, printLines);
    else
      hl.highlightTokens(filePath, printLines);
  }
}
