/// Author: Aziz Köksal
/// License: GPL3
module dil.lexer.IdentsEnum;

import dil.lexer.IdentsGenerator;

version(DDoc)
  enum IDK : ushort; /// Enumeration of predefined identifier kinds.
else
mixin(
  // Enumerates predefined identifiers.
  "enum IDK : ushort {"
    "Null,"
    ~ generateIDMembers ~
  "}"
);
