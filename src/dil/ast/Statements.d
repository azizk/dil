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
       dil.ast.NodeCopier,
       dil.ast.Meta;
import dil.lexer.IdTable;
import common;

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

  Statement[] stmnts() @property
  {
    return cast(Statement[])this.children;
  }

  void stmnts(Statement[] stmnts) @property
  {
    this.children = cast(Node[])stmnts;
  }

  mixin(memberInfo("stmnts"));

  mixin methods;
}

class IllegalStmt : Statement
{
  mixin(memberInfo());
  this()
  {
    mixin(set_kind);
  }
  mixin methods;
}

class EmptyStmt : Statement
{
  mixin(memberInfo());
  this()
  {
    mixin(set_kind);
  }
  mixin methods;
}

class FuncBodyStmt : Statement
{
  Statement funcBody, inBody, outBody;
  Token* outIdent; /// $(BNF "out" "(" Identifier ")")
  mixin(memberInfo("funcBody", "inBody", "outBody", "outIdent"));
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

  mixin methods;
}

class ScopeStmt : Statement
{
  Statement stmnt;
  mixin(memberInfo("stmnt"));
  this(Statement s)
  {
    mixin(set_kind);
    addChild(s);
    this.stmnt = s;
  }
  mixin methods;
}

class LabeledStmt : Statement
{
  Token* label;
  Statement stmnt;
  mixin(memberInfo("label", "stmnt"));
  this(Token* label, Statement s)
  {
    mixin(set_kind);
    addChild(s);
    this.label = label;
    this.stmnt = s;
  }
  mixin methods;
}

class ExpressionStmt : Statement
{
  Expression expr;
  mixin(memberInfo("expr"));
  this(Expression e)
  {
    mixin(set_kind);
    addChild(e);
    this.expr = e;
  }
  mixin methods;
}

class DeclarationStmt : Statement
{
  Declaration decl;
  mixin(memberInfo("decl"));
  this(Declaration decl)
  {
    mixin(set_kind);
    addChild(decl);
    this.decl = decl;
  }
  mixin methods;
}

class IfStmt : Statement
{
  Declaration variable; // VariablesDecl
  Expression condition;
  Statement ifBody;
  Statement elseBody;
  mixin(memberInfo("variable", "condition", "ifBody", "elseBody"));
  this(Declaration variable, Expression condition, Statement ifBody,
       Statement elseBody)
  {
    mixin(set_kind);
    if (variable) {
      addChild(variable);
      assert(variable.kind == NodeKind.VariablesDecl);
    }
    else
      addChild(condition);
    addChild(ifBody);
    addOptChild(elseBody);

    this.variable = variable;
    this.condition = condition;
    this.ifBody = ifBody;
    this.elseBody = elseBody;
  }
  mixin methods;
}

class WhileStmt : Statement
{
  Expression condition;
  Statement whileBody;
  mixin(memberInfo("condition", "whileBody"));
  this(Expression condition, Statement whileBody)
  {
    mixin(set_kind);
    addChild(condition);
    addChild(whileBody);

    this.condition = condition;
    this.whileBody = whileBody;
  }
  mixin methods;
}

class DoWhileStmt : Statement
{
  Statement doBody;
  Expression condition;
  mixin(memberInfo("condition", "doBody"));
  this(Expression condition, Statement doBody)
  {
    mixin(set_kind);
    addChild(doBody);
    addChild(condition);

    this.condition = condition;
    this.doBody = doBody;
  }
  mixin methods;
}

class ForStmt : Statement
{
  Statement init;
  Expression condition, increment;
  Statement forBody;

  mixin(memberInfo("init", "condition", "increment", "forBody"));
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
  mixin methods;
}

class ForeachStmt : Statement
{
  TOK tok;
  Parameters params;
  Expression aggregate;
  Statement forBody;

  mixin(memberInfo("tok", "params", "aggregate", "forBody"));
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

  mixin methods;
}

