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

  // A template macro for building isXYZ() methods.
  private template is_(char[] kind)
  {
    const char[] is_ = `bool is`~kind~`(){ return sid == SYM.`~kind~`; }`;
  }
  mixin(is_!("Module"));
  mixin(is_!("Class"));
  mixin(is_!("Interface"));
  mixin(is_!("Struct"));
  mixin(is_!("Union"));
  mixin(is_!("Variable"));
  mixin(is_!("Function"));
  mixin(is_!("Type"));
}
