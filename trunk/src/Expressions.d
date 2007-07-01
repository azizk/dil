/++
  Author: Aziz Köksal
  License: GPL2
+/
module Expressions;
import Token;

class Expression
{

}

class UnaryExpression : Expression
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

class IdentExpression : CmpExpression
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
  this(Expression left, Expression right, TOK tok)
  { super(left, right, tok); }
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

class PostfixExpression : UnaryExpression
{

}

class DotExpression : UnaryExpression
{

}

class NewExpression : UnaryExpression
{

}

class DeleteExpression : UnaryExpression
{

}

class CastExpression : UnaryExpression
{

}

class AnonClassExpression : UnaryExpression
{

}

class PrimaryExpression
{

}

class IndexExpression
{

}

class SliceExpression
{

}

class AssertExpression
{

}

class MixinExpression
{

}

class ImportExpression
{

}

class TypeIdExpression
{

}

class IsExpression : CmpExpression
{
  this(Expression left, Expression right, TOK tok)
  { super(left, right, tok); }
}
