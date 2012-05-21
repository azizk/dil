/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module main;

import dil.parser.Parser;
import dil.lexer.Lexer,
       dil.lexer.Funcs,
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
import dil.i18n.Messages;
import dil.String,
       dil.Version,
       dil.Diagnostics,
       dil.SourceText,
       dil.Compilation,
       dil.PyTreeEmitter;

import util.Path,
       util.OptParser;

import cmd.Command,
       cmd.Compile,
       cmd.Highlight,
       cmd.Statistics,
       cmd.ImportGraph,
       cmd.DDoc;

import Settings,
       SettingsLoader,
       common;

import Integer = tango.text.convert.Integer;
import tango.stdc.stdio;
import tango.io.device.File;
import tango.text.Util : split;
import tango.text.Regex : Regex;
import tango.time.StopWatch;
import tango.core.Array : sort;

debug
import tango.core.tools.TraceExceptions;

/// Entry function of DIL.
void main(cstring[] args)
{
  version(unittest)
    return; // Don't run anything when unittests are executed.
  if (args.length == 0)
    throw new Exception("main() received 0 arguments");

  // 1. Create a global compilation context.
  auto globalCC = newCompilationContext();
  auto diag = globalCC.diag;
  // 2. Load the configuration file of DIL.
  auto config = ConfigLoader(globalCC, diag, args[0]);
  config.load();
  if (config.resourceBundle)
    diag.bundle = config.resourceBundle;

  if (diag.hasInfo())
    return printErrors(diag);
  if (args.length <= 1)
    return printHelp("main", diag);

  // 3. Execute a command.
  auto op = new OptParser(args[2..$]);
  cstring command = args[1];

  switch (command)
  {
  case "c2":
  case "c", "compile":
    if (!op.hasArgs())
      return printHelp(command, diag);
    bool useCommand2 = command == "c2";

    auto cmd = new CompileCommand();
    cmd.context = globalCC;
    cmd.diag = diag;
    cstring value;

    op.add({ return parseDebugOrVersion(op, cmd.context); });
    op.add("-I", value, { cmd.context.importPaths ~= value; });
    op.add("-J", value, { cmd.context.includePaths ~= value; });
    op.add("-release", cmd.context.releaseBuild);
    op.add("-unittest", cmd.context.unittestBuild, {
      version(D2)
        cmd.context.addVersionId("unittest");
    });
    op.add("-d", cmd.context.acceptDeprecated);
    op.add("-ps", cmd.printSymbolTree);
    op.add("-pm", cmd.printModuleTree);
    op.add("-v", cmd.verbose);
    op.parseArgs();
    cmd.filePaths = op.argv; // Remaining arguments are file paths.

    Command cmd_ = cmd;
    if (useCommand2)
    { // Temporary code to test CompileCommand2.
      auto cmd2 = new CompileCommand2();
      cmd2.cc = cmd.context;
      cmd2.filePaths = cmd.filePaths;
      cmd2.mm = cmd.moduleMan;
      cmd2.verbose = cmd.verbose;
      cmd_ = cmd2;
    }

    cmd_.run();

    diag.hasInfo() && printErrors(diag);
    break;
  case "pytree", "py":
    if (op.argv.length < 2)
      return printHelp(command, diag);

    class PyTreeCommand : Command
    {
      CompilationContext cc;
      Path dest;
      cstring format = "d_{0}.py";
      cstring[] filePaths;

      void run()
      {
        foreach (path; filePaths)
        {
          auto modul = new Module(path, cc);
          lzy(log("parse: {}", path));
          modul.parse();
          if (modul.hasErrors())
            continue;
          auto py = new PyTreeEmitter(modul);
          auto modFQN = modul.getFQN().replace('.', '_');
          auto pckgName = modul.packageName.replace('.', '_');
          auto modName = modul.moduleName;
          auto fileName = Format(format, modFQN, pckgName, modName);
          auto destPath = (dest/fileName).toString;
          lzy(log("emit:  {}", destPath));
          auto f = new File(destPath, File.WriteCreate);
          f.write(py.emit());
        }
      }
    }

    auto cmd = new PyTreeCommand();
    cmd.dest = Path(op.getArg());
    cmd.cc = globalCC;

    op.add("--fmt", cmd.format);
    op.add("-v", cmd.verbose);
    op.parseArgs();
    cmd.filePaths = op.argv; // Remaining arguments are file paths.

    cmd.run();

    diag.hasInfo() && printErrors(diag);
    break;
  case "ddoc", "d":
    if (op.argv.length < 2)
      return printHelp(command, diag);

    auto cmd = new DDocCommand();
    cmd.destDirPath = op.getArg();
    cmd.context = globalCC;
    cmd.diag = diag;
    cstring value;

    // Parse arguments.
    op.add({ return parseDebugOrVersion(op, cmd.context); });
    op.add("--xml", cmd.writeXML);
    op.add("--raw", cmd.rawOutput);
    op.add("-hl", cmd.writeHLFiles);
    op.add("-i", cmd.includeUndocumented);
    op.add("--inc-private", cmd.includePrivate);
    op.add("-v", cmd.verbose);
    op.add("--kandil", cmd.useKandil);
    op.add("--report", cmd.writeReport);
    op.add("-rx", value, { cmd.regexps ~= new Regex(value); });
    op.add("-m", cmd.modsTxtPath);
    op.parseArgs();
    foreach (arg; op.argv)
      if (arg.length > 6 && String(arg[$-5..$]).icmp(String(".ddoc")) == 0)
        cmd.macroPaths ~= arg;
      else
        cmd.filePaths ~= arg;

    cmd.run();
    diag.hasInfo() && printErrors(diag);
    break;
  case "hl", "highlight":
    if (!op.hasArgs())
      return printHelp(command, diag);

    auto cmd = new HighlightCommand();
    cmd.cc = globalCC;
    cmd.diag = diag;

    bool dummy;
    alias HighlightCommand.Option HO;

    op.add("--syntax", dummy, { cmd.add(HO.Syntax); });
    op.add("--xml", dummy, { cmd.add(HO.XML); });
    op.add("--html", dummy, { cmd.add(HO.HTML); });
    op.add("--lines", dummy, { cmd.add(HO.PrintLines); });
    op.parseArgs();
    foreach (arg; op.argv)
      if (!cmd.filePathSrc)
        cmd.filePathSrc = arg;
      else
        cmd.filePathDest = arg;

    cmd.run();
    diag.hasInfo() && printErrors(diag);
    break;
  case "importgraph", "igraph":
    if (!op.hasArgs())
      return printHelp(command, diag);

    auto cmd = new IGraphCommand();
    cmd.context = globalCC;

    cstring value;
    bool dummy;
    alias IGraphCommand.Option IO;

    op.add({ return parseDebugOrVersion(op, cmd.context); });
    op.add("-I", value, { cmd.context.importPaths ~= value; });
    op.add("-x", value, { cmd.regexps ~= value; });
    op.add("-l", value, { cmd.levels = Integer.toInt(value); });
    op.add("-si", value, { cmd.siStyle = value; });
    op.add("-pi", value, { cmd.piStyle = value; });
    op.add("--dot", dummy,   { cmd.add(IO.PrintDot); });
    op.add("--paths", dummy, { cmd.add(IO.PrintPaths); });
    op.add("--list", dummy,  { cmd.add(IO.PrintList); });
    op.add("--hle", dummy,   { cmd.add(IO.HighlightCyclicEdges); });
    op.add("--hlv", dummy,   { cmd.add(IO.HighlightCyclicVertices); });
    op.add("--gbp", dummy,   { cmd.add(IO.GroupByPackageNames); });
    op.add("--gbf", dummy,   { cmd.add(IO.GroupByFullPackageName); });
    op.add("-i", dummy,      { cmd.add(IO.IncludeUnlocatableModules); });
    op.add("-m", dummy,      { cmd.add(IO.MarkCyclicModules); });
    op.add({ cmd.filePath = op.getArg(); return true; });
    op.parseArgs();

    cmd.run();
    diag.hasInfo() && printErrors(diag);
    break;
  case "stats", "statistics":
    if (!op.hasArgs())
      return printHelp(command, diag);

    auto cmd = new StatsCommand();
    cmd.cc = globalCC;

    op.add("--toktable", cmd.printTokensTable);
    op.add("--asttable", cmd.printNodesTable);
    op.parseArgs();
    cmd.filePaths = op.argv;

    cmd.run();
    break;
  case "tok", "tokenize":
    if (!op.hasArgs())
      return printHelp(command, diag);

    class TokenizeCommand : Command
    {
      CompilationContext cc;
      cstring srcFilePath;
      cstring separator = "\n";
      bool ignoreWSToks, printWS, fromStdin;

      void run()
      {
        auto sourceText = fromStdin ?
          new SourceText("stdin", readStdin()) :
          new SourceText(srcFilePath, true);

        auto lx = new Lexer(sourceText, cc.tables.lxtables, cc.diag);
        lx.scanAll();

        if (cc.diag.hasInfo())
          return;

        auto token = lx.firstToken();
        for (; token.kind != TOK.EOF; token = token.next)
        {
          if (token.kind == TOK.Newline || ignoreWSToks && token.isWhitespace)
            continue;
          if (printWS && token.ws)
            Stdout(token.wsChars);
          Stdout(token.text)(separator);
        }
      }
    }

    auto cmd = new TokenizeCommand();
    cmd.cc = globalCC;

    op.add("-s", cmd.separator);
    op.add("-", cmd.fromStdin);
    op.add("-i", cmd.ignoreWSToks);
    op.add("-ws", cmd.printWS);
    op.add({ cmd.srcFilePath = op.getArg(); return true; });
    op.parseArgs();

    if (op.error)
      return printUsageError(op);

    cmd.run();

    diag.hasInfo() && printErrors(diag);
    break;
  case "dlexed", "dlx":
    if (!op.hasArgs())
      return printHelp(command, diag);

    class SerializeCommand : Command
    {
      CompilationContext cc;
      cstring srcFilePath, outFilePath;
      bool fromStdin;

      void run()
      {
        auto sourceText = fromStdin ?
          new SourceText("stdin", readStdin()) :
          new SourceText(srcFilePath, true);

        auto lx = new Lexer(sourceText, cc.tables.lxtables, cc.diag);
        lx.scanAll();

        if (cc.diag.hasInfo())
          return;

        auto data = TokenSerializer.serialize(lx.firstToken());
        if (outFilePath.length)
        {
          scope file = new File(outFilePath, File.WriteCreate);
          file.write(data);
          file.close();
        }
        else
          Stdout(cast(cstring)data);
      }
    }

    auto cmd = new SerializeCommand();
    cmd.cc = globalCC;

    op.add("-", cmd.fromStdin);
    op.add("-o", cmd.outFilePath);
    op.add({ cmd.srcFilePath = op.getArg(); return true; });
    op.parseArgs();

    cmd.run();

    diag.hasInfo() && printErrors(diag);
    break;
  case "trans", "translate":
    if (!op.hasArgs())
      return printHelp(command, diag);

    if (args[2] != "German")
      return cast(void)Stdout.formatln(
        "Error: unrecognized target language ‘{}’", args[2]);

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
    if (!op.hasArgs())
      break;
    cstring[] filePaths;
    if (args[2] == "dstress")
    {
      auto text = cast(cstring) File.get("dstress_files");
      filePaths = split(text, "\0");
    }
    else
      filePaths = args[2..$];

    auto tables = globalCC.tables.lxtables;

    StopWatch swatch;
    swatch.start;

    foreach (filePath; filePaths)
      (new Lexer(new SourceText(filePath, true), tables)).scanAll();

    Stdout.formatln("Scanned in {:f10}s.", swatch.stop);
    break;
  case "settings", "set":
    alias GlobalSettings GS;
    cstring versionIds, importPaths, ddocPaths;
    foreach (item; GS.versionIds)
      versionIds ~= item ~ ";";
    foreach (item; GS.importPaths)
      importPaths ~= item ~ ";";
    foreach (item; GS.ddocFilePaths)
      ddocPaths ~= item ~ ";";

    cstring[string] settings = [
      "DATADIR":GS.dataDir, "VERSION_IDS":versionIds,
      "KANDILDIR":GS.kandilDir,
      "IMPORT_PATHS":importPaths, "DDOC_FILES":ddocPaths,
      "LANG_FILE":GS.langFile, "XML_MAP":GS.xmlMapFile,
      "HTML_MAP":GS.htmlMapFile, "LEXER_ERROR":GS.lexerErrorFormat,
      "PARSER_ERROR":GS.parserErrorFormat,
      "SEMANTIC_ERROR":GS.semanticErrorFormat,
      "TAB_WIDTH":Format("{}", GS.tabWidth)
    ];

    cstring[] retrieve_settings;
    if (args.length > 2)
      retrieve_settings = args[2..$];

    if (retrieve_settings.length) // Print select settings.
      foreach (name; retrieve_settings)
      {
        if (auto psetting = (name = String(name).toupper().array) in settings)
          Stdout.formatln("{}={}", name, *psetting);
      }
    else // Print all settings.
    {
      auto names = settings.keys;
      names.sort((string a, string b){ return a < b; });
      foreach (name; names)
        Stdout.formatln("{}={}", name, settings[name]);
    }
    break;
  case "?", "h", "help":
    printHelp(op.hasArgs() ? op.getArg() : "", diag);
    break;
  case "-v", "v", "--version", "version":
    Stdout(VERSION).newline;
    break;
  default:
    printHelp("main", diag);
  }
}

