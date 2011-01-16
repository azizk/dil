/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.semantic.Symbol;

import dil.ast.Node;
import dil.lexer.Identifier;
import dil.lexer.IdTable;
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
  Scope,
  Parameter,
  Parameters,
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

  /// A template for building isXYZ() methods.
  private static string is_()(string kind)
  {
    return `bool is`~kind~`(){ return sid == SYM.`~kind~`; }`;
  }

  mixin(is_("Module"));
  mixin(is_("Package"));
  mixin(is_("Class"));
  mixin(is_("Interface"));
  mixin(is_("Struct"));
  mixin(is_("Union"));
  mixin(is_("Enum"));
  mixin(is_("EnumMember"));
  mixin(is_("Template"));
  mixin(is_("Variable"));
  mixin(is_("Function"));
  mixin(is_("Alias"));
  mixin(is_("OverloadSet"));
  mixin(is_("Scope"));
  mixin(is_("Parameter"));
  mixin(is_("Parameters"));
//   mixin(is_("Type"));

  /// Casts the symbol to Class.
  Class to(Class)()
  {
    assert(mixin(`this.sid == mixin("SYM." ~
      { const N = Class.stringof; // Slice off "Symbol" from the name.
        return N[$-6..$] == "Symbol" ? N[0..$-6] : N; }())`));
    return cast(Class)cast(void*)this;
  }

  /// Returns: the fully qualified name of this symbol.
  /// E.g.: dil.semantic.Symbol.Symbol.getFQN
  char[] getFQN()
  {
    auto name = this.name;
    if (name is null)
      name = Ident.Empty; // Equals "".
    // Check if the parent is the "root package", which has
    // Ident.Empty as its name.
    if (parent !is null && parent.name !is Ident.Empty)
      return parent.getFQN() ~ '.' ~ name.str;
    return name.str;
  }

  /// Returns the mangled name of this symbol.
  char[] toMangle()
  {
    // TODO:
    return name.str.dup;
  }

  /// Returns the string representation of this symbol.
  char[] toString()
  {
    return name.str.dup;
  }
}
