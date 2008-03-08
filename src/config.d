/// The configuration file of dil.
///
/// Relative paths are resolved from the directory of the executable.
module config;

/// Predefined version identifiers.
var version_ids = ["X86", "linux", "LittleEndian"];
// "X86_64", "Windows", "Win32", "Win64", "BigEndian"

/// Path to the language file.
var langfile = "lang_en.d";

/// An array of import paths to look for modules.
var import_paths = []; /// E.g.: ["src/", "import/"]

/// DDoc macro file paths.
///
/// Macro definitions in ddoc_files[n] override the ones in ddoc_files[n-1].
var ddoc_files = ["predefined.ddoc"]; /// E.g.: ["src/mymacros.ddoc", "othermacros.ddoc"]

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
