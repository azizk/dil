/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.ASTStats;

import dil.ast.DefaultVisitor;
import dil.ast.Node;

class ASTStats : DefaultVisitor
{
  uint[] table; /// Table for counting nodes.

  uint[] count(Node root)
  {
    table = new uint[classNames.length];
    super.visitN(root);
    return table;
  }

  // TODO: add visit methods.
}
