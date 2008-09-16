/// Author: Aziz Köksal
/// License: GPL3
module dil.doc.Macro;

import dil.doc.Parser;
import dil.lexer.Funcs;
import dil.Unicode;
import dil.Information;
import dil.Messages;
import common;

/// The DDoc macro class.
class Macro
{
  string name; /// The name of the macro.
  string text; /// The substitution text.
  uint callLevel;  /// Recursive call level.
  this (string name, string text)
  {
    this.name = name;
    this.text = text;
  }
}

/// Maps macro names to Macro objects.
///
/// MacroTables can be chained so that they build a linear hierarchy.
/// Macro definitions in the current table override the ones in the parent tables.
class MacroTable
{
  /// The parent in the hierarchy. Or null if this is the root.
  MacroTable parent;
  Macro[string] table; /// The associative array that holds the macro definitions.

  /// Constructs a MacroTable instance.
  this(MacroTable parent = null)
  {
    this.parent = parent;
  }

  /// Inserts the macro m into the table.
  /// Overwrites the current macro if one exists.
  void insert(Macro m)
  {
    table[m.name] = m;
  }

  /// Inserts an array of macros into the table.
  void insert(Macro[] macros)
  {
    foreach (m; macros)
      insert(m);
  }

  /// Creates a macro using name and text and inserts that into the table.
  void insert(string name, string text)
  {
    insert(new Macro(name, text));
  }

  /// Creates a macro using name[n] and text[n] and inserts that into the table.
  void insert(string[] names, string[] texts)
  {
    assert(names.length == texts.length);
    foreach (i, name; names)
      insert(name, texts[i]);
  }

  /// Searches for a macro.
  ///
  /// If the macro isn't found in this table the search
  /// continues upwards in the table hierarchy.
  /// Returns: the macro if found, or null if not.
  Macro search(string name)
  {
    auto pmacro = name in table;
    if (pmacro)
      return *pmacro;
    if (!isRoot())
      return parent.search(name);
    return null;
  }

  /// Returns: true if this is the root of the hierarchy.
  bool isRoot()
  { return parent is null; }
}

/// Parses a text with macro definitions.
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

  /// Scans for a macro invocation. E.g.: &#36;(DDOC)
  /// Returns: a pointer set to one char past the closing parenthesis,
  /// or null if this isn't a macro invocation.
  static char* scanMacro(char* p, char* textEnd)
  {
    assert(*p == '$');
    if (p+2 < textEnd && p[1] == '(')
    {
      p += 2;
      if (isidbeg(*p) || isUnicodeAlpha(p, textEnd)) // IdStart
      {
        do // IdChar*
          p++;
        while (p < textEnd && (isident(*p) || isUnicodeAlpha(p, textEnd)))
        MacroExpander.scanArguments(p, textEnd);
        p != textEnd && p++; // Skip ')'.
        return p;
      }
    }
    return null;
  }
}

/// Expands DDoc macros in a text.
struct MacroExpander
{
  MacroTable mtable; /// Used to look up macros.
  InfoManager infoMan; /// Collects warning messages.
  char[] filePath; /// Used in warning messages.

  /// Starts expanding the macros.
  static char[] expand(MacroTable mtable, char[] text, char[] filePath,
                       InfoManager infoMan = null)
  {
    MacroExpander me;
    me.mtable = mtable;
    me.infoMan = infoMan;
    me.filePath = filePath;
    return me.expandMacros(text);
  }

  /// Reports a warning message.
  void warning(char[] msg, char[] macroName)
  {
    msg = Format(msg, macroName);
    if (infoMan)
      infoMan ~= new Warning(new Location(filePath, 0), msg);
  }

