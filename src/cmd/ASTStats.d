/// Author: Aziz Köksal
/// License: GPL3
module cmd.ASTStats;

import dil.ast.DefaultVisitor,
       dil.ast.Node,
       dil.ast.Declaration,
       dil.ast.Statement,
       dil.ast.Expression,
       dil.ast.Types;

/// Counts the nodes in a syntax tree.
class ASTStats : DefaultVisitor
{
  uint[] table; /// Table for counting nodes.

  /// Starts counting.
  uint[] count(Node root)
  {
    table = new uint[g_classNames.length];
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
