/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Expression;

import dil.ast.Node;
import dil.semantic.Scope;
import dil.semantic.Types;
import common;

abstract class Expression : Node
{
  Type type; /// The type of this expression.

  this()
  {
    super(NodeCategory.Expression);
  }

  // Semantic analysis:

  Expression semantic(Scope scop)
  {
    debug Stdout("SA for "~this.classinfo.name).newline;
    if (!type)
      type = Types.Undefined;
    return this;
  }

  Expression evaluate()
  {
    return null;
  }

  import dil.Messages;
  void error(Scope scop, MID mid)
  {
    scop.error(this.begin, mid);
  }

  void error(Scope scop, char[] msg)
  {

  }
}
