/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module common;

import tango.io.stream.Format;
public import tango.io.Stdout;
public import tango.text.convert.Layout : Layout;
public import tango.core.Vararg;

/// General int.
alias int_t = sizediff_t;
/// General uint.
alias uint_t = size_t;

/// Signed size type.
alias ssize_t = sizediff_t;

/// Const character aliases.
alias cchar = const(char);
alias cwchar = const(wchar); /// ditto
alias cdchar = const(dchar); /// ditto
/// Constant string aliases.
alias cstring = const(char)[];
alias cwstring = const(wchar)[]; /// ditto
alias cdstring = const(dchar)[]; /// ditto

/// Binary, typeless string.
alias binstr = ubyte[];
alias cbinstr = const(ubyte)[]; /// ditto

alias FormatOut = FormatOutput!(char);
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
    auto num = 10 - msg.length/8 - 1;
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
  alias Tuple = T;
}

/// Converts an array to a tuple.
template Array2Tuple(alias T)
{
  static if (T.length == 0)
    alias Array2Tuple = Tuple!();
  else static if (T.length == 1)
    alias Array2Tuple = Tuple!(T[0]);
  else
    alias Array2Tuple = Tuple!(T[0], Array2Tuple!(T[1..$]));
}

/// Supports expressions like: 13 in Set(8,13,0)
auto Set(Xs...)(Xs xs)
{
  struct Set
  {
    Xs xs;
    bool opBinaryRight(string op : "in", X)(X x)
    {
      static if (is(X == class) || is(X dummy : P*, P)) // Class or pointer?
      {
        foreach (x_; xs)
          if (x is x_)
            return true;
      }
      else
        foreach (x_; xs)
          if (x == x_)
            return true;
      return false;
    }
  }
  return Set(xs);
}

/// Like Set, but used like: 13.In(8,13,0)
/// NB: DMD generates worse code for Set() because of the inner struct.
bool In(X, Xs...)(X x, Xs xs)
{
  static if (is(X == class) || is(X dummy : P*, P)) // Class or pointer?
  {
    foreach (x_; xs)
      if (x is x_)
        return true;
  }
  else
    foreach (x_; xs)
      if (x == x_)
        return true;
  return false;
}

void testSet()
{
  scope msg = new UnittestMsg("Testing functions Set() and In().");
  auto x = new Object();
  assert(x.In(x));
  assert(x in Set(x));
  assert((&x).In(&x));
  assert(&x in Set(&x));
  assert(null.In(null));
  assert(null in Set(null));
  assert(1.In(1,2,3));
  assert(1 in Set(1,2,3));
  assert("unittest".In("xyz", "", cast(cstring)null, "unittest"));
  assert("unittest" in Set("xyz", "", cast(cstring)null, "unittest"));
  assert(!'x'.In('y', 'z'));
  assert('x' !in Set('y', 'z'));
}
