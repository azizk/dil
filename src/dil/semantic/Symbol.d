/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Symbol;

import dil.ast.Node;
import dil.lexer.Identifier;
import common;

/// Enumeration of Symbol IDs.
enum SYM
{
  Module,
  Package,
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

/// A symbol represents an object with semantic code information.
class Symbol
{ /// Enumeration of symbol statuses.
  enum Status : ushort
  {
    Declared,   /// The symbol has been declared.
    Completing, /// The symbol is being processed.
    Complete    /// The symbol is complete.
  }

  SYM sid; /// The ID of this symbol.
  Status status; /// The semantic status of this symbol.
  Symbol parent; /// The parent this symbol belongs to.
  Identifier* name; /// The name of this symbol.
  /// The syntax tree node that produced this symbol.
  /// Useful for source code location info and retrieval of doc comments.
  Node node;

  /// Constructs a Symbol object.
  /// Params:
  ///   sid = the symbol's ID.
  ///   name = the symbol's name.
  ///   node = the symbol's node.
  this(SYM sid, Identifier* name, Node node)
  {
    this.sid = sid;
    this.name = name;
    this.node = node;
  }

  /// Change the status to Status.Completing.
  void setCompleting()
  { status = Status.Completing; }

  /// Change the status to Status.Complete.
  void setComplete()
  { status = Status.Complete; }

  /// Returns true if the symbol is being completed.
  bool isCompleting()
  { return status == Status.Completing; }

  /// Returns true if the symbols is complete.
  bool isComplete()
  { return status == Status.Complete; }

  /// A template macro for building isXYZ() methods.
  private template isX(char[] kind)
  {
    const char[] isX = `bool is`~kind~`(){ return sid == SYM.`~kind~`; }`;
  }
  mixin(isX!("Module"));
  mixin(isX!("Package"));
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

  /// Casts the symbol to Class.
  Class to(Class)()
  {
    assert(mixin(`this.sid == mixin("SYM." ~ Class.stringof)`));
    return cast(Class)cast(void*)this;
  }

  /// Returns: the fully qualified name of this symbol.
  /// E.g.: dil.semantic.Symbol.Symbol.getFQN
  char[] getFQN()
  {
    if (!name)
      return parent ? parent.getFQN() : "";
    if (parent)
      return parent.getFQN() ~ '.' ~ name.str;
    return name.str;
  }
}
