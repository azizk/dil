/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.FileBOM;
import common;

/// Enumeration of byte order marks.
enum BOM
{
  None,    /// No BOM
  UTF8,    /// UTF-8: EF BB BF
  UTF16BE, /// UTF-16 Big Endian: FE FF
  UTF16LE, /// UTF-16 Little Endian: FF FE
  UTF32BE, /// UTF-32 Big Endian: 00 00 FE FF
  UTF32LE  /// UTF-32 Little Endian: FF FE 00 00
}

/// Looks at the first bytes of data and returns the corresponding BOM.
BOM tellBOM(ubyte[] data)
{
  BOM bom = BOM.None;
  if (data.length < 2)
    return bom;

  if (data[0..2] == cast(ubyte[2])x"FE FF")
  {
    bom = BOM.UTF16BE; // FE FF
  }
  else if (data[0..2] == cast(ubyte[2])x"FF FE")
  {
    if (data.length >= 4 && data[2..4] == cast(ubyte[2])x"00 00")
      bom = BOM.UTF32LE; // FF FE 00 00
    else
      bom = BOM.UTF16LE; // FF FE XX XX
  }
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
  Stdout("Testing function tellBOM().\n");

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
    {cast(ub)x"FF FE 00 00", BOM.UTF32LE}
  ];

  foreach (pair; map)
    assert(tellBOM(pair.data) == pair.bom, Format("Failed at {0}", pair.data));
}
