/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.Expression;

import dil.ast.Node;
import dil.semantic.Types,
       dil.semantic.Symbol;
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

  /// Returns true if the expression's type is semantically resolved.
  /// That is, if the type isn't null and it isn't Types.DontKnowYet.
  bool isChecked()
  {
    return hasType() && type !is Types.DontKnowYet;
  }

  override abstract Expression copy();
}
