/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.SourceText;

import dil.Converter;
import dil.Information;
import common;

import tango.io.File;

/// Represents D source code.
///
/// The source text may come from a file or from a memory buffer.
final class SourceText
{
  string filePath; /// The file path to the source text. Mainly used for error messages.
  char[] data; /// The UTF-8, zero-terminated source text.

  /// Params:
  ///   filePath = file path to the source file.
  ///   loadFile = whether to load the file in the constructor.
  this(string filePath, bool loadFile = false)
  {
    this.filePath = filePath;
    loadFile && load();
  }

  /// Params:
  ///   filePath = file path for error messages.
  ///   data = memory buffer.
  this(string filePath, char[] data)
  {
    this(filePath);
    this.data = data;
    addSentinelCharacter();
  }

  void load(InfoManager infoMan = null)
  {
    if (!infoMan)
      infoMan = new InfoManager;
    assert(filePath.length);
    // Read the file.
    auto rawdata = cast(ubyte[]) (new File(filePath)).read();
    // Convert the data.
    auto converter = Converter(filePath, infoMan);
    data = converter.data2UTF8(rawdata);
    addSentinelCharacter();
  }

  private void addSentinelCharacter()
  {
    if (data.length == 0 || data[$-1] != 0)
      data ~= 0;
  }
}
