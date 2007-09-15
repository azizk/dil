/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Information;
import dil.Messages;
import common;

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
  string message;

  this(InfoType type, MID id, uint loc, string message)
  {
    this.id = id;
    this.type = type;
    this.loc = loc;
    this.message = message;
  }

  string getMsg()
  {
    return this.message;
  }
}
