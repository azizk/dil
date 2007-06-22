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
  auto lx = new Lexer(srctext);

  auto tokens = lx.getTokens();
  char* end = lx.text.ptr;

  writef(`<?xml version="1.0"?>
<?xml-stylesheet href="format.css" type="text/css"?>
<sourcetext>`);
  foreach(ref token; tokens)
  {
    if (end != token.start)
      writef("%s", xmlescape(end[0 .. token.start - end]));
    char[] span = xmlescape(token.start[0 .. token.end-token.start]);
    switch(token.type)
    {
      case TOK.Identifier:
        writef("<i>%s</i>", span);
      break;
      case TOK.Whitespace:
        writef(span);
      break;
      case TOK.Comment:
        writef("<c>%s</c>", span);
      break;
      default:
    }
    end = token.end;
  }
  writef("</sourcetext>");
}