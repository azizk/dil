/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module main;

import dil.parser.Parser;
import dil.lexer.Lexer,
       dil.lexer.Token,
       dil.lexer.TokenSerializer;
import dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Node,
       dil.ast.Visitor;
import dil.semantic.Module,
       dil.semantic.Symbols,
       dil.semantic.Pass1,
       dil.semantic.Pass2,
       dil.semantic.Passes;
import dil.code.Interpreter;
import dil.translator.German;
import dil.Messages;
import dil.Version;
import dil.Diagnostics;
import dil.SourceText;
import dil.Compilation;
import dil.PyTreeEmitter;

import util.Path;

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
import tango.io.device.File;
import tango.text.Util;
import tango.text.Regex : Regex;
import tango.time.StopWatch;
import tango.text.Ascii : icompare, toUpper;

debug
import tango.core.tools.TraceExceptions;

/// Entry function of dil.
void main(string[] args)
{
  auto globalCC = newCompilationContext();
  auto diag = globalCC.diag;
  ConfigLoader(globalCC, diag, args[0]).load();
  if (diag.hasInfo)
    return printErrors(diag);

  if (args.length <= 1)
    return printHelp("main");

  OptParser op;
  op.argv = args[2..$];
  string command = args[1];

  switch (command)
  {
  case "c", "compile":
    if (args.length < 3)
      return printHelp(command);

    CompileCommand cmd;
    cmd.context = globalCC;
    cmd.diag = diag;
    string value;

    while (op.hasArgs())
      if (parseDebugOrVersion(op, cmd.context)) {}
      else if (op.parse("-I", value))
        cmd.context.importPaths ~= value;
      else if (op.parse("-release", cmd.context.releaseBuild)) {}
      else if (op.parse("-unittest", cmd.context.unittestBuild)) {
      version(D2)
        cmd.context.addVersionId("unittest");
      }
      else if (op.parse("-d", cmd.context.acceptDeprecated)) {}
      else if (op.parse("-ps", cmd.printSymbolTree)) {}
      else if (op.parse("-pm", cmd.printModuleTree)) {}
      else cmd.filePaths ~= op.getArg();

    cmd.run();
    diag.hasInfo && printErrors(diag);
    break;
  case "pytree", "py":
    if (args.length < 4)
      return printHelp(command);
    auto dest = Path(op.getArg());
    string[] filePaths;
    string format = "d_{0}.py";
    bool verbose;

    while (op.hasArgs())
      if (op.parse("--fmt", format)) {}
      else if (op.parse("-v", verbose)) {}
      else filePaths ~= op.getArg();

    // Execute the command.
    foreach (path; filePaths)
    {
      auto modul = new Module(path, globalCC, diag);
      modul.parse();
      if (!modul.hasErrors)
      {
        auto py = new PyTreeEmitter(modul);
        auto modFQN = replace(modul.getFQN().dup, '.', '_');
        auto pckgName = replace(modul.packageName.dup, '.', '_');
        auto modName = modul.moduleName;
        auto fileName = Format(format, modFQN, pckgName, modName);
        auto destPath = (dest/fileName).toString;
        if (verbose)
          Stdout(path~" > "~destPath).newline;
        auto f = new File(destPath, File.WriteCreate);
        f.write(py.emit());
      }
    }
    diag.hasInfo && printErrors(diag);
    break;
  case "ddoc", "d":
    if (args.length < 4)
      return printHelp(command);

    DDocCommand cmd;
    cmd.destDirPath = op.getArg();
    cmd.context = globalCC;
    cmd.diag = diag;
    string value;

    // Parse arguments.
    while (op.hasArgs())
    {
      if (parseDebugOrVersion(op, cmd.context)) {}
      else if (op.parse("--xml", cmd.writeXML)) {}
      else if (op.parse("--raw", cmd.rawOutput)) {}
      else if (op.parse("-hl", cmd.writeHLFiles)) {}
      else if (op.parse("-i", cmd.includeUndocumented)) {}
      else if (op.parse("--inc-private", cmd.includePrivate)) {}
      else if (op.parse("-v", cmd.verbose)) {}
      else if (op.parse("--kandil", cmd.useKandil)) {}
      else if (op.parse("--report", cmd.writeReport)) {}
      else if (op.parse("-rx", value))
        cmd.regexps ~= new Regex(value);
      else if (op.parse("-m", value))
        cmd.modsTxtPath = value;
      else
      {
        auto arg = op.getArg();
        if (arg.length > 6 && icompare(arg[$-5..$], ".ddoc") == 0)
          cmd.macroPaths ~= arg;
        else
          cmd.filePaths ~= arg;
      }
    }

    cmd.run();
    diag.hasInfo && printErrors(diag);
    break;
  case "hl", "highlight":
    if (args.length < 3)
      return printHelp(command);

    HighlightCommand cmd;
    cmd.cc = globalCC;
    cmd.diag = diag;

    while (op.hasArgs())
    {
      auto arg = op.getArg();
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
        if (!cmd.filePathSrc)
          cmd.filePathSrc = arg;
        else
          cmd.filePathDest = arg;
      }
    }

    cmd.run();
    diag.hasInfo && printErrors(diag);
    break;
  case "importgraph", "igraph":
    if (args.length < 3)
      return printHelp(command);

    IGraphCommand cmd;
    cmd.context = globalCC;
    string value;

    while (op.hasArgs())
    {
      if (parseDebugOrVersion(op, cmd.context)) {}
      else if (op.parse("-I", value))
        cmd.context.importPaths ~= value;
      else if (op.parse("-x", value))
        cmd.regexps ~= value;
      else if (op.parse("-l", value))
        cmd.levels = Integer.toInt(value);
      else if (op.parse("-si", value))
        cmd.siStyle = value;
      else if (op.parse("-pi", value))
        cmd.piStyle = value;
      else
        switch (value = op.getArg())
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
          cmd.filePath = value;
        }
    }

    cmd.run();
    break;
  case "stats", "statistics":
    if (args.length < 3)
      return printHelp(command);

    StatsCommand cmd;
    cmd.cc = globalCC;

    while (op.hasArgs())
      if (op.parse("--toktable", cmd.printTokensTable)) {}
      else if (op.parse("--asttable", cmd.printNodesTable)) {}
      else cmd.filePaths ~= op.getArg();

    cmd.run();
    break;
  case "tok", "tokenize":
    if (args.length < 3)
      return printHelp(command);
    SourceText sourceText;
    string srcFilePath;
    string separator = "\n";
    bool ignoreWSToks, printWS, fromStdin;

    while (op.hasArgs())
      if (op.parse("-s", separator)) {}
      else if (op.parse("-", fromStdin)) {}
      else if (op.parse("-i", ignoreWSToks)) {}
      else if (op.parse("-ws", printWS)) {}
      else srcFilePath = op.getArg();

    sourceText = fromStdin ?
      new SourceText("stdin", readStdin()) :
      new SourceText(srcFilePath, true);


    diag = new Diagnostics();
    auto lx = new Lexer(sourceText, globalCC.tables, diag);
    lx.scanAll();
    auto token = lx.firstToken();

    for (; token.kind != TOK.EOF; token = token.next)
    {
      if (token.kind == TOK.Newline || ignoreWSToks && token.isWhitespace)
        continue;
      if (printWS && token.ws)
        Stdout(token.wsChars);
      Stdout(token.text)(separator);
    }

    diag.hasInfo && printErrors(diag);
    break;
  case "dlexed", "dlx":
    if (args.length < 3)
      return printHelp(command);
    SourceText sourceText;
    string srcFilePath, outFilePath;
    bool fromStdin;

    while (op.hasArgs())
      if (op.parse("-", fromStdin)) {}
      else if (op.parse("-o", outFilePath)) {}
      else srcFilePath = op.getArg();

    sourceText = fromStdin ?
      new SourceText("stdin", readStdin()) :
      new SourceText(srcFilePath, true);

    diag = new Diagnostics();
    auto lx = new Lexer(sourceText, globalCC.tables, diag);
    lx.scanAll();

    if (lx.errors.length || diag.hasInfo)
      printErrors(diag);
    else
    {
      auto data = TokenSerializer.serialize(lx.firstToken());
      if (outFilePath.length)
      {
        scope file = new File(outFilePath, File.WriteCreate);
        file.write(data);
        file.close();
      }
      else
        Stdout(cast(string)data);
    }

    break;
  case "trans", "translate":
    if (args.length < 3)
      return printHelp(command);

    if (args[2] != "German")
      return Stdout.formatln("Error: unrecognized target language \"{}\"", args[2]);

    auto filePath = args[3];
    auto mod = new Module(filePath, globalCC);
    // Parse the file.
    mod.parse();
    if (!mod.hasErrors)
    { // Translate
      auto german = new GermanTranslator(Stdout, "  ");
      german.translate(mod.root);
    }
    printErrors(diag);
    break;
  case "profile":
    if (args.length < 3)
      break;
    string[] filePaths;
    if (args[2] == "dstress")
    {
      auto text = cast(string) File.get("dstress_files");
      filePaths = split(text, "\0");
    }
    else
      filePaths = args[2..$];

    auto tables = globalCC.tables;

    StopWatch swatch;
    swatch.start;

    foreach (filePath; filePaths)
      (new Lexer(new SourceText(filePath, true), tables)).scanAll();

    Stdout.formatln("Scanned in {:f10}s.", swatch.stop);
    break;
  case "settings", "set":
    alias GlobalSettings GS;
    string versionIds, importPaths, ddocPaths;
    foreach (item; GS.versionIds)
      versionIds ~= item ~ ";";
    foreach (item; GS.importPaths)
      importPaths ~= item ~ ";";
    foreach (item; GS.ddocFilePaths)
      ddocPaths ~= item ~ ";";
    string[string] settings = [
      "DATADIR"[]:GS.dataDir, "VERSION_IDS":versionIds,
      "KANDILDIR":GS.kandilDir,
      "IMPORT_PATHS":importPaths, "DDOC_FILES":ddocPaths,
      "LANG_FILE":GS.langFile, "XML_MAP":GS.xmlMapFile,
      "HTML_MAP":GS.htmlMapFile, "LEXER_ERROR":GS.lexerErrorFormat,
      "PARSER_ERROR":GS.parserErrorFormat,
      "SEMANTIC_ERROR":GS.semanticErrorFormat,
      "TAB_WIDTH":Format("{}", GS.tabWidth)
    ];
    string[] retrieve_settings;
    if (args.length > 2)
      retrieve_settings = args[2..$];
    if (retrieve_settings.length) // Print select settings.
      foreach (name; retrieve_settings)
      {
        if (auto psetting = (name = toUpper(name)) in settings)
          Stdout.formatln("{}={}", name, *psetting);
      }
    else // Print all settings.
      foreach (name; ["DATADIR", "VERSION_IDS", "IMPORT_PATHS", "DDOC_FILES",
          "KANDILDIR",
          "LANG_FILE", "XML_MAP", "HTML_MAP", "LEXER_ERROR",
          "PARSER_ERROR", "SEMANTIC_ERROR", "TAB_WIDTH"])
        Stdout.formatln("{}={}", name, settings[name]);
    break;
  case "?", "help":
    printHelp(args.length >= 3 ? args[2] : "");
    break;
  case "-v", "v", "--version", "version":
    Stdout(VERSION).newline;
    break;
  default:
    printHelp("main");
  }
}

