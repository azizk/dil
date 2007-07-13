/++
  Author: Aziz Köksal
  License: GPL2
+/
module Statements;

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
