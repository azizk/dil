/// Author: Aziz Köksal
/// License: GPL3
module dil.code.Interpreter;

import dil.ast.Visitor,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;
import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Types;
import dil.Diagnostics;

/// Used for compile-time evaluation of D code.
class Interpreter : Visitor
{
  Diagnostics diag;

  static class Result : Expression
  {
    override Result copy(){return null;}
  }

  static const Result NAR; /// Not a Result. Similar to NAN in floating point arithmetics.

  static this()
  {
    NAR = new Result;
    NAR.type = Types.Error;
  }

  /// Evaluates the expression e.
  /// Returns: NAR or a value.
  static Expression interpret(Expression e, Diagnostics diag)
  {
    return (new Interpreter(diag)).eval(e);
  }

  /// Executes the function at compile-time with the given arguments.
  /// Returns: NAR or a value.
  static Expression interpret(FunctionDeclaration fd, Expression[] args, Diagnostics diag)
  {
    return (new Interpreter(diag)).eval(fd, args);
  }

  /// Constructs an Interpreter object.
  this(Diagnostics diag)
  {
    this.diag = diag;
  }

  /// Start evaluation.
  Expression eval(Expression e)
  {
    return e;
  }

  /// Start evaluation of a function.
  Expression eval(FunctionDeclaration fd, Expression[] args)
  {
    // We cache this result so that we don't blindly try to reevaluate functions
    // that can't be evaluated at compile time
    if(fd.cantInterpret)
      return NAR;

    // TODO: check for nested/method

    // Check for invalid parameter types
    if(fd.params.hasVariadic() || fd.params.hasLazy())
    {
      fd.cantInterpret = true;
      return NAR;
    }

    // remove me plx
    assert(false);
    return NAR;
  }

  alias Expression E;

override
{
  E visit(CondExpression e)
  {
    auto res = visitE(e.condition);

    if(res !is NAR)
    {
      if(isBool(res, true))
        res = visitE(e.lhs);
      else if(isBool(res, false))
        res = visitE(e.rhs);
      else
        res = NAR;
    }

    return res;
  }

  E visit(CommaExpression e)
  {
    auto res = visitE(e.lhs);

    if(res !is NAR)
      res = visitE(e.rhs);

    return res;
  }

  E visit(OrOrExpression e)
  {
    auto res = visitE(e.lhs);

    if(res !is NAR)
    {
      if(isBool(res, true))
        res = new IntExpression(1, Types.Bool);
      else if(isBool(res, false))
      {
        res = visitE(e.rhs);

        if(res !is NAR)
        {
          if(isBool(res, true))
            res = new IntExpression(1, Types.Bool);
          else if(isBool(res, false))
            res = new IntExpression(0, Types.Bool);
          else
            res = NAR;
        }
      }
      else
        res = NAR;
    }

    return res;
  }

  E visit(AndAndExpression e)
  {
    auto res = visitE(e.lhs);

    if(res !is NAR)
    {
      if(isBool(res, false))
        res = new IntExpression(0, Types.Bool);
      else if(isBool(res, true))
      {
        res = visitE(e.rhs);

        if(res !is NAR)
        {
          if(isBool(res, true))
            res = new IntExpression(1, Types.Bool);
          else if(isBool(res, false))
            res = new IntExpression(0, Types.Bool);
          else
            res = NAR;
        }
      }
      else
        res = NAR;
    }

    return res;
  }

  /// Returns true if e is immutable.
  bool isImmutable(Expression e)
  {
    switch (e.kind)
    {
    alias NodeKind NK;
    case NK.IntExpression, NK.RealExpression,
         NK.ComplexExpression, NK.CharExpression,
         NK.BoolExpression, NK.StringExpression,
         NK.NullExpression:
      return true;
    default:
    }
    return false;
  }

  static bool isBool(Expression e, bool value)
  {
    switch(e.kind)
    {
    alias NodeKind NK;

    case NK.IntExpression:
      auto num = (cast(IntExpression)e).number;
      return num ? value == true : value == false;

    case NK.RealExpression:
      auto num = (cast(RealExpression)e).number;
      return num ? value == true : value == false;

    case NK.ComplexExpression:
      auto num = (cast(RealExpression)e).number;
      return num ? value == true : value == false;

    case NK.CharExpression:
      auto num = (cast(CharExpression)e).value.number;
      return num ? value == true : value == false;

    case NK.BoolExpression:
      auto num = (cast(BoolExpression)e).value.number;
      return num ? value == true : value == false;

    case NK.StringExpression:
      return value == true;

    case NK.NullExpression:
      return value == false;

    default:
    }
  }
}
