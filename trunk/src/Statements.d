/++
  Author: Aziz Köksal
  License: GPL2
+/
module Statements;
import Expressions;
import Types;
import Token;

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
  Expression condition;
  Statement whileBody;
  this(Expression condition, Statement whileBody)
  {
    this.condition = condition;
    this.whileBody = whileBody;
  }
}

class DoWhileStatement : Statement
{
  Expression condition;
  Statement doBody;
  this(Expression condition, Statement doBody)
  {
    this.condition = condition;
    this.doBody = doBody;
  }
}

class ForStatement : Statement
{
  Statement init;
  Expression condition, increment;
  Statement forBody;

  this(Statement init, Expression condition, Expression increment, Statement forBody)
  {
    this.init = init;
    this.condition = condition;
    this.increment = increment;
    this.forBody = forBody;
  }
}

class ForeachStatement : Statement
{
  TOK tok;
  Parameters params;
  Expression aggregate;
  Statement forBody;

  this(TOK tok, Parameters params, Expression aggregate, Statement forBody)
  {
    this.tok = tok;
    this.params = params;
    this.aggregate = aggregate;
    this.forBody = forBody;
  }
}

class SwitchStatement : Statement
{
  Expression condition;
  Statement switchBody;

  this(Expression condition, Statement switchBody)
  {
    this.condition = condition;
    this.switchBody = switchBody;
  }
}

class CaseStatement : Statement
{
  Expression[] values;
  Statement caseBody;

  this(Expression[] values, Statement caseBody)
  {
    this.values = values;
    this.caseBody = caseBody;
  }
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
