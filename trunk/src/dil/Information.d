/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Information;
import dil.Messages;
import common;

public import dil.Location;

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
  Location location;
  uint column;
  string message;

  this(InfoType type, MID id, Location location, string message)
  {
    assert(location !is null);
    this.id = id;
    this.type = type;
    this.location = location;
    this.message = message;
  }

  string getMsg()
  {
    return this.message;
  }

  size_t loc()
  {
    return location.lineNum;
  }

  size_t col()
  {
    if (column == 0)
      column = location.calculateColumn();
    return column;
  }

  string filePath()
  {
    return location.filePath;
  }
}

class InformationManager
{
  Information[] info;
}
