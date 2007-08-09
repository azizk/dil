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

char[] xmlescape(char[] text)
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
import Declarations, SyntaxTree;
void main(char[][] args)
{
  auto srctext = cast(char[]) std.file.read(args[1]);
  auto parser = new Parser(srctext, args[1]);
  parser.start();
  auto decls = parser.parseModule();

void print(Node[] decls, char[] indent)
{
  foreach(decl; decls)
  {
    assert(decl !is null);
    writefln(indent, decl.classinfo.name, ":", decl.children.length);
    print(decl.children, indent ~ "  ");
  }
}
print(decls, "");
foreach (error; parser.errors)
{
  writefln(`%s(%d)P: %s`, parser.lx.fileName, error.loc, error.getMsg);
}
std.c.stdlib.exit(0);

  auto lx = new Lexer(srctext, args[1]);

  auto tokens = lx.getTokens();
  char* end = lx.text.ptr;

  writef(`<?xml version="1.0"?>
<?xml-stylesheet href="format.css" type="text/css"?>
<root>
<compilerinfo>`\n);
  foreach (error; lx.errors)
  {
    writefln(`<error t="%s">%s(%d): %s</error>`, "l", lx.fileName, error.loc, error.getMsg);
  }
  writef(`</compilerinfo>
<sourcetext>`);
  foreach (ref token; tokens)
  {
    if (end != token.start)
      writef("%s", xmlescape(end[0 .. token.start - end]));
    string srcText = xmlescape(token.srcText);
    switch(token.type)
    {
      case TOK.Identifier:
        writef("<i>%s</i>", srcText);
      break;
      case TOK.Comment:
        string c;
        switch (token.start[1])
        {
        case '/': c = "lc"; break;
        case '*': c = "bc"; break;
        case '+': c = "nc"; break;
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
      case TOK.Assign, TOK.Equal,
        TOK.Less, TOK.Greater,
        TOK.LShiftAssign, TOK.LShift,
        TOK.RShiftAssign, TOK.RShift,
        TOK.URShiftAssign, TOK.URShift,
        TOK.OrAssign, TOK.OrBinary,
        TOK.AndAssign, TOK.AndBinary,
        TOK.PlusAssign, TOK.PlusPlus, TOK.Plus,
        TOK.MinusAssign, TOK.MinusMinus, TOK.Minus,
        TOK.DivAssign, TOK.Div,
        TOK.MulAssign, TOK.Mul,
        TOK.ModAssign, TOK.Mod,
        TOK.XorAssign, TOK.Xor,
        TOK.CatAssign, TOK.Catenate,
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
      case TOK.EOF: break;
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