/++
  Author: Aziz Köksal
  License: GPL3
+/

string lang_code = "en";

string[] messages = [
  // Lexer messages:
  "illegal character found: '{0}'",
//   "invalid Unicode character.",
  "invalid UTF-8 sequence: '{0}'",
  // ''
  "unterminated character literal.",
  "empty character literal.",
  // #line
  "expected ‘line’ after ‘#’.",
  "integer expected after #line",
//   `expected filespec string (e.g. "path\to\file".)`,
  "unterminated filespec string.",
  "expected a terminating newline after special token.",
  // ""
  "unterminated string literal.",
  // x""
  "non-hex character '{0}' found in hex string.",
  "odd number of hex digits in hex string.",
  "unterminated hex string.",
  // /* */ /+ +/
  "unterminated block comment (/* */).",
  "unterminated nested comment (/+ +/).",
  // `` r""
  "unterminated raw string.",
  "unterminated back quote string.",
  // \x \u \U
  "found undefined escape sequence '{0}'.",
  "found invalid Unicode escape sequence '{0}'.",
  "insufficient number of hex digits in escape sequence: '{0}'",
  // \&[a-zA-Z][a-zA-Z0-9]+;
  "undefined HTML entity '{0}'",
  "unterminated HTML entity '{0}'.",
  "HTML entities must begin with a letter.",
  // integer overflows
  "decimal number overflows sign bit.",
  "overflow in decimal number.",
  "overflow in hexadecimal number.",
  "overflow in binary number.",
  "overflow in octal number.",
  "overflow in float number.",
  "digits 8 and 9 are not allowed in octal numbers.",
  "octal number literals are deprecated",
  "invalid hex number; at least one hex digit expected.",
  "invalid binary number; at least one binary digit expected.",
  "the exponent of a hexadecimal float number is required.",
  "hexadecimal float exponents must start with a digit.",
  "exponents must start with a digit.",
  "cannot read module file",
  "module file doesn’t exist",
  "value of octal escape sequence is greater than 0xFF: ‘{}’",
  "the file name ‘{}’ can’t be used as a module name; it’s an invalid or reserved D identifier",
  "the delimiter character cannot be whitespace",
  "expected delimiter character or identifier after ‘q\"’",
  "expected a newline after identifier delimiter ‘{}’",
  "unterminated delimited string literal",
  "expected ‘\"’ after delimiter ‘{}’",
  "unterminated token string literal",

  // Parser messages
  "expected ‘{0}’, but found ‘{1}’.",
  "‘{0}’ is redundant.",
  "template tuple parameters can only be last.",
  "the functions ‘in’ contract was already parsed.",
  "the functions ‘out’ contract was already parsed.",
  "no linkage type was specified.",
  "unrecognized linkage type ‘{0}’; valid types are C, C++, D, Windows, Pascal und System.",
  "expected one or more base classes, not ‘{0}’.",
  "base classes are not allowed in forward declarations.",
  "invalid UTF-8 sequence in string literal: ‘{}’",
  "a module declaration is only allowed as the first declaration in a file",
  "string literal has mistmatching postfix character",
  "identifier ‘{}’ not allowed in a type",
  "expected identifier after ‘(Type).’, not ‘{}’",
  "expected module identifier, not ‘{}’",
  "illegal declaration found: “{}”",
  "expected ‘system’ or ‘safe’, not ‘{}’",
  "expected function name, not ‘{}’",
  "expected variable name, not ‘{}’",
  "expected function body, not ‘{}’",
  "redundant linkage type: ‘{}’",
  "redundant protection attribute: ‘{}’",
  "expected pragma identifier, not ‘{}’",
  "expected alias module name, not ‘{}’",
  "expected alias name, not ‘{}’",
  "expected an identifier, not ‘{}’",
  "expected enum member, not ‘{}’",
  "expected enum body, not ‘{}’",
  "expected class name, not ‘{}’",
  "expected class body, not ‘{}’",
  "expected interface name, not ‘{}’",
  "expected interface body, not ‘{}’",
  "expected struct body, not ‘{}’",
  "expected union body, not ‘{}’",
  "expected template name, not ‘{}’",
  "expected an identifier, not ‘{}’",
  "illegal statement found: “{}”",
  "didn’t expect ‘;’, use ‘{{ }’ instead",
  "expected ‘exit’, ‘success’ or ‘failure’, not ‘{}’",
  "‘exit’, ‘success’, ‘failure’ are valid scope identifiers, but not ‘{}’",
  "expected ‘C’, ‘C++’, ‘D’, ‘Windows’, ‘Pascal’ or ‘System’, but not ‘{}’",
  "expected an identifier after ‘@’",
  "unrecognized attribute: ‘@{}’",
  "expected an integer after align, not ‘{}’",
  "illegal asm statement found: “{}”",
  "illegal binary operator ‘{}’ in asm statement",
  "expected declarator identifier, not ‘{}’",
  "expected one or more template parameters, not ‘)’",
  "expected a type or and expression, not ‘)’",
  "expected name for alias template parameter, not ‘{}’",
  "expected name for ‘this’ template parameter, not ‘{}’",
  "expected an identifier or an integer, not ‘{}’",
  "try statement is missing a catch or finally body",
  "expected closing ‘{}’ (‘{}’ @{},{}), not ‘{}’",
  "initializers are not allowed for alias types",
  "expected a variable declaration in alias, not ‘{}’",
  "expected a variable declaration in typedef, not ‘{}’",
  "only one expression is allowed for the start of a case range",
  "expected default value for parameter ‘{}’",
  "variadic parameter cannot be ‘ref’ or ‘out’",
  "cannot have parameters after a variadic parameter",

  // Semantic analysis:
  "couldn’t find module file ‘{}’",
  "module is in conflict with module ‘{}’",
  "module is in conflict with package ‘{}’",
  "package ‘{0}’ is in conflict with module ‘{0}’",
  "expected module to be in package ‘{}’",
  "undefined identifier ‘{}’",
  "declaration ‘{}’ conflicts with declaration @{}",
  "variable ‘{}’ conflicts with declaration @{}",
  "an interface can't have member variables",
  "the mixin argument must evaluate to a string",
  "debug={} must be at module level",
  "version={} must be at module level",

  "invalid UTF-16 sequence \\u{:X4}\\u{:X4}",
  "missing low surrogate in UTF-16 sequence \\u{:X4}\\uXXXX",
  "missing high surrogate in UTF-16 sequence \\uXXXX\\u{:X4}",
  "invalid template argument ‘{}’",

  // Converter:
  "invalid UTF-16 character: '\\u{:X4}'",
  "invalid UTF-32 character: '\\U{:X8}'",
  "the byte length of a UTF-16 source file must be divisible by 2",
  "the byte length of a UTF-32 source file must be divisible by 4",

  // DDoc messages:
  "Ddoc macro ‘{}’ is undefined",
  "Ddoc macro ‘{}’ has no closing ‘)’",
  "undocumented symbol",
  "empty comment",
  "missing params section",
  "undocumented parameter ‘{}’",

  // Help messages:
  "Unknown command: ‘{}’",

  // HelpMain
  `dil v{0}
Copyright (c) 2007-2011 by Aziz Köksal. Licensed under the GPL3.

Subcommands:
{1}
Type 'dil help <subcommand>' for more help on a particular subcommand.

Compiled with {2} v{3} on {4}.`,

  // HelpCompile
  `Compile D source files.
Usage:
  dil c[ompile] file.d [file2.d, ...] [Options]

  This command only parses the source files and does little semantic analysis.
  Errors are printed to standard error output.

Options:
  -d               : accept deprecated code
  -debug           : include debug code
  -debug=LEVEL     : include debug(l) code where l <= LEVEL
  -debug=IDENT     : include debug(IDENT) code
  -version=LEVEL   : include version(l) code where l >= LEVEL
  -version=IDENT   : include version(IDENT) code
  -I=PATH          : add PATH to the list of import paths
  -J=PATH          : add PATH to the list of string import paths
  -release         : compile a release build
  -unittest        : compile a unittest build
  -x86             : emit 32 bit code (default on 32 bit machines)
  -x64             : emit 64 bit code (default on 64 bit machines)
  -of=FILE         : output the binary to FILE

  -ps              : print the symbol tree of the modules
  -pm              : print the package/module tree
  -v               : verbose output

Example:
  dil c src/main.d -I=src/`,

  // HelpPytree
  `Export a D parse tree to a Python source file.
Usage:
  dil py[tree] Destination file.d [file2.d, ...] [Options]

Options:
  --tokens         : only emit a list of the tokens (N/A yet)
  --fmt            : the format string for the destination file names
                     Default: d_{0}.py
                     {0} = fully qualified module name (e.g. dil_PyTreeEmitter)
                     {1} = package name (e.g. dil, dil_ast, dil_lexer etc.)
                     {2} = module name (e.g. PyTreeEmitter)
  -v               : verbose output

Example:
  dil py pyfiles/ src/dil/PyTreeEmitter.d`,

  // HelpDdoc
  `Generate documentation from DDoc comments in D source files.
Usage:
  dil d[doc] Destination file.d [file2.d, ...] [Options]

  Destination is the folder where the documentation files are written to.
  Files with the extension .ddoc are recognized as macro definition files.

Options:
  --kandil         : use kandil as the documentation front-end
  --report         : write a problem report to Destination/report.txt
  -rx=REGEXP       : exclude modules from the report if their names
                     match REGEXP (can be used many times)
  --xml            : write XML instead of HTML documents
  --raw            : don't expand macros in the output (useful for debugging)
  -hl              : write syntax highlighted files to Destination/htmlsrc
  -i               : include undocumented symbols
  --inc-private    : include private symbols
  -v               : verbose output
  -m=PATH          : write list of processed modules to PATH
  -version=ident   : see "dil help compile" for more details

Examples:
  dil d doc/ src/main.d data/macros_dil.ddoc -i -m=doc/modules.txt
  dil d tangodoc/ -v -version=Windows -version=Tango \
        --kandil tangosrc/file_1.d tangosrc/file_n.d`,

  // HelpHighlight
  `Highlight a D source file with XML or HTML tags.
Usage:
  dil hl file.d [Destination] [Options]

  The file will be output to stdout if ‘Destination’ is not specified.

Options:
  --syntax         : generate tags for the syntax tree
  --html           : use HTML format (default)
  --xml            : use XML format
  --lines          : print line numbers

Examples:
  dil hl src/main.d --syntax > main.html
  dil hl --xml src/main.d main.xml`,

  // HelpImportgraph
  `Parse a module and build a module dependency graph based on its imports.
Usage:
  dil i[mport]graph file.d Format [Options]

  The directory of file.d is implicitly added to the list of import paths.

Format:
  --dot            : generate a dot document (default)
    Options related to --dot:
  --gbp            : Group modules by package names
  --gbf            : Group modules by full package name
  --hle            : highlight cyclic edges in the graph
  --hlv            : highlight modules in cyclic relationships
  -si=STYLE        : the edge style to use for static imports
  -pi=STYLE        : the edge style to use for public imports
      STYLE        : “dashed”, “dotted”, “solid”, “invis” or “bold”

  --paths          : print the file paths of the modules in the graph
  --list           : print the names of the module in the graph
    Options common to --paths and --list:
  -l=N             : print N levels
  -m               : use ‘*’ to mark modules in cyclic relationships

Options:
  -I=PATH          : add PATH to the list of import paths
  -x=REGEXP        : exclude modules whose names match REGEXP
  -i               : include unlocatable modules

Examples:
  dil igraph src/main.d --list
  dil igraph src/main.d | dot -Tpng > main.png`,

  // HelpTokenize
  `Print the tokens of a D source file.
Usage:
  dil tok[enize] file.d [Options]

Options:
  -               : read text from STDIN
  -s=SEPARATOR    : print SEPARATOR instead of '\n' between tokens
  -i              : ignore whitespace tokens (e.g. comments, shebang etc.)
  -ws             : print a token's preceding whitespace characters

Examples:
  echo 'module foo; void func(){}' | dil tok -
  dil tok src/main.d | grep ^[0-9]`,

  // HelpDlexed
  `Write the begin/end indices of all tokens in a binary format.
Usage:
  dil dlx file.d [Options]

Options:
  -               : read text from STDIN
  -o=FILE         : output to FILE instead of STDOUT

Examples:
  echo 'module foo; void func(){}' | dil dlx - > test.dlx
  dil dlx src/main.d -o dlx/main.dlx`,

  // HelpStatistics
  "Gather statistics about D source files.
Usage:
  dil stat[istic]s file.d [file2.d, ...] [Options]

Options:
  --toktable      : print the count of all token kinds in a table
  --asttable      : print the count of all node kinds in a table

Example:
  dil stats src/main.d src/dil/Unicode.d",

  // HelpTranslate
  `Translate a D source file to another language.
Usage:
  dil trans[late] Language file.d

  Languages that are supported:
    *) German

Example:
  dil trans German src/main.d`,

  // HelpSettings
  "Print the value of a settings variable.
Usage:
  dil set[tings] [name, name2...]

  The names have to match the setting names in dilconf.d.

Example:
  dil set import_paths datadir",

  // HelpHelp
  "Give help on a particular subcommand.
Usage:
  dil help subcommand

Examples:
  dil help compile
  dil ? hl",
];
