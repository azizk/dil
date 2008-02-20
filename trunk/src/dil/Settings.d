/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Settings;
import common;

/// Global application settings.
struct GlobalSettings
{
static:
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
  string xmlMapFile = "xml_map.d";
  string htmlMapFile = "html_map.d";
  string lexerErrorFormat = "{0}({1},{2})L: {3}";
  string parserErrorFormat = "{0}({1},{2})P: {3}";
  string semanticErrorFormat = "{0}({1},{2})S: {3}";
}
