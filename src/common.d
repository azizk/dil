/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module common;

import tango.io.stream.Format;
public import tango.io.Stdout;
public import tango.text.convert.Layout : Layout;
public import tango.core.Vararg;

/// Const character aliases.
alias const(char) cchar;
alias const(wchar) cwchar; /// ditto
alias const(dchar) cdchar; /// ditto
/// Constant string aliases.
alias const(char)[] cstring;
alias const(wchar)[] cwstring; /// ditto
alias const(dchar)[] cdstring; /// ditto

alias FormatOutput!(char) FormatOut;
/// Global formatter instance.
static Layout!(char) Format;
static typeof(&Stdout.format) Printf;
static typeof(&Stdout.formatln) Printfln;
static this()
{
  Format = new typeof(Format);
  Printf = &Stdout.format;
  Printfln = &Stdout.formatln;
}

/// Replaces a with b in str.
/// Returns: A copy.
cstring replace(cstring str, char a, char b)
{
  auto tmp = str.dup;
  foreach (ref c; tmp)
    if (c == a)
      c = b;
  return tmp;
}

// Check version IDs.
version(D1) {
  version(D2)
    static assert(0, "Can't have both D1 and D2 defined.");
}
else
version(D2)
{}
else
  static assert(0, "Either -version=D1 or D2 must be defined.");
