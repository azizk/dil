/++
  Author: Aziz Köksal
  License: GPL3
+/
module common;

public import tango.io.Stdout;
public import tango.text.convert.Layout;

alias char[] string;
alias wchar[] wstring;
alias dchar[] dstring;

static Layout!(char) Format;
static this()
{
  Format = new typeof(Format);
}
