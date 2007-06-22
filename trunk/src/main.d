/++
  Author: Aziz Köksal
  License: GPL2
+/
module dparser;
import Lexer;
import Token;
import std.stdio;
import std.file;

void main(char[][] args)
{
  auto srctext = cast(char[]) std.file.read(args[1]);
  auto lx = new Lexer(srctext);

  foreach(token; lx.getTokens())
  {
    if (token.type == TOK.Whitespace)
      writefln("%s", token.start[0..token.end-token.start]);
  }
}