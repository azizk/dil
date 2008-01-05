/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Statements;

import dil.ast.Node;
import dil.ast.Expressions;
import dil.ast.Declarations;
import dil.ast.Types;
import dil.lexer.IdTable;
import dil.semantic.Scope;
import dil.semantic.Analysis;

abstract class Statement : Node
{
  this()
  {
    super(NodeCategory.Statement);
  }

  void semantic(Scope scop)
  {

  }
}

class Statements : Statement
{
  this()
  {
    mixin(set_kind);
  }

  void opCatAssign(Statement s)
  {
    addChild(s);
  }
}

class IllegalStatement : Statement
{
  this()
  {
    mixin(set_kind);
  }
}

class EmptyStatement : Statement
{
  this()
  {
    mixin(set_kind);
  }
}

class FunctionBody : Node
{
  Statement funcBody, inBody, outBody;
  Identifier* outIdent;
  this()
  {
    super(NodeCategory.Other);
    mixin(set_kind);
  }

  void finishConstruction()
  {
    addOptChild(funcBody);
    addOptChild(inBody);
    addOptChild(outBody);
  }
}

class ScopeStatement : Statement
{
  Statement s;
  this(Statement s)
  {
    mixin(set_kind);
    addChild(s);
    this.s = s;
  }
}

class LabeledStatement : Statement
{
  Identifier* label;
  Statement s;
  this(Identifier* label, Statement s)
  {
    mixin(set_kind);
    addChild(s);
    this.label = label;
    this.s = s;
  }
}

class ExpressionStatement : Statement
{
  Expression expression;
  this(Expression expression)
  {
    mixin(set_kind);
    addChild(expression);
    this.expression = expression;
  }
}

class DeclarationStatement : Statement
{
  Declaration declaration;
  this(Declaration declaration)
  {
    mixin(set_kind);
    addChild(declaration);
    this.declaration = declaration;
  }
}

class IfStatement : Statement
{
  Statement variable; // AutoDeclaration or VariableDeclaration
  Expression condition;
  Statement ifBody;
  Statement elseBody;
  this(Statement variable, Expression condition, Statement ifBody, Statement elseBody)
  {
    mixin(set_kind);
    if (variable)
      addChild(variable);
    else
      addChild(condition);
    addChild(ifBody);
    addOptChild(elseBody);

    this.variable = variable;
    this.condition = condition;
    this.ifBody = ifBody;
    this.elseBody = elseBody;
  }
}

class WhileStatement : Statement
{
  Expression condition;
  Statement whileBody;
  this(Expression condition, Statement whileBody)
  {
    mixin(set_kind);
    addChild(condition);
    addChild(whileBody);

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
    mixin(set_kind);
    addChild(condition);
    addChild(doBody);

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
    mixin(set_kind);
    addOptChild(init);
    addOptChild(condition);
    addOptChild(increment);
    addChild(forBody);

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
    mixin(set_kind);
    addChildren([cast(Node)params, aggregate, forBody]);

    this.tok = tok;
    this.params = params;
    this.aggregate = aggregate;
    this.forBody = forBody;
  }
}

version(D2)
{
class ForeachRangeStatement : Statement
{
  TOK tok;
  Parameters params;
  Expression lower, upper;
  Statement forBody;

  this(TOK tok, Parameters params, Expression lower, Expression upper, Statement forBody)
  {
    mixin(set_kind);
    addChildren([cast(Node)params, lower, upper, forBody]);

    this.tok = tok;
    this.params = params;
    this.lower = lower;
    this.upper = upper;
    this.forBody = forBody;
  }
}
}

class SwitchStatement : Statement
{
  Expression condition;
  Statement switchBody;

  this(Expression condition, Statement switchBody)
  {
    mixin(set_kind);
    addChild(condition);
    addChild(switchBody);

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
    mixin(set_kind);
    addChildren(values);
    addChild(caseBody);

    this.values = values;
    this.caseBody = caseBody;
  }
}

class DefaultStatement : Statement
{
  Statement defaultBody;
  this(Statement defaultBody)
  {
    mixin(set_kind);
    addChild(defaultBody);

    this.defaultBody = defaultBody;
  }
}

class ContinueStatement : Statement
{
  Identifier* ident;
  this(Identifier* ident)
  {
    mixin(set_kind);
    this.ident = ident;
  }
}

class BreakStatement : Statement
{
  Identifier* ident;
  this(Identifier* ident)
  {
    mixin(set_kind);
    this.ident = ident;
  }
}

class ReturnStatement : Statement
{
  Expression expr;
  this(Expression expr)
  {
    mixin(set_kind);
    addOptChild(expr);
    this.expr = expr;
  }
}

class GotoStatement : Statement
{
  Identifier* ident;
  Expression caseExpr;
  this(Identifier* ident, Expression caseExpr)
  {
    mixin(set_kind);
    addOptChild(caseExpr);
    this.ident = ident;
    this.caseExpr = caseExpr;
  }
}

