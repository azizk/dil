/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
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
       dil.semantic.Passes;
import dil.code.Interpreter;
import dil.translator.German;
import dil.Messages;
import dil.CompilerInfo;
import dil.Diagnostics;
import dil.SourceText;
import dil.Compilation;

import cmd.Compile;
import cmd.Highlight;
import cmd.Statistics;
import cmd.ImportGraph;
import cmd.DDoc;
import dil.PyTreeEmitter;

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

/// Entry function of dil.
void main(char[][] args)
{
  auto diag = new Diagnostics();
  ConfigLoader(diag, args[0]).load();
  if (diag.hasInfo)
    return printErrors(diag);

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
    cmd.diag = diag;

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
    diag.hasInfo && printErrors(diag);
    break;
  case "pytree", "py":
    if (args.length < 4)
      return printHelp(command);
    auto dest = args[2];
    string[] filePaths;
    string format = "d_{0}.py";
    bool verbose;
    // Parse arguments.
    bool skip;
    args = args[3..$];
    foreach (i, arg; args)
    {
      if (skip)
        skip = false;
      else if (strbeg(arg, "--fmt="))
        format = arg[6..$];
      else if (arg == "--fmt" && i+1 != args.length) {
        format = args[i+1];
        skip = true; // Skip next argument.
      }
      else if (arg == "-v")
        verbose = true;
      else
        filePaths ~= arg;
    }

    // Execute the command.
    foreach (path; filePaths)
    {
      auto modul = new Module(path, diag);
      modul.parse();
      if (!modul.hasErrors)
      {
        auto py = new PyTreeEmitter(modul);
        auto modFQN = replace(modul.getFQN().dup, '.', '_');
        auto pckgName = replace(modul.packageName.dup, '.', '_');
        auto modName = modul.moduleName;
        auto fileName = Format(format, modFQN, pckgName, modName);
        if (verbose)
          Stdout(path~" > "~dest~"/"~fileName).newline;
        auto f = new File(dest~"/"~fileName, File.WriteCreate);
        f.write(py.emit());
      }
    }
    diag.hasInfo && printErrors(diag);
    break;
  case "ddoc", "d":
    if (args.length < 4)
      return printHelp(command);

    DDocCommand cmd;
    cmd.destDirPath = args[2];
    cmd.macroPaths = GlobalSettings.ddocFilePaths;
    cmd.context = newCompilationContext();
    cmd.diag = diag;

    // Parse arguments.
    foreach (arg; args[3..$])
    {
      if (parseDebugOrVersion(arg, cmd.context))
      {}
      else if (arg == "--xml")
        cmd.writeXML = true;
      else if (arg == "--raw")
        cmd.rawOutput = true;
      else if (arg == "-hl")
        cmd.writeHLFiles = true;
      else if (arg == "-i")
        cmd.includeUndocumented = true;
      else if (arg == "-v")
        cmd.verbose = true;
      else if (arg == "--kandil")
        cmd.useKandil = true;
      else if (arg == "--report")
        cmd.writeReport = true;
      else if(strbeg(arg, "-rx="))
        cmd.regexps ~= new Regex(arg[4..$]);
      else if (arg.length > 3 && strbeg(arg, "-m="))
        cmd.modsTxtPath = arg[3..$];
      else if (arg.length > 5 && icompare(arg[$-4..$], "ddoc") == 0)
        cmd.macroPaths ~= arg;
      else
        cmd.filePaths ~= arg;
    }
    cmd.run();
    diag.hasInfo && printErrors(diag);
    break;
  case "hl", "highlight":
    if (args.length < 3)
      return printHelp(command);

    HighlightCommand cmd;
    cmd.diag = diag;

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

    diag = new Diagnostics();
    auto lx = new Lexer(sourceText, diag);
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
  case "trans", "translate":
    if (args.length < 3)
      return printHelp(command);

    if (args[2] != "German")
      return Stdout.formatln("Error: unrecognized target language \"{}\"", args[2]);

    diag = new Diagnostics();
    auto filePath = args[3];
    auto mod = new Module(filePath, diag);
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
    char[][] filePaths;
    if (args[2] == "dstress")
    {
      auto text = cast(char[]) File.get("dstress_files");
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
  case "settings", "set":
    alias GlobalSettings GS;
    char[] versionIds, importPaths, ddocPaths;
    foreach (item; GS.versionIds)
      versionIds ~= item ~ ";";
    foreach (item; GS.importPaths)
      importPaths ~= item ~ ";";
    foreach (item; GS.ddocFilePaths)
      ddocPaths ~= item ~ ";";
    string[string] settings = ["DATADIR"[]:GS.dataDir, "VERSION_IDS":versionIds,
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
      foreach (name; retrieve_settings) {
        name = toUpper(name);
        if (name in settings)
          Stdout.formatln("{}={}", name, settings[name]);
      }
    else // Print all settings.
      foreach (name; ["DATADIR", "VERSION_IDS", "IMPORT_PATHS", "DDOC_FILES",
          "LANG_FILE", "XML_MAP", "HTML_MAP", "LEXER_ERROR",
          "PARSER_ERROR", "SEMANTIC_ERROR", "TAB_WIDTH"])
        Stdout.formatln("{}={}", name, settings[name]);
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
  "  help (?)\n"
  "  compile (c)\n"
  "  ddoc (d)\n"
  "  highlight (hl)\n"
  "  importgraph (igraph)\n"
  "  python (py)\n"
  "  settings (set)\n"
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

/// Prints the errors collected in diag.
void printErrors(Diagnostics diag)
{
  foreach (info; diag.info)
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
  -32              : produce 32 bit code (default)
  -64              : produce 64 bit code
  -ofPROG          : output program to PROG

  -ps              : print the symbol tree of the modules
  -pm              : print the package/module tree

Example:
  dil c src/main.d -Isrc/`;
    break;
  case "py", "python":
    msg = `Write a D parse tree to a Python source file.
Usage:
  dil python Destination file.d [file2.d, ...] [Options]

Options:
  --tokens         : only emit a list of the tokens (N/A yet)
  --fmt            : the format string for the destination file names
                     Default: d_{0}.py
                     {0} = fully qualified module name (e.g. dil_PyTreeEmitter)
                     {1} package name (e.g. dil, dil_ast, dil_lexer etc.)
                     {2} module name (e.g. PyTreeEmitter)
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
  -v               : verbose output
  -m=PATH          : write list of processed modules to PATH
  -version=ident   : see "dil help compile" for more details

Example:
  dil d doc/ src/main.d data/macros_dil.ddoc -i -m=doc/modules.txt
  dil d tangodoc/ -v -version=Windows -version=Tango -version=DDoc \
        --kandil kandil/kandil.ddoc tangosrc/file_1.d tangosrc/file_n.d`;
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
  dil stats file.d [file2.d, ...] [Options]

Options:
  --toktable      : print the count of all kinds of tokens in a table.
  --asttable      : print the count of all kinds of nodes in a table.

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
    auto COMPILED_WITH = __VENDOR__;
    auto COMPILED_VERSION = Format("{}.{,:d3}", __VERSION__/1000, __VERSION__%1000);
    auto COMPILED_DATE = __TIMESTAMP__;
    msg = FormatMsg(MID.HelpMain, VERSION, COMMANDS, COMPILED_WITH,
                    COMPILED_VERSION, COMPILED_DATE);
  }
  Stdout(msg).newline;
}
