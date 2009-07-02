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
