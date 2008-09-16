/// Author: Aziz Köksal
/// License: GPL3
module dil.ast.Type;

import dil.ast.Node;
import dil.semantic.Types,
       dil.semantic.Symbol;

/// The root class of all type nodes.
abstract class TypeNode : Node
{
  TypeNode next; /// The next type in the type chain.
  Type type; /// The semantic type of this type node.
  Symbol symbol;

  this()
  {
    this(null);
  }

  this(TypeNode next)
  {
    super(NodeCategory.Type);
    addOptChild(next);
    this.next = next;
  }

  /// Returns the root type of the type chain.
  TypeNode baseType()
  {
    auto type = this;
    while (type.next)
      type = type.next;
    return type;
  }

  /// Returns true if the member 'type' is not null.
  bool hasType()
  {
    return type !is null;
  }

  /// Returns true if the member 'symbol' is not null.
  bool hasSymbol()
  {
    return symbol !is null;
  }

  override abstract TypeNode copy();
}