// version(D2)
// {
class ForeachRangeStmt : Statement
{
  TOK tok;
  Parameters params;
  Expression lower, upper;
  Statement forBody;

  mixin(memberInfo("tok", "params", "lower", "upper", "forBody"));
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
  mixin methods;
}
// }

class SwitchStmt : Statement
{
  Expression condition;
  Statement switchBody;
  bool isFinal;

  mixin(memberInfo("condition", "switchBody", "isFinal"));
  this(Expression condition, Statement switchBody, bool isFinal = false)
  {
    mixin(set_kind);
    addChild(condition);
    addChild(switchBody);

    this.condition = condition;
    this.switchBody = switchBody;
    this.isFinal = isFinal;
  }
  mixin methods;
}

class CaseStmt : Statement
{
  Expression[] values;
  Statement caseBody;

  mixin(memberInfo("values", "caseBody"));
  this(Expression[] values, Statement caseBody)
  {
    mixin(set_kind);
    addChildren(values);
    addChild(caseBody);

    this.values = values;
    this.caseBody = caseBody;
  }
  mixin methods;
}

// D2
class CaseRangeStmt : Statement
{
  Expression left, right;
  Statement caseBody;

  mixin(memberInfo("left", "right", "caseBody"));
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
  mixin methods;
}

class DefaultStmt : Statement
{
  Statement defaultBody;
  mixin(memberInfo("defaultBody"));
  this(Statement defaultBody)
  {
    mixin(set_kind);
    addChild(defaultBody);

    this.defaultBody = defaultBody;
  }
  mixin methods;
}

class ContinueStmt : Statement
{
  Token* ident;
  mixin(memberInfo("ident"));
  this(Token* ident)
  {
    mixin(set_kind);
    this.ident = ident;
  }
  mixin methods;
}

class BreakStmt : Statement
{
  Token* ident;
  mixin(memberInfo("ident"));
  this(Token* ident)
  {
    mixin(set_kind);
    this.ident = ident;
  }
  mixin methods;
}

class ReturnStmt : Statement
{
  Expression expr;
  mixin(memberInfo("expr"));
  this(Expression e)
  {
    mixin(set_kind);
    addOptChild(e);
    this.expr = e;
  }
  mixin methods;
}

class GotoStmt : Statement
{
  Token* ident;
  Expression expr;
  mixin(memberInfo("ident", "expr"));
  this(Token* ident, Expression expr)
  {
    mixin(set_kind);
    addOptChild(expr);
    this.ident = ident;
    this.expr = expr;
  }
  mixin methods;
}

class WithStmt : Statement
{
  Expression expr;
  Statement withBody;
  mixin(memberInfo("expr", "withBody"));
  this(Expression e, Statement withBody)
  {
    mixin(set_kind);
    addChild(e);
    addChild(withBody);

    this.expr = e;
    this.withBody = withBody;
  }
  mixin methods;
}

class SynchronizedStmt : Statement
{
  Expression expr;
  Statement syncBody;
  mixin(memberInfo("expr", "syncBody"));
  this(Expression e, Statement syncBody)
  {
    mixin(set_kind);
    addOptChild(e);
    addChild(syncBody);

    this.expr = e;
    this.syncBody = syncBody;
  }
  mixin methods;
}

class TryStmt : Statement
{
  Statement tryBody;
  CatchStmt[] catchBodies;
  FinallyStmt finallyBody;
  mixin(memberInfo("tryBody", "catchBodies", "finallyBody"));
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
  mixin methods;
}

class CatchStmt : Statement
{
  Parameter param;
  Statement catchBody;
  mixin(memberInfo("param", "catchBody"));
  this(Parameter param, Statement catchBody)
  {
    mixin(set_kind);
    addOptChild(param);
    addChild(catchBody);
    this.param = param;
    this.catchBody = catchBody;
  }
  mixin methods;
}

class FinallyStmt : Statement
{
  Statement finallyBody;
  mixin(memberInfo("finallyBody"));
  this(Statement finallyBody)
  {
    mixin(set_kind);
    addChild(finallyBody);
    this.finallyBody = finallyBody;
  }
  mixin methods;
}

