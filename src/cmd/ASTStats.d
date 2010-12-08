/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module cmd.ASTStats;

import dil.ast.DefaultVisitor,
       dil.ast.Node,
       dil.ast.Declaration,
       dil.ast.Statement,
       dil.ast.Expression,
       dil.ast.Types;

/// Counts the nodes in a syntax tree.
class ASTStats : DefaultVisitor2
{
  uint[] table; /// Table for counting nodes.

  /// Starts counting.
  uint[] count(Node root)
  {
    table = new uint[NodeClassNames.length];
    super.visitN(root);
    return table;
  }

  // Override dispatch function.
  override void dispatch(Node n)
  {
    table[n.kind]++;
    super.dispatch(n);
  }
}
