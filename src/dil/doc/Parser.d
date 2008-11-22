/// Author: Aziz Köksal
/// License: GPL3
module dil.doc.Parser;

import dil.lexer.Funcs;
import dil.Unicode;
import common;

/// A pair of strings.
class IdentValue
{
  string ident;
  string value;
  this (string ident, string value)
  {
    this.ident = ident;
    this.value = value;
  }
}

/// Parses text in the form of:
/// <pre>
/// ident = value
/// ident2 = value2
///          more text
/// </pre>
struct IdentValueParser
{
  char* p; /// Current pointer.
  char* textEnd;

  /// Parses the text into a list of IdentValues.
  /// All newlines in text must be converted to '\n'.
  IdentValue[] parse(string text)
  {
    if (!text.length)
      return null;

    p = text.ptr;
    textEnd = p + text.length;

    IdentValue[] idvalues;

    string ident, nextIdent;
    char* bodyBegin = p, nextBodyBegin;

    // Init.
    findNextIdent(ident, bodyBegin);
    // Continue.
    while (findNextIdent(nextIdent, nextBodyBegin))
    {
      idvalues ~= new IdentValue(ident, textBody(bodyBegin, nextIdent.ptr));
      ident = nextIdent;
      bodyBegin = nextBodyBegin;
    }
    // Add last ident value.
    idvalues ~= new IdentValue(ident, textBody(bodyBegin, textEnd));
    return idvalues;
  }

  /// Strips off leading and trailing whitespace characters.
  /// Returns: the text body, or null if empty.
  static char[] textBody(char* begin, char* end)
  {
    while (begin < end && (isspace(*begin) || *begin == '\n'))
      begin++;
    // The body of A is empty when e.g.:
    // A =
    // B = some text
    // ^- begin and end point to B (or to this.textEnd in the 2nd case.)
    if (begin is end)
      return null;
    // Remove trailing whitespace.
    while (isspace(*--end) || *end == '\n')
    {}
    end++;
    return makeString(begin, end);
  }

  /// Finds the next "Identifier =".
  /// Params:
  ///   ident = set to Identifier.
  ///   bodyBegin = set to the beginning of the text body (whitespace skipped.)
  /// Returns: true if found.
  bool findNextIdent(ref string ident, ref char* bodyBegin)
  {
    while (p < textEnd)
    {
      skipWhitespace();
      if (p is textEnd)
        break;
      assert(p < textEnd && (isascii(*p) || isLeadByte(*p)));
      ident = scanIdentifier(p, textEnd);
      skipWhitespace();
      if (ident && p < textEnd && *p == '=')
      {
        bodyBegin = ++p;
        skipLine();
        return true;
      }
      skipLine();
    }
    assert(p is textEnd);
    return false;
  }

  void skipWhitespace()
  {
    while (p < textEnd && isspace(*p))
      p++;
  }

  void skipLine()
  {
    while (p < textEnd && *p != '\n')
      p++;
    while (p < textEnd && *p == '\n')
      p++;
  }
}

/// Returns a string slice ranging from begin to end.
char[] makeString(char* begin, char* end)
{
  assert(begin && end && begin <= end);
  return begin[0 .. end - begin];
}

unittest
{
  Stdout("Testing dil.doc.Parser.\n");
  char[] text = "A =
B = text
C =
 <b>text</b>
  D = $(LINK www.dil.com)
E=<
F = G = H
Äş=??
A6İ=µ
End=";

  IdentValue iv(string s1, string s2)
  {
    return new IdentValue(s1, s2);
  }

  auto results = [
    iv("A", ""),
    iv("B", "text"),
    iv("C", "<b>text</b>"),
    iv("D", "$(LINK www.dil.com)"),
    iv("E", "<"),
    iv("F", "G = H"),
    iv("Äş", "??"),
    iv("A6İ", "µ"),
    iv("End", ""),
  ];

  auto parser = IdentValueParser();
  foreach (i, parsed; parser.parse(text))
  {
    auto expected = results[i];
    assert(parsed.ident == expected.ident,
           Format("Parsed ident '{}', but expected '{}'.",
                  parsed.ident, expected.ident));
    assert(parsed.value == expected.value,
           Format("Parsed value '{}', but expected '{}'.",
                  parsed.value, expected.value));
  }
}
