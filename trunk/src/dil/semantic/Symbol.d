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
  private template is_(char[] kind)
  {
    const char[] is_ = `bool is`~kind~`(){ return sid == SYM.`~kind~`; }`;
  }
  mixin(is_!("Module"));
  mixin(is_!("Class"));
  mixin(is_!("Interface"));
  mixin(is_!("Struct"));
  mixin(is_!("Union"));
  mixin(is_!("Enum"));
  mixin(is_!("Template"));
  mixin(is_!("Variable"));
  mixin(is_!("Function"));
  mixin(is_!("Alias"));
  mixin(is_!("OverloadSet"));
//   mixin(is_!("Type"));
}