/// Prints a command usage error.
void printUsageError(OptParser op)
{
  Printfln("Usage error:\n  {}", op.error);
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
enum string COMMANDS =
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
  "  translate (trans)\n"
  "  version (v)\n";

/// Creates the global compilation context.
CompilationContext newCompilationContext()
{
  auto cc = new CompilationContext;
  cc.importPaths = GlobalSettings.importPaths;
  cc.addVersionId("DIL");
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
  cstring val;
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
    cstring errorFormat;
    auto tid = typeid(info);
    if (tid is typeid(LexerError))
      errorFormat = GlobalSettings.lexerErrorFormat;
    else if (tid is typeid(ParserError))
      errorFormat = GlobalSettings.parserErrorFormat;
    else if (tid is typeid(SemanticError))
      errorFormat = GlobalSettings.semanticErrorFormat;
    else if (tid is typeid(Warning))
      errorFormat = "{0}: Warning: {3}";
    else if (tid is typeid(GeneralError))
      errorFormat = "Error: {3}";
    else
      continue;
    auto err = cast(Problem)info;
    Stderr.formatln(errorFormat, err.filePath, err.loc, err.col, err.getMsg);
  }
}

/// Prints the help message of a command.
/// If the command wasn't found, the main help message is printed.
void printHelp(cstring command, Diagnostics diag)
{
  cstring msg;
  MID mid;
  switch (command)
  {
  case "c", "compile":          mid = MID.HelpCompile;     goto Lcommon;
  case "py", "pytree":          mid = MID.HelpPytree;      goto Lcommon;
  case "ddoc", "d":             mid = MID.HelpDdoc;        goto Lcommon;
  case "hl", "highlight":       mid = MID.HelpHighlight;   goto Lcommon;
  case "importgraph", "igraph": mid = MID.HelpImportGraph; goto Lcommon;
  case "tok", "tokenize":       mid = MID.HelpTokenize;    goto Lcommon;
  case "dlexed", "dlx":         mid = MID.HelpDlexed;      goto Lcommon;
  case "stats", "statistics":   mid = MID.HelpStatistics;  goto Lcommon;
  case "trans", "translate":    mid = MID.HelpTranslate;   goto Lcommon;
  case "settings", "set":       mid = MID.HelpSettings;    goto Lcommon;
  case "?", "h", "help":        mid = MID.HelpHelp;        goto Lcommon;
  Lcommon:
    msg = diag.formatMsg(mid);
    break;
  case "main", "":
    auto COMPILED_WITH = __VENDOR__;
    auto COMPILED_VERSION = diag.format("{}.{,:d3}",
      __VERSION__/1000, __VERSION__%1000);
    auto COMPILED_DATE = __TIMESTAMP__;
    msg = diag.formatMsg(MID.HelpMain, VERSION, COMMANDS,
      COMPILED_WITH, COMPILED_VERSION, COMPILED_DATE);
    break;
  default:
    msg = diag.formatMsg(MID.UnknownCommand, command);
  }
  Stdout(msg).newline;
}
