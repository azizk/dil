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
  string lexerErrorFormat = "{1}({2},{3})L: {4}";
  string parserErrorFormat = "{1}({2},{3})L: {4}";
  string semanticErrorFormat = "{1}({2},{3})L: {4}";
}
