/++
  Author: Aziz Köksal
  License: GPL3
+/
module main;

import dil.Parser;
import dil.Lexer;
import dil.Token;
import dil.Messages;
import dil.Settings;
import dil.SettingsLoader;
import dil.CompilerInfo;
import dil.Module;
import dil.Declarations, dil.Expressions, dil.SyntaxTree;
import dil.Information;
import dil.File;
import cmd.Generate;
import cmd.Statistics;
import cmd.ImportGraph;
import common;

import Integer = tango.text.convert.Integer;
import tango.io.File;
import tango.text.Util;
import tango.util.time.StopWatch;

void main(char[][] args)
{
  dil.SettingsLoader.loadSettings();

  if (args.length <= 1)
    return Stdout(helpMain()).newline;

  string command = args[1];
  switch (command)
  {
  case "c", "compile":
    if (args.length < 2)
      return printHelp("compile");

    auto infoMan = new InformationManager();
    auto filePaths = args[2..$];
    foreach (filePath; filePaths)
    {
      auto mod = new Module(filePath, infoMan);
      mod.parse();
    }

    foreach (info; infoMan.info)
    {
      char[] errorFormat;
      if (info.classinfo is LexerError.classinfo)
        errorFormat = GlobalSettings.lexerErrorFormat;
      else if (info.classinfo is ParserError.classinfo)
        errorFormat = GlobalSettings.parserErrorFormat;
      else if (info.classinfo is SemanticError.classinfo)
        errorFormat = GlobalSettings.semanticErrorFormat;
      else
        continue;
      auto err = cast(Problem)info;
      Stderr.formatln(errorFormat, err.filePath, err.loc, err.col, err.getMsg);
    }
    break;
  case "gen", "generate":
    char[] fileName;
    DocOption options = DocOption.Tokens;
    foreach (arg; args[2..$])
    {
      switch (arg)
      {
      case "--syntax":
        options |= DocOption.Syntax; break;
      case "--xml":
        options |= DocOption.XML; break;
      case "--html":
        options |= DocOption.HTML; break;
      default:
        fileName = arg;
      }
    }
    if (!(options & (DocOption.XML | DocOption.HTML)))
      options |= DocOption.XML; // Default to XML.
    cmd.Generate.execute(fileName, options);
    break;
  case "importgraph", "igraph":
    string filePath;
    string[] includePaths;
    string[] regexps;
    uint levels;
    IGraphOption options;
    foreach (arg; args[2..$])
    {
      if (strbeg(arg, "-I"))
        includePaths ~= arg[2..$];
      else if(strbeg(arg, "-r"))
        regexps ~= arg[2..$];
      else if(strbeg(arg, "-l"))
        levels = Integer.toInt(arg[2..$]);
      else
        switch (arg)
        {
        case "--dot":
          options |= IGraphOption.PrintDot; break;
        case "--paths":
          options |= IGraphOption.PrintPaths; break;
        case "--list":
          options |= IGraphOption.PrintList; break;
        case "-i":
          options |= IGraphOption.IncludeUnlocatableModules; break;
        case "-hle":
          options |= IGraphOption.HighlightCyclicEdges; break;
        case "-hlv":
          options |= IGraphOption.HighlightCyclicVertices; break;
        case "-gbp":
          options |= IGraphOption.GroupByPackageNames; break;
        case "-gbf":
          options |= IGraphOption.GroupByFullPackageName; break;
        case "-m":
          options |= IGraphOption.MarkCyclicModules; break;
        default:
          filePath = arg;
        }
    }
    cmd.ImportGraph.execute(filePath, includePaths, regexps, levels, options);
    break;
  case "stats", "statistics":
    cmd.Statistics.execute(args[2..$]);
    break;
  case "tok", "tokenize":
    char[] filePath;
    char[] sourceText;
    char[] separator;
    bool ignoreWSToks;
    bool printWS;

    foreach (arg; args[2..$])
    {
      if (strbeg(arg, "-t"))
        sourceText = arg[2..$];
      else if (strbeg(arg, "-s"))
        separator = arg[2..$];
      else if (arg == "-i")
        ignoreWSToks = true;
      else if (arg == "-ws")
        printWS = true;
      else
        filePath = arg;
    }

    separator  || (separator = "\n");
    sourceText || (sourceText = loadFile(filePath));

    auto lx = new Lexer(sourceText, null);
    lx.scanAll();
    auto token = lx.firstToken();

    for (; token.type != TOK.EOF; token = token.next)
    {
      if (token.type == TOK.Newline || ignoreWSToks && token.isWhitespace)
        continue;
      if (printWS && token.ws)
        Stdout(token.wsChars);
      Stdout(token.srcText)(separator);
    }
    break;
  case "profile":
    if (args.length < 3)
      break;
    char[][] filePaths;
    if (args[2] == "dstress")
    {
      auto text = cast(char[])(new File("dstress_files")).read();
      filePaths = split(text, "\0");
    }
    else
      filePaths = args[2..$];

    StopWatch swatch;
    swatch.start;

    foreach (filePath; filePaths)
      (new Lexer(loadFile(filePath), null)).scanAll();

    Stdout.formatln("Scanned in {:f10}s.", swatch.stop);
    break;
  case "parse":
    if (args.length == 3)
      parse(args[2]);
    break;
  case "?", "help":
    printHelp(args.length >= 3 ? args[2] : "");
    break;
  default:
  }
}

