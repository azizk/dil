/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.lexer.IdentsEnum;

import dil.lexer.IdentsGenerator;

mixin(
  "enum ID : ushort {"
    "Null,"
    ~ generateIDMembers ~
  "}"
);
