/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.doc.Parser;

import dil.lexer.Funcs;
import dil.Unicode;
import common;

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
/// ident = value
/// ident2 = value2
///          more text
struct IdentValueParser
{
  char* p;
  char* textEnd;

  IdentValue[] parse(string text)
  {
    if (!text.length)
      return null;

    p = text.ptr;
    textEnd = p + text.length;

    IdentValue[] idvalues;

    string ident, nextIdent;
    char* bodyBegin, nextBodyBegin;

    // Init.
    findNextIdent(ident, bodyBegin);
    // Continue.
    while (findNextIdent(nextIdent, nextBodyBegin))
    {
      idvalues ~= new IdentValue(ident, makeString(bodyBegin, nextIdent.ptr));
      ident = nextIdent;
      bodyBegin = nextBodyBegin;
    }
    // Add last ident value.
    idvalues ~= new IdentValue(ident, makeString(bodyBegin, textEnd));
    return idvalues;
  }

  bool findNextIdent(ref string ident, ref char* bodyBegin)
  {
    while (p < textEnd)
    {
      skipWhitespace();
      auto idBegin = p;
      if (isidbeg(*p) || isUnicodeAlpha(p, textEnd)) // IdStart
      {
        do // IdChar*
          p++;
        while (p < textEnd && (isident(*p) || isUnicodeAlpha(p, textEnd)))
        auto idEnd = p;

        skipWhitespace();
        if (*p == '=')
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
  return begin[0 .. end - begin];
}
