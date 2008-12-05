/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.Version;

private char[] toString(uint x)
{
  char[] str;
  do
    str = cast(char)('0' + (x % 10)) ~ str;
  while (x /= 10)
  return str;
}

private char[] toString(uint x, uint pad)
{
  char[] str = toString(x);
  if (pad > str.length)
    for (uint i = pad-str.length; i; i--)
      str = "0" ~ str;
  return str;
}

version(D2)
  const uint VERSION_MAJOR_DEFAULT = 2;
else
  const uint VERSION_MAJOR_DEFAULT = 1;

/// The major version number of this compiler.
const uint VERSION_MAJOR = VERSION_MAJOR_DEFAULT;
/// The minor version number of this compiler.
const uint VERSION_MINOR = 0;
/// The compiler version formatted as a string.
const char[] VERSION = toString(VERSION_MAJOR)~"."~toString(VERSION_MINOR, 3);
/// The name of the compiler.
const char[] VENDOR = "dil";
