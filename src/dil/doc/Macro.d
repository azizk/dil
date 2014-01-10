/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.doc.Macro;

import dil.doc.Parser;
import dil.lexer.Funcs;
import dil.i18n.Messages;
import dil.Unicode,
       dil.Diagnostics,
       dil.String,
       dil.Array;
import common;

/// The DDoc macro class.
class Macro
{
  /// Enum of special marker characters.
  enum Marker
  {
    Opening   = '\1', /// Opening macro character.
    Closing   = '\2', /// Closing macro character.
    Unclosed  = '\3', /// Unclosed macro character.
    ArgsStart = '\4', /// Marks the start of a macro's arguments.
  }

  cstring name; /// The name of the macro.
  cstring text; /// The substitution text.
  uint callLevel; /// The recursive call level.

  /// Constructs a Macro object.
  this(cstring name, cstring text)
  {
    this.name = name;
    this.text = text;
  }

  /// Converts a macro text to the internal format.
  static cstring convert(cstring text)
  {
    CharArray result;
    auto p = text.ptr;
    auto end = p + text.length;
    auto prev = p;
    CharArray parens; // Stack of parentheses and markers.
    for (; p < end; p++)
      switch (*p)
      {
      case '$':
        auto p2 = p+2;
        if (p2 < end && p[1] == '(' && isIdentifierStart(p2, end)) // IdStart
        { // Scanned: "$(IdStart"
          if (!result.ptr)
            result.cap = text.length; // Reserve space the first time.
          if (prev != p)
            result ~= slice(prev, p); // Copy previous text.
          parens ~= Macro.Marker.Opening;
          result ~= Macro.Marker.Opening; // Relace "$(".
          prev = p = p2; // Move to IdStart.
        }
        break;
      case '(': // Only push on the stack, when inside a macro.
        if (parens.len)
          parens ~= '(';
        break;
      case ')':
        if (!parens.len)
          break; // Ignore parentheses outside macro.
        if (parens[Neg(1)] == Macro.Marker.Opening)
        { // Found matching closing parenthesis.
          if (prev != p) {
            result ~= slice(prev, p);
            prev = p+1;
          }
          result ~= Macro.Marker.Closing; // Replace ')'.
        }
        else
          assert(parens[Neg(1)] == '(');
        parens.cur--;
        break;
      default:
      }
    if (prev == text.ptr)
      return text; // No macros found. Return original text.
    if (prev < end)
      result ~= slice(prev, end);
    foreach (c; parens[])
      if (c == Macro.Marker.Opening) // Unclosed macros?
        result ~= Macro.Marker.Unclosed; // Add marker for errors.
    return result[];
  }
}

void testMacroConvert()
{
  scope msg = new UnittestMsg("Testing function Macro.convert().");
  alias fn = Macro.convert;
  auto r = fn("$(bla())");
  assert(r == "\1bla()\2");
  r = fn("($(ÖÜTER ( $(NestedMacro ?,ds()))))");
  assert(r == "(\1ÖÜTER ( \1NestedMacro ?,ds()\2)\2)");
  r = fn("$(Unclosed macro ");
  assert(r == "\1Unclosed macro \3");
}

/// Maps macro names to Macro objects.
///
/// MacroTables can be chained so that they build a linear hierarchy.
/// Macro definitions in the current table
/// override the ones in the parent tables.
class MacroTable
{
  /// The parent in the hierarchy. Or null if this is the root.
  MacroTable parent;
  /// The associative array that holds the macro definitions.
  Macro[hash_t] table;

  /// Constructs a MacroTable instance.
  this(MacroTable parent = null)
  {
    this.parent = parent;
  }

  /// Inserts the macro m into the table.
  /// Overwrites the current macro if one exists.
  /// Params:
  ///   m = The macro.
  ///   convertText = Convert the macro text to the internal format.
  void insert(Macro m, bool convertText = true)
  {
    if (convertText)
      m.text = Macro.convert(m.text);
    table[hashOf(m.name)] = m;
  }

  /// Inserts an array of macros into the table.
  void insert(Macro[] macros)
  {
    foreach (m; macros)
      insert(m);
  }

  /// Creates a macro using name and text and inserts it into the table.
  void insert(cstring name, cstring text)
  {
    insert(new Macro(name, text));
  }

