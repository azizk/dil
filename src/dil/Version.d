/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.Version;

import dil.String : itoactf;

private char[] toString(uint x, uint pad)
{
  char[] str = itoactf(x);
  if (pad > str.length)
    for (size_t i = pad-str.length; i; i--)
      str = "0" ~ str;
  return str;
}

version(D2)
  immutable VERSION_MAJOR_DEFAULT = 2;
else
  immutable VERSION_MAJOR_DEFAULT = 1;

/// The major version number of this compiler.
immutable VERSION_MAJOR = VERSION_MAJOR_DEFAULT;
/// The minor version number of this compiler.
immutable VERSION_MINOR = 0;
/// The optional suffix.
immutable VERSION_SUFFIX = "";
/// The compiler version formatted as a string.
immutable VERSION =
  (itoactf(VERSION_MAJOR)~"."~toString(VERSION_MINOR, 3)~VERSION_SUFFIX).idup;
/// The name of the compiler.
immutable VENDOR = "DIL";
