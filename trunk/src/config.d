// Relative paths are resolved from the directory of dil's executable.

// Path to the language file.
auto langfile = "lang_en.d";
// An array of import paths to look for modules.
auto import_paths = [];
/*
  Customizing error messages.
  1: file path to the source text.
  2: line number.
  3: column number.
  4: error message.
*/
auto lexer_error = "{1}({2},{3})L: {4}";
auto parser_error = "{1}({2},{3})P: {4}";
auto semantic_error = "{1}({2},{3})S: {4}";
