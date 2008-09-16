/// Author: Aziz Köksal
/// License: GPL3
module main;

import dil.parser.Parser;
import dil.lexer.Lexer,
       dil.lexer.Token;
import dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Node,
       dil.ast.Visitor;
import dil.semantic.Module,
       dil.semantic.Symbols,
       dil.semantic.Pass1,
       dil.semantic.Pass2,
       dil.semantic.Passes,
       dil.semantic.Interpreter;
import dil.translator.German;
import dil.doc.Doc;
import dil.Messages;
import dil.CompilerInfo;
import dil.Information;
import dil.SourceText;
import dil.Compilation;

import cmd.Compile;
import cmd.Highlight;
import cmd.Statistics;
import cmd.ImportGraph;
import cmd.DDoc;

import Settings;
import SettingsLoader;
import common;

import Integer = tango.text.convert.Integer;
import tango.stdc.stdio;
import tango.io.File;
import tango.text.Util;
import tango.time.StopWatch;
import tango.text.Ascii : icompare;

/// Entry function of dil.
void main(char[][] args)
{
  auto infoMan = new InfoManager();
  ConfigLoader(infoMan).load();
  if (infoMan.hasInfo)
    return printErrors(infoMan);

  if (args.length <= 1)
    return printHelp("main");

  string command = args[1];
  switch (command)
  {
  case "c", "compile":
    if (args.length < 3)
      return printHelp(command);

    CompileCommand cmd;
    cmd.context = newCompilationContext();
    cmd.infoMan = infoMan;

    foreach (arg; args[2..$])
    {
      if (parseDebugOrVersion(arg, cmd.context))
      {}
      else if (strbeg(arg, "-I"))
        cmd.context.importPaths ~= arg[2..$];
      else if (arg == "-release")
        cmd.context.releaseBuild = true;
      else if (arg == "-unittest")
      {
      version(D2)
        cmd.context.addVersionId("unittest");
        cmd.context.unittestBuild = true;
      }
      else if (arg == "-d")
        cmd.context.acceptDeprecated = true;
      else if (arg == "-ps")
        cmd.printSymbolTree = true;
      else if (arg == "-pm")
        cmd.printModuleTree = true;
      else
        cmd.filePaths ~= arg;
    }
    cmd.run();
    infoMan.hasInfo && printErrors(infoMan);
    break;
  case "ddoc", "d":
    if (args.length < 4)
      return printHelp(command);

    DDocCommand cmd;
    cmd.destDirPath = args[2];
    cmd.macroPaths = GlobalSettings.ddocFilePaths;
    cmd.context = newCompilationContext();
    cmd.infoMan = infoMan;

    // Parse arguments.
    foreach (arg; args[3..$])
    {
      if (parseDebugOrVersion(arg, cmd.context))
      {}
      else if (arg == "--xml")
        cmd.writeXML = true;
      else if (arg == "-i")
        cmd.includeUndocumented = true;
      else if (arg == "-v")
        cmd.verbose = true;
      else if (arg.length > 5 && icompare(arg[$-4..$], "ddoc") == 0)
        cmd.macroPaths ~= arg;
      else
        cmd.filePaths ~= arg;
    }
    cmd.run();
    infoMan.hasInfo && printErrors(infoMan);
    break;
  case "hl", "highlight":
    if (args.length < 3)
      return printHelp(command);

    HighlightCommand cmd;
    cmd.infoMan = infoMan;

    foreach (arg; args[2..$])
    {
      switch (arg)
      {
      case "--syntax":
        cmd.add(HighlightCommand.Option.Syntax); break;
      case "--xml":
        cmd.add(HighlightCommand.Option.XML); break;
      case "--html":
        cmd.add(HighlightCommand.Option.HTML); break;
      case "--lines":
        cmd.add(HighlightCommand.Option.PrintLines); break;
      default:
        cmd.filePath = arg;
      }
    }
    cmd.run();
    infoMan.hasInfo && printErrors(infoMan);
    break;
  case "importgraph", "igraph":
    if (args.length < 3)
      return printHelp(command);

    IGraphCommand cmd;
    cmd.context = newCompilationContext();

    foreach (arg; args[2..$])
    {
      if (parseDebugOrVersion(arg, cmd.context))
      {}
      else if (strbeg(arg, "-I"))
        cmd.context.importPaths ~= arg[2..$];
      else if(strbeg(arg, "-x"))
        cmd.regexps ~= arg[2..$];
      else if(strbeg(arg, "-l"))
        cmd.levels = Integer.toInt(arg[2..$]);
      else if(strbeg(arg, "-si"))
        cmd.siStyle = arg[3..$];
      else if(strbeg(arg, "-pi"))
        cmd.piStyle = arg[3..$];
      else
        switch (arg)
        {
        case "--dot":
          cmd.add(IGraphCommand.Option.PrintDot); break;
        case "--paths":
          cmd.add(IGraphCommand.Option.PrintPaths); break;
        case "--list":
          cmd.add(IGraphCommand.Option.PrintList); break;
        case "-i":
          cmd.add(IGraphCommand.Option.IncludeUnlocatableModules); break;
        case "-hle":
          cmd.add(IGraphCommand.Option.HighlightCyclicEdges); break;
        case "-hlv":
          cmd.add(IGraphCommand.Option.HighlightCyclicVertices); break;
        case "-gbp":
          cmd.add(IGraphCommand.Option.GroupByPackageNames); break;
        case "-gbf":
          cmd.add(IGraphCommand.Option.GroupByFullPackageName); break;
        case "-m":
          cmd.add(IGraphCommand.Option.MarkCyclicModules); break;
        default:
          cmd.filePath = arg;
        }
    }
    cmd.run();
    break;
  case "stats", "statistics":
    if (args.length < 3)
      return printHelp(command);

    StatsCommand cmd;
    foreach (arg; args[2..$])
      if (arg == "--toktable")
        cmd.printTokensTable = true;
      else if (arg == "--asttable")
        cmd.printNodesTable = true;
      else
        cmd.filePaths ~= arg;
    cmd.run();
    break;
  case "tok", "tokenize":
    if (args.length < 3)
      return printHelp(command);
    SourceText sourceText;
    char[] filePath;
    char[] separator;
    bool ignoreWSToks;
    bool printWS;

    foreach (arg; args[2..$])
    {
      if (strbeg(arg, "-s"))
        separator = arg[2..$];
      else if (arg == "-")
        sourceText = new SourceText("stdin", readStdin());
      else if (arg == "-i")
        ignoreWSToks = true;
      else if (arg == "-ws")
        printWS = true;
      else
        filePath = arg;
    }

    separator || (separator = "\n");
    if (!sourceText)
      sourceText = new SourceText(filePath, true);

    infoMan = new InfoManager();
    auto lx = new Lexer(sourceText, infoMan);
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

    infoMan.hasInfo && printErrors(infoMan);
    break;
  case "trans", "translate":
    if (args.length < 3)
      return printHelp(command);

    if (args[2] != "German")
      return Stdout.formatln("Error: unrecognized target language \"{}\"", args[2]);

    infoMan = new InfoManager();
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
      (new Lexer(new SourceText(filePath, true))).scanAll();

    Stdout.formatln("Scanned in {:f10}s.", swatch.stop);
    break;
  case "?", "help":
    printHelp(args.length >= 3 ? args[2] : "");
    break;
  default:
    printHelp("main");
  }
}