/// A command line option parser.
struct OptParser
{
  string[] argv; /// The argument vector.

  /// Parses a parameter.
  bool parse(string param, ref string out_arg)
  {
    if (!hasArgs()) return false;
    auto arg0 = argv[0];
    auto n = param.length;
    if (strbeg(arg0, param))
    {
      if (arg0.length == n) // arg0 == param
      { // Eg: -I /include/path
        if (argv.length <= 1)
          goto Lerr;
        out_arg = argv[1];
        n = 2;
      }
      else
      { // Eg: -I/include/path
        auto skipEqualSign = arg0[n] == '=';
        out_arg = arg0[n + skipEqualSign .. $];
        n = 1;
      }
      consume(n); // Consume n arguments.
      return true;
    }
    return false;
  Lerr:
    return false;
  }

  /// Parses a flag.
  bool parse(string flag, ref bool out_arg)
  {
    if (hasArgs() && argv[0] == flag) {
      out_arg = true;
      consume(1);
      return true;
    }
    return false;
  }

  /// Slices off n elements from argv.
  void consume(size_t n)
  {
    argv = argv[n..$];
  }

  bool hasArgs()
  {
    return argv.length != 0;
  }

  string getArg()
  {
    auto arg = argv[0];
    consume(1);
    return arg;
  }
}

