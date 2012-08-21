/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.doc.Parser;

import dil.lexer.Funcs;
import dil.Unicode,
       dil.String;
import common;

/// A pair of strings.
class IdentValue
{
  cstring ident;
  cstring value;
  this(cstring ident, cstring value)
  {
    this.ident = ident;
    this.value = value;
  }
}

/// Parses text in the form of:
/// $(PRE
////ident = value
////ident2 = value2
////         more text
////)
struct IdentValueParser
{
  cchar* p; /// Current pointer.
  cchar* textEnd;

  /// Parses the text into a list of IdentValues.
  /// All newlines in text must be converted to '\n'.
  IdentValue[] parse(cstring text)
  {
    if (!text.length)
      return null;

    p = text.ptr;
    textEnd = p + text.length;

    IdentValue[] idvalues;

    cstring ident, nextIdent;
    cchar* bodyBegin, nextBodyBegin;

    // Init.
    if (findNextIdent(ident, bodyBegin))
      // Continue.
      while (findNextIdent(nextIdent, nextBodyBegin))
      {
        idvalues ~= new IdentValue(ident, textBody(bodyBegin, nextIdent.ptr));
        ident = nextIdent;
        bodyBegin = nextBodyBegin;
      }
    else // No "ident = value" pair found.
      bodyBegin = p; // Take the whole text and give it an empty ident.
    // Add last ident value.
    idvalues ~= new IdentValue(ident, textBody(bodyBegin, textEnd));
    return idvalues;
  }

  /// Strips off leading and trailing whitespace characters.
  /// Returns: the text body, or null if empty.
  static cstring textBody(cchar* begin, cchar* end)
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
    return slice(begin, end);
  }

  /// Finds the next "Identifier =".
  /// Params:
  ///   ident = Set to Identifier.
  ///   bodyBegin = Set to the beginning of the text body (whitespace skipped.)
  /// Returns: true if found.
  bool findNextIdent(out cstring ident, out cchar* bodyBegin)
  {
    while (p < textEnd)
    {
      skipWhitespace();
      if (p is textEnd)
        break;
      assert(p < textEnd && (isascii(*p) || isLeadByte(*p)));
      auto id = scanIdentifier(p, textEnd);
      skipWhitespace();
      if (id && p < textEnd && *p == '=')
      {
        ident = id;
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

unittest
{
  scope msg = new UnittestMsg("Testing struct dil.doc.Parser.");
  auto text = "A =
B = text
C =
 <b>text</b>
  D = $(LINK www.dil.com)
E=<
F = G = H
Äş=??
A6İ=µ
End=";

  IdentValue iv(cstring s1, cstring s2)
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
