/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Analysis;

import dil.ast.Node;
import dil.ast.Expressions;
import dil.semantic.Scope;
import dil.lexer.IdTable;
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
