/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.semantic.Analysis;

import dil.ast.Node,
       dil.ast.Expressions;
import dil.semantic.Scope,
       dil.semantic.Types,
       dil.semantic.TypesEnum;
import dil.lexer.IdTable;
import dil.Compilation;
import common;

/// Common semantics for pragma declarations and statements.
void pragmaSemantic(Scope scop, Token* pragmaLoc,
                    Identifier* ident,
                    Expression[] args)
{
  if (ident is Ident.msg)
    pragma_msg(scop, pragmaLoc, args);
  else if (ident is Ident.lib)
    pragma_lib(scop, pragmaLoc, args);
  // else
  //   scop.error(begin, "unrecognized pragma");
}

/// Evaluates a msg pragma.
void pragma_msg(Scope scop, Token* pragmaLoc, Expression[] args)
{
  if (args.length == 0)
    return /*scop.error(pragmaLoc, "expected expression arguments to pragma")*/;

  foreach (arg; args)
  {
    auto e = arg/+.evaluate()+/;
    if (e is null)
    {
      // scop.error(e.begin, "expression is not evaluatable at compile time");
    }
    else if (auto stringExpr = e.Is!(StringExpression))
      // Print string to standard output.
      Stdout(stringExpr.getString());
    else
    {
      // scop.error(e.begin, "expression must evaluate to a string");
    }
  }
  // Print a newline at the end.
  Stdout('\n');
}

/// Evaluates a lib pragma.
void pragma_lib(Scope scop, Token* pragmaLoc, Expression[] args)
{
  if (args.length != 1)
    return /*scop.error(pragmaLoc, "expected one expression argument to pragma")*/;

  auto e = args[0]/+.evaluate()+/;
  if (e is null)
  {
    // scop.error(e.begin, "expression is not evaluatable at compile time");
  }
  else if (auto stringExpr = e.Is!(StringExpression))
  {
    // TODO: collect library paths in Module?
    // scop.modul.addLibrary(stringExpr.getString());
  }
  else
  {
    // scop.error(e.begin, "expression must evaluate to a string");
  }
}

/// Returns true if the first branch (of a debug declaration/statement) or
/// false if the else-branch should be compiled in.
bool debugBranchChoice(Token* cond, CompilationContext context)
{
  if (cond)
  {
    if (cond.kind == TOK.Identifier)
    {
      if (context.findDebugId(cond.ident.str))
        return true;
    }
    else if (cond.uint_ <= context.debugLevel)
      return true;
  }
  else if (1 <= context.debugLevel)
    return true;
  return false;
}

/// Returns true if the first branch (of a version declaration/statement) or
/// false if the else-branch should be compiled in.
bool versionBranchChoice(Token* cond, CompilationContext context)
{
  assert(cond);
  if (cond.kind == TOK.Identifier || cond.kind == TOK.Unittest)
  {
    if (context.findVersionId(cond.ident.str))
      return true;
  }
  else if (cond.uint_ >= context.versionLevel)
    return true;
  return false;
}

/// Performs an integer promotion on the type of e, according to spec.
void integerPromotion(Expression e)
{
  assert(e.type !is null);
  switch (e.type.baseType().tid)
  {
  case TYP.Bool, TYP.Int8, TYP.UInt8, TYP.Int16,
       TYP.UInt16, TYP.Char, TYP.WChar:
    e.type = Types.Int32;
    break;
  case TYP.DChar:
    e.type = Types.UInt32;
    break;
  default:
  }
}
