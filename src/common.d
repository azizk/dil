/// Author: Aziz Köksal
/// License: GPL3
module common;

public import tango.io.Stdout;
public import tango.text.convert.Layout;

/// String aliases.
alias char[] string;
alias wchar[] wstring; /// ditto
alias dchar[] dstring; /// ditto

/// Global formatter instance.
static Layout!(char) Format;
static this()
{
  Format = new typeof(Format);
}
