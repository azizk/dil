/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.SourceText;

import dil.i18n.Messages;
import dil.Converter,
       dil.Diagnostics;
import util.Path;
import common;

import std.file;

/// Represents D source code.
///
/// The source text may come from a file or from a memory buffer.
final class SourceText
{
  /// The file path to the source text. Mainly used for error messages.
  cstring filePath;
  cstring data; /// The UTF-8, zero-terminated source text.
  /// The data member must be terminated with this string.
  /// Four zeros are used to make certain optimizations possible in the Lexer.
  static immutable  sentinelString = "\0\0\0\0";
  /// True when the text has no invalid UTF8 sequences.
  //bool isValidUTF8; // TODO: could this be useful?

  /// Constructs a SourceText object.
  /// Params:
  ///   filePath = File path to the source file.
  ///   loadFile = Whether to load the file in the constructor.
  this(cstring filePath, bool loadFile = false)
  {
    this.filePath = filePath;
    loadFile && load();
  }

  /// Constructs a SourceText object.
  /// Params:
  ///   filePath = File path for error messages.
  ///   data = Memory buffer (may be terminated with sentinelString.)
  this(cstring filePath, cstring data)
  {
    this(filePath);
    addSentinelString(data);
    this.data = data;
  }

  /// Returns a slice to the source text, excluding the sentinel string.
  cstring text()
  {
    return data[0..$-4];
  }

  /// Loads the source text from a file.
  /// Returns: true for success, false on failure.
  bool load(Diagnostics diag = null)
  {
    if (!diag)
      diag = new Diagnostics();
    assert(filePath.length);

    scope(failure)
    {
      auto loc = new Location(filePath, 0);
      auto mid = Path(this.filePath).exists() ?
        MID.CantReadFile : MID.InexistantFile;
      diag ~= new LexerError(loc, diag.msg(mid));
      data = sentinelString.dup;
      return false;
    }

    // Read the file.
    auto rawdata = cast(ubyte[])filePath.read();
    // Convert the data.
    auto converter = Converter(filePath, diag);
    cstring text = converter.data2UTF8(rawdata);
    addSentinelString(text);
    this.data = text;
    return true;
  }

  /// Appends the sentinel string to the text (if not already there.)
  static void addSentinelString(ref cstring text)
  {
    if (text.length < 4 ||
        // Same as: text[$-4..$] != sentinelString
        *cast(uint*)(text.ptr+text.length-4) != 0)
      text ~= sentinelString;
  }
}
