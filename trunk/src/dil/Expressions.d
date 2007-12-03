/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Expressions;
import dil.SyntaxTree;
import dil.Token;
import dil.Types;
import dil.Declarations;
import dil.Statements;

abstract class Expression : Node
{
  this()
  {
    super(NodeCategory.Expression);
  }
}

class EmptyExpression : Expression
{
  this()
  {
    mixin(set_kind);
  }
}

abstract class BinaryExpression : Expression
{
  Expression left, right;
  Token* tok;
  this(Expression left, Expression right, Token* tok)
  {
    addChildren([left, right]);
    this.left = left;
    this.right = right;
    this.tok = tok;
  }
}

class CondExpression : BinaryExpression
{
  Expression condition;
  this(Expression condition, Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
    addChild(condition);
    this.condition = condition;
  }
}

class CommaExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class OrOrExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class AndAndExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class OrExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class XorExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class AndExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

abstract class CmpExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
  }
}

class EqualExpression : CmpExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class IdentityExpression : CmpExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class RelExpression : CmpExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class InExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class LShiftExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class RShiftExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class URShiftExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class PlusExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class MinusExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class CatExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class MulExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class DivExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class ModExpression : BinaryExpression
{
  this(Expression left, Expression right, Token* tok)
  {
    super(left, right, tok);
    mixin(set_kind);
  }
}

class AssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  {
    super(left, right, null);
    mixin(set_kind);
  }
}
class LShiftAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  {
    super(left, right, null);
    mixin(set_kind);
  }
}
class RShiftAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  {
    super(left, right, null);
    mixin(set_kind);
  }
}
class URShiftAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  {
    super(left, right, null);
    mixin(set_kind);
  }
}
class OrAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  {
    super(left, right, null);
    mixin(set_kind);
  }
}
class AndAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  {
    super(left, right, null);
    mixin(set_kind);
  }
}
class PlusAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  {
    super(left, right, null);
    mixin(set_kind);
  }
}
class MinusAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  {
    super(left, right, null);
    mixin(set_kind);
  }
}
class DivAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  {
    super(left, right, null);
    mixin(set_kind);
  }
}
class MulAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  {
    super(left, right, null);
    mixin(set_kind);
  }
}
class ModAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  {
    super(left, right, null);
    mixin(set_kind);
  }
}
class XorAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  {
    super(left, right, null);
    mixin(set_kind);
  }
}
class CatAssignExpression : BinaryExpression
{
  this(Expression left, Expression right)
  {
    super(left, right, null);
    mixin(set_kind);
  }
}

abstract class UnaryExpression : Expression
{
  Expression e;
  this(Expression e)
  {
    addChild(e);
    this.e = e;
  }
}

class AddressExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class PreIncrExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class PreDecrExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class PostIncrExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class PostDecrExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class DerefExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class SignExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class NotExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class CompExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
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
    mixin(set_kind);
    addChild(dotList);
    this.dotList = dotList;
  }
}