/// Reads the standard input and returns its contents.
char[] readStdin()
{
  char[] text;
  while (1)
  {
    auto c = getc(stdin);
    if (c == EOF)
      break;
    text ~= c;
  }
  return text;
}

/// Available commands.
const char[] COMMANDS =
  "  compile (c)\n"
  "  ddoc (d)\n"
  "  help (?)\n"
  "  highlight (hl)\n"
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

/// Creates the global compilation context.
CompilationContext newCompilationContext()
{
  auto cc = new CompilationContext;
  cc.importPaths = GlobalSettings.importPaths;
  cc.addVersionId("dil");
  cc.addVersionId("all");
version(D2)
  cc.addVersionId("D_Version2");
  foreach (versionId; GlobalSettings.versionIds)
    if (Lexer.isValidUnreservedIdentifier(versionId))
      cc.addVersionId(versionId);
  return cc;
}

/// Parses a debug or version command line option.
bool parseDebugOrVersion(string arg, CompilationContext context)
{
  if (strbeg(arg, "-debug"))
  {
    if (arg.length > 7)
    {
      auto val = arg[7..$];
      if (isdigit(val[0]))
        context.debugLevel = Integer.toInt(val);
      else if (Lexer.isValidUnreservedIdentifier(val))
        context.addDebugId(val);
    }
    else
      context.debugLevel = 1;
  }
  else if (arg.length > 9 && strbeg(arg, "-version="))
  {
    auto val = arg[9..$];
    if (isdigit(val[0]))
      context.versionLevel = Integer.toInt(val);
    else if (Lexer.isValidUnreservedIdentifier(val))
      context.addVersionId(val);
  }
  else
    return false;
  return true;
}

