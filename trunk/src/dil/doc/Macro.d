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
      if (isidbeg(*p) || isUnicodeAlpha(p, textEnd)) // IdStart
      {
        do // IdChar*
          p++;
        while (isident(*p) || isUnicodeAlpha(p, textEnd))
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
}

char[] makeString(char* begin, char* end)
{
  return begin[0 .. end - begin];
}

char[] expandMacros(MacroTable table, char[] text)
{
  char[] result;
  char* p = text.ptr;
  char* textEnd = p + text.length;
//   while (p < text.length)
//   {

//   }
  return result;
}

