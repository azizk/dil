/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.doc.Macro;

import dil.lexer.Funcs;
import dil.Unicode;
import common;

class Macro
{
  string name; /// The name of the macro.
  string text; /// Substitution text.
  this (string name, string text)
  {
    this.name = name;
    this.text = text;
  }
}

class MacroTable
{
  MacroTable parent;
  Macro[string] table;

  this(MacroTable parent = null)
  {
    this.parent = parent;
  }

  void insert(Macro macro_)
  {
    table[macro_.name] = macro_;
  }

  Macro search(string name)
  {
    auto pmacro = name in table;
    if (pmacro)
      return *pmacro;
    if (parent)
      return parent.search(name);
    return null;
  }

  bool isRoot()
  { return parent is null; }
}

void skipWhitespace(ref char* p)
{
  while (isspace(*p) || *p == '\n')
    p++;
}

struct MacroParser
{
  char* p;
  char* textEnd;

  Macro[] parse(string text)
  {
    if (!text.length)
      return null;
    if (text[$-1] != '\0')
      text ~= '\0';
    p = text.ptr;
    textEnd = p + text.length;

    Macro[] macros;

    char* idBegin, idEnd, bodyBegin;
    char* nextIdBegin, nextIdEnd, nextBodyBegin;

    // Init.
    findNextMacroId(idBegin, idEnd, bodyBegin);
    // Continue.
    while (findNextMacroId(nextIdBegin, nextIdEnd, nextBodyBegin))
    {
      macros ~= new Macro(makeString(idBegin, idEnd), makeString(bodyBegin, nextIdBegin));
      idBegin = nextIdBegin;
      idEnd = nextIdEnd;
      bodyBegin = nextBodyBegin;
    }
    // Add last macro.
    macros ~= new Macro(makeString(idBegin, idEnd), makeString(bodyBegin, textEnd));
    return macros;
  }

  bool findNextMacroId(ref char* ref_idBegin, ref char* ref_idEnd, ref char* ref_bodyBegin)
  {
    while (*p != '\0')
    {
      skipWhitespace(p);
      auto idBegin = p;
      if (isidbeg(*p) || isUnicodeAlpha(p)) // IdStart
      {
        do // IdChar*
          p++;
        while (isident(*p) || isUnicodeAlpha(p))
        auto idEnd = p;

        skipWhitespace(p);
        if (*p == '=')
        {
          ref_idBegin = idBegin;
          ref_idEnd = idEnd;
          ref_bodyBegin = p + 1;
          return true;
        }
      }
      skipLine();
    }
    return false;
  }

  void skipLine()
  {
    while (*p != '\n')
      p++;
    p++;
  }

  bool isUnicodeAlpha(ref char* ref_p)
  {
    char* p = ref_p; // Copy.
    if (isascii(*p))
      return false;

    dchar d = *p;
    p++; // Move to second byte.
    // Error if second byte is not a trail byte.
    if (!isTrailByte(*p))
      return false;
    // Check for overlong sequences.
    switch (d)
    {
    case 0xE0, 0xF0, 0xF8, 0xFC:
      if ((*p & d) == 0x80)
        return false;
    default:
      if ((d & 0xFE) == 0xC0) // 1100000x
        return false;
    }
    const char[] checkNextByte = "if (!isTrailByte(*++p))"
                                 "  return false;";
    const char[] appendSixBits = "d = (d << 6) | *p & 0b0011_1111;";
    // Decode
    if ((d & 0b1110_0000) == 0b1100_0000)
    {
      d &= 0b0001_1111;
      mixin(appendSixBits);
    }
    else if ((d & 0b1111_0000) == 0b1110_0000)
    {
      d &= 0b0000_1111;
      mixin(appendSixBits ~
            checkNextByte ~ appendSixBits);
    }
    else if ((d & 0b1111_1000) == 0b1111_0000)
    {
      d &= 0b0000_0111;
      mixin(appendSixBits ~
            checkNextByte ~ appendSixBits ~
            checkNextByte ~ appendSixBits);
    }
    else
      return false;

    assert(isTrailByte(*p));
    if (!isValidChar(d) || !isUniAlpha(d))
      return false;
    // Only advance pointer if this is a Unicode alpha character.
    ref_p = p;
    return true;
  }
}

char[] makeString(char* begin, char* end)
{
  return begin[0 .. end - begin];
}
