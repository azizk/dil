/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Statements;
import dil.SyntaxTree;
import dil.Expressions;
import dil.Declarations;
import dil.Types;
import dil.Token;

abstract class Statement : Node
{
  this()
  {
    super(NodeCategory.Statement);
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
    this.children ~= s;
  }
}

class IllegalStatement : Statement
{
  Token* tok;
  this(Token* tok)
  {
    mixin(set_kind);
    this.tok = tok;
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
  Token* outIdent;
  this()
  {
    super(NodeCategory.Other);
    mixin(set_kind);
  }

  void finishConstruction()
  {
    if (funcBody)
      this.children ~= funcBody;
    if (inBody)
      this.children ~= inBody;
    if (outBody)
      this.children ~= outBody;
  }
}

class ScopeStatement : Statement
{
  Statement s;
  this(Statement s)
  {
    mixin(set_kind);
    this.children = [s];
    this.s = s;
  }
}

class LabeledStatement : Statement
{
  Token* label;
  Statement s;
  this(Token* label, Statement s)
  {
    mixin(set_kind);
    this.children = [s];
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
    this.children = [expression];
    this.expression = expression;
  }
}

class DeclarationStatement : Statement
{
  Declaration declaration;
  this(Declaration declaration)
  {
    mixin(set_kind);
    this.children = [declaration];
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
      this.children ~= variable;
    else
      this.children ~= condition;
    this.children ~= ifBody;
    if (elseBody)
      this.children ~= elseBody;
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
    this.children = [cast(Node)condition, whileBody];
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
    this.children = [cast(Node)condition, doBody];
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
    if (init)
      this.children ~= init;
    if (condition)
      this.children ~= condition;
    if (increment)
      this.children ~= increment;
    this.children ~= forBody;
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
    this.children = [cast(Node)params, aggregate, forBody];
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
    this.children = [cast(Node)params, lower, upper, forBody];
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
    this.children = [cast(Node)condition, switchBody];
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
    this.children = cast(Node[])values ~ [caseBody];
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
    this.children = [defaultBody];
    this.defaultBody = defaultBody;
  }
}

class ContinueStatement : Statement
{
  Token* ident;
  this(Token* ident)
  {
    mixin(set_kind);
    this.ident = ident;
  }
}

class BreakStatement : Statement
{
  Token* ident;
  this(Token* ident)
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
    if (expr)
      this.children = [expr];
    this.expr = expr;
  }
}

class GotoStatement : Statement
{
  Token* ident;
  Expression caseExpr;
  this(Token* ident, Expression caseExpr)
  {
    mixin(set_kind);
    if (caseExpr)
      this.children = [caseExpr];
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
    this.children = [cast(Node)expr, withBody];
    this.expr = expr;
    this.withBody = withBody;
  }
}

class SynchronizedStatement : Statement
{
  Expression expr;
  Statement syncBody;
  this(Expression expr, Statement withBody)
  {
    mixin(set_kind);
    this.children = [cast(Node)expr, syncBody];
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
    this.children = [tryBody];
    if (catchBodies.length)
      this.children ~= catchBodies;
    if (finallyBody)
      this.children ~= finallyBody;
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
    this.children = [cast(Node)param, catchBody];
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
    this.children = [finallyBody];
    this.finallyBody = finallyBody;
  }
}

class ScopeGuardStatement : Statement
{
  Token* condition;
  Statement scopeBody;
  this(Token* condition, Statement scopeBody)
  {
    mixin(set_kind);
    this.children = [scopeBody];
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
    this.children = [expr];
    this.expr = expr;
  }
}

class VolatileStatement : Statement
{
  Statement volatileBody;
  this(Statement volatileBody)
  {
    mixin(set_kind);
    if (volatileBody)
      this.children = [volatileBody];
    this.volatileBody = volatileBody;
  }
}

class AsmStatement : Statement
{
  Statements statements;
  this(Statements statements)
  {
    mixin(set_kind);
    this.children = [statements];
    this.statements = statements;
  }
}

class AsmInstruction : Statement
{
  Token* ident;
  Expression[] operands;
  this(Token* ident, Expression[] operands)
  {
    mixin(set_kind);
    this.children = operands;
    this.ident = ident;
    this.operands = operands;
  }
}

class IllegalAsmInstruction : IllegalStatement
{
  this(Token* token)
  {
    super(token);
    mixin(set_kind);
  }
}

class PragmaStatement : Statement
{
  Token* ident;
  Expression[] args;
  Statement pragmaBody;
  this(Token* ident, Expression[] args, Statement pragmaBody)
  {
    mixin(set_kind);
    if (args.length)
      this.children = args;
    this.children ~= pragmaBody;
    this.ident = ident;
    this.args = args;
    this.pragmaBody = pragmaBody;
  }
}

class MixinStatement : Statement
{
  Expression[] templateIdents;
  Token* mixinIdent;
  this(Expression[] templateIdents, Token* mixinIdent)
  {
    mixin(set_kind);
    this.children = templateIdents;
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
    this.children = [cast(Node)condition, ifBody];
    if (elseBody)
      this.children ~= elseBody;
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
    this.children = [condition];
    if (message)
      this.children ~= message;
    this.condition = condition;
    this.message = message;
  }
}

class DebugStatement : Statement
{
  Token* cond;
  Statement debugBody, elseBody;
  this(Token* cond, Statement debugBody, Statement elseBody)
  {
    mixin(set_kind);
    this.children = [debugBody];
    if (elseBody)
      this.children ~= elseBody;
    this.cond = cond;
    this.debugBody = debugBody;
    this.elseBody = elseBody;
  }
}

class VersionStatement : Statement
{
  Token* cond;
  Statement versionBody, elseBody;
  this(Token* cond, Statement versionBody, Statement elseBody)
  {
    mixin(set_kind);
    this.children = [versionBody];
    if (elseBody)
      this.children ~= [elseBody];
    this.cond = cond;
    this.versionBody = versionBody;
    this.elseBody = elseBody;
  }
}

class AttributeStatement : Statement
{
  TOK tok;
  Statement statement;
  this(TOK tok, Statement statement)
  {
    mixin(set_kind);
    assert(statement !is null);
    this.children = [statement];
    this.tok = tok;
    this.statement = statement;
  }
}

class ExternStatement : AttributeStatement
{
  Linkage linkage;
  this(Linkage linkage, Statement statement)
  {
    super(TOK.Extern, statement);
    mixin(set_kind);
    if (linkage)
      this.children ~= linkage;
    this.linkage = linkage;
  }
}
