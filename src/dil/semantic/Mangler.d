/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.semantic.Mangler;

import dil.ast.Visitor,
       dil.ast.Node,
       dil.ast.Expressions;
import dil.semantic.TypesEnum;
import dil.i18n.Messages;
import dil.Float,
       dil.Unicode,
       dil.String,
       dil.Diagnostics;
import common;

/// Mangles expressions used as template arguments.
class TArgMangler : Visitor2
{
  char[] text; /// The mangled text.
  Diagnostics diag;
  string filePath;

  void mangleFloat(Float f)
  {
    if (f.isNaN())
      text ~= "NAN";
    // FIXME:
    // Replace('-', 'N')
    // Ignore('+', 'X', '.')
    // Ignore leading 0. E.g.: "0X123" -> "123"

    // Converting from Float to long double is probably inaccurate.
    // Matching the mangled strings of DMD will be difficult.
    // Just use Float.toString() for now.
    text ~= f.toString();
  }

  /// Issues an error message.
  void error(Token* tok, MID mid, ...)
  {
    auto location = tok.getErrorLocation(filePath);
    auto msg = diag.formatMsg(mid, _arguments, _argptr);
    auto error = new SemanticError(location, msg);
    diag ~= error;
  }

  void utf16Error(Token* tok, cwstring s, size_t i)
  {
    auto e = dil.Unicode.utf16Error(s, i);
    ushort arg1 = s[i-1], arg2 = arg1;
    MID mid = MID.InvalidUTF16Sequence;
    if (e == UTF16Error.Invalid)
      arg1 = s[i-2];
    else if (e == UTF16Error.LoSurrogate)
      mid = MID.MissingLowSurrogate;
    else if (e == UTF16Error.HiSurrogate)
      mid = MID.MissingHighSurrogate;
    else
      assert(0);
    error(tok, mid, arg1, arg2);
  }

override:
  alias super.visit visit;

  void unhandled(Node n)
  {
    error(n.begin, MID.InvalidTemplateArgument, n.toText());
  }

  void visit(IntExpr e)
  {
    if (cast(long)e.number < 0)
      text ~= 'N' ~ itoa(-e.number);
    else
      text ~= 'i' ~ itoa(e.number);
  }

  void visit(FloatExpr e)
  {
    text ~= 'e';
    mangleFloat(e.number);
  }

  void visit(ComplexExpr e)
  {
    text ~= 'c';
    mangleFloat(e.re);
    text ~= 'c';
    mangleFloat(e.im);
  }

  void visit(NullExpr e)
  {
    text ~= 'n';
  }

  void visit(StringExpr e)
  { // := MangleChar UTF8StringLength "_" UTF8StringInHex
    char mc; // Mangle character.
    cstring utf8str;
    char[] tmp;
    switch (e.charType.tid)
    {
    case TYP.Char:
      mc = 'a';
      utf8str = e.getString();
      break;
    case TYP.WChar:
      mc = 'w';
      auto str = e.getWString();
      for (size_t i; i < str.length;)
      {
        auto c = decode(str, i);
        if (c == ERROR_CHAR) {
          utf16Error(e.begin, str, i);
          break;
        }
        else
          encode(tmp, c);
      }
      utf8str = tmp;
      break;
    case TYP.DChar:
      mc = 'd';
      auto str = e.getDString();
      foreach (dchar c; str)
        if (!isValidChar(c)) {
          error(e.begin, MID.InvalidUTF32Character, c+0);
          break;
        }
        else
          encode(tmp, c);
      utf8str = tmp;
      break;
    default: assert(0);
    }
    auto s = String(utf8str);
    // Finally append the mangled string.
    text ~= mc ~ itoa(s.len) ~ "_" ~ s.toHex().array;
  }

  void visit(ArrayLiteralExpr e)
  {
    text ~= 'A' ~ itoa(e.values.length);
    foreach (val; e.values)
      visitN(val);
  }

  void visit(AArrayLiteralExpr e)
  {
    text ~= 'A' ~ itoa(e.values.length);
    foreach (i, key; e.keys)
      visitN(key), visitN(e.values[i]);
  }

  void visit(StructInitExpr e)
  {
    text ~= 'S' ~ itoa(e.values.length);
    foreach (val; e.values)
      if (val.kind == NodeKind.VoidInitExpr)
        text ~= 'v';
      else
        visitN(val);
  }
}
