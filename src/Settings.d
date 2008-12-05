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
  string dataDir = "data/";
  /// Predefined version identifiers.
  string[] versionIds;
  /// Path to the language file.
  string langFile = "lang_en.d";
  /// Language code of loaded messages catalogue.
  string langCode = "en";
  /// Table of localized compiler messages.
  string[] messages;
  /// Array of import paths to look for modules.
  string[] importPaths;
  /// Array of DDoc macro file paths.
  string[] ddocFilePaths;
  string xmlMapFile = "xml_map.d"; /// XML map file.
  string htmlMapFile = "html_map.d"; /// HTML map file.
  string lexerErrorFormat = "{0}({1},{2})L: {3}"; /// Lexer error.
  string parserErrorFormat = "{0}({1},{2})P: {3}"; /// Parser error.
  string semanticErrorFormat = "{0}({1},{2})S: {3}"; /// Semantic error.
  uint tabWidth = 4; /// Tabulator character width.
}
