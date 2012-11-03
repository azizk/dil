/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.Type;

import dil.ast.Node;
import dil.semantic.Types,
       dil.semantic.Symbol;

/// The root class of all type nodes.
abstract class TypeNode : Node
{
  TypeNode next; /// The next type in the type chain.
  TypeNode parent; /// The parent TypeNode of this symbol.
  Type type; /// The semantic type of this type node.
  Symbol symbol; /// Semantic symbol.

  this()
  {
    this(null);
  }

  this(TypeNode next)
  {
    addOptChild(next);
    if (next !is null)
      next.parent = this;
    this.next = next;
  }

  /// Sets the member 'next'. This node becomes the parent of 'n'.
  void setNext(TypeNode n)
  {
    assert(n !is null);
    next = n;
    n.parent = this;
    if (children.length)
      children[0] = next;
    else
      children ~= next;
  }

  /// Returns the end type of the type chain.
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
