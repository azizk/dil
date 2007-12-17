/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Information;

import dil.Messages;
import common;

public import dil.Location;

class Information
{

}

class InfoManager
{
  Information[] info;

  void opCatAssign(Information info)
  {
    this.info ~= info;
  }
}

class Problem : Information
{
  Location location;
  uint column; /// Cache variable for column.
  string message;

  this(Location location, string message)
  {
    assert(location !is null);
    this.location = location;
    this.message = message;
  }

  string getMsg()
  {
    return this.message;
  }

  /// Returns the line of code.
  size_t loc()
  {
    return location.lineNum;
  }

  /// Returns the column.
  size_t col()
  {
    if (column == 0)
      column = location.calculateColumn();
    return column;
  }

  /// Returns the file path.
  string filePath()
  {
    return location.filePath;
  }
}

class Warning : Problem
{
  this(Location location, string message)
  {
    super(location, message);
  }
}

class Error : Problem
{
  this(Location location, string message)
  {
    super(location, message);
  }
}

class LexerError : Error
{
  this(Location location, string message)
  {
    super(location, message);
  }
}

class ParserError : Error
{
  this(Location location, string message)
  {
    super(location, message);
  }
}

class SemanticError : Error
{
  this(Location location, string message)
  {
    super(location, message);
  }
}
