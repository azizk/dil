/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Location;
import dil.LexerFuncs;
import dil.Unicode;
import common;

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

  /++
    This is a primitive method to count the number of characters in a string.
    Unicode compound characters and other special characters are not
    taken into account.
  +/
  uint calculateColumn()
  {
    uint col;
    auto p = lineBegin;
    if (!p)
      return 0;
    for (; p <= to; ++p)
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
      ++col;
    }
    return col;
  }
}
