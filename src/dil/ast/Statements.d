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

class CompoundStmt : Statement
{
  this()
  {
    mixin(set_kind);
  }

  this(Statement[] stmnts)
  {
    this();
    addChildren(stmnts);
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
    this.children = cast(Node[])stmnts;
  }

  mixin copyMethod;
}

class IllegalStmt : Statement
{
  this()
  {
    mixin(set_kind);
  }
  mixin copyMethod;
}

class EmptyStmt : Statement
{
  this()
  {
    mixin(set_kind);
  }
  mixin copyMethod;
}

class FuncBodyStmt : Statement
{
  Statement funcBody, inBody, outBody;
  Token* outIdent; /// $(BNF "out" "(" Identifier ")")
  this(Statement funcBody, Statement inBody, Statement outBody,
       Token* outIdent)
  {
    mixin(set_kind);
    addOptChild(funcBody);
    addOptChild(inBody);
    addOptChild(outBody);
    this.funcBody = funcBody;
    this.inBody = inBody;
    this.outBody = outBody;
    this.outIdent = outIdent;
  }

  bool isEmpty()
  {
    return funcBody is null;
  }

  mixin copyMethod;
}

class ScopeStmt : Statement
{
  Statement stmnt;
  this(Statement s)
  {
    mixin(set_kind);
    addChild(s);
    this.stmnt = s;
  }
  mixin copyMethod;
}

class LabeledStmt : Statement
{
  Token* label;
  Statement stmnt;
  this(Token* label, Statement s)
  {
    mixin(set_kind);
    addChild(s);
    this.label = label;
    this.stmnt = s;
  }
  mixin copyMethod;
}

class ExpressionStmt : Statement
{
  Expression expr;
  this(Expression e)
  {
    mixin(set_kind);
    addChild(e);
    this.expr = e;
  }
  mixin copyMethod;
}

class DeclarationStmt : Statement
{
  Declaration decl;
  this(Declaration decl)
  {
    mixin(set_kind);
    addChild(decl);
    this.decl = decl;
  }
  mixin copyMethod;
}

class IfStmt : Statement
{
  Statement variable; // AutoDecl or VariableDecl
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
  mixin copyMethod;
}

class WhileStmt : Statement
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
  mixin copyMethod;
}

class DoWhileStmt : Statement
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
  mixin copyMethod;
}

class ForStmt : Statement
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
  mixin copyMethod;
}

class ForeachStmt : Statement
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
    return tok == TOK.ForeachReverse;
  }

  mixin copyMethod;
}

// version(D2)
// {
class ForeachRangeStmt : Statement
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
  mixin copyMethod;
}
// }

class SwitchStmt : Statement
{
  Expression condition;
  Statement switchBody;
  bool isFinal;

  this(Expression condition, Statement switchBody, bool isFinal = false)
  {
    mixin(set_kind);
    addChild(condition);
    addChild(switchBody);

    this.condition = condition;
    this.switchBody = switchBody;
    this.isFinal = isFinal;
  }
  mixin copyMethod;
}

class CaseStmt : Statement
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
  mixin copyMethod;
}

// D2
class CaseRangeStmt : Statement
{
  Expression left, right;
  Statement caseBody;

  this(Expression left, Expression right, Statement caseBody)
  {
    mixin(set_kind);
    addChild(left);
    addChild(right);
    addChild(caseBody);

    this.left = left;
    this.right = right;
    this.caseBody = caseBody;
  }
  mixin copyMethod;
}

class DefaultStmt : Statement
{
  Statement defaultBody;
  this(Statement defaultBody)
  {
    mixin(set_kind);
    addChild(defaultBody);

    this.defaultBody = defaultBody;
  }
  mixin copyMethod;
}

class ContinueStmt : Statement
{
  Token* ident;
  this(Token* ident)
  {
    mixin(set_kind);
    this.ident = ident;
  }
  mixin copyMethod;
}

class BreakStmt : Statement
{
  Token* ident;
  this(Token* ident)
  {
    mixin(set_kind);
    this.ident = ident;
  }
  mixin copyMethod;
}

class ReturnStmt : Statement
{
  Expression expr;
  this(Expression e)
  {
    mixin(set_kind);
    addOptChild(e);
    this.expr = e;
  }
  mixin copyMethod;
}

class GotoStmt : Statement
{
  Token* ident;
  Expression expr;
  this(Token* ident, Expression expr)
  {
    mixin(set_kind);
    addOptChild(expr);
    this.ident = ident;
    this.expr = expr;
  }
  mixin copyMethod;
}

