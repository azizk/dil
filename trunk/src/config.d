// Relative paths are resolved from the directory of dil's executable.

// Path to the language file.
var langfile = "lang_en.d";
// An array of import paths to look for modules.
var import_paths = [];
/*
  Customizing error messages.
  0: file path to the source text.
  1: line number.
  2: column number.
  3: error message.
*/
var lexer_error = "{0}({1},{2})L: {3}";
var parser_error = "{0}({1},{2})P: {3}";
var semantic_error = "{0}({1},{2})S: {3}";
