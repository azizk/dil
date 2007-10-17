/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.misc.misc;

char[] docgen_version = "Dil document generator 0.1";

enum DocFormat {
  LaTeX,
  XML,
  HTML,
  PlainText
}

enum CommentFormat {
  Ddoc,
  Doxygen
}