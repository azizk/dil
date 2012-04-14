/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module Settings;

import common;

/// Global application settings.
struct GlobalSettings
{
static:
  /// Path to the data directory.
  cstring dataDir = "data/";
  /// Path to the directory of kandil.
  cstring kandilDir = "kandil/";
  /// Predefined version identifiers.
  cstring[] versionIds;
  /// Path to the language file.
  cstring langFile = "lang_en.d";
  /// Language code of loaded messages catalogue.
  string langCode = "en";
  /// Table of localized compiler messages.
  cstring[] messages;
  /// Array of import paths to look for modules.
  cstring[] importPaths;
  /// Array of DDoc macro file paths.
  cstring[] ddocFilePaths;
  cstring xmlMapFile = "xml_map.d"; /// XML map file.
  cstring htmlMapFile = "html_map.d"; /// HTML map file.
  cstring lexerErrorFormat = "{0}({1},{2})L: {3}"; /// Lexer error.
  cstring parserErrorFormat = "{0}({1},{2})P: {3}"; /// Parser error.
  cstring semanticErrorFormat = "{0}({1},{2})S: {3}"; /// Semantic error.
  uint tabWidth = 4; /// Tabulator character width.
}
