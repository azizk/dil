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
  Interface,
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