  /// Expands the macros from the table in the text.
  char[] expandMacros(char[] text, char[] prevArg0 = null/+, uint depth = 1000+/)
  {
    // if (depth == 0)
    //   return  text;
    // depth--;
    char[] result;
    char* p = text.ptr;
    char* textEnd = p + text.length;
    char* macroEnd = p;
    while (p+3 < textEnd) // minimum 4 chars: $(x)
    {
      if (*p == '$' && p[1] == '(')
      {
        // Copy string between macros.
        if (macroEnd != p)
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
          if (p == textEnd)
          {
            warning(MSG.UnterminatedDDocMacro, macroName);
            result ~= "$(" ~ macroName ~ " ";
          }
          else
            p++;
          macroEnd = p; // Point past ')'.

          auto macro_ = mtable.search(macroName);
          if (macro_)
          { // Ignore recursive macro if:
            auto macroArg0 = macroArgs.length ? macroArgs[0] : null;
            if (macro_.callLevel != 0 &&
                (macroArgs.length == 0/+ || // Macro has no arguments.
                 prevArg0 == macroArg0+/)) // macroArg0 equals previous arg0.
            { continue; }
            macro_.callLevel++;
            // Expand the arguments in the macro text.
            auto expandedText = expandArguments(macro_.text, macroArgs);
            result ~= expandMacros(expandedText, macroArg0/+, depth+/);
            macro_.callLevel--;
          }
          else
          {
            warning(MSG.UndefinedDDocMacro, macroName);
            //result ~= makeString(macroName.ptr-2, macroEnd);
          }
          continue;
        }
      }
      p++;
    }
    if (macroEnd == text.ptr)
      return text; // No macros found. Return original text.
    if (macroEnd < textEnd)
      result ~= makeString(macroEnd, textEnd);
    return result;
  }

  /// Scans until the closing parenthesis is found. Sets p to one char past it.
  /// Returns: [arg0, arg1, arg2 ...].
  static char[][] scanArguments(ref char* p, char* textEnd)
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
  MainLoop:
    while (p < textEnd)
    {
      switch (*p)
      {
      case ',':
        if (level != 1) // Ignore comma if inside ().
          break;
        // Add a new argument.
        args ~= makeString(argBegin, p);
        while (++p < textEnd && isspace(*p)) // Skip spaces.
        {}
        argBegin = p;
        continue;
      case '(':
        level++;
        break;
      case ')':
        if (--level == 0)
          break MainLoop;
        break;
      // Commented out: causes too many problems in the expansion pass.
      // case '"', '\'':
      //   auto c = *p;
      //   while (++p < textEnd && *p != c) // Scan to next " or '.
      //   {}
      //   assert(*p == c || p == textEnd);
      //   if (p == textEnd)
      //     break MainLoop;
      //   break;
      case '<':
        p++;
        if (p+2 < textEnd && *p == '!' && p[1] == '-' && p[2] == '-') // <!--
        {
          p += 2; // Point to 2nd '-'.
          // Scan to closing "-->".
          while (++p < textEnd)
            if (p+2 < textEnd && *p == '-' && p[1] == '-' && p[2] == '>')
              p += 2; // Point to '>'.
        } // <tag ...> or </tag>
        else if (p < textEnd && (isalpha(*p) || *p == '/'))
          while (++p < textEnd && *p != '>') // Skip to closing '>'.
          {}
        else
          continue MainLoop;
        if (p == textEnd)
          break MainLoop;
        assert(*p == '>');
        break;
      default:
      }
      p++;
    }
    assert(*p == ')' && level == 0 || p == textEnd);
    if (arg0Begin == p)
      return null;
    // arg0 spans the whole argument list.
    auto arg0 = makeString(arg0Begin, p);
    // Add last argument.
    args ~= makeString(argBegin, p);
    return arg0 ~ args;
  }

  /// Expands "&#36;+", "&#36;0" - "&#36;9" with args[n] in text.
  /// Params:
  ///   text = the text to scan for argument placeholders.
  ///   args = the first element, args[0], is the whole argument string and
  ///          the following elements are slices into it.$(BR)
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
      if (*p == '$' && (*++p == '+' || isdigit(*p)))
      {
        // Copy string between argument placeholders.
        if (placeholderEnd != p-1)
          result ~= makeString(placeholderEnd, p-1);
        placeholderEnd = p+1; // Set new placeholder end.

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
    if (placeholderEnd == text.ptr)
      return text; // No placeholders found. Return original text.
    if (placeholderEnd < textEnd)
      result ~= makeString(placeholderEnd, textEnd);
    return result;
  }
}
