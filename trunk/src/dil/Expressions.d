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
import dil.Identifier;
import dil.Scope;
import dil.TypeSystem;
import common;

abstract class Expression : Node
{
  Type type; /// The type of this expression.
  this()
  {
    super(NodeCategory.Expression);
  }

  // Semantic analysis:

  Expression semantic(Scope scop)
  {
    debug Stdout("SA for "~this.classinfo.name).newline;
    if (!type)
      type = Types.Undefined;
    return this;
  }

  import dil.Messages;
  void error(Scope scop, MID mid)
  {
    scop.error(this.begin, mid);
  }

  void error(Scope scop, char[] msg)
  {

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

  Expression semantic(Scope scop)
  {
    left = left.semantic(scop);
    right = right.semantic(scop);
    return this;
  }
}

class CondExpression : BinaryExpression
{
  Expression condition;
  this(Expression condition, Expression left, Expression right, Token* tok)
  {
    addChild(condition);
    super(left, right, tok);
    mixin(set_kind);
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
  TypeNode type;
  Expression[] ctorArgs;
  this(/*Expression e, */Expression[] newArgs, TypeNode type, Expression[] ctorArgs)
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
  TypeNode type;
  this(Expression e, TypeNode type)
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
  Identifier* identifier;
  this(Identifier* identifier)
  {
    mixin(set_kind);
    this.identifier = identifier;
  }
}

class SpecialTokenExpression : Expression
{
  Token* specialToken;
  this(Token* specialToken)
  {
    mixin(set_kind);
    this.specialToken = specialToken;
  }

  Expression e; /// The expression created in the semantic phase.

  Expression semantic(Scope)
  {
    if (type)
      return e;
    switch (specialToken.type)
    {
    case TOK.LINE, TOK.VERSION:
      e = new IntExpression(specialToken.uint_, Types.Uint);
      break;
    case TOK.FILE, TOK.DATE, TOK.TIME, TOK.TIMESTAMP, TOK.VENDOR:
      e = new StringExpression(specialToken.str);
      break;
    default:
      assert(0);
    }
    type = e.type;
    return e;
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
  Identifier* ident;
  TemplateArguments targs;
  this(Identifier* ident, TemplateArguments targs)
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

  this(Type type)
  {
    this();
    this.type = type;
  }

  Expression semantic(Scope)
  {
    if (!type)
      type = Types.Void_ptr;
    return this;
  }
}

class DollarExpression : Expression
{
  this()
  {
    mixin(set_kind);
  }

  Expression semantic(Scope scop)
  {
    if (type)
      return this;
    type = Types.Size_t;
    // if (!scop.inArraySubscript)
    //   error(scop, "$ can only be in an array subscript.");
    return this;
  }
}

class BoolExpression : Expression
{
  this()
  {
    mixin(set_kind);
  }

  Expression e;
  Expression semantic(Scope scop)
  {
    if (type)
      return this;
    assert(this.begin !is null);
    auto b = (this.begin.type == TOK.True) ? true : false;
    e = new IntExpression(b, Types.Bool);
    type = Types.Bool;
    return this;
  }
}

class IntExpression : Expression
{
  ulong number;

  this(ulong number, Type type)
  {
    mixin(set_kind);
    this.number = number;
    this.type = type;
  }

  this(Token* token)
  {
    auto type = Types.Int; // Should be most common case.
    switch (token.type)
    {
    // case TOK.Int32:
    //   type = Types.Int; break;
    case TOK.Uint32:
      type = Types.Uint; break;
    case TOK.Int64:
      type = Types.Long; break;
    case TOK.Uint64:
      type = Types.Ulong; break;
    default:
      assert(token.type == TOK.Int32);
    }
    this(token.ulong_, type);
  }

  Expression semantic(Scope)
  {
    if (type)
      return this;

    if (number & 0x8000_0000_0000_0000)
      type = Types.Ulong; // 0xFFFF_FFFF_FFFF_FFFF
    else if (number & 0xFFFF_FFFF_0000_0000)
      type = Types.Long; // 0x7FFF_FFFF_FFFF_FFFF
    else if (number & 0x8000_0000)
      type = Types.Uint; // 0xFFFF_FFFF
    else
      type = Types.Int; // 0x7FFF_FFFF
    return this;
  }
}

class RealExpression : Expression
{
  real number;

  this(real number, Type type)
  {
    mixin(set_kind);
    this.number = number;
    this.type = type;
  }

