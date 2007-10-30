/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.CompilerInfo;
import std.metastrings : FormatT = Format, ToString;

template Pad(char[] str, uint amount)
{
  static if (str.length >= amount)
    const char[] Pad = str;
  else
    const char[] Pad = "0" ~ Pad!(str, amount-1);
}

template Pad(int num, uint amount)
{
  const char[] Pad = Pad!(ToString!(num), amount);
}

version(D2)
{
  const VERSION_MAJOR = 2;
  const VERSION_MINOR = 0;
}
else
{
  const VERSION_MAJOR = 1;
  const VERSION_MINOR = 0;
}

const VERSION = FormatT!("%s.%s", VERSION_MAJOR, Pad!(VERSION_MINOR, 3));
const VENDOR = "dil";

/// Used in main help message.
const COMPILED_WITH = __VENDOR__;
/// ditto
const COMPILED_VERSION = FormatT!("%s.%s", __VERSION__/1000, Pad!(__VERSION__%1000, 3));
/// ditto
const COMPILED_DATE = __TIMESTAMP__;