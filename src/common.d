/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module common;

import tango.io.stream.Format;
public import tango.io.Stdout;
public import tango.text.convert.Layout : Layout;
public import tango.core.Vararg;

/// Signed size type.
alias sizediff_t ssize_t;

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

/// Writes a message to stdout.
scope class UnittestMsg
{
  cstring msg;
  cstring passed = "Passed!\n";
  this(cstring msg)
  {
    this.msg = msg;
    Stdout(msg);
  }
  ~this()
  {
    auto tabs = "\t\t\t\t\t\t\t\t\t\t";
    // FIXME: the calculation could be more accurate.
    auto num = (80 - msg.length - passed.length) / 8;
    Stdout(tabs[0..num] ~ passed);
  }
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

/// Constructs a compile-time tuple.
template Tuple(T...)
{
  alias T Tuple;
}

/// Converts an array to a tuple.
template Array2Tuple(alias T)
{
  static if (T.length == 0)
    alias Tuple!() Array2Tuple;
  else static if (T.length == 1)
    alias Tuple!(T[0]) Array2Tuple;
  else
    alias Tuple!(T[0], Array2Tuple!(T[1..$])) Array2Tuple;
}
