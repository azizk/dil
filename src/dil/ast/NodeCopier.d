/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.NodeCopier;

import dil.ast.NodesEnum;

import common;

/// Provides a copy() method for subclasses of Node.
mixin template copyMethod()
{
  override typeof(this) copy()
  { // First do a shallow copy.
    auto n = cast(typeof(this))cast(void*)this.dup;
    // Then copy each subnode.
    foreach (i, T; _mtypes)
    {
      enum m = _members[i];
      static if (is(T : Node)) // A Node?
      {
        static if (_mayBeNull[i])
          mixin("if(n."~m~") n."~m~" = n."~m~".copy();");
        else
          mixin("n."~m~" = n."~m~".copy();");
      }
      else static if (is(T t : E[], E) && is(E : Node)) // A Node array?
      {
        static if (_mayBeNull[i])
          mixin("n."~m~" = n."~m~".dup;
                  foreach (ref x; n."~m~")
                    if (x) x = x.copy();");
        else
          mixin("n."~m~" = n."~m~".dup;
                      foreach (ref x; n."~m~")
                        x = x.copy();");
      }
    }
    return n;
  }
}
