/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module util.Format;

import std.format : FormatSpec, formatValue;

alias FSpec = FormatSpec!char;

/// Parses a Tango-style format string fragment.
/// Regex: \{(\d*)\s*([,.]\s*-?\d*\s*)?(:[^}]*)?\}
const(C)[] parseFmt(C=char)(const(C)[] fmt, ref FSpec fs)
{
  auto p = fmt.ptr;
  auto end = fmt.ptr + fmt.length;

  auto inc = () => (assert(p < end), ++p, true);
  bool loop(lazy bool pred) { return pred() && loop(pred); }
  auto loopUntil = (lazy bool pred) => loop(!pred() && p < end && inc());
  auto current = (C c) => p < end && *p == c;
  auto next = (C c) => p+1 < end && p[1] == c;
  auto skipped = (C c) => current(c) && inc();
  ubyte digit; // Scanned single digit.
  auto isdigit = () => p < end && (digit = cast(ubyte)(*p-'0')) < 10 && inc();
  int number; // Scanned number.
  auto adddigit = () => isdigit() && ((number = number * 10 + digit), true);
  auto isnumber = () => isdigit() && ((number = digit), loop(adddigit()), true);

  // Start scanning.
  loopUntil(skipped('{') && !current('{')); // Find { but skip {{.

  auto begin = p-1;

  if (p >= end)
    return null;

  if (isnumber())
    fs.indexStart = fs.indexEnd = cast(ubyte)(number + 1);

  loopUntil(!current(' '));

  if (skipped(',') || skipped('.'))
  {
    C minmaxChar = *(p-1);
    loopUntil(!current(' '));
    fs.flDash = skipped('-');
    if (isnumber())
    {
      if (minmaxChar == ',')
        fs.width = number;
      else // TODO: '.'
      {}
    }
    loopUntil(!current(' '));
  }

  if (skipped(':'))
  {
    auto fmtBegin = p;
    loopUntil(current('}'));
    auto end2 = p;
    p = fmtBegin;
    if (p < end2)
    {
      if (cast(ubyte)((*p | 0x20) - 'a') <= 'z'-'a') // Letter?
        fs.spec = *p++;
      if (isnumber())
        fs.precision = number;
      foreach (c; p[0..end2-p])
        if (c == '+')
          fs.flPlus = true;
        else if (c == ' ')
          fs.flSpace = true;
        else if (c == '0')
          fs.flZero = true;
        //else if (c == '.')
        //{} // Strips trailing zeros.
        else if (c == '#')
          fs.flHash = true;
    }
  }

  skipped('}');
  return begin[0..p-begin];
}

void formatTangoActual(C=char, Writer)
  (ref Writer w, const(C)[] fmt, void delegate(ref FormatSpec!C)[] fmtFuncs)
{
  ubyte argIndex; // 0-based.
  while (fmt.length)
  {
    FSpec fs;
    auto fmtSlice = parseFmt(fmt, fs);

    if (fmtSlice is null)
      break;
    if (fs.indexStart) // 1-based.
      argIndex = cast(ubyte)(fs.indexStart - 1);

    auto fmtIndex = fmtSlice.ptr - fmt.ptr;
    if (fmtIndex)
      w ~= fmt[0..fmtIndex]; // Append previous non-format string.

    if (argIndex < fmtFuncs.length)
      fmtFuncs[argIndex](fs); // Write the formatted value.
    else
    {} // TODO: emit error string?

    fmt = fmt[fmtIndex+fmtSlice.length .. $];

    argIndex++;
  }
  if (fmt.length)
    w ~= fmt;
}

void formatTango(C=char, Writer, AS...)(ref Writer w, const(C)[] fmt, AS as)
{
  void delegate(ref FormatSpec!C)[AS.length] fmtFuncs;
  foreach (i, A; AS)
    fmtFuncs[i] = (ref fs) => formatValue(w, as[i], fs);
  formatTangoActual(w, fmt, fmtFuncs);
}

void testFormatTango()
{
  import std.stdio;
  import dil.Array;
  CharArray a;
  struct CharArrayWriter
  {
    import dil.Unicode : encode;
    CharArray* a;
    ref CharArray a_ref()
    {
      return *a;
    }
    alias a_ref  this;
    void put(dchar dc)
    {
      ensureOrGrow(4);
      auto utf8Chars = encode(a.cur, dc);
      a.cur += utf8Chars.length;
      assert(utf8Chars.length <= 4);
    }
  }
  auto w = CharArrayWriter(&a);
  formatTango(w, "test{}a{{0}>{,6}<", 12345, "läla");
  assert(a[] == "test12345a{{0}> läla<");
  writefln("a[]='%s'", a[]);
}
