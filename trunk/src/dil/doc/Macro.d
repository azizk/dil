/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.doc.Macro;

import dil.doc.Parser;
import dil.lexer.Funcs;
import dil.Unicode;
import common;

class Macro
{
  string name; /// The name of the macro.
  string text; /// Substitution text.
  uint callLevel;  /// Recursive call level.
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

  void insert(Macro[] macros)
  {
    foreach (macro_; macros)
      insert(macro_);
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

struct MacroParser
{
  Macro[] parse(string text)
  {
    IdentValueParser parser;
    auto idvalues = parser.parse(text);
    auto macros = new Macro[idvalues.length];
    foreach (i, idvalue; idvalues)
      macros[i] = new Macro(idvalue.ident, idvalue.value);
    return macros;
  }
}

char[] makeString(char* begin, char* end)
{
  return begin[0 .. end - begin];
}

char[] expandMacros(MacroTable table, char[] text, char[][] args = null)
{
  char[] result;
  char* p = text.ptr;
  char* textEnd = p + text.length;
  char* macroEnd = p;
  while (p+3 < textEnd) // minimum 4 chars: $(x)
  {
    if (*p == '$' && p[1] == '(')
    {
      // Copy string between macros.
      if (macroEnd !is p)
        result ~= makeString(macroEnd, p);
      p += 2;
      auto idBegin = p;
      if (isidbeg(*p) || isUnicodeAlpha(p, textEnd)) // IdStart
      {
        do // IdChar*
          p++;
        while (p < textEnd && (isident(*p) || isUnicodeAlpha(p, textEnd)))
        // Create macro name.
        auto macroName = makeString(idBegin, p);
        // Get arguments.
        auto macroArgs = scanArguments(p, textEnd);
        // TODO: still expand macro if no closing bracket was found?
        if (p == textEnd)
          break; // No closing bracket found.
        assert(*p == ')');
        p++;
        macroEnd = p;

        auto macro_ = table.search(macroName);
        if (macro_)
        { // Ignore recursive macro if:
          if (macro_.callLevel != 0 &&
               (macroArgs.length == 0 || // Macro has no arguments.
                args.length && args[0] == macroArgs[0]) // arg0 == macroArg0.
             )
            continue;
          macro_.callLevel++;
          auto expandedText = expandArguments(macro_.text, macroArgs);
          result ~= expandMacros(table, expandedText, macroArgs);
          macro_.callLevel--;
        }
        continue;
      }
    }
    p++;
  }
  if (macroEnd < textEnd)
    result ~= makeString(macroEnd, textEnd);
  return result;
}

/// Scans until the closing ')' is found.
/// Returns [$0, $1, $2 ...].
char[][] scanArguments(ref char* p, char* textEnd)
out(args) { assert(args.length != 1); }
body
{
  // D specs: "The argument text can contain nested parentheses,
  //           "" or '' strings, comments, or tags."
  uint level = 1; // Nesting level of the parentheses.
  char[][] args;

  // Skip leading spaces.
  while (p < textEnd && isspace(*p))
    p++;

  char* arg0Begin = p; // Whole argument list.
  char* argBegin = p;
Loop:
  while (p < textEnd)
  {
    switch (*p)
    {
    case ',':
      // Add a new argument.
      args ~= makeString(argBegin, p);
      while (++p < textEnd && isspace(*p))
      {}
      argBegin = p;
      continue;
    case '(':
      level++;
      break;
    case ')':
      if (--level == 0)
        break Loop;
      break;
    case '"', '\'':
      auto c = *p;
      while (++p < textEnd && *p != c) // Scan to next " or '.
      {}
      assert(*p == c || p == textEnd);
      if (p == textEnd)
        break Loop;
      break;
    case '<':
      if (p+3 < textEnd && p[1] == '!' && p[2] == '-' && p[3] == '-') // <!--
      {
        p += 3;
        // Scan to closing "-->".
        while (++p + 2 < textEnd)
          if (*p == '-' && p[1] == '-' && p[2] == '>')
          {
            p += 3;
            continue Loop;
          }
        p = textEnd; // p += 2;
      } // <tag ...> or </tag>
      else if (p+1 < textEnd && (isalpha(p[1]) || p[1] == '/'))
        while (++p < textEnd && *p != '>') // Skip to closing '>'.
        {}
      if (p == textEnd)
        break Loop;
      break;
    default:
    }
    p++;
  }
  assert(*p == ')' && level == 0 || p == textEnd);
  if (arg0Begin is p)
    return null;
  // arg0 spans the whole argument list.
  auto arg0 = makeString(arg0Begin, p);
  // Add last argument.
  args ~= makeString(argBegin, p);
  return arg0 ~ args;
}

/// Expands "$+", "$0" - "$9" with args[n] in text.
/// Params:
///   text = the text to scan for argument placeholders.
///   args = the first element, args[0], is the whole argument string and
///          the following elements are slices into it.
///          The array is empty if there are no arguments.
char[] expandArguments(char[] text, char[][] args)
in { assert(args.length != 1, "zero or more than 1 args expected"); }
body
{
  char[] result;
  char* p = text.ptr;
  char* textEnd = p + text.length;
  char* placeholderEnd = p;

  while (p+1 < textEnd)
  {
    if (*p == '$' && (p[1] == '+' || isdigit(p[1])))
    {
      // Copy string between argument placeholders.
      if (placeholderEnd !is p)
        result ~= makeString(placeholderEnd, p);
      p++;
      placeholderEnd = p + 1; // Set new argument end.

      if (args.length == 0)
        continue;

      if (*p == '+')
      { // $+ = $2 to $n
        if (args.length > 2)
          result ~= makeString(args[2].ptr, args[0].ptr + args[0].length);
      }
      else
      { // 0 - 9
        uint nthArg = *p - '0';
        if (nthArg < args.length)
          result ~= args[nthArg];
      }
    }
    p++;
  }
  if (placeholderEnd < textEnd)
    result ~= makeString(placeholderEnd, textEnd);
  return result;
}
