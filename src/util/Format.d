/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module util.Format;

import std.format : FormatSpec;

alias FSpec = FormatSpec!char;

/// Parses a Tango-style format string fragment.
/// Regex: \{(\d*)\s*([,.]\s*-?\d*\s*)?(:[^}]*)?\}
const(C)[] parseFmt(C=char)(const(C)[] fmt, ref FSpec fs)
{
  auto p = fmt.ptr;
  auto end = fmt.ptr + fmt.length;

  auto inc = () => (assert(p < end), ++p, true);
  bool loop(lazy bool pred) { return pred() && loop(pred); }
  auto loopUntil = (lazy bool pred) => loop(!pred() && inc());
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

  if (p == end)
    return null;

  if (isnumber())
    fs.indexStart = cast(ubyte)(number + 1);

  loopUntil(!current(' '));

  if (skipped(',') || skipped('.'))
  {
    C minmaxChar = *(p-1);
    loopUntil(!current(' '));
    auto negate = skipped('-');
    if (isnumber())
      if (minmaxChar == ',')
        fs.width = negate ? -number : number;
      else // TODO: '.'
      {}
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
