/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.Statement;

import dil.ast.Node;

/// The root class of all statements.
abstract class Statement : Node
{
  this()
  {
    super(NodeCategory.Statement);
  }

  override abstract Statement copy();
}
