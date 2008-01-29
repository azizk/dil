/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Symbol;

import dil.ast.Node;
import dil.lexer.Identifier;
import common;

/// Symbol IDs.
enum SYM
{
  Module,
  Class,
  Interface,
  Struct,
  Union,
  Enum,
  EnumMember,
  Template,
  Variable,
  Function,
  Alias,
  OverloadSet,
//   Type,
}

/++
  A symbol represents an object with semantic code information.
+/
class Symbol
{
  SYM sid;
  Symbol parent; /// The parent this symbol belongs to.
  Identifier* name; /// The name of this symbol.
  /// The AST node that produced this symbol.
  /// Useful for source code location info and retrieval of doc comments.
  Node node;

  this(SYM sid, Identifier* name, Node node)
  {
    this.sid = sid;
    this.name = name;
    this.node = node;
  }

  // A template macro for building isXYZ() methods.
  private template isX(char[] kind)
  {
    const char[] isX = `bool is`~kind~`(){ return sid == SYM.`~kind~`; }`;
  }
  mixin(isX!("Module"));
  mixin(isX!("Class"));
  mixin(isX!("Interface"));
  mixin(isX!("Struct"));
  mixin(isX!("Union"));
  mixin(isX!("Enum"));
  mixin(isX!("EnumMember"));
  mixin(isX!("Template"));
  mixin(isX!("Variable"));
  mixin(isX!("Function"));
  mixin(isX!("Alias"));
  mixin(isX!("OverloadSet"));
//   mixin(isX!("Type"));
}
