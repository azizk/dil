/++
  Author: Aziz Köksal
  License: GPL3
+/
module Expressions;
import SyntaxTree;
import Token;
import Types;
import Declarations;
import Statements;

class Expression : Node
{
  this()
  {
    super(NodeType.Expression);
  }
}

class EmptyExpression : Expression
{

}

class BinaryExpression : Expression
{
  Expression left, right;
  Token* tok;
  this(Expression left, Expression right, Token* tok)
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
    super(left, right, null);
  }
}

class CommaExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class OrOrExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class AndAndExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class OrExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class XorExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class AndExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class CmpExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class EqualExpression : CmpExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class IdentityExpression : CmpExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class RelExpression : CmpExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class InExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class LShiftExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class RShiftExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class URShiftExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class PlusExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class MinusExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class CatExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class MulExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class DivExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class ModExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  { super(left, right, tok); }
}

class AssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, null); }
}
class LShiftAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, null); }
}
class RShiftAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, null); }
}
class URShiftAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, null); }
}
class OrAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, null); }
}
class AndAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, null); }
}
class PlusAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, null); }
}
class MinusAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, null); }
}
class DivAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, null); }
}
class MulAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, null); }
}
class ModAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, null); }
}
class XorAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, null); }
}
class CatAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  { super(left, right, null); }
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
  this(Expression e)
  {
    super(e);
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
/+
class DotIdExpression : UnaryExpression
{
  string ident;
  this(Expression e, string ident)
  {
    super(e);
    this.ident = ident;
  }
}
+/
/+
class DotTemplateInstanceExpression : UnaryExpression
{
  string ident;
  TemplateArguments targs;
  this(Expression e, string ident, TemplateArguments targs)
  {
    super(e);
    this.ident = ident;
    this.targs = targs;
  }
}
+/
class PostDotListExpression : UnaryExpression
{
  DotListExpression dotList;
  this(Expression e, DotListExpression dotList)
  {
    super(e);
    this.dotList = dotList;
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

class NewExpression : /*Unary*/Expression
{
  Expression[] newArgs;
  Type type;
  Expression[] ctorArgs;
  this(/*Expression e, */Expression[] newArgs, Type type, Expression[] ctorArgs)
  {
    /*super(e);*/
    this.newArgs = newArgs;
    this.type = type;
    this.ctorArgs = ctorArgs;
  }
}

class NewAnonClassExpression : /*Unary*/Expression
{
  Expression[] newArgs;
  BaseClass[] bases;
  Expression[] ctorArgs;
  Declaration[] decls;
  this(/*Expression e, */Expression[] newArgs, BaseClass[] bases, Expression[] ctorArgs, Declaration[] decls)
  {
    /*super(e);*/
    this.newArgs = newArgs;
    this.bases = bases;
    this.ctorArgs = ctorArgs;
    this.decls = decls;
  }
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
  Token* identifier;
  this(Token* identifier)
  {
    this.identifier = identifier;
  }
}
/*
class IdentifierListExpression : Expression
{
  Expression[] identList;
  this(Expression[] identList)
  {
    this.identList = identList;
  }
}
*/
class DotListExpression : Expression
{
  Expression[] items;
  this(Expression[] items)
  {
    this.items = items;
  }
}

class TemplateInstanceExpression : Expression
{
  Token* ident;
  TemplateArguments targs;
  this(Token* ident, TemplateArguments targs)
  {
    this.ident = ident;
    this.targs = targs;
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
  this()
  {}
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
  this()
  {}
}

class StringLiteralsExpression : Expression
{
  Token*[] strLiterals;
  this(Token*[] strLiterals)
  { this.strLiterals = strLiterals; }
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
  Token* ident;
  this(Type type, Token* ident)
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
  Token* ident;
  Token* opTok, specTok;
  Type specType;
  this(Type type, Token* ident, Token* opTok, Token* specTok, Type specType)
  {
    this.type = type;
    this.ident = ident;
    this.opTok = opTok;
    this.specTok = specTok;
    this.specType = specType;
  }
}

class FunctionLiteralExpression : Expression
{
  FunctionType funcType;
  FunctionBody funcBody;
  TOK funcTok;

  this(FunctionType funcType, FunctionBody funcBody, TOK funcTok = TOK.Invalid)
  {
    this.funcType = funcType;
    this.funcBody = funcBody;
    this.funcTok = funcTok;
  }
}

class VoidInitializer : Expression
{

}

class ArrayInitializer : Expression
{
  Expression[] keys;
  Expression[] values;
  this(Expression[] keys, Expression[] values)
  {
    this.keys = keys;
    this.values = values;
  }
}

class StructInitializer : Expression
{
  Token*[] idents;
  Expression[] values;
  this(Token*[] idents, Expression[] values)
  {
    this.idents = idents;
    this.values = values;
  }
}
