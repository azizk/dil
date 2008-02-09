/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Type;

import dil.ast.Node;
import dil.semantic.Types;

/// The base class of all type nodes.
abstract class TypeNode : Node
{
  TypeNode next;
  Type type; /// The semantic type of this type node.

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

  TypeNode baseType()
  {
    auto type = this;
    while (type.next)
      type = type.next;
    return type;
  }
}
