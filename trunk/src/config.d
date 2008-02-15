/// The configuration file of dil.
///
/// Relative paths are resolved from the directory of the executable.
module config;

/// Path to the language file.
var langfile = "lang_en.d";

/// An array of import paths to look for modules.
var import_paths = []; /// E.g.: ["src/", "import/"]

/// DDoc macro file paths.
var ddoc_files = []; /// E.g.: ["src/mymacros.ddoc", "othermacros.ddoc"]

var xml_map = "xml_map.d";
var html_map = "html_map.d";

/// Customizable formats for error messages.
///
/// <ul>
///   <li>0: file path to the source text.</li>
///   <li>1: line number.</li>
///   <li>2: column number.</li>
///   <li>3: error message.</li>
/// </ul>
var lexer_error = "{0}({1},{2})L: {3}";
var parser_error = "{0}({1},{2})P: {3}"; /// ditto
var semantic_error = "{0}({1},{2})S: {3}"; /// ditto
