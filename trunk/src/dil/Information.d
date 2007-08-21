/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Information;
import dil.Messages;
import std.stdarg;

enum InfoType
{
  Lexer,
  Parser,
  Semantic
}

class Information
{
  MID id;
  InfoType type;
  uint loc;
  string[] arguments;

  this(InfoType type, MID id, uint loc, string[] arguments)
  {
    this.id = id;
    this.type = type;
    this.loc = loc;
    this.arguments = arguments;
  }

  string getMsg()
  {
    return format_args(GetMsg(id), arguments);
  }
}
