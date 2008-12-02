/// Author: Aziz Köksal
/// License: GPL3
module dil.Converter;

import dil.lexer.Funcs;
import dil.Diagnostics;
import dil.Location;
import dil.Unicode;
import dil.FileBOM;
import dil.Messages;
import common;

/// Converts various Unicode encoding formats to UTF-8.
struct Converter
{
  char[] filePath; /// For error messages.
  Diagnostics diag;

  static Converter opCall(char[] filePath, Diagnostics diag)
  {
    Converter conv;
    conv.filePath = filePath;
    conv.diag = diag;
    return conv;
  }

  /// Byte-swaps c.
  dchar swapBytes(dchar c)
  {
    return c = (c << 24) |
               (c >> 24) |
              ((c >> 8) & 0xFF00) |
              ((c << 8) & 0xFF0000);
  }

  /// Byte-swaps c.
  wchar swapBytes(wchar c)
  {
    return (c << 8) | (c >> 8);
  }

  /// Swaps the bytes of c on a little-endian machine.
  dchar BEtoMachineDword(dchar c)
  {
    version(LittleEndian)
      return swapBytes(c);
    else
      return c;
  }

  /// Swaps the bytes of c on a big-endian machine.
  dchar LEtoMachineDword(dchar c)
  {
    version(LittleEndian)
      return c;
    else
      return swapBytes(c);
  }

  /// Swaps the bytes of c on a little-endian machine.
  wchar BEtoMachineWord(wchar c)
  {
    version(LittleEndian)
      return swapBytes(c);
    else
      return c;
  }

  /// Swaps the bytes of c on a big-endian machine.
  wchar LEtoMachineWord(wchar c)
  {
    version(LittleEndian)
      return c;
    else
      return swapBytes(c);
  }

  /// Converts a UTF-32 text to UTF-8.
  char[] UTF32toUTF8(bool isBigEndian)(ubyte[] data)
  {
    if (data.length == 0)
      return null;

    char[] result;
    uint lineNum = 1;
    dchar[] text = cast(dchar[]) data[0 .. $-($%4)]; // Trim to multiple of 4.
    foreach (dchar c; text)
    {
      static if (isBigEndian)
        c = BEtoMachineDword(c);
      else
        c = LEtoMachineDword(c);

      if (!isValidChar(c))
      {
        diag ~= new LexerError(
          new Location(filePath, lineNum),
          Format(MSG.InvalidUTF32Character, c)
        );
        c = REPLACEMENT_CHAR;
      }

      if (isNewline(c))
        ++lineNum;
      dil.Unicode.encode(result, c);
    }

    if (data.length % 4)
      diag ~= new LexerError(
        new Location(filePath, lineNum),
        MSG.UTF32FileMustBeDivisibleBy4
      );

    return result;
  }

  alias UTF32toUTF8!(true) UTF32BEtoUTF8; /// Instantiation for UTF-32 BE.
  alias UTF32toUTF8!(false) UTF32LEtoUTF8; /// Instantiation for UTF-32 LE.

  /// Converts a UTF-16 text to UTF-8.
  char[] UTF16toUTF8(bool isBigEndian)(ubyte[] data)
  {
    if (data.length == 0)
      return null;

    wchar[] text = cast(wchar[]) data[0 .. $-($%2)]; // Trim to multiple of two.
    wchar* p = text.ptr,
         end = text.ptr + text.length;
    char[] result;
    uint lineNum = 1;

    for (; p < end; p++)
    {
      dchar c = *p;
      static if (isBigEndian)
        c = BEtoMachineWord(c);
      else
        c = LEtoMachineWord(c);

      if (0xD800 > c || c > 0xDFFF)
      {}
      else if (c <= 0xDBFF && p+1 < end)
      { // Decode surrogate pairs.
        wchar c2 = p[1];
        static if (isBigEndian)
          c2 = BEtoMachineWord(c2);
        else
          c2 = LEtoMachineWord(c2);

        if (0xDC00 <= c2 && c2 <= 0xDFFF)
        {
          c = (c - 0xD7C0) << 10;
          c |= (c2 & 0x3FF);
          ++p;
        }
      }
      else
      {
        diag ~= new LexerError(
          new Location(filePath, lineNum),
          Format(MSG.InvalidUTF16Character, c)
        );
        c = REPLACEMENT_CHAR;
      }

      if (isNewline(c))
        ++lineNum;
      dil.Unicode.encode(result, c);
    }

    if (data.length % 2)
      diag ~= new LexerError(
        new Location(filePath, lineNum),
        MSG.UTF16FileMustBeDivisibleBy2
      );
    return result;
  }

  alias UTF16toUTF8!(true) UTF16BEtoUTF8; /// Instantiation for UTF-16 BE.
  alias UTF16toUTF8!(false) UTF16LEtoUTF8; /// Instantiation for UTF-16 LE.

