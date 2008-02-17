/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.lexer.IdentsEnum;

import dil.lexer.IdentsGenerator;

mixin(
  // Enumerates predefined identifiers.
  "enum IDK : ushort {"
    "Null,"
    ~ generateIDMembers ~
  "}"
);
