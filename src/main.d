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
       dil.ast.Visitor,
       dil.ast.ASTPrinter,
       dil.ast.ASTSerializer;
import dil.semantic.Module,
       dil.semantic.Symbols,
       dil.semantic.Pass1,
       dil.semantic.Pass2,
       dil.semantic.Passes;
import dil.code.Interpreter;
import dil.translator.PyTreeEmitter;
import dil.i18n.Messages;
import dil.String,
       dil.Version,
       dil.Diagnostics,
       dil.SourceText,
       dil.Compilation;

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

import std.file,
       std.conv,
       std.datetime,
       std.regex;

debug
import tango.core.tools.TraceExceptions;

alias toInt = to!int;

/// Entry function of DIL.
void main(cstring[] args)
{
  debug if (args.length >= 2 && args[1] == "unittests")
    return runUnittests();

  if (args.length == 0)
    throw new Exception("main() received 0 arguments");

  // 1. Create a global compilation context.
  auto globalCC = newCompilationContext();
  auto diag = globalCC.diag;
  // 2. Load the configuration file of DIL.
  auto config = ConfigLoader(globalCC, diag, args[0]);
  config.load();
  diag.bundle = config.resourceBundle;
  updateWithSettings(globalCC);

  if (diag.hasInfo())
    return printErrors(diag);
  if (args.length <= 1)
    return printHelp("main", diag);

  // 3. Execute a command.
  auto op = new OptParser(args[2..$]);
  op.missingArgMessage = diag.bundle.msg(MID.MissingOptionArgument);
  op.usageErrorMessage = diag.bundle.msg(MID.UsageError);
  cstring command = args[1];

  switch (command)
  {
  case "c2":
  case "c", "compile":
    if (!op.hasArgs)
      return printHelp(command, diag);
    bool useCommand2 = command == "c2";

    auto cmd = new CompileCommand();
    auto cc = cmd.context = globalCC;
    cmd.diag = diag;
    cstring value;

    op.add({ return parseDebugOrVersion(op, cc); });
    op.add("-I", value, { cc.importPaths ~= value; });
    op.add("-J", value, { cc.includePaths ~= value; });
    op.add("-m32", cmd.m32);
    op.add("-m64", cmd.m64);
    op.add("-of", value, { cmd.binOutput = value; });
    op.add("-release", cc.releaseBuild);
    op.add("-unittest", cc.unittestBuild, {
      version(D2)
        cc.addVersionId("unittest");
    });
    op.add("-d", cc.acceptDeprecated);
    op.add("-ps", cmd.printSymbolTree);
    op.add("-pm", cmd.printModuleTree);
    op.add("-v", cmd.verbose);
    if (!op.parseArgs())
      return op.printUsageError();

    cmd.filePaths = op.argv; // Remaining arguments are file paths.

    Command cmd_ = cmd;
    if (useCommand2)
    { // Temporary code to test CompileCommand2.
      auto cmd2 = new CompileCommand2();
      cmd2.cc = cc;
      cmd2.filePaths = cmd.filePaths;
      cmd2.mm = cmd.moduleMan;
      cmd2.verbose = cmd.verbose;
      cmd_ = cmd2;
    }

    // TODO:
    //if (cmd.m32)
    //{
    //  cc.removeVersionId("D_InlineAsm_X86_64");
    //  cc.removeVersionId("X86_64");
    //  cc.addVersionId("D_InlineAsm_X86");
    //  cc.addVersionId("X86");
    //}
    //if (cmd.m64)
    //{
    //  cc.addVersionId("D_InlineAsm_X86_64");
    //  cc.addVersionId("X86_64");
    //  cc.removeVersionId("D_InlineAsm_X86");
    //  cc.removeVersionId("X86");
    //}

    cmd_.run();

    diag.hasInfo() && printErrors(diag);
    break;
  case "print":
    if (!op.hasArgs)
      return printHelp(command, diag);
    cstring path;
    op.addDefault({ path = op.popArg(); });
    op.parseArgs();
    auto m = new Module(path, globalCC);
    m.parse();
    if (!m.hasErrors())
    {
      auto ap = new ASTPrinter(true, globalCC);
      auto text = ap.print(m.root);
      Printfln("{}", text);
    }
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

      override void run()
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
          destPath.write(py.emit());
        }
      }
    }

    auto cmd = new PyTreeCommand();
    cmd.dest = Path(op.popArg());
    cmd.cc = globalCC;

    op.add("--fmt", cmd.format);
    op.add("-v", cmd.verbose);
    if (!op.parseArgs())
      return op.printUsageError();
    cmd.filePaths = op.argv; // Remaining arguments are file paths.

    cmd.run();

    diag.hasInfo() && printErrors(diag);
    break;
  case "ddoc", "d":
    if (op.argv.length < 2)
      return printHelp(command, diag);

    auto cmd = new DDocCommand();
    cmd.destDirPath = op.popArg();
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
    op.add("-rx", value, { cmd.regexps ~= regex(value); });
    op.add("-m", cmd.modsTxtPath);
    if (!op.parseArgs())
      return op.printUsageError();
    foreach (arg; op.argv)
      if (arg.length > 6 && String(arg[$-5..$]).ieql(".ddoc"))
        cmd.macroPaths ~= arg;
      else
        cmd.filePaths ~= arg;

    cmd.run();
    diag.hasInfo() && printErrors(diag);
    break;
  case "hl", "highlight":
    if (!op.hasArgs)
      return printHelp(command, diag);

    auto cmd = new HighlightCommand();
    cmd.cc = globalCC;
    cmd.diag = diag;

    bool dummy;
    alias HO = HighlightCommand.Option;

    op.add("--syntax", dummy, { cmd.add(HO.Syntax); });
    op.add("--xml", dummy, { cmd.add(HO.XML); });
    op.add("--html", dummy, { cmd.add(HO.HTML); });
    op.add("--lines", dummy, { cmd.add(HO.PrintLines); });
    if (!op.parseArgs())
      return op.printUsageError();
    foreach (arg; op.argv)
      if (!cmd.filePathSrc)
        cmd.filePathSrc = arg;
      else
        cmd.filePathDest = arg;

    cmd.run();
    diag.hasInfo() && printErrors(diag);
    break;
  case "importgraph", "igraph":
    if (!op.hasArgs)
      return printHelp(command, diag);

    auto cmd = new IGraphCommand();
    cmd.context = globalCC;

    cstring value;
    bool dummy;
    alias IO = IGraphCommand.Option;

    op.add({ return parseDebugOrVersion(op, cmd.context); });
    op.add("-I", value, { cmd.context.importPaths ~= value; });
    op.add("-x", value, { cmd.regexps ~= value; });
    op.add("-l", value, { cmd.levels = toInt(value); });
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
    op.addDefault({ cmd.filePath = op.popArg(); });
    if (!op.parseArgs())
      return op.printUsageError();

    cmd.run();
    diag.hasInfo() && printErrors(diag);
    break;
  case "stats", "statistics":
    if (!op.hasArgs)
      return printHelp(command, diag);

    auto cmd = new StatsCommand();
    cmd.cc = globalCC;

    op.add("--toktable", cmd.printTokensTable);
    op.add("--asttable", cmd.printNodesTable);
    if (!op.parseArgs())
      return op.printUsageError();
    cmd.filePaths = op.argv;

    cmd.run();
    break;
  case "tok", "tokenize":
    if (!op.hasArgs)
      return printHelp(command, diag);

    class TokenizeCommand : Command
    {
      CompilationContext cc;
      cstring srcFilePath;
      cstring separator = "\n";
      bool ignoreWSToks, printWS, fromStdin;

      override void run()
      {
        auto sourceText = fromStdin ?
          new SourceText("stdin", readStdin()) :
          new SourceText(srcFilePath, true);

        auto lx = new Lexer(sourceText, cc.tables.lxtables, cc.diag);
        lx.scanAll();

        if (cc.diag.hasInfo())
          return;

        foreach (token; lx.tokenList[0..$-1])
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
    op.addDefault({ cmd.srcFilePath = op.popArg(); });
    if (!op.parseArgs())
      return op.printUsageError();

    cmd.run();

    diag.hasInfo() && printErrors(diag);
    break;
  case "dlexed", "dlx":
    if (!op.hasArgs)
      return printHelp(command, diag);

    class SerializeCommand : Command
    {
      CompilationContext cc;
      cstring srcFilePath, outFilePath;
      bool fromStdin;

      override void run()
      {
        auto sourceText = fromStdin ?
          new SourceText("stdin", readStdin()) :
          new SourceText(srcFilePath, true);

        auto lx = new Lexer(sourceText, cc.tables.lxtables, cc.diag);
        lx.scanAll();

        if (cc.diag.hasInfo())
          return;

        auto data = TokenSerializer.serialize(lx.tokenList);
        if (outFilePath.length)
          outFilePath.write(data);
        else
          Stdout(cast(cstring)data);
      }
    }

    auto cmd = new SerializeCommand();
    cmd.cc = globalCC;

    op.add("-", cmd.fromStdin);
    op.add("-o", cmd.outFilePath);
    op.addDefault({ cmd.srcFilePath = op.popArg(); });
    if (!op.parseArgs())
      return op.printUsageError();

    cmd.run();

    diag.hasInfo() && printErrors(diag);
    break;
  case "serialize", "sz":
    if (!op.hasArgs)
      return printHelp(command, diag);

    class SerializeASTCommand : Command
    {
      CompilationContext cc;
      cstring srcFilePath, outFilePath;
      bool fromStdin;

      override void run()
      {
        auto sourceText = fromStdin ?
          new SourceText("stdin", readStdin()) :
          new SourceText(srcFilePath, true);

        auto mod = new Module(sourceText, cc);
        mod.parse();

        if (cc.diag.hasInfo())
          return;

        auto astWriter = new ASTSerializer();
        const data = astWriter.serialize(mod);

        if (outFilePath.length)
          outFilePath.write(data);
        else
          Stdout(cast(cstring)data);
      }
    }

    auto cmd = new SerializeASTCommand();
    cmd.cc = globalCC;

    op.add("-", cmd.fromStdin);
    op.add("-o", cmd.outFilePath);
    op.addDefault({ cmd.srcFilePath = op.popArg(); });
    if (!op.parseArgs())
      return op.printUsageError();

    cmd.run();

    diag.hasInfo() && printErrors(diag);
    break;
  case "profile":
    if (!op.hasArgs)
      break;
    const(String)[] filePaths = (args[2] == "dstress") ?
      String(cast(cstring)"dstress_files".read()).split('\0') :
      toStrings(args[2..$]);

    auto tables = globalCC.tables.lxtables;

    auto mt = measureTime!((swatch){
      Printfln("Scanned in {}ms.", swatch.msecs);
    });

    foreach (filePath; filePaths)
      new Lexer(new SourceText(filePath[], true), tables).scanAll();
    break;
  case "settings", "set":
    alias GS = GlobalSettings;
    cstring
      versionIds = String(";").join(GS.versionIds)[],
      importPaths = String(";").join(GS.importPaths)[],
      ddocPaths = String(";").join(GS.ddocFilePaths)[];

    cstring[string] settings = [
      "DIL":config.executablePath,
      "DILCONF":config.dilconfPath,
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
        if (auto psetting = (name = String(name).toupper()[]) in settings)
          Printfln("{}={}", name, *psetting);
      }
    else // Print all settings.
      foreach (name; settings.keys.sort)
        Printfln("{}={}", name, settings[name]);
    break;
  case "?", "h", "help":
    printHelp(op.hasArgs ? op.popArg() : "", diag);
    break;
  case "-v", "v", "--version", "version":
    Stdout(VERSION).newline;
    break;
  default:
    printHelp("main", diag);
  }
}