  /// Creates a macro using name[n] and text[n] pairs
  /// and inserts it into the table.
  void insert(cstring[] names, cstring[] texts)
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
  Macro search(cstring name)
  {
    if (auto pmacro = hashOf(name) in table)
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
static:
  Macro[] parse(cstring text)
  {
    IdentValueParser parser;
    auto idvalues = parser.parse(text);
    auto macros = new Macro[idvalues.length];
    foreach (i, idvalue; idvalues)
      macros[i] = new Macro(idvalue.ident, idvalue.value);
    return macros;
  }
}

/// Expands DDoc macros in a text.
struct MacroExpander
{
  MacroTable mtable; /// Used to look up macros.
  Diagnostics diag; /// Collects warning messages.
  cstring filePath; /// Used in warning messages.
  CharArray buffer; /// Text buffer.
  cstring[10] margs; /// Currently parsed macro arguments.

  /// Starts expanding the macros.
  static cstring expand(MacroTable mtable, cstring text, cstring filePath,
                        Diagnostics diag = null)
  {
    MacroExpander me;
    me.mtable = mtable;
    me.diag = diag;
    me.filePath = filePath;
    me.expandMacros(text);
    return me.buffer[];
  }

  /// Reports a warning message.
  void warning(MID mid, cstring macroName)
  {
    if (diag !is null)
      diag ~= new Warning(new Location(filePath, 0),
        diag.formatMsg(mid, macroName));
  }

  /// Expands the macros in the text using the definitions from the table.
  void expandMacros(cstring text
    /+, cstring prevArg0 = null, uint depth = 1000+/)
  { // prevArg0 and depth are commented out, causes problems with recursion.
    // if (depth == 0)
    //   return  text;
    // depth--;
    auto p = text.ptr;
    auto textEnd = p + text.length;
    auto macroEnd = p;

    // Scan for: "\1MacroName ...\2"
    for (; p+2 < textEnd; p++) // 2 chars look-ahead.
      if (*p == Macro.Marker.Opening)
      {
        // Copy string between macros.
        if (macroEnd != p)
          buffer ~= slice(macroEnd, p);
        p++;
        if (auto macroName = scanIdentifier(p, textEnd))
        { // Scanned "\1MacroName" so far.
          // Get arguments.
          auto macroArgs = scanArguments(margs, p, textEnd);
          macroEnd = p;
          // Closing parenthesis not found?
          if (p == textEnd || *p == Macro.Marker.Unclosed)
            warning(MID.UnterminatedDDocMacro, macroName),
            (buffer ~= "$(" ~ macroName ~ " ");
          else // p points to the closing marker.
            macroEnd = p+1; // Point past the closing marker.

          auto macro_ = mtable.search(macroName);
          if (!macro_)
            warning(MID.UndefinedDDocMacro, macroName),
            // Insert into the table to avoid more warnings.
            mtable.insert(macro_ = new Macro(macroName, "$0"));
          // Ignore recursive macro if:
          //auto macroArg0 = macroArgs.length ? macroArgs[0] : null;
          if (macro_.callLevel != 0 &&
              (macroArgs.length == 0/+ || // Macro has no arguments.
                prevArg0 == macroArg0+/)) // macroArg0 equals previous arg0.
            continue;
          macro_.callLevel++;
          // Expand the arguments in the macro text.
          auto expandedText = expandArguments(macro_.text, macroArgs);
          // Expand macros inside that text.
          expandMacros(expandedText/+, macroArg0, depth+/);
          macro_.callLevel--;
        }
      }
    if (macroEnd < textEnd)
      buffer ~= slice(macroEnd, textEnd);
  }

