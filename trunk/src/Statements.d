/++
  Author: Aziz Köksal
  License: GPL2
+/
module Statements;
import Expressions;
import Types;

class Statement
{

}

class Statements : Statement
{
  Statement[] ss;
  void opCatAssign(Statement s)
  {
    this.ss ~= s;
  }
}

class ScopeStatement : Statement
{
  Statement s;
  this(Statement s)
  {
    this.s = s;
  }
}

class LabeledStatement : Statement
{
  string label;
  Statement s;
  this(string label, Statement s)
  {
    this.label = label;
    this.s = s;
  }
}

class ExpressionStatement : Statement
{

}

class DeclarationStatement : Statement
{

}

class IfStatement : Statement
{
  Type type;
  string ident;
  Expression condition;
  Statement ifBody;
  Statement elseBody;
  this(Type type, string ident, Expression condition, Statement ifBody, Statement elseBody)
  {
    this.type = type;
    this.ident = ident;
    this.condition = condition;
    this.ifBody = ifBody;
    this.elseBody = elseBody;
  }
}

class ConditionalStatement : Statement
{

}

class WhileStatement : Statement
{

}

class DoStatement : Statement
{

}

class ForStatement : Statement
{

}

class ForeachStatement : Statement
{

}

class SwitchStatement : Statement
{

}

class CaseStatement : Statement
{

}

class DefaultStatement : Statement
{

}

class ContinueStatement : Statement
{

}

class BreakStatement : Statement
{

}

class ReturnStatement : Statement
{

}

class GotoStatement : Statement
{

}

class WithStatement : Statement
{

}

class SynchronizedStatement : Statement
{

}

class TryStatement : Statement
{

}

class ScopeGuardStatement : Statement
{

}

class ThrowStatement : Statement
{

}

class VolatileStatement : Statement
{

}

class AsmStatement : Statement
{

}

class PragmaStatement : Statement
{

}

class MixinStatement : Statement
{

}
