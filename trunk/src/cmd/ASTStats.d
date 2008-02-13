/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.ASTStats;

import dil.ast.DefaultVisitor;
import dil.ast.Node,
       dil.ast.Declaration,
       dil.ast.Statement,
       dil.ast.Expression,
       dil.ast.Types;

class ASTStats : DefaultVisitor
{
  uint[] table; /// Table for counting nodes.

  uint[] count(Node root)
  {
    table = new uint[classNames.length];
    super.visitN(root);
    return table;
  }

  // Override dispatch function.
  override Node dispatch(Node n)
  {
    table[n.kind]++;
    return super.dispatch(n);
  }
}
