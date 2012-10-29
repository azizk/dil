/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.Version;

import dil.String : itoactf;

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
immutable VERSION = (
  (V => V[0] ~ "." ~ V[1..4])(itoactf(VERSION_MAJOR*1000+VERSION_MINOR)) ~
  (VERSION_SUFFIX.length ? "-" ~ VERSION_SUFFIX : "")
).idup;
/// The name of the compiler.
immutable VENDOR = "DIL";
