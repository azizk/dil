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

  // Override dispatch functions.
override:
  Declaration visitD(Declaration n)
  {
    table[n.kind]++;
    return super.visitD(n);
  }

  Statement visitS(Statement n)
  {
    table[n.kind]++;
    return super.visitS(n);
  }

  Expression visitE(Expression n)
  {
    table[n.kind]++;
    return super.visitE(n);
  }

  TypeNode visitT(TypeNode n)
  {
    table[n.kind]++;
    return super.visitT(n);
  }

  Node visitN(Node n)
  {
    table[n.kind]++;
    return super.visitN(n);
  }
}