/// Prints the errors collected in infoMan.
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
    else if (info.classinfo is Warning.classinfo)
      errorFormat = "{0}: Warning: {3}";
    else if (info.classinfo is dil.Information.Error.classinfo)
      errorFormat = "Error: {3}";
    else
      continue;
    auto err = cast(Problem)info;
    Stderr.formatln(errorFormat, err.filePath, err.loc, err.col, err.getMsg);
  }
}

/// Prints the help message of a command.
/// If the command wasn't found, the main help message is printed.
void printHelp(char[] command)
{
  char[] msg;
  switch (command)
  {
  case "c", "compile":
    msg = `Compile D source files.
Usage:
  dil compile file.d [file2.d, ...] [Options]

  This command only parses the source files and does little semantic analysis.
  Errors are printed to standard error output.

Options:
  -d               : accept deprecated code
  -debug           : include debug code
  -debug=level     : include debug(l) code where l <= level
  -debug=ident     : include debug(ident) code
  -version=level   : include version(l) code where l >= level
  -version=ident   : include version(ident) code
  -Ipath           : add 'path' to the list of import paths
  -release         : compile a release build
  -unittest        : compile a unittest build

  -ps              : print the symbol tree of the modules
  -pm              : print the package/module tree

Example:
  dil c src/main.d -Isrc/`;
    break;
  case "ddoc", "d":
    msg = `Generate documentation from DDoc comments in D source files.
Usage:
  dil ddoc Destination file.d [file2.d, ...] [Options]

  Destination is the folder where the documentation files are written to.
  Files with the extension .ddoc are recognized as macro definition files.

Options:
  --xml            : write XML instead of HTML documents
  -i               : include undocumented symbols
  -v               : verbose output

Example:
  dil d doc/ src/main.d src/macros_dil.ddoc -i`;
    break;
  case "hl", "highlight":
//     msg = GetMsg(MID.HelpGenerate);
    msg = `Highlight a D source file with XML or HTML tags.
Usage:
  dil hl file.d [Options]

Options:
  --syntax         : generate tags for the syntax tree
  --xml            : use XML format (default)
  --html           : use HTML format
  --lines          : print line numbers

Example:
  dil hl src/main.d --html --syntax > main.html`;
    break;
  case "importgraph", "igraph":
//     msg = GetMsg(MID.HelpImportGraph);
    msg = `Parse a module and build a module dependency graph based on its imports.
Usage:
  dil igraph file.d Format [Options]

  The directory of file.d is implicitly added to the list of import paths.

Format:
  --dot            : generate a dot document (default)
  Options related to --dot:
  -gbp             : Group modules by package names
  -gbf             : Group modules by full package name
  -hle             : highlight cyclic edges in the graph
  -hlv             : highlight modules in cyclic relationships
  -siSTYLE         : the edge style to use for static imports
  -piSTYLE         : the edge style to use for public imports
  STYLE can be: "dashed", "dotted", "solid", "invis" or "bold"

  --paths          : print the file paths of the modules in the graph

  --list           : print the names of the module in the graph
  Options common to --paths and --list:
  -lN              : print N levels.
  -m               : use '*' to mark modules in cyclic relationships

Options:
  -Ipath           : add 'path' to the list of import paths where modules are
                     looked for
  -xREGEXP         : exclude modules whose names match the regular expression
                     REGEXP
  -i               : include unlocatable modules

Example:
  dil igraph src/main.d --list
  dil igraph src/main.d | dot -Tpng > main.png`;
    break;
  case "tok", "tokenize":
    msg = `Print the tokens of a D source file.
Usage:
  dil tok file.d [Options]

Options:
  -               : reads text from the standard input.
  -sSEPARATOR     : print SEPARATOR instead of newline between tokens.
  -i              : ignore whitespace tokens (e.g. comments, shebang etc.)
  -ws             : print a token's preceding whitespace characters.

Example:
  echo "module foo; void func(){}" | dil tok -
  dil tok src/main.d | grep ^[0-9]`;
    break;
  case "stats", "statistics":
    msg = "Gather statistics about D source files.
Usage:
  dil stat file.d [file2.d, ...] [Options]

Options:
  --toktable      : print the count of all kinds of tokens in a table.
  --asttable      : print the count of all kinds of nodes in a table.

Example:
  dil stat src/main.d src/dil/Unicode.d";
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
  case "main":
  default:
    auto COMPILED_WITH = __VENDOR__;
    auto COMPILED_VERSION = Format("{}.{,:d3}", __VERSION__/1000, __VERSION__%1000);
    auto COMPILED_DATE = __TIMESTAMP__;
    msg = FormatMsg(MID.HelpMain, VERSION, COMMANDS, COMPILED_WITH,
                    COMPILED_VERSION, COMPILED_DATE);
  }
  Stdout(msg).newline;
}
