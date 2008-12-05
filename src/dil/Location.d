/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.Location;

import dil.lexer.Funcs;
import dil.Unicode;

/// Represents a location in a source text.
final class Location
{
  char[] filePath; /// The file path.
  size_t lineNum; /// The line number.
  char* lineBegin, to; /// Used to calculate the column.

  static uint TAB_WIDTH = 4; /// The default width of the tabulator character.

  /// Forwards the parameters to the second constructor.
  this(char[] filePath, size_t lineNum)
  {
    set(filePath, lineNum);
  }

  /// Constructs a Location object.
  this(char[] filePath, size_t lineNum, char* lineBegin, char* to)
  {
    set(filePath, lineNum, lineBegin, to);
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

  /// Uses a simple method to count the number of characters in a string.
  ///
  /// Note: Unicode compound characters and other special characters are not
  /// taken into account.
  /// Params:
  ///   tabWidth = the width of the tabulator character.
  uint calculateColumn(uint tabWidth = Location.TAB_WIDTH)
  {
    uint col;
    auto p = lineBegin;
    if (!p)
      return 0;
    for (; p <= to; p++)
    {
      assert(delegate ()
        {
          // Check that there is no newline between p and to.
          // But 'to' may point to a newline.
          if (p != to && isNewline(*p))
            return false;
          if (to-p >= 2 && isUnicodeNewline(p))
            return false;
          return true;
        }() == true
      );

      // Skip this byte if it is a trail byte of a UTF-8 sequence.
      if (isTrailByte(*p))
        continue; // *p == 0b10xx_xxxx

      // Only count ASCII characters and the first byte of a UTF-8 sequence.
      if (*p == '\t')
        col += tabWidth;
      else
        col++;
    }
    return col;
  }
  alias calculateColumn colNum;
}