/// Reads the standard input and returns its contents.
string readStdin()
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
const string COMMANDS =
  "  help (?)\n"
  "  compile (c)\n"
  "  ddoc (d)\n"
  "  dlexed (dlx)\n"
  "  highlight (hl)\n"
  "  importgraph (igraph)\n"
  "  pytree (py)\n"
  "  settings (set)\n"
  "  statistics (stats)\n"
  "  tokenize (tok)\n"
  "  translate (trans)\n";

/// Returns true if str starts with s.
bool strbeg(string str, string s)
{
  return str.length >= s.length &&
         str[0 .. s.length] == s;
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
    if (cc.tables.idents.isValidUnreservedIdentifier(versionId))
      cc.addVersionId(versionId);
  return cc;
}

/// Parses a debug or version command line option.
bool parseDebugOrVersion(ref OptParser op, CompilationContext context)
{
  string val;
  if (op.argv[0] == "-debug")
    context.debugLevel = 1;
  else if (op.parse("-debug", val))
  {
    if (val.length && isdigit(val[0]))
      context.debugLevel = Integer.toInt(val);
    else if (context.tables.idents.isValidUnreservedIdentifier(val))
      context.addDebugId(val);
  }
  else if (op.parse("-version", val))
  {
    if (val.length && isdigit(val[0]))
      context.versionLevel = Integer.toInt(val);
    else if (context.tables.idents.isValidUnreservedIdentifier(val))
      context.addVersionId(val);
  }
  else
    return false;
  return true;
}

