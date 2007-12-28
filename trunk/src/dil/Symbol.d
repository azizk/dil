/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Symbol;

import common;

/// Symbol IDs.
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

/++
  A symbol represents an object with semantic code information.
+/
class Symbol
{
  SYM sid;
}
