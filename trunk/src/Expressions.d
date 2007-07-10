/++
  Author: Aziz Köksal
  License: GPL2
+/
module Expressions;
import Token;
import Types;
import Declarations;

class Expression
{

}

class EmptyExpression : Expression
{

}

class BinaryExpression : Expression
{
  Expression left, right;
  TOK tok;
  this(Expression left, Expression right, TOK tok)
  {
    this.left = left;
    this.right = right;
    this.tok = tok;
  }
}

class CondExpression : BinaryExpression
{
  Expression condition;
  this(Expression condition, Expression left, Expression right)
  {
    this.condition = condition;
    super(left, right, TOK.Comma);
  }
}

class CommaExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.Comma); }
}

class OrOrExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.OrLogical); }
}

class AndAndExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.AndLogical); }
}

class OrExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.OrBinary); }
}

class XorExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.Xor); }
}

class AndExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.AndBinary); }
}

class CmpExpression : BinaryExpression
{
  this(Expression left, Expression right, TOK tok)
  { super(left, right, tok); }
}

class EqualExpression : CmpExpression
{
  this(Expression left, Expression right, TOK tok)
  { super(left, right, TOK.Equal); }
}

class IdentityExpression : CmpExpression
{
  this(Expression left, Expression right, TOK tok)
  { super(left, right, tok); }
}

class RelExpression : CmpExpression
{
  this(Expression left, Expression right, TOK tok)
  { super(left, right, tok); }
}

class InExpression : BinaryExpression
{
  this(Expression left, Expression right, TOK tok)
  { super(left, right, TOK.In); }
}

class LShiftExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.LShiftAssign); }
}

class RShiftExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.RShiftAssign); }
}

class URShiftExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.URShiftAssign); }
}

class PlusExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.Plus); }
}

class MinusExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.Minus); }
}

class MulExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.Mul); }
}

class DivExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.Div); }
}

class ModExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.Mod); }
}

class CatExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.Catenate); }
}

class AssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.Assign); }
}
class LShiftAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.LShiftAssign); }
}
class RShiftAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.RShiftAssign); }
}
class URShiftAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.URShiftAssign); }
}
class OrAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.OrAssign); }
}
class AndAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.AndAssign); }
}
class PlusAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.PlusAssign); }
}
class MinusAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.MinusAssign); }
}
class DivAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.DivAssign); }
}
class MulAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.MulAssign); }
}
class ModAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.ModAssign); }
}
class XorAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.XorAssign); }
}
class CatAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, TOK.CatAssign); }
}

class UnaryExpression : Expression
{
  Expression e;
  this(Expression e)
  { this.e = e; }
}

class AddressExpression : UnaryExpression
{
  this(Expression e)
  { super(e); }
}

class PreIncrExpression : UnaryExpression
{
  this(Expression e)
  { super(e); }
}

class PreDecrExpression : UnaryExpression
{
  this(Expression e)
  { super(e); }
}

class PostIncrExpression : UnaryExpression
{
  this(Expression e)
  { super(e); }
}

class PostDecrExpression : UnaryExpression
{
  this(Expression e)
  { super(e); }
}

class DerefExpression : UnaryExpression
{
  this(Expression e)
  { super(e); }
}

class SignExpression : UnaryExpression
{
  TOK sign;
  this(Expression e, TOK sign)
  {
    super(e);
    this.sign = sign;
  }
}

class NotExpression : UnaryExpression
{
  this(Expression e)
  { super(e); }
}

class CompExpression : UnaryExpression
{
  this(Expression e)
  { super(e); }
}

class DotExpression : UnaryExpression
{
  this(Expression e)
  { super(e); }
}

class DotIdExpression : UnaryExpression
{
  string ident;
  this(Expression e, string ident)
  {
    super(e);
    this.ident = ident;
  }
}

class CallExpression : UnaryExpression
{
  Expression[] args;
  this(Expression e, Expression[] args)
  {
    super(e);
    this.args = args;
  }
}

class NewExpression : UnaryExpression
{
  this(Expression e)
  { super(e); }
}

class DeleteExpression : UnaryExpression
{
  this(Expression e)
  { super(e); }
}

class CastExpression : UnaryExpression
{
  Type type;
  this(Expression e, Type type)
  {
    super(e);
    this.type = type;
  }
}

class AnonClassExpression : UnaryExpression
{
  this(Expression e)
  { super(e); }
}

class IndexExpression : UnaryExpression
{
  Expression[] args;
  this(Expression e, Expression[] args)
  {
    super(e);
    this.args = args;
  }
}

class SliceExpression : UnaryExpression
{
  Expression left, right;
  this(Expression e, Expression left, Expression right)
  {
    super(e);
    this.left = left;
    this.right = right;
  }
}

/*
class PrimaryExpression
{

}
*/

class IdentifierExpression : Expression
{
  string identifier;
  this(string identifier)
  {
    this.identifier = identifier;
  }
}

class GlobalIdExpression : Expression
{
  string identifier;
  this(string identifier)
  {
    this.identifier = identifier;
  }
}

class ThisExpression : Expression
{
  this()
  {}
}

class SuperExpression : Expression
{
  this()
  {}
}

class NullExpression : Expression
{
  this()
  {}
}

class DollarExpression : Expression
{
  this()
  {}
}

class BoolExpression : Expression
{
  bool value;
  this(bool value)
  { this.value = value; }
}

class IntNumberExpression : Expression
{
  TOK type;
  ulong number;
  this(TOK type, ulong number)
  {
    this.number = number;
    this.type = type;
  }
}

class RealNumberExpression : Expression
{
  TOK type;
  real number;
  this(TOK type, real number)
  {
    this.number = number;
    this.type = type;
  }
}

class CharLiteralExpression : Expression
{
  TOK tok;
  this(TOK tok)
  { this.tok = tok; }
}

class StringLiteralExpression : Expression
{
  string str;
  this(string str)
  { this.str = str; }
}

class ArrayLiteralExpression : Expression
{
  Expression[] values;
  this(Expression[] values)
  { this.values = values; }
}

class AssocArrayLiteralExpression : Expression
{
  Expression[] keys, values;
  this(Expression[] keys, Expression[] values)
  {
    this.keys = keys;
    this.values = values;
  }
}

class AssertExpression : Expression
{
  Expression expr, msg;
  this(Expression expr, Expression msg)
  {
    this.expr = expr;
    this.msg = msg;
  }
}

class MixinExpression : Expression
{
  Expression expr;
  this(Expression expr)
  {
    this.expr = expr;
  }
}

class ImportExpression : Expression
{
  Expression expr;
  this(Expression expr)
  {
    this.expr = expr;
  }
}

class TypeofExpression : Expression
{
  Type type;
  this(Type type)
  {
    this.type = type;
  }
}

class TypeDotIdExpression : Expression
{
  Type type;
  string ident;
  this(Type type, string ident)
  {
    this.type = type;
    this.ident = ident;
  }
}

class TypeidExpression : Expression
{
  Type type;
  this(Type type)
  {
    this.type = type;
  }
}

class IsExpression : Expression
{
  Type type;
  string ident;
  SpecializationType specType;
  this(Type type, string ident, SpecializationType specType)
  {
    this.type = type;
    this.ident = ident;
    this.specType = specType;
  }
}

class FunctionLiteralExpression : Expression
{
  FunctionType func;
  Declaration[] decls;
  TOK funcTok;

  this(FunctionType func, Declaration[] decls, TOK funcTok = TOK.Invalid)
  {
    this.func = func;
    this.decls = decls;
    this.funcTok = funcTok;
  }
}
