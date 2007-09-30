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

final class Location
{
  char[] filePath;
  size_t lineNum;
  char* lineBegin, to; // Used to calculate column.

  this(char[] filePath, size_t lineNum)
  {
    set(filePath, lineNum);
  }

  this(char[] filePath, size_t lineNum, char* lineBegin, char* to)
  {
    set(filePath, lineNum, lineBegin, to);
  }

  Location clone()
  {
    return new Location(filePath, lineNum, lineBegin, to);
  }

  void set(char[] filePath, size_t lineNum)
  {
    set(filePath, lineNum, null, null);
  }

  void set(char[] filePath, size_t lineNum, char* lineBegin, char* to)
  {
    this.filePath  = filePath;
    set(lineNum, lineBegin, to);
  }

  void set(size_t lineNum, char* lineBegin, char* to)
  {
    assert(lineBegin <= to);
    this.lineNum   = lineNum;
    this.lineBegin = lineBegin;
    this.to        = to;
  }

  void setFilePath(char[] filePath)
  {
    this.filePath = filePath;
  }

  /+
    This is a primitive method to count the number of characters in a string.
    Unicode compound characters and other special characters are not
    taken into account.
  +/
  uint calculateColumn()
  {
    uint col;
    auto p = lineBegin;
    for (; p <= to; ++p)
    {
      assert(delegate ()
        {
          const char[3] LS = \u2028;
          const char[3] PS = \u2029;
          // Check that there is no newline between p and to.
          // But 'to' may point to a newline.
          if (p != to && (*p == '\n' || *p == '\r'))
            return false;
          if (to-p >= 2)
          {
            if (*p == LS[0] && p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
              return false;
          }
          return true;
        }() == true
      );

      // Skip this byte if it is a trail byte of a UTF-8 sequence.
      if (*p & 0x80 && !(*p & 0x40))
        continue; // *p == 0b10xx_xxxx
      // Only count ASCII characters and the first byte of a UTF-8 sequence.
      ++col;
    }
    return col;
  }
}