const char[] COMMANDS =
  "  compile (c)\n"
  "  generate (gen)\n"
  "  help (?)\n"
  "  importgraph (igraph)\n"
  "  statistics (stats)\n"
  "  tokenize (tok)\n";

bool strbeg(char[] str, char[] begin)
{
  if (str.length >= begin.length)
  {
    if (str[0 .. begin.length] == begin)
      return true;
  }
  return false;
}

char[] helpMain()
{
  return FormatMsg(MID.HelpMain, VERSION, COMMANDS, COMPILED_WITH, COMPILED_VERSION, COMPILED_DATE);
}

void printHelp(char[] command)
{
  char[] msg;
  switch (command)
  {
  case "c", "compile":
    msg = "Compile D source files.
Usage:
  dil compile file.d [file2.d, ...] [Options]

  This command only parses the source files and does little semantic analysis.
  Errors are printed to standard error output.

Options:

Example:
  dil c src/main.d";
    break;
  case "gen", "generate":
    msg = GetMsg(MID.HelpGenerate);
    break;
  case "importgraph", "igraph":
    msg = GetMsg(MID.HelpImportGraph);
    break;
  case "tok", "tokenize":
    msg = `Print the tokens of a D source file.
Usage:
  dil tok file.d [Options]

Options:
  -tTEXT          : tokenize TEXT instead of a file.
  -sSEPARATOR     : print SEPARATOR instead of newline between tokens.
  -i              : ignore whitespace tokens (e.g. comments, shebang etc.)
  -ws             : print a token's preceding whitespace characters.

Example:
  dil tok -t"module foo; void func(){}"
  dil tok main.d | grep ^[0-9]`;
    break;
  case "stats", "statistics":
    msg = "Gather statistics about D source files.
Usage:
  dil stat file.d [file2.d, ...]

Example:
  dil stat src/dil/Parser.d src/dil/Lexer.d";
    break;
  default:
    msg = helpMain();
  }
  Stdout(msg).newline;
}

void parse(string fileName)
{
  auto sourceText = loadFile(fileName);
  auto parser = new Parser(sourceText, fileName);
  auto root = parser.start();

void print(Node[] decls, char[] indent)
{
  foreach(decl; decls)
  {
    assert(decl !is null);
    Stdout.formatln("{}{}: begin={} end={}", indent, decl.classinfo.name, decl.begin ? decl.begin.srcText : "\33[31mnull\33[0m", decl.end ? decl.end.srcText : "\33[31mnull\33[0m");
    print(decl.children, indent ~ "  ");
  }
}
print(root.children, "");
foreach (error; parser.errors)
{
  Stdout.format(`{0}({1})P: {2}`, error.filePath, error.loc, error.getMsg);
}
}
