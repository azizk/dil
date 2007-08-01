/++
  Author: Aziz Köksal
  License: GPL3
+/
module Information;
import Messages;
import std.string;
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
    char[] msg = messages[id];

    if (arguments.length == 0)
      return msg;

    foreach (i, arg; arguments)
      msg = replace(msg, format("{%s}", i+1), arg);

    return msg;
  }
}

char[][] arguments(TypeInfo[] tinfos, void* argptr)
{
  char[][] args;
  foreach (ti; tinfos)
  {
    if (ti == typeid(char[]))
      args ~= format(va_arg!(char[])(argptr));
    else if (ti == typeid(int))
      args ~= format(va_arg!(int)(argptr));
    else if (ti == typeid(dchar))
      args ~= format(va_arg!(dchar)(argptr));
    else
      assert(0, "argument type not supported yet.");
  }
  return args;
}
