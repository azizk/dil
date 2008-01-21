/++
  Author: Aziz Köksal
  License: GPL3
+/
module main;

import dil.parser.Parser;
import dil.parser.Factory;
import dil.lexer.Lexer,
       dil.lexer.Token;
import dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Node,
       dil.ast.Visitor;
import dil.semantic.Module;
import dil.semantic.Symbols;
import dil.semantic.Pass1;
import dil.translator.German;
import dil.doc.Doc;
import dil.Messages;
import dil.Settings;
import dil.SettingsLoader;
import dil.CompilerInfo;
import dil.Information;
import dil.File;

import cmd.Generate;
import cmd.Statistics;
import cmd.ImportGraph;
import common;

import Integer = tango.text.convert.Integer;
import tango.io.File;
import tango.text.Util;
import tango.time.StopWatch;

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

    auto infoMan = new InfoManager();
    auto filePaths = args[2..$];
    foreach (filePath; filePaths)
    {
      auto mod = new Module(filePath, infoMan);
      // Parse the file.
      mod.parse();
      if (mod.hasErrors)
        continue;

      // Start semantic analysis.
      auto pass1 = new SemanticPass1(mod);
      pass1.start();

      void printSymbolTable(ScopeSymbol scopeSym)
      {
        foreach (member; scopeSym.members)
        {
          auto tokens = getDocComments(member.node);
          char[] docText;
          foreach (token; tokens)
            docText ~= token.srcText;
          Stdout.formatln("Id:{}, Symbol:{}, DocText:{}", member.name.str, member.classinfo.name, docText);
        }
      }

      printSymbolTable(mod);
    }

    printErrors(infoMan);
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
    char[][] filePaths;
    bool printTokensTable;
    bool printNodesTable;
    foreach (arg; args[2..$])
      if (arg == "--toktable")
        printTokensTable = true;
      else if (arg == "--asttable")
        printNodesTable = true;
      else
        filePaths ~= arg;
    cmd.Statistics.execute(filePaths, printTokensTable, printNodesTable);
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

    for (; token.kind != TOK.EOF; token = token.next)
    {
      if (token.kind == TOK.Newline || ignoreWSToks && token.isWhitespace)
        continue;
      if (printWS && token.ws)
        Stdout(token.wsChars);
      Stdout(token.srcText)(separator);
    }
    break;
  case "trans", "translate":
    if (args.length < 3)
      return printHelp("trans");

    if (args[2] != "German")
      return Stdout.formatln("Error: unrecognized target language \"{}\"", args[2]);

    auto infoMan = new InfoManager();
    auto filePath = args[3];
    auto mod = new Module(filePath, infoMan);
    // Parse the file.
    mod.parse();
    if (!mod.hasErrors)
    { // Translate
      auto german = new GermanTranslator(Stdout, "  ");
      german.translate(mod.root);
    }
    printErrors(infoMan);
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
  "  tokenize (tok)\n"
  "  translate (trans)\n";

bool strbeg(char[] str, char[] begin)
{
  if (str.length >= begin.length)
  {
    if (str[0 .. begin.length] == begin)
      return true;
  }
  return false;
}

void printErrors(InfoManager infoMan)
{
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
  dil stat file.d [file2.d, ...] [Options]

Options:
  --toktable      : print the count of all kinds of tokens in a table.
  --asttable      : print the count of all kinds of nodes in a table.

Example:
  dil stat src/dil/Parser.d src/dil/Lexer.d";
    break;
  case "trans", "translate":
    msg = `Translate a D source file to another language.
Usage:
  dil translate Language file.d

  Languages that are supported:
    *) German

Example:
  dil trans German src/main.d`;
    break;
  default:
    msg = helpMain();
  }
  Stdout(msg).newline;
}

void parse(string fileName)
{
  auto mod = new Module(fileName);
  mod.parse();

  void print(Node[] decls, char[] indent)
  {
    foreach(decl; decls)
    {
      assert(decl !is null);
      Stdout.formatln("{}{}: begin={} end={}", indent, decl.classinfo.name, decl.begin ? decl.begin.srcText : "\33[31mnull\33[0m", decl.end ? decl.end.srcText : "\33[31mnull\33[0m");
      print(decl.children, indent ~ "  ");
    }
  }
  print(mod.root.children, "");
}