  /// Converts the text in data to UTF-8.
  /// Leaves data unchanged if it is in UTF-8 already.
  char[] data2UTF8(ubyte[] data)
  {
    if (data.length == 0)
      return "";

    char[] text;
    BOM bom = tellBOM(data);

    switch (bom)
    {
    case BOM.None:
      // No BOM found. According to the specs the first character
      // must be an ASCII character.
      if (data.length >= 4)
      {
        if (data[0..3] == cast(ubyte[3])x"00 00 00")
        {
          text = UTF32BEtoUTF8(data); // UTF-32BE: 00 00 00 XX
          break;
        }
        else if (data[1..4] == cast(ubyte[3])x"00 00 00")
        {
          text = UTF32LEtoUTF8(data); // UTF-32LE: XX 00 00 00
          break;
        }
      }
      if (data.length >= 2)
      {
        if (data[0] == 0) // UTF-16BE: 00 XX
        {
          text = UTF16BEtoUTF8(data);
          break;
        }
        else if (data[1] == 0) // UTF-16LE: XX 00
        {
          text = UTF16LEtoUTF8(data);
          break;
        }
      }
      text = cast(char[])data; // UTF-8
      break;
    case BOM.UTF8:
      text = cast(char[])data[3..$];
      break;
    case BOM.UTF16BE:
      text = UTF16BEtoUTF8(data[2..$]);
      break;
    case BOM.UTF16LE:
      text = UTF16LEtoUTF8(data[2..$]);
      break;
    case BOM.UTF32BE:
      text = UTF32BEtoUTF8(data[4..$]);
      break;
    case BOM.UTF32LE:
      text = UTF32LEtoUTF8(data[4..$]);
      break;
    default:
      assert(0);
    }
    return text;
  }
}

/// Replaces invalid UTF-8 sequences with U+FFFD (if there's enough space,)
/// and Newlines with '\n'.
char[] sanitizeText(char[] text)
{
  if (!text.length)
    return null;

  char* p = text.ptr; // Reader.
  char* end = p + text.length;
  char* q = p; // Writer.

  for (; p < end; p++, q++)
  {
    assert(q <= p);
    if (isascii(*p)) {
      *q = *p; // Just copy ASCII characters.
      continue;
    }
    switch (*p)
    {
    case '\r':
      if (p+1 < end && p[1] == '\n')
        p++;
    case '\n':
      *q = '\n'; // Copy newlines as '\n'.
      continue;
    default:
      if (p+2 < end && isUnicodeNewline(p))
      {
        p += 2;
        goto case '\n';
      }

      auto p2 = p; // Remember beginning of the UTF-8 sequence.
      dchar c = decode(p, end);

      if (c == ERROR_CHAR)
      { // Skip to next ASCII character or valid UTF-8 sequence.
        while (++p < end && isTrailByte(*p))
        {}
        alias REPLACEMENT_STR R;
        if (q+2 < p) // Copy replacement char if there is enough space.
          (*q = R[0]), (*++q = R[1]), (*++q = R[2]);
        p--;
      }
      else
      { // Copy the valid UTF-8 sequence.
        while (p2 < p) // p points to one past the last trail byte.
          *q++ = *p2++; // Copy code units.
        q--;
        p--;
      }
    }
  }
  assert(p == end);
  text.length = q - text.ptr;
  return text;
}

unittest
{
  Stdout("Testing function Converter.\n");
  struct Data2Text
  {
    char[] text;
    char[] expected = "source";
    ubyte[] data()
    { return cast(ubyte[])text; }
  }
  const Data2Text[] map = [
    // Without BOM
    {"source"},
    {"s\0o\0u\0r\0c\0e\0"},
    {"\0s\0o\0u\0r\0c\0e"},
    {"s\0\0\0o\0\0\0u\0\0\0r\0\0\0c\0\0\0e\0\0\0"},
    {"\0\0\0s\0\0\0o\0\0\0u\0\0\0r\0\0\0c\0\0\0e"},
    // With BOM
    {"\xEF\xBB\xBFsource"},
    {"\xFE\xFF\0s\0o\0u\0r\0c\0e"},
    {"\xFF\xFEs\0o\0u\0r\0c\0e\0"},
    {"\x00\x00\xFE\xFF\0\0\0s\0\0\0o\0\0\0u\0\0\0r\0\0\0c\0\0\0e"},
    {"\xFF\xFE\x00\x00s\0\0\0o\0\0\0u\0\0\0r\0\0\0c\0\0\0e\0\0\0"},
  ];
  auto converter = Converter("", new Diagnostics);
  foreach (i, pair; map)
    assert(converter.data2UTF8(pair.data) == pair.expected, Format("failed at item {}", i));
}