class WithStmt : Statement
{
  Expression expr;
  Statement withBody;
  this(Expression e, Statement withBody)
  {
    mixin(set_kind);
    addChild(e);
    addChild(withBody);

    this.expr = e;
    this.withBody = withBody;
  }
  mixin copyMethod;
}

class SynchronizedStmt : Statement
{
  Expression expr;
  Statement syncBody;
  this(Expression e, Statement syncBody)
  {
    mixin(set_kind);
    addOptChild(e);
    addChild(syncBody);

    this.expr = e;
    this.syncBody = syncBody;
  }
  mixin copyMethod;
}

class TryStmt : Statement
{
  Statement tryBody;
  CatchStmt[] catchBodies;
  FinallyStmt finallyBody;
  this(Statement tryBody, CatchStmt[] catchBodies, FinallyStmt finallyBody)
  {
    mixin(set_kind);
    addChild(tryBody);
    addOptChildren(catchBodies);
    addOptChild(finallyBody);

    this.tryBody = tryBody;
    this.catchBodies = catchBodies;
    this.finallyBody = finallyBody;
  }
  mixin copyMethod;
}

class CatchStmt : Statement
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
  mixin copyMethod;
}

class FinallyStmt : Statement
{
  Statement finallyBody;
  this(Statement finallyBody)
  {
    mixin(set_kind);
    addChild(finallyBody);
    this.finallyBody = finallyBody;
  }
  mixin copyMethod;
}

class ScopeGuardStmt : Statement
{
  Token* condition;
  Statement scopeBody;
  this(Token* condition, Statement scopeBody)
  {
    mixin(set_kind);
    addChild(scopeBody);
    this.condition = condition;
    this.scopeBody = scopeBody;
  }
  mixin copyMethod;
}

class ThrowStmt : Statement
{
  Expression expr;
  this(Expression e)
  {
    mixin(set_kind);
    addChild(e);
    this.expr = e;
  }
  mixin copyMethod;
}

class VolatileStmt : Statement
{
  Statement volatileBody;
  this(Statement volatileBody)
  {
    mixin(set_kind);
    addOptChild(volatileBody);
    this.volatileBody = volatileBody;
  }
  mixin copyMethod;
}

class AsmBlockStmt : Statement
{
  CompoundStmt statements;
  this(CompoundStmt statements)
  {
    mixin(set_kind);
    addChild(statements);
    this.statements = statements;
  }
  mixin copyMethod;
}

class AsmStmt : Statement
{
  Token* ident;
  Expression[] operands;
  this(Token* ident, Expression[] operands)
  {
    mixin(set_kind);
    addOptChildren(operands);
    this.ident = ident;
    this.operands = operands;
  }
  mixin copyMethod;
}

class AsmAlignStmt : Statement
{
  int number;
  Token* numtok;
  this(Token* numtok)
  {
    mixin(set_kind);
    this.numtok = numtok;
    this.number = numtok.int_;
  }
  mixin copyMethod;
}

class IllegalAsmStmt : IllegalStmt
{
  this()
  {
    mixin(set_kind);
  }
  mixin copyMethod;
}

class PragmaStmt : Statement
{
  Token* ident;
  Expression[] args;
  Statement pragmaBody;
  this(Token* ident, Expression[] args, Statement pragmaBody)
  {
    mixin(set_kind);
    addOptChildren(args);
    addChild(pragmaBody);

    this.ident = ident;
    this.args = args;
    this.pragmaBody = pragmaBody;
  }
  mixin copyMethod;
}

class MixinStmt : Statement
{
  Expression templateExpr;
  Token* mixinIdent;
  this(Expression templateExpr, Token* mixinIdent)
  {
    mixin(set_kind);
    addChild(templateExpr);
    this.templateExpr = templateExpr;
    this.mixinIdent = mixinIdent;
  }
  mixin copyMethod;
}

class StaticIfStmt : Statement
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
  mixin copyMethod;
}

class StaticAssertStmt : Statement
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
  mixin copyMethod;
}

abstract class ConditionalCompilationStmt : Statement
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

class DebugStmt : ConditionalCompilationStmt
{
  this(Token* cond, Statement debugBody, Statement elseBody)
  {
    super(cond, debugBody, elseBody);
    mixin(set_kind);
  }
  mixin copyMethod;
}

class VersionStmt : ConditionalCompilationStmt
{
  this(Token* cond, Statement versionBody, Statement elseBody)
  {
    super(cond, versionBody, elseBody);
    mixin(set_kind);
  }
  mixin copyMethod;
}
