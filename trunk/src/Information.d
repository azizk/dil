/++
  Author: Aziz Köksal
  License: GPL2
+/
module Information;
import Messages;
import std.string;

enum Type
{
  Lexer,
  Parser,
  Semantic
}

class Information
{
  MID id;
  Type type;
  uint loc;
  string[] arguments;

  this(Type type, MID id, uint loc, string[] arguments)
  {
    this.id = id;
    this.type = type;
    this.loc = loc;
    this.arguments = arguments;
  }

  string getMsg()
  {
    char[] msg = messages[id];

    if (arguments.length == 0)
      return msg;

    foreach (i, arg; arguments)
      msg = replace(msg, format("{%s}", i+1), arg);

    return msg;
  }
}

