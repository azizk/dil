/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Interpreter;

import dil.ast.Visitor;
import dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;

import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Scope,
       dil.semantic.Types;
import dil.Information;

class Interpreter : Visitor
{
  Scope scop;
  InfoManager infoMan;

  static class Result : Expression
  {
  }

  static const Result CantInterpret;

  static this()
  {
    CantInterpret = new Result;
    CantInterpret.type = Types.Error;
  }

  this(InfoManager infoMan)
  {
    this.infoMan = infoMan;
  }

  /// Start interpretation.
  Expression start(Expression e)
  {
    return e;
  }

  bool isImmutable(Expression e)
  {
    switch (e.kind)
    {
    alias NodeKind NK;
    case NK.IntExpression, NK.RealExpression,
         NK.ComplexExpression, NK.CharExpression,
         NK.BoolExpression, NK.StringExpression:
      return true;
    default:
      return false;
    }
  }
}
