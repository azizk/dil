/++
  Author: Aziz Köksal
  License: GPL3
+/
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

/// Parses text of the form:
/// <pre>
/// ident = value
/// ident2 = value2
///          more text
/// </pre>
struct IdentValueParser
{
  char* p; /// Current pointer.
  char* textEnd;

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

  /// Removes trailing whitespace characters from the text body.
  char[] textBody(char* begin, char* end)
  {
    // The body of A is empty, e.g.:
    // A =
    // B = some text
    // ^- begin and end point to B (or to this.textEnd in the 2nd case.)
    if (begin is end)
      return "";
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
      if (p >= textEnd)
        break;
      auto idBegin = p;
      if (isidbeg(*p) || isUnicodeAlpha(p, textEnd)) // IdStart
      {
        do // IdChar*
          p++;
        while (p < textEnd && (isident(*p) || isUnicodeAlpha(p, textEnd)))
        auto idEnd = p;

        skipWhitespace();
        if (p < textEnd && *p == '=')
        {
          p++;
          skipWhitespace();
          bodyBegin = p;
          ident = makeString(idBegin, idEnd);
          return true;
        }
      }
      skipLine();
    }
    return false;
  }

  void skipWhitespace()
  {
    while (p < textEnd && (isspace(*p) || *p == '\n'))
      p++;
  }

  void skipLine()
  {
    while (p < textEnd && *p != '\n')
      p++;
    p++;
  }
}

char[] makeString(char* begin, char* end)
{
  assert(begin && end && begin <= end);
  return begin[0 .. end - begin];
}
