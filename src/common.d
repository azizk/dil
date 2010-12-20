/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module common;

import tango.io.stream.Format;
public import tango.io.Stdout;
public import tango.text.convert.Layout : Layout;

/// String aliases.
alias char[] string;
alias wchar[] wstring; /// ditto
alias dchar[] dstring; /// ditto

alias FormatOutput!(char) FormatOut;
/// Global formatter instance.
static Layout!(char) Format;
static this()
{
  Format = new typeof(Format);
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
