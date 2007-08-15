/++
  Author: Aziz Köksal
  License: GPL3
+/
module dparser;
import Parser;
import Lexer;
import Token;
import Messages;
import std.stdio;
import std.file;
import Settings;
import Declarations, Expressions, SyntaxTree;

void main(char[][] args)
{
  GlobalSettings.load();

  if (args.length <= 1)
    return writefln(format(MID.HelpMain, VERSION, usageHighlight, COMPILED_WITH, COMPILED_VERSION, COMPILED_DATE));

  string command = args[1];
  switch (command)
  {
  case "hl", "highlight":
    if (args.length == 3)
      tokensToXML(args[2]);
    break;
  case "parse":
    if (args.length == 3)
      parse(args[2]);
    break;
  default:
  }
}

void parse(string fileName)
{
  auto sourceText = cast(char[]) std.file.read(fileName);
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

char[] xml_escape(char[] text)
{
  char[] result;
  foreach(c; text)
    switch(c)
    {
      case '<': result ~= "&lt;";  break;
      case '>': result ~= "&gt;";  break;
      case '&': result ~= "&amp;"; break;
      default:  result ~= c;
    }
  return result;
}

void tokensToXML(string fileName)
{
  auto sourceText = cast(char[]) std.file.read(fileName);
  auto lx = new Lexer(sourceText, fileName);

  auto token = lx.getTokens();
  char* end = lx.text.ptr;

  writef(`<?xml version="1.0"?>`
         `<?xml-stylesheet href="format.css" type="text/css"?>`
         `<root>`);
  if (lx.errors.length)
  {
    writefln("<compilerinfo>");
    foreach (error; lx.errors)
    {
      writefln(`<error t="%s">%s(%d): %s</error>`, "l", lx.fileName, error.loc, xml_escape(error.getMsg));
    }
    writefln("</compilerinfo>");
  }
  writef(`<sourcetext>`);

  // Traverse linked list and print tokens.
  while (token.type != TOK.EOF)
  {
    token = token.next;

    // Print whitespace between previous and current token.
    if (end != token.start)
      writef("%s", xml_escape(end[0 .. token.start - end]));

    string srcText = xml_escape(token.srcText);

    switch(token.type)
    {
    case TOK.Identifier:
      writef("<i>%s</i>", srcText);
      break;
    case TOK.Comment:
      string c;
      switch (token.start[1])
      {
      case '/': c = "l"; break;
      case '*': c = "b"; break;
      case '+': c = "n"; break;
      default:
        assert(0);
      }
      writef(`<c c="%s">%s</c>`, c, srcText);
      break;
    case TOK.String:
      writef("<sl>%s</sl>", srcText);
      break;
    case TOK.CharLiteral, TOK.WCharLiteral, TOK.DCharLiteral:
      writef("<cl>%s</cl>", srcText);
      break;
    case TOK.Assign,        TOK.Equal,
         TOK.Less,          TOK.Greater,
         TOK.LShiftAssign,  TOK.LShift,
         TOK.RShiftAssign,  TOK.RShift,
         TOK.URShiftAssign, TOK.URShift,
         TOK.OrAssign,      TOK.OrBinary,
         TOK.AndAssign,     TOK.AndBinary,
         TOK.PlusAssign,    TOK.PlusPlus,   TOK.Plus,
         TOK.MinusAssign,   TOK.MinusMinus, TOK.Minus,
         TOK.DivAssign,     TOK.Div,
         TOK.MulAssign,     TOK.Mul,
         TOK.ModAssign,     TOK.Mod,
         TOK.XorAssign,     TOK.Xor,
         TOK.CatAssign,
         TOK.Tilde,
         TOK.Unordered,
         TOK.UorE,
         TOK.UorG,
         TOK.UorGorE,
         TOK.UorL,
         TOK.UorLorE,
         TOK.LorEorG:
      writef("<op>%s</op>", srcText);
      break;
    case TOK.LorG:
      writef(`<op c="lg">&lt;&gt;</op>`);
      break;
    case TOK.LessEqual:
      writef(`<op c="le">&lt;=</op>`);
      break;
    case TOK.GreaterEqual:
      writef(`<op c="ge">&gt;=</op>`);
      break;
    case TOK.AndLogical:
      writef(`<op c="aa">&amp;&amp;</op>`);
      break;
    case TOK.OrLogical:
      writef(`<op c="oo">||</op>`);
      break;
    case TOK.NotEqual:
      writef(`<op c="ne">!=</op>`);
      break;
    case TOK.Not:
      // Check if this is part of a template instantiation.
      // TODO: comments aren't skipped.
      if (token.prev.type == TOK.Identifier && token.next.type == TOK.LParen)
        goto default;
      writef(`<op c="n">!</op>`);
      break;
    case TOK.Int32, TOK.Int64, TOK.Uint32, TOK.Uint64,
         TOK.Float32, TOK.Float64, TOK.Float80,
         TOK.Imaginary32, TOK.Imaginary64, TOK.Imaginary80:
      writef("<n>%s</n>", srcText);
      break;
    case TOK.LParen, TOK.RParen, TOK.LBracket,
         TOK.RBracket, TOK.LBrace, TOK.RBrace:
      writef("<br>%s</br>", srcText);
      break;
    case TOK.Special:
      writef("<st>%s</st>", srcText);
      break;
    default:
      if (token.isKeyword())
        writef("<k>%s</k>", srcText);
      else
        writef("%s", srcText);
    }
    end = token.end;
  }
  writef("\n</sourcetext>\n</root>");
}