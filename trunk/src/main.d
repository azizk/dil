/++
  Author: Aziz Köksal
  License: GPL3
+/
module main;
import std.stdio;
import dil.Parser;
import dil.Lexer;
import dil.Token;
import dil.Messages;
import dil.Settings;
import dil.Declarations, dil.Expressions, dil.SyntaxTree;
import dil.File;
import cmd.Generate;
import cmd.Statistics;

void main(char[][] args)
{
  GlobalSettings.load();

  if (args.length <= 1)
    return writefln(helpMain());

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
    if (options & DocOption.Syntax)
      syntaxToDoc(fileName, options);
    else
      tokensToDoc(fileName, options);
    break;
  case "stats", "statistics":
    statistics(args[2]);
    break;
  case "parse":
    if (args.length == 3)
      parse(args[2]);
    break;
  case "?", "help":
    if (args.length == 3)
      printHelp(args[2]);
    else
      writefln(helpMain());
    break;
  default:
  }
}

const char[] COMMANDS =
  "  generate (gen)\n"
  "  help (?)\n"
  "  statistics (stats)\n";

char[] helpMain()
{
  return format(MID.HelpMain, VERSION, COMMANDS, COMPILED_WITH, COMPILED_VERSION, COMPILED_DATE);
}

void printHelp(char[] command)
{
  char[] msg;
  switch (command)
  {
  case "gen", "generate":
    msg = GetMsg(MID.HelpGenerate);
    break;
  default:
    msg = helpMain();
  }
  writefln(msg);
}

void parse(string fileName)
{
  auto sourceText = loadFile(fileName);
  auto parser = new Parser(sourceText, fileName);
  parser.start();
  auto root = parser.parseModule();

void print(Node[] decls, char[] indent)
{
  foreach(decl; decls)
  {
    assert(decl !is null);
    writefln(indent, decl.classinfo.name, ": begin=%s end=%s", decl.begin ? decl.begin.srcText : "\33[31mnull\33[0m", decl.end ? decl.end.srcText : "\33[31mnull\33[0m");
    print(decl.children, indent ~ "  ");
  }
}
print(root.children, "");
foreach (error; parser.errors)
{
  writefln(`%s(%d)P: %s`, parser.lx.fileName, error.loc, error.getMsg);
}
}