class WithStatement : Statement
{
  Expression expr;
  Statement withBody;
  this(Expression expr, Statement withBody)
  {
    mixin(set_kind);
    addChild(expr);
    addChild(withBody);

    this.expr = expr;
    this.withBody = withBody;
  }
}

class SynchronizedStatement : Statement
{
  Expression expr;
  Statement syncBody;
  this(Expression expr, Statement syncBody)
  {
    mixin(set_kind);
    addOptChild(expr);
    addChild(syncBody);

    this.expr = expr;
    this.syncBody = syncBody;
  }
}

class TryStatement : Statement
{
  Statement tryBody;
  CatchBody[] catchBodies;
  FinallyBody finallyBody;
  this(Statement tryBody, CatchBody[] catchBodies, FinallyBody finallyBody)
  {
    mixin(set_kind);
    addChild(tryBody);
    addOptChildren(catchBodies);
    addOptChild(finallyBody);

    this.tryBody = tryBody;
    this.catchBodies = catchBodies;
    this.finallyBody = finallyBody;
  }
}

class CatchBody : Statement
{
  Parameter param;
  Statement catchBody;
  this(Parameter param, Statement catchBody)
  {
    mixin(set_kind);
    addOptChild(param);
    addChild(catchBody);
    this.param = param;
    this.catchBody = catchBody;
  }
}

class FinallyBody : Statement
{
  Statement finallyBody;
  this(Statement finallyBody)
  {
    mixin(set_kind);
    addChild(finallyBody);
    this.finallyBody = finallyBody;
  }
}

class ScopeGuardStatement : Statement
{
  Identifier* condition;
  Statement scopeBody;
  this(Identifier* condition, Statement scopeBody)
  {
    mixin(set_kind);
    addChild(scopeBody);
    this.condition = condition;
    this.scopeBody = scopeBody;
  }
}

class ThrowStatement : Statement
{
  Expression expr;
  this(Expression expr)
  {
    mixin(set_kind);
    addChild(expr);
    this.expr = expr;
  }
}

class VolatileStatement : Statement
{
  Statement volatileBody;
  this(Statement volatileBody)
  {
    mixin(set_kind);
    addOptChild(volatileBody);
    this.volatileBody = volatileBody;
  }
}

class AsmStatement : Statement
{
  Statements statements;
  this(Statements statements)
  {
    mixin(set_kind);
    addChild(statements);
    this.statements = statements;
  }
}

class AsmInstruction : Statement
{
  Identifier* ident;
  Expression[] operands;
  this(Identifier* ident, Expression[] operands)
  {
    mixin(set_kind);
    addOptChildren(operands);
    this.ident = ident;
    this.operands = operands;
  }
}

class AsmAlignStatement : Statement
{
  int number;
  this(int number)
  {
    mixin(set_kind);
    this.number = number;
  }
}

class IllegalAsmInstruction : IllegalStatement
{
  this()
  {
    mixin(set_kind);
  }
}

class PragmaStatement : Statement
{
  Identifier* ident;
  Expression[] args;
  Statement pragmaBody;
  this(Identifier* ident, Expression[] args, Statement pragmaBody)
  {
    mixin(set_kind);
    addOptChildren(args);
    addChild(pragmaBody);

    this.ident = ident;
    this.args = args;
    this.pragmaBody = pragmaBody;
  }

  override void semantic(Scope scop)
  {
    pragmaSemantic(scop, begin, ident, args);
    pragmaBody.semantic(scop);
  }
}

class MixinStatement : Statement
{
  Expression[] templateIdents;
  Identifier* mixinIdent;
  this(Expression[] templateIdents, Identifier* mixinIdent)
  {
    mixin(set_kind);
    addChildren(templateIdents);
    this.templateIdents = templateIdents;
    this.mixinIdent = mixinIdent;
  }
}

class StaticIfStatement : Statement
{
  Expression condition;
  Statement ifBody, elseBody;
  this(Expression condition, Statement ifBody, Statement elseBody)
  {
    mixin(set_kind);
    addChild(condition);
    addChild(ifBody);
    addOptChild(elseBody);
    this.condition = condition;
    this.ifBody = ifBody;
    this.elseBody = elseBody;
  }
}

class StaticAssertStatement : Statement
{
  Expression condition, message;
  this(Expression condition, Expression message)
  {
    mixin(set_kind);
    addChild(condition);
    addOptChild(message);
    this.condition = condition;
    this.message = message;
  }
}

abstract class ConditionalCompilationStatement : Statement
{
  Token* cond;
  Statement mainBody, elseBody;
  this(Token* cond, Statement mainBody, Statement elseBody)
  {
    addChild(mainBody);
    addOptChild(elseBody);
    this.cond = cond;
    this.mainBody = mainBody;
    this.elseBody = elseBody;
  }
}

class DebugStatement : ConditionalCompilationStatement
{
  this(Token* cond, Statement debugBody, Statement elseBody)
  {
    super(cond, debugBody, elseBody);
    mixin(set_kind);
  }
}

class VersionStatement : ConditionalCompilationStatement
{
  this(Token* cond, Statement versionBody, Statement elseBody)
  {
    super(cond, versionBody, elseBody);
    mixin(set_kind);
  }
}