  /// Scans until the closing parenthesis is found. Sets p to one char past it.
  /// Returns: [arg0, arg1, arg2 ...].
  /// Params:
  ///   args = Provides space for at least 10 arguments.
  ///   ref_p = Will point to Macro.Marker.Closing or Marker.Unclosed,
  ///           or to textEnd if it wasn't found.
  cstring[] scanArguments(cstring[] args, ref cchar* ref_p, cchar* textEnd)
  in { assert(args.length == 10); }
  out(outargs) { assert(outargs.length != 1); }
  body
  {
    // D specs: "The argument text can contain nested parentheses,
    //           "" or '' strings, comments, or tags."
    uint mlevel = 1; // Nesting level of macros.
    uint plevel = 0; // Nesting level of parentheses.
    size_t nargs;
    auto p = ref_p; // Use a non-ref variable to scan the text.

    if (p < textEnd && isspace(*p)) // Skip first space.
      p++;
    // Skip leading spaces.
    //while (p < textEnd && isspace(*p))
    //  p++;

    // Skip special arguments marker. (DIL extension!)
    // This is needed to preserve the whitespace that comes after the marker.
    if (p < textEnd && *p == Macro.Marker.ArgsStart)
      p++;

    auto arg0Begin = p; // Begin of all arguments.
    auto argBegin = p; // Begin of current argument.
  MainLoop:
    while (p < textEnd)
    {
      switch (*p)
      {
      case Macro.Marker.Opening:
        mlevel++;
        break;
      case Macro.Marker.Closing, Macro.Marker.Unclosed:
        if (--mlevel == 0) // Final closing macro character?
          break MainLoop;
        break;
      case '(': plevel++; break;
      case ')': if (plevel) plevel--; break;
      case ',':
        if ((plevel+mlevel) != 1) // Ignore comma if inside ( ).
          break;
        if (nargs < 9)
        { // Set nth argument.
          args[++nargs] = slice(argBegin, p);
          if (++p < textEnd && isspace(*p)) // Skip first space.
            p++;
          //while (++p < textEnd && isspace(*p)) // Skip spaces.
          //{}
          argBegin = p;
        }
        else
          p++; // Skip ','.
        continue;
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
            if (p+2 < textEnd && *p == '-' && p[1] == '-' && p[2] == '>') {
              p += 2; // Point to '>'.
              break;
            }
        } // <tag ...> or </tag>
        else if (p < textEnd && (isalpha(*p) || *p == '/'))
          while (++p < textEnd && *p != '>') // Skip to closing '>'.
          {}
        else
          continue MainLoop;
        assert(p <= textEnd);
        if (p == textEnd)
          break MainLoop;
        assert(*p == '>');
        break;
      default:
      }
      p++;
    }
    assert(mlevel == 0 &&
      (*p == Macro.Marker.Closing || *p == Macro.Marker.Unclosed) ||
      p == textEnd);
    ref_p = p;
    if (arg0Begin == p)
      return null; // No arguments.
    args[0] = slice(arg0Begin, p); // arg0 spans the whole argument list.
    if (nargs < 9)
      args[++nargs] = slice(argBegin, p);
    return args[0..nargs+1];
  }

  /// Expands "&#36;+", "&#36;0" - "&#36;9" with args[n] in text.
  /// Params:
  ///   text = The text to scan for argument placeholders.
  ///   args = The first element, args[0], is the whole argument string and
  ///          the following elements are slices into it.$(BR)
  ///          The array is empty if there are no arguments.
  static cstring expandArguments(cstring text, cstring[] args)
  in { assert(args.length != 1, "zero or more than 1 args expected"); }
  body
  {
    CharArray buffer;
    auto p = text.ptr;
    auto textEnd = p + text.length;
    auto placeholderEnd = p;

    while (p+1 < textEnd)
    {
      if (*p == '$' && (*++p == '+' || isdigit(*p)))
      {
        // Copy string between argument placeholders.
        if (placeholderEnd != p-1)
          buffer ~= slice(placeholderEnd, p-1);
        placeholderEnd = p+1; // Set new placeholder end.

        if (args.length == 0)
          continue;

        if (*p == '+')
        { // $+ = $2 to $n
          if (args.length > 2)
          {
            assert(String(args[2]).slices(args[0]),
              Format("arg[2] ({}) is not a slice of arg[0] ({})",
                args[2], args[0]));
            buffer ~= slice(args[2].ptr, String(args[0]).end);
          }
        }
        else
        { // 0 - 9
          uint nthArg = *p - '0';
          if (nthArg < args.length)
            buffer ~= args[nthArg];
          else // DMD uses args0 if nthArg is not available.
            buffer ~= args[0];
        }
      }
      p++;
    }
    if (placeholderEnd is text.ptr)
      return text;
    if (placeholderEnd < textEnd)
      buffer ~= slice(placeholderEnd, textEnd);
    return buffer[];
  }
}
