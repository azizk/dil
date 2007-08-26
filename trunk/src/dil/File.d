/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.File;
import std.stdio, std.file, std.utf;

/// Loads a file in any valid Unicode format and converts it to UTF-8.
char[] loadFile(char[] fileName)
{
  ubyte[] data = cast(ubyte[]) std.file.read(fileName);
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
        text = toUTF8(cast(dchar[])utf32BEtoLE(data)); // UTF-32BE: 00 00 00 XX
      else if (data[1..4] == cast(ubyte[3])x"00 00 00")
        text = toUTF8(cast(dchar[])data); // UTF-32LE: XX 00 00 00
      else
        text = cast(char[])data; // UTF-8
    }
    else if (data.length >= 2)
    {
      if (data[0] == 0) // UTF-16BE: 00 XX
        text = toUTF8(cast(wchar[])utf16BEtoLE(data));
      else if (data[1] == 0) // UTF-16LE: XX 00
        text = toUTF8(cast(wchar[])data);
      else
        text = cast(char[])data; // UTF-8
    }
    else
      text = cast(char[])data; // UTF-8
    break;
  case BOM.UTF8:
    text = cast(char[])data[3..$];
    break;
  case BOM.UTF16BE:
    text = toUTF8(cast(wchar[])utf16BEtoLE(data[2..$]));
    break;
  case BOM.UTF16LE:
    text = toUTF8(cast(wchar[])data[2..$]);
    break;
  case BOM.UTF32BE:
    text = toUTF8(cast(dchar[])utf32BEtoLE(data[4..$]));
    break;
  case BOM.UTF32LE:
    text = toUTF8(cast(dchar[])data[4..$]);
    break;
  default:
    assert(0);
  }
  assert(text !is null);
  return text;
}

ubyte[] utf16BEtoLE(ubyte[] data)
{
  if (data.length % 2)
    throw new Exception("UTF-16 big endian source file byte length must be divisible by 2.");
  wchar[] result = cast(wchar[]) new ubyte[data.length];
  // BE to LE "1A 2B" -> "2B 1A"
  foreach (i, c; cast(wchar[]) data)
    result[i] = (c << 8) | (c >> 8);
  return cast(ubyte[]) result;
}

ubyte[] utf32BEtoLE(ubyte[] data)
{
  if (data.length % 4)
    throw new Exception("UTF-32 big endian source file byte length must be divisible by 4.");
  dchar[] result = cast(dchar[]) new ubyte[data.length];
  // BE to LE "1A 2B 3C 4D" -> "4D 3C 2B 1A"
  foreach (i, c; cast(dchar[]) data)
    result[i] = ((c & 0xFF) << 24) |
                ((c & 0xFF00) << 16) |
                ((c & 0xFF0000) << 8) |
                 (c & 0xFF000000);
  return cast(ubyte[]) result;
}

/// Byte Order Mark
enum BOM
{
  None,    /// No BOM
  UTF8,    /// UTF-8: EF BB BF
  UTF16BE, /// UTF-16 Big Endian: FE FF
  UTF16LE, /// UTF-16 Little Endian: FF FE
  UTF32BE, /// UTF-32 Big Endian: 00 00 FE FF
  UTF32LE  /// UTF-32 Little Endian: FF FE 00 00
}

BOM tellBOM(ubyte[] data)
{
  BOM bom = BOM.None;
  if (data.length < 2)
    return bom;

  if (data[0..2] == cast(ubyte[2])x"FE FF")
  {
    if (data.length >= 4 && data[2..4] == cast(ubyte[2])x"00 00")
      bom = BOM.UTF32LE; // FE FF 00 00
    else
      bom = BOM.UTF16BE; // FE FF XX XX
  }
  else if (data[0..2] == cast(ubyte[2])x"FF FE")
    bom = BOM.UTF16LE; // FF FE
  else if (data[0..2] == cast(ubyte[2])x"00 00")
  {
    if (data.length >= 4 && data[2..4] == cast(ubyte[2])x"FE FF")
      bom = BOM.UTF32BE; // 00 00 FE FF
  }
  else if (data[0..2] ==  cast(ubyte[2])x"EF BB")
  {
    if (data.length >= 3 && data[2] == '\xBF')
      bom =  BOM.UTF8; // EF BB BF
  }
  return bom;
}

unittest
{
  writefln("Testing function tellBOM().");

  struct Data2BOM
  {
    ubyte[] data;
    BOM bom;
  }
  alias ubyte[] ub;
  const Data2BOM[] map = [
    {cast(ub)x"12",          BOM.None},
    {cast(ub)x"12 34",       BOM.None},
    {cast(ub)x"00 00 FF FE", BOM.None},
    {cast(ub)x"EF BB FF",    BOM.None},

    {cast(ub)x"EF",          BOM.None},
    {cast(ub)x"EF BB",       BOM.None},
    {cast(ub)x"FE",          BOM.None},
    {cast(ub)x"FF",          BOM.None},
    {cast(ub)x"00",          BOM.None},
    {cast(ub)x"00 00",       BOM.None},
    {cast(ub)x"00 00 FE",    BOM.None},

    {cast(ub)x"FE FF 00",    BOM.UTF16BE},
    {cast(ub)x"FE FF 00 FF", BOM.UTF16BE},

    {cast(ub)x"EF BB BF",    BOM.UTF8},
    {cast(ub)x"FE FF",       BOM.UTF16BE},
    {cast(ub)x"FF FE",       BOM.UTF16LE},
    {cast(ub)x"00 00 FE FF", BOM.UTF32BE},
    {cast(ub)x"FE FF 00 00", BOM.UTF32LE}
  ];

  foreach (pair; map)
    assert(tellBOM(pair.data) == pair.bom, std.string.format("Failed at %s", pair.data));
}