  this(Token* token)
  {
    auto type = Types.Double; // Most common case?
    switch (token.type)
    {
    case TOK.Float32:
      type = Types.Float; break;
    // case TOK.Float64:
    //   type = Types.Double; break;
    case TOK.Float80:
      type = Types.Real; break;
    case TOK.Imaginary32:
      type = Types.Ifloat; break;
    case TOK.Imaginary64:
      type = Types.Idouble; break;
    case TOK.Imaginary80:
      type = Types.Ireal; break;
    default:
      assert(token.type == TOK.Float64);
    }
    this(token.real_, type);
  }

  Expression semantic(Scope)
  {
    if (type)
      return this;
    type = Types.Double;
    return this;
  }
}

/++
  This expression holds a complex number.
  It is only created in the semantic phase.
+/
class ComplexExpression : Expression
{
  creal number;

  this(creal number, Type type)
  {
    mixin(set_kind);
    this.number = number;
    this.type = type;
  }

  Expression semantic(Scope)
  {
    if (type)
      return this;
    type = Types.Cdouble;
    return this;
  }
}

class CharExpression : Expression
{
  dchar character;
  this(dchar character)
  {
    mixin(set_kind);
    this.character = character;
  }

  Expression semantic(Scope scop)
  {
    if (type)
      return this;
    if (character <= 0xFF)
      type = Types.Char;
    else if (character <= 0xFFFF)
      type = Types.Wchar;
    else
      type = Types.Dchar;
    return this;
  }
}

class StringExpression : Expression
{
  Token*[] stringTokens;
  this()
  { mixin(set_kind); }

  /// Constructor used in parsing phase.
  this(Token*[] stringTokens)
  {
    this();
    this.stringTokens = stringTokens;
  }

  ubyte[] str;   /// The string data.
  Type charType; /// The character type of the string.
  // Constructors used in semantic phase.
  this(ubyte[] str, Type charType)
  {
    this();
    this.str = str;
    this.charType = charType;
    type = new TypeSArray(charType, str.length);
  }

  this(char[] str)
  {
    this(cast(ubyte[])str, Types.Char);
  }
  this(wchar[] str)
  {
    this(cast(ubyte[])str, Types.Wchar);
  }
  this(dchar[] str)
  {
    this(cast(ubyte[])str, Types.Dchar);
  }

  Expression semantic()
  {
    if (type)
      return this;
  }

  char[] getString()
  {
    char[] buffer;
    foreach (token; stringTokens)
      buffer ~= token.str[0..$-1];
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

  // import dil.Parser;
  Expression semantic(Scope scop)
  {
    // TODO:
    /+
    auto expr = this.expr.semantic(scop);
    auto strExpr = Cast!(StringExpression)(expr);
    // if (strExpr is null)
    //  error(scop, MID.MixinExpressionMustBeString);
    auto parser = new Parser(strExpr.getString(), "", scop.infoMan);
    expr = parser.start2();
    return expr;
    +/
    return null;
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
  TypeNode type;
  this(TypeNode type)
  {
    mixin(set_kind);
    addChild(type);
    this.type = type;
  }
}

class TypeDotIdExpression : Expression
{
  TypeNode type;
  Identifier* ident;
  this(TypeNode type, Identifier* ident)
  {
    mixin(set_kind);
    addChild(type);
    this.type = type;
    this.ident = ident;
  }
}

class TypeidExpression : Expression
{
  TypeNode type;
  this(TypeNode type)
  {
    mixin(set_kind);
    addChild(type);
    this.type = type;
  }
}

class IsExpression : Expression
{
  TypeNode type;
  Identifier* ident;
  Token* opTok, specTok;
  TypeNode specType;
  TemplateParameters tparams; // D 2.0
  this(TypeNode type, Identifier* ident, Token* opTok, Token* specTok,
       TypeNode specType, typeof(tparams) tparams)
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
  TypeNode returnType;
  Parameters parameters;
  FunctionBody funcBody;

  this()
  {
    mixin(set_kind);
    addOptChild(returnType);
    addOptChild(parameters);
    addChild(funcBody);
  }

  this(TypeNode returnType, Parameters parameters, FunctionBody funcBody)
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
  Identifier* ident;
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
  Identifier*[] idents;
  Expression[] values;
  this(Identifier*[] idents, Expression[] values)
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
  Identifier* register;
  int number; // ST(0) - ST(7) or FS:0, FS:4, FS:8
  this(Identifier* register, int number = -1)
  {
    mixin(set_kind);
    this.register = register;
    this.number = number;
  }
}