/// Prints the errors collected in diag.
void printErrors(Diagnostics diag)
{
  foreach (info; diag.info)
  {
    string errorFormat;
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
void printHelp(string command)
{
  string msg;
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
  -32              : produce 32 bit code (default)
  -64              : produce 64 bit code
  -ofPROG          : output program to PROG

  -ps              : print the symbol tree of the modules
  -pm              : print the package/module tree

Example:
  dil c src/main.d -Isrc/`;
    break;
  case "py", "pytree":
    msg = `Exports a D parse tree to a Python source file.
Usage:
  dil pytree Destination file.d [file2.d, ...] [Options]

Options:
  --tokens         : only emit a list of the tokens (N/A yet)
  --fmt            : the format string for the destination file names
                     Default: d_{0}.py
                     {0} = fully qualified module name (e.g. dil_PyTreeEmitter)
                     {1} = package name (e.g. dil, dil_ast, dil_lexer etc.)
                     {2} = module name (e.g. PyTreeEmitter)
  -v               : verbose output

Example:
  dil py pyfiles/ src/dil/PyTreeEmitter.d`;
    break;
  case "ddoc", "d":
    msg = `Generate documentation from DDoc comments in D source files.
Usage:
  dil ddoc Destination file.d [file2.d, ...] [Options]

  Destination is the folder where the documentation files are written to.
  Files with the extension .ddoc are recognized as macro definition files.

Options:
  --kandil         : use kandil as the documentation front-end
  --report         : write a problem report to Destination/report.txt
  -rx=REGEXP       : exclude modules from the report if their names
                     match REGEXP (can be used many times)
  --xml            : write XML instead of HTML documents
  --raw            : don't expand macros in the output (useful for debugging)
  -hl              : write syntax highlighted files to Destination/htmlsrc
  -i               : include undocumented symbols
  --inc-private    : include private symbols
  -v               : verbose output
  -m=PATH          : write list of processed modules to PATH
  -version=ident   : see "dil help compile" for more details

Example:
  dil d doc/ src/main.d data/macros_dil.ddoc -i -m=doc/modules.txt
  dil d tangodoc/ -v -version=Windows -version=Tango \
        --kandil tangosrc/file_1.d tangosrc/file_n.d`;
    break;
  case "hl", "highlight":
//     msg = GetMsg(MID.HelpGenerate);
    msg = `Highlight a D source file with XML or HTML tags.
Usage:
  dil hl file.d [Destination] [Options]

  The file will be output to stdout if 'Destination' is not specified.

Options:
  --syntax         : generate tags for the syntax tree
  --html           : use HTML format (default)
  --xml            : use XML format
  --lines          : print line numbers

Example:
  dil hl src/main.d --syntax > main.html
  dil hl --xml src/main.d main.xml`;
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
  -               : read text from STDIN.
  -sSEPARATOR     : print SEPARATOR instead of '\n' between tokens.
  -i              : ignore whitespace tokens (e.g. comments, shebang etc.)
  -ws             : print a token's preceding whitespace characters.

Example:
  echo 'module foo; void func(){}' | dil tok -
  dil tok src/main.d | grep ^[0-9]`;
    break;
  case "dlexed", "dlx":
    msg = `Write the begin/end indices of all tokens in a binary format.
Usage:
  dil dlx file.d [Options]

Options:
  -               : read text from STDIN.
  -o FILE         : output to FILE instead of STDOUT.

Example:
  echo 'module foo; void func(){}' | dil dlx - > test.dlx
  dil dlx src/main.d -o dlx/main.dlx`;
    break;
  case "stats", "statistics":
    msg = "Gather statistics about D source files.
Usage:
  dil stats file.d [file2.d, ...] [Options]

Options:
  --toktable      : print the count of all token kinds in a table.
  --asttable      : print the count of all node kinds in a table.

Example:
  dil stats src/main.d src/dil/Unicode.d";
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
  case "settings", "set":
    msg = "Print the value of a settings variable.
Usage:
  dil set [name, name2...]

  The names have to match the setting names in dilconf.d.

Example:
  dil set import_paths datadir";
    break;
  case "main":
  default:
    if (command != "" && command != "main")
      msg = Format("Unknown command: ‘{}’", command);
    else
    {
      auto COMPILED_WITH = __VENDOR__;
      auto COMPILED_VERSION = Format("{}.{,:d3}",
        __VERSION__/1000, __VERSION__%1000);
      auto COMPILED_DATE = __TIMESTAMP__;
      msg = FormatMsg(MID.HelpMain, VERSION, COMMANDS, COMPILED_WITH,
                      COMPILED_VERSION, COMPILED_DATE);
    }
  }
  Stdout(msg).newline;
}
