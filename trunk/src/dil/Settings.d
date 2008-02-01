/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Settings;
import common;

struct GlobalSettings
{
static:
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
  string lexerErrorFormat = "{0}({1},{2})L: {3}";
  string parserErrorFormat = "{0}({1},{2})P: {3}";
  string semanticErrorFormat = "{0}({1},{2})S: {3}";
}
