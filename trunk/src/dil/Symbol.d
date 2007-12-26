/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Symbol;

import common;

enum SYM
{
  Module,
  Class,
  Struct,
  Union,
  Variable,
  Function,
  Type,
}

class Symbol
{
  SYM sid;
}
