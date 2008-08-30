/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Expression;

import dil.ast.Node;
import dil.semantic.Types;
import dil.semantic.Symbol;
import common;

/// The root class of all expressions.
abstract class Expression : Node
{
  Type type; /// The semantic type of this expression.
  Symbol symbol;

  this()
  {
    super(NodeCategory.Expression);
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

  override abstract Expression copy();
}
