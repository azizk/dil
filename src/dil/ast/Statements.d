/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.ast.Statements;

public import dil.ast.Statement;
import dil.ast.Node,
       dil.ast.Expression,
       dil.ast.Declaration,
       dil.ast.Type,
       dil.ast.Parameters,
       dil.ast.NodeCopier;
import dil.lexer.IdTable;
import dil.semantic.Symbols;

class CompoundStatement : Statement
{
  this()
  {
    mixin(set_kind);
  }

  void opCatAssign(Statement s)
  {
    addChild(s);
  }

  Statement[] stmnts()
  {
    return cast(Statement[])this.children;
  }

  void stmnts(Statement[] stmnts)
  {
    this.children = stmnts;
  }

  mixin(copyMethod);
}

class IllegalStatement : Statement
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
}

class EmptyStatement : Statement
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
}

class FuncBodyStatement : Statement
{
  Statement funcBody, inBody, outBody;
  Identifier* outIdent;
  this()
  {
    mixin(set_kind);
  }

  void finishConstruction()
  {
    addOptChild(funcBody);
    addOptChild(inBody);
    addOptChild(outBody);
  }

  bool isEmpty()
  {
    return funcBody is null;
  }

  Function symbol;

  mixin(copyMethod);
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
  mixin(copyMethod);
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
  mixin(copyMethod);
}

class ExpressionStatement : Statement
{
  Expression e;
  this(Expression e)
  {
    mixin(set_kind);
    addChild(e);
    this.e = e;
  }
  mixin(copyMethod);
}

class DeclarationStatement : Statement
{
  Declaration decl;
  this(Declaration decl)
  {
    mixin(set_kind);
    addChild(decl);
    this.decl = decl;
  }
  mixin(copyMethod);
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
  mixin(copyMethod);
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
  mixin(copyMethod);
}

class DoWhileStatement : Statement
{
  Statement doBody;
  Expression condition;
  this(Expression condition, Statement doBody)
  {
    mixin(set_kind);
    addChild(doBody);
    addChild(condition);

    this.condition = condition;
    this.doBody = doBody;
  }
  mixin(copyMethod);
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
  mixin(copyMethod);
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

  /// Returns true if this is a foreach_reverse statement.
  bool isReverse()
  {
    return tok == TOK.Foreach_reverse;
  }

  mixin(copyMethod);
}

// version(D2)
// {
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
  mixin(copyMethod);
}
// }

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
  mixin(copyMethod);
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
  mixin(copyMethod);
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
  mixin(copyMethod);
}

class ContinueStatement : Statement
{
  Identifier* ident;
  this(Identifier* ident)
  {
    mixin(set_kind);
    this.ident = ident;
  }
  mixin(copyMethod);
}

class BreakStatement : Statement
{
  Identifier* ident;
  this(Identifier* ident)
  {
    mixin(set_kind);
    this.ident = ident;
  }
  mixin(copyMethod);
}

class ReturnStatement : Statement
{
  Expression e;
  this(Expression e)
  {
    mixin(set_kind);
    addOptChild(e);
    this.e = e;
  }
  mixin(copyMethod);
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
  mixin(copyMethod);
}

class WithStatement : Statement
{
  Expression e;
  Statement withBody;
  this(Expression e, Statement withBody)
  {
    mixin(set_kind);
    addChild(e);
    addChild(withBody);

    this.e = e;
    this.withBody = withBody;
  }
  mixin(copyMethod);
}

class SynchronizedStatement : Statement
{
  Expression e;
  Statement syncBody;
  this(Expression e, Statement syncBody)
  {
    mixin(set_kind);
    addOptChild(e);
    addChild(syncBody);

    this.e = e;
    this.syncBody = syncBody;
  }
  mixin(copyMethod);
}

class TryStatement : Statement
{
  Statement tryBody;
  CatchStatement[] catchBodies;
  FinallyStatement finallyBody;
  this(Statement tryBody, CatchStatement[] catchBodies, FinallyStatement finallyBody)
  {
    mixin(set_kind);
    addChild(tryBody);
    addOptChildren(catchBodies);
    addOptChild(finallyBody);

    this.tryBody = tryBody;
    this.catchBodies = catchBodies;
    this.finallyBody = finallyBody;
  }
  mixin(copyMethod);
}

class CatchStatement : Statement
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
  mixin(copyMethod);
}

class FinallyStatement : Statement
{
  Statement finallyBody;
  this(Statement finallyBody)
  {
    mixin(set_kind);
    addChild(finallyBody);
    this.finallyBody = finallyBody;
  }
  mixin(copyMethod);
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
  mixin(copyMethod);
}

class ThrowStatement : Statement
{
  Expression e;
  this(Expression e)
  {
    mixin(set_kind);
    addChild(e);
    this.e = e;
  }
  mixin(copyMethod);
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
  mixin(copyMethod);
}

class AsmBlockStatement : Statement
{
  CompoundStatement statements;
  this(CompoundStatement statements)
  {
    mixin(set_kind);
    addChild(statements);
    this.statements = statements;
  }
  mixin(copyMethod);
}

class AsmStatement : Statement
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
  mixin(copyMethod);
}

class AsmAlignStatement : Statement
{
  int number;
  this(int number)
  {
    mixin(set_kind);
    this.number = number;
  }
  mixin(copyMethod);
}

class IllegalAsmStatement : IllegalStatement
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
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
  mixin(copyMethod);
}

class MixinStatement : Statement
{
  Expression templateExpr;
  Identifier* mixinIdent;
  this(Expression templateExpr, Identifier* mixinIdent)
  {
    mixin(set_kind);
    addChild(templateExpr);
    this.templateExpr = templateExpr;
    this.mixinIdent = mixinIdent;
  }
  mixin(copyMethod);
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
  mixin(copyMethod);
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
  mixin(copyMethod);
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
  mixin(copyMethod);
}

class VersionStatement : ConditionalCompilationStatement
{
  this(Token* cond, Statement versionBody, Statement elseBody)
  {
    super(cond, versionBody, elseBody);
    mixin(set_kind);
  }
  mixin(copyMethod);
}
