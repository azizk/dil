/// The configuration file of dil.
///
/// The file is searched for in the following order:
/// $(OL
///   $(LI The environment variable DILCONF.)
///   $(LI The current working directory.)
///   $(LI The directory set in the environment variable HOME.)
///   $(LI The executable's directory.)
/// )
/// The program will fail with an error msg if the file couldn't be found.$(BR)
///
/// The following variables are expanded inside strings (only where paths are expected):
/// $(UL
///   $(LI ${DATADIR} -> the data directory of dil (e.g. /home/user/dil/bin/data or C:\dil\bin\data).)
///   $(LI ${HOME} -> the home directory (e.g. /home/name or C:\Documents and Settings\name).)
///   $(LI ${EXECDIR} -> the absolute path to the directory of dil's executable (e.g. /home/name/dil/bin).)
/// )
module config;

/// Files needed by dil are located in this directory.
///
/// A relative path is resolved from the directory of dil's executable.
var DATADIR = "data/";

/// Predefined version identifiers.
var VERSION_IDS = ["X86", "linux", "LittleEndian"];
// "X86_64", "Windows", "Win32", "Win64", "BigEndian"

/// An array of import paths to look for modules.
///
/// Relative paths are resolved from the current working directory.
var IMPORT_PATHS = []; /// E.g.: ["src/", "import/"]

/// DDoc macro file paths.
///
/// Macro definitions in ddoc_files[n] override the ones in ddoc_files[n-1].$(BR)
/// Relative paths are resolved from the current working directory.
var DDOC_FILES = ["${DATADIR}/predefined.ddoc"]; /// E.g.: ["src/mymacros.ddoc", "othermacros.ddoc"]

/// Path to the language file.
var LANG_FILE = "${DATADIR}/lang_en.d";
/// Path to the xml map.
var XML_MAP = "${DATADIR}/xml_map.d";
/// Path to the html map.
var HTML_MAP = "${DATADIR}/html_map.d";

/// Customizable formats for error messages.
///
/// $(UL
///   $(LI 0: file path to the source text.)
///   $(LI 1: line number.)
///   $(LI 2: column number.)
///   $(LI 3: error message.)
/// )
var LEXER_ERROR = "{0}({1},{2})L: {3}";
var PARSER_ERROR = "{0}({1},{2})P: {3}"; /// ditto
var SEMANTIC_ERROR = "{0}({1},{2})S: {3}"; /// ditto
