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
import dil.Declarations, dil.Expressions, dil.SyntaxTree;
import dil.File;
import cmd.Generate;
import cmd.Statistics;
import cmd.ImportGraph;
import common;

import Integer = tango.text.convert.Integer;

void main(char[][] args)
{
  GlobalSettings.load();

  if (args.length <= 1)
    return Stdout(helpMain()).newline;

  string command = args[1];
  switch (command)
  {
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
        default:
          filePath = arg;
        }
    }
    cmd.ImportGraph.execute(filePath, includePaths, regexps, levels, options);
    break;
  case "stats", "statistics":
    cmd.Statistics.execute(args[2]);
    break;
  case "parse":
    if (args.length == 3)
      parse(args[2]);
    break;
  case "?", "help":
    if (args.length == 3)
      printHelp(args[2]);
    else
      Stdout(helpMain());
    break;
  default:
  }
}

const char[] COMMANDS =
  "  generate (gen)\n"
  "  help (?)\n"
  "  importgraph (igraph)\n"
  "  statistics (stats)\n";

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
  case "gen", "generate":
    msg = GetMsg(MID.HelpGenerate);
    break;
  case "importgraph", "igraph":
    msg = GetMsg(MID.HelpImportGraph);
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
//     writefln(indent, decl.classinfo.name, ": begin=%s end=%s", decl.begin ? decl.begin.srcText : "\33[31mnull\33[0m", decl.end ? decl.end.srcText : "\33[31mnull\33[0m");
    print(decl.children, indent ~ "  ");
  }
}
print(root.children, "");
foreach (error; parser.errors)
{
  Stdout.format(`{0}({1})P: {2}`, parser.lx.fileName, error.loc, error.getMsg);
}
}
