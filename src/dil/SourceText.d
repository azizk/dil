/// Author: Aziz Köksal
/// License: GPL3
module dil.SourceText;

import dil.Converter;
import dil.Information;
import dil.Location;
import dil.Messages;
import common;

import tango.io.File,
       tango.io.FilePath;

/// Represents D source code.
///
/// The source text may come from a file or from a memory buffer.
final class SourceText
{
  string filePath; /// The file path to the source text. Mainly used for error messages.
  char[] data; /// The UTF-8, zero-terminated source text.

  /// Constructs a SourceText object.
  /// Params:
  ///   filePath = file path to the source file.
  ///   loadFile = whether to load the file in the constructor.
  this(string filePath, bool loadFile = false)
  {
    this.filePath = filePath;
    loadFile && load();
  }

  /// Constructs a SourceText object.
  /// Params:
  ///   filePath = file path for error messages.
  ///   data = memory buffer.
  this(string filePath, char[] data)
  {
    this(filePath);
    this.data = data;
    addSentinelCharacter();
  }

  /// Loads the source text from a file.
  void load(Diagnostics diag = null)
  {
    if (!diag)
      diag = new Diagnostics;
    assert(filePath.length);

    scope(failure)
    {
      if (!(new FilePath(this.filePath)).exists())
        diag ~= new LexerError(new Location(filePath, 0),
                                  MSG.InexistantFile);
      else
        diag ~= new LexerError(new Location(filePath, 0),
                                  MSG.CantReadFile);
      data = "\0";
      return;
    }

    // Read the file.
    auto rawdata = cast(ubyte[]) (new File(filePath)).read();
    // Convert the data.
    auto converter = Converter(filePath, diag);
    data = converter.data2UTF8(rawdata);
    addSentinelCharacter();
  }

  /// Adds '\0' to the text (if not already there.)
  private void addSentinelCharacter()
  {
    if (data.length == 0 || data[$-1] != 0)
      data ~= 0;
  }
}
