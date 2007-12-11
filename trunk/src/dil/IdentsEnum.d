/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.IdentsEnum;
import dil.IdentsGenerator;

mixin(
  "enum ID : ushort {"
    "Null,"
    ~ generateIDMembers ~
  "}"
);
