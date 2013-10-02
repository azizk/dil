/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.lexer.IDsEnum;

import dil.lexer.IDsList;

version(DDoc)
  enum IDK : ushort; /// Enumeration of predefined identifier kinds.
else
mixin(
  // Enumerates predefined identifiers.
  "enum IDK : ushort {
    None, /// Uninitialized or defined at run-time.\n"
    ~ {
    char[] members;
    foreach (pair; keywordIDs)
      members ~= pair[0] ~ ",\n";
    foreach (pair; specialIDs)
      members ~= pair[0] ~ ",\n";
    foreach (pair; predefinedIDs)
      members ~= pair[0] ~ ",\n";
    return members;
  }() ~
  "}"
);
