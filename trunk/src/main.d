/++
  Author: Aziz Köksal
  License: GPL2
+/
module dparser;
import Lexer;
import Token;
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

void main(char[][] args)
{
  auto srctext = cast(char[]) std.file.read(args[1]);
  auto lx = new Lexer(srctext, args[1]);

  auto tokens = lx.getTokens();
  char* end = lx.text.ptr;

  writef(`<?xml version="1.0"?>
<?xml-stylesheet href="format.css" type="text/css"?>
<sourcetext>`);
  foreach(ref token; tokens)
  {
    if (end != token.start)
      writef("%s", xmlescape(end[0 .. token.start - end]));
    string span = xmlescape(token.span);
    switch(token.type)
    {
      case TOK.Identifier:
        writef("<i>%s</i>", span);
      break;
      case TOK.Comment:
        writef("<c>%s</c>", span);
      break;
      case TOK.String:
        writef("<sl>%s</sl>", span);
      break;
      case TOK.Character:
        writef("<cl>%s</cl>", span);
      break;
      case TOK.DivisionAssign:
        writef("<op>%s</op>", span);
      break;
      case TOK.AndLogical:
        writef("<op>∧</op>");
      break;
      case TOK.OrLogical:
        writef("<op>∨</op>");
      break;
//       case TOK.NotEqual:
//         writef("<op>≠</op>");
//       break;
      case TOK.Number:
        writef("<n>%s</n>", span);
      break;
      case TOK.LParen, TOK.RParen, TOK.LBracket,
           TOK.RBracket, TOK.LBrace, TOK.RBrace:
        writef("<br>%s</br>", span);
      break;
      case TOK.EOF: break;
      default:
        if (token.isKeyword())
          writef("<k>%s</k>", span);
        else
          writef("%s", span);
    }
    end = token.end;
  }
  writef("\n</sourcetext>");
}