/// Reads the standard input and returns its contents.
char[] readStdin()
{
  import std.stdio;
  char[] text;
  foreach (buffer; stdin.byChunk(4096))
    text ~= buffer;
  return text;
}

/// Available commands.
enum string COMMANDS =
  "  help (?)
  compile (c)
  ddoc (d)
  dlexed (dlx)
  highlight (hl)
  importgraph (igraph)
  pytree (py)
  serialize (sz)
  settings (set)
  statistics (stats)
  tokenize (tok)
  version (v)";

/// Creates the global compilation context.
CompilationContext newCompilationContext()
{
  /// Generates code: Adds a version id to a list if defined.
  /// E.g.: version(X86) ids ~= "X86";
  char[] defineVersionIds(string[] ids...)
  {
    char[] code;
    foreach (id; ids)
      code ~= "version(" ~ id ~ ") ids ~= \"" ~ id ~ "\";";
    return code;
  }

  auto cc = new CompilationContext;
  string[] ids = ["DIL", "all"];
  mixin(defineVersionIds(
    "Windows", "Win32", "Win64", "linux", "OSX", "FreeBSD", "OpenBSD", "BSD",
    "Solaris", "Posix", "AIX", "SkyOS", "SysV3", "SysV4", "Hurd", "Android",
    "Cygwin", "MinGW", "X86", "X86_64", "ARM", "PPC", "PPC64", "IA64", "MIPS",
    "MIPS64", "SPARC", "SPARC64", "S390", "S390X", "HPPA", "HPPA64", "SH",
    "SH64", "Alpha", "LittleEndian", "BigEndian", "D_InlineAsm_X86",
    "D_InlineAsm_X86_64", "D_LP64", "D_PIC", "D_SIMD"
  ));
version(D2)
  ids ~= "D_Version2";
  foreach (id; ids)
    cc.addVersionId(id);
  return cc;
}