class CallExpression : UnaryExpression
{
  Expression[] args;
  this(Expression e, Expression[] args)
  {
    super(e);
    mixin(set_kind);
    addOptChildren(args);
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
    mixin(set_kind);
    addOptChildren(newArgs);
    addChild(type);
    addOptChildren(ctorArgs);
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
  Declarations decls;
  this(/*Expression e, */Expression[] newArgs, BaseClass[] bases, Expression[] ctorArgs, Declarations decls)
  {
    /*super(e);*/
    mixin(set_kind);
    addOptChildren(newArgs);
    addOptChildren(bases);
    addOptChildren(ctorArgs);
    addChild(decls);

    this.newArgs = newArgs;
    this.bases = bases;
    this.ctorArgs = ctorArgs;
    this.decls = decls;
  }
}

class DeleteExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class CastExpression : UnaryExpression
{
  Type type;
  this(Expression e, Type type)
  {
    addChild(type); // Add type before super().
    super(e);
    mixin(set_kind);
    this.type = type;
  }
}

class IndexExpression : UnaryExpression
{
  Expression[] args;
  this(Expression e, Expression[] args)
  {
    super(e);
    mixin(set_kind);
    addChildren(args);
    this.args = args;
  }
}

class SliceExpression : UnaryExpression
{
  Expression left, right;
  this(Expression e, Expression left, Expression right)
  {
    super(e);
    mixin(set_kind);
    assert(left ? (right !is null) : right is null);
    if (left)
      addChildren([left, right]);

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
    mixin(set_kind);
    this.identifier = identifier;
  }
}

class SpecialTokenExpression : Expression
{
  Token* special;
  this(Token* special)
  {
    mixin(set_kind);
    this.special = special;
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

class DotExpression : Expression
{
  this()
  {
    mixin(set_kind);
  }
}

class DotListExpression : Expression
{
  Expression[] items;
  this(Expression[] items)
  {
    mixin(set_kind);
    addChildren(items);
    this.items = items;
  }
}

class TemplateInstanceExpression : Expression
{
  Token* ident;
  TemplateArguments targs;
  this(Token* ident, TemplateArguments targs)
  {
    mixin(set_kind);
    addOptChild(targs);
    this.ident = ident;
    this.targs = targs;
  }
}

class ThisExpression : Expression
{
  this()
  {
    mixin(set_kind);
  }
}

class SuperExpression : Expression
{
  this()
  {
    mixin(set_kind);
  }
}

class NullExpression : Expression
{
  this()
  {
    mixin(set_kind);
  }
}

class DollarExpression : Expression
{
  this()
  {
    mixin(set_kind);
  }
}

class BoolExpression : Expression
{
  this()
  {
    mixin(set_kind);
  }
}

class IntExpression : Expression
{
  TOK type;
  ulong number;
  this(TOK type, ulong number)
  {
    mixin(set_kind);
    this.number = number;
    this.type = type;
  }
}

class RealExpression : Expression
{
  TOK type;
  real number;
  this(TOK type, real number)
  {
    mixin(set_kind);
    this.number = number;
    this.type = type;
  }
}

class CharExpression : Expression
{
  Token* charLiteral;
  this(Token* charLiteral)
  {
    mixin(set_kind);
    this.charLiteral = charLiteral;
  }
}

class StringExpression : Expression
{
  Token*[] strings;
  this(Token*[] strings)
  {
    mixin(set_kind);
    this.strings = strings;
  }

  char[] getString()
  {
    char[] buffer;
    foreach (strTok; strings)
    {
      buffer ~= strTok.str[0..$-1];
    }
    return buffer;
  }
}

class ArrayLiteralExpression : Expression
{
  Expression[] values;
  this(Expression[] values)
  {
    mixin(set_kind);
    addOptChildren(values);
    this.values = values;
  }
}

class AArrayLiteralExpression : Expression
{
  Expression[] keys, values;
  this(Expression[] keys, Expression[] values)
  {
    assert(keys.length == values.length);
    mixin(set_kind);
    foreach (i, key; keys)
      addChildren([key, values[i]]);
    this.keys = keys;
    this.values = values;
  }
}

class AssertExpression : Expression
{
  Expression expr, msg;
  this(Expression expr, Expression msg)
  {
    mixin(set_kind);
    addChild(expr);
    addOptChild(msg);
    this.expr = expr;
    this.msg = msg;
  }
}

class MixinExpression : Expression
{
  Expression expr;
  this(Expression expr)
  {
    mixin(set_kind);
    addChild(expr);
    this.expr = expr;
  }
}

class ImportExpression : Expression
{
  Expression expr;
  this(Expression expr)
  {
    mixin(set_kind);
    addChild(expr);
    this.expr = expr;
  }
}

class TypeofExpression : Expression
{
  Type type;
  this(Type type)
  {
    mixin(set_kind);
    addChild(type);
    this.type = type;
  }
}

class TypeDotIdExpression : Expression
{
  Type type;
  Token* ident;
  this(Type type, Token* ident)
  {
    mixin(set_kind);
    addChild(type);
    this.type = type;
    this.ident = ident;
  }
}

class TypeidExpression : Expression
{
  Type type;
  this(Type type)
  {
    mixin(set_kind);
    addChild(type);
    this.type = type;
  }
}

class IsExpression : Expression
{
  Type type;
  Token* ident;
  Token* opTok, specTok;
  Type specType;
  TemplateParameters tparams; // D 2.0
  this(Type type, Token* ident, Token* opTok, Token* specTok, Type specType, typeof(tparams) tparams)
  {
    mixin(set_kind);
    addChild(type);
    addOptChild(specType);
  version(D2)
    addOptChild(tparams);
    this.type = type;
    this.ident = ident;
    this.opTok = opTok;
    this.specTok = specTok;
    this.specType = specType;
    this.tparams = tparams;
  }
}

class FunctionLiteralExpression : Expression
{
  Type returnType;
  Parameters parameters;
  FunctionBody funcBody;

  this()
  {
    mixin(set_kind);
    addOptChild(returnType);
    addOptChild(parameters);
    addChild(funcBody);
  }

  this(Type returnType, Parameters parameters, FunctionBody funcBody)
  {
    this.returnType = returnType;
    this.parameters = parameters;
    this.funcBody = funcBody;
    this();
  }

  this(FunctionBody funcBody)
  {
    this.funcBody = funcBody;
    this();
  }
}

version(D2)
{
class TraitsExpression : Expression
{
  Token* ident;
  TemplateArguments targs;
  this(typeof(ident) ident, typeof(targs) targs)
  {
    mixin(set_kind);
    addOptChild(targs);
    this.ident = ident;
    this.targs = targs;
  }
}
}

class VoidInitializer : Expression
{
  this()
  {
    mixin(set_kind);
  }
}

class ArrayInitializer : Expression
{
  Expression[] keys;
  Expression[] values;
  this(Expression[] keys, Expression[] values)
  {
    assert(keys.length == values.length);
    mixin(set_kind);
    foreach (i, key; keys)
    {
      addOptChild(key); // The key is optional in ArrayInitializers.
      addChild(values[i]);
    }
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
    mixin(set_kind);
    addOptChildren(values);
    this.idents = idents;
    this.values = values;
  }
}

class AsmTypeExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class AsmOffsetExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class AsmSegExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class AsmPostBracketExpression : UnaryExpression
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class AsmBracketExpression : Expression
{
  Expression e;
  this(Expression e)
  {
    mixin(set_kind);
    addChild(e);
    this.e = e;
  }
}

class AsmLocalSizeExpression : Expression
{
  this()
  {
    mixin(set_kind);
  }
}

class AsmRegisterExpression : Expression
{
  Token* register;
  Token* number; // ST(0) - ST(7) or FS:0, FS:4, FS:8
  this(Token* register, Token* number = null)
  {
    mixin(set_kind);
    this.register = register;
    this.number = number;
  }
}
