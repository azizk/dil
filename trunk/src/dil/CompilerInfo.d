/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.CompilerInfo;

version(D2)
  /// The major version number of this compiler.
  const uint VERSION_MAJOR = 2;
else
  /// The major version number of this compiler.
  const uint VERSION_MAJOR = 1;

/// The minor version number of this compiler.
const uint VERSION_MINOR = 0;

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
  if (pad < str.length)
    return str;
  for (uint i = pad-str.length; i; i--)
    str = "0" ~ str;
  return str;
}

/// The compiler version formatted as a string.
const char[] VERSION = toString(VERSION_MAJOR)~"."~toString(VERSION_MINOR, 3);
/// The name of the compiler.
const char[] VENDOR = "dil";

/// The global, default alignment size for struct fields.
const uint DEFAULT_ALIGN_SIZE = 4;

version(DDoc)
  const uint PTR_SIZE = 0; /// The pointer size depending on the platform.
else
version(X86_64)
  const uint PTR_SIZE = 8; // Pointer size on 64-bit platforms.
else
  const uint PTR_SIZE = 4; // Pointer size on 32-bit platforms.