/// Updates cc with variables from GlobalSettings.
void updateWithSettings(CompilationContext cc)
{
  cc.importPaths = GlobalSettings.importPaths;
  foreach (versionId; GlobalSettings.versionIds)
    if (cc.tables.idents.isValidUnreservedIdentifier(versionId))
      cc.addVersionId(versionId);
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
      context.debugLevel = toInt(val);
    else if (context.tables.idents.isValidUnreservedIdentifier(val))
      context.addDebugId(val);
  }
  else if (op.parse("-version", val))
  {
    if (val.length && isdigit(val[0]))
      context.versionLevel = toInt(val);
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
  case "serialize", "sz":       mid = MID.HelpSerialize;   goto Lcommon;
  case "stats", "statistics":   mid = MID.HelpStatistics;  goto Lcommon;
  case "settings", "set":       mid = MID.HelpSettings;    goto Lcommon;
  case "?", "h", "help":        mid = MID.HelpHelp;        goto Lcommon;
  Lcommon:
    msg = diag.msg(mid);
    break;
  case "main", "":
    const COMPILED_WITH = __VENDOR__;
    const COMPILED_VERSION = (V => V[0] ~ "." ~ V[1..4])(itoa(__VERSION__));
    const COMPILED_DATE = __TIMESTAMP__;
    msg = diag.formatMsg(MID.HelpMain, VERSION, COMMANDS, COMPILED_WITH,
      COMPILED_VERSION, COMPILED_DATE);
    break;
  default:
    msg = diag.formatMsg(MID.UnknownCommand, command);
  }
  Stdout(msg).newline;
}

void runUnittests()
{
  import cmd.ImportGraph,
         dil.ast.Visitor,
         dil.doc.Macro,
         dil.doc.Parser,
         dil.lexer.Lexer,
         dil.Float,
         dil.Complex,
         dil.Converter,
         dil.FileBOM,
         dil.HtmlEntities,
         dil.String,
         util.uni;

  auto testFuncs = [
    &testGraph, &testFloat, &testComplex, &testConverter,
    &testTellBOM, &testEntity2Unicode, &testString,
    &testVisitor, &testMacroConvert, &testDocParser,
    &testLexer, &testLexerPeek, &testIsUniAlpha,
    &testSet,
  ];

  foreach (testFunc; testFuncs)
    testFunc();
}