class ScopeGuardStmt : Statement
{
  Token* condition;
  Statement scopeBody;
  mixin(memberInfo("condition", "scopeBody"));
  this(Token* condition, Statement scopeBody)
  {
    mixin(set_kind);
    addChild(scopeBody);
    this.condition = condition;
    this.scopeBody = scopeBody;
  }
  mixin methods;
}

class ThrowStmt : Statement
{
  Expression expr;
  mixin(memberInfo("expr"));
  this(Expression e)
  {
    mixin(set_kind);
    addChild(e);
    this.expr = e;
  }
  mixin methods;
}

class VolatileStmt : Statement
{
  Statement volatileBody;
  mixin(memberInfo("volatileBody"));
  this(Statement volatileBody)
  {
    mixin(set_kind);
    addOptChild(volatileBody);
    this.volatileBody = volatileBody;
  }
  mixin methods;
}

class AsmBlockStmt : Statement
{
  CompoundStmt statements;
  mixin(memberInfo("statements"));
  this(CompoundStmt statements)
  {
    mixin(set_kind);
    addChild(statements);
    this.statements = statements;
  }
  mixin methods;
}

class AsmStmt : Statement
{
  Token* ident;
  Expression[] operands;
  mixin(memberInfo("ident", "operands"));
  this(Token* ident, Expression[] operands)
  {
    mixin(set_kind);
    addOptChildren(operands);
    this.ident = ident;
    this.operands = operands;
  }
  mixin methods;
}

class AsmAlignStmt : Statement
{
  int number;
  Token* numtok;
  mixin(memberInfo("numtok"));
  this(Token* numtok)
  {
    mixin(set_kind);
    this.numtok = numtok;
    this.number = numtok.int_;
  }
  mixin methods;
}

class IllegalAsmStmt : Statement
{
  mixin(memberInfo());
  this()
  {
    mixin(set_kind);
  }
  mixin methods;
}

class PragmaStmt : Statement
{
  Token* ident;
  Expression[] args;
  Statement pragmaBody;
  mixin(memberInfo("ident", "args", "pragmaBody"));
  this(Token* ident, Expression[] args, Statement pragmaBody)
  {
    mixin(set_kind);
    addOptChildren(args);
    addChild(pragmaBody);

    this.ident = ident;
    this.args = args;
    this.pragmaBody = pragmaBody;
  }
  mixin methods;
}

class MixinStmt : Statement
{
  Expression templateExpr;
  Token* mixinIdent;
  mixin(memberInfo("templateExpr", "mixinIdent"));
  this(Expression templateExpr, Token* mixinIdent)
  {
    mixin(set_kind);
    addChild(templateExpr);
    this.templateExpr = templateExpr;
    this.mixinIdent = mixinIdent;
  }
  mixin methods;
}

class StaticIfStmt : Statement
{
  Expression condition;
  Statement ifBody, elseBody;
  mixin(memberInfo("condition", "ifBody", "elseBody"));
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
  mixin methods;
}

class StaticAssertStmt : Statement
{
  Expression condition, message;
  mixin(memberInfo("condition", "message"));
  this(Expression condition, Expression message)
  {
    mixin(set_kind);
    addChild(condition);
    addOptChild(message);
    this.condition = condition;
    this.message = message;
  }
  mixin methods;
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
  mixin(memberInfo("cond", "mainBody", "elseBody"));
  this(Token* cond, Statement debugBody, Statement elseBody)
  {
    super(cond, debugBody, elseBody);
    mixin(set_kind);
  }
  mixin methods;
}

class VersionStmt : ConditionalCompilationStmt
{
  mixin(memberInfo("cond", "mainBody", "elseBody"));
  this(Token* cond, Statement versionBody, Statement elseBody)
  {
    super(cond, versionBody, elseBody);
    mixin(set_kind);
  }
  mixin methods;
}
