/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Statement;

import dil.ast.Node;

abstract class Statement : Node
{
  this()
  {
    super(NodeCategory.Statement);
  }
}
