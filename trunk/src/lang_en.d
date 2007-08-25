/++
  Author: Aziz Köksal
  License: GPL3
+/

string lang_code = "en";

string[] messages = [
  // Lexer messages:
  "invalid Unicode character.",
  "invalid UTF-8 sequence.",
  // ''
  "unterminated character literal.",
  "empty character literal.",
  // #line
  "expected 'line' after '#'.",
  "integer expected after #line",
  `expected filespec string (e.g. "path\to\file".)`,
  "unterminated filespec string.",
  "expected a terminating newline after special token.",
  // ""
  "unterminated string literal.",
  // x""
  "non-hex character '{1}' found in hex string.",
  "odd number of hex digits in hex string.",
  "unterminated hex string.",
  // /* */ /+ +/
  "unterminated block comment (/* */).",
  "unterminated nested comment (/+ +/).",
  // `` r""
  "unterminated raw string.",
  "unterminated back quote string.",
  // \x \u \U
  "found undefined escape sequence.",
  "insufficient number of hex digits in escape sequence.",
  // \&[a-zA-Z][a-zA-Z0-9]+;
  "undefined HTML entity '{1}'",
  "unterminated HTML entity.",
  "HTML entities must begin with a letter.",
  // integer overflows
  "decimal number overflows sign bit.",
  "overflow in decimal number.",
  "overflow in hexadecimal number.",
  "overflow in binary number.",
  "overflow in octal number.",
  "overflow in float number.",
  "digits 8 and 9 are not allowed in octal numbers.",
  "invalid hex number; at least one hex digit expected.",
  "invalid binary number; at least one binary digit expected.",
  "the exponent of a hexadecimal float number is required.",
  "missing decimal digits in hexadecimal float exponent.",
  "exponents have to start with a digit.",

  // Parser messages
  "expected '{1}', but found '{2}'.",
  "'{1}' is redundant.",
  "template tuple parameters can only be last.",
  "the functions 'in' contract was already parsed.",
  "the functions 'out' contract was already parsed.",

  // Help messages:
  `dil v{1}
Copyright (c) 2007 by Aziz Köksal. Licensed under the GPL3.

Subcommands:
{2}
Type 'dil help <subcommand>' for more help on a particular subcommand.

Compiled with {3} v{4} on {5}.`,
  `Generate an XML or HTML document from a D source file.
Usage:
  dil gen file.d [Options]

Options:
  --syntax         : generate tags for the syntax tree
  --xml            : use XML format (default)
  --html           : use HTML format

Example:
  dil gen Parser.d --html --syntax > Parser.html`,
];