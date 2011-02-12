/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.ast.Expressions;

public import dil.ast.Expression;
import dil.ast.Node,
       dil.ast.Types,
       dil.ast.Declarations,
       dil.ast.Statements,
       dil.ast.Parameters,
       dil.ast.NodeCopier;
import dil.lexer.Identifier;
import dil.semantic.Types;
import dil.Float,
       dil.Complex;
import common;

class IllegalExpr : Expression
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
}

/// The base class for every binary operator.
///
/// The copy method is mixed in here, not in any derived class.
/// If a derived class has other nodes than lhs and rhs, then it has
/// to have its own copy method which handles additional nodes.
abstract class BinaryExpr : Expression
{
  Expression lhs; /// Left-hand side expression.
  Expression rhs; /// Right-hand side expression.
  Token* optok;   /// The operator token.

  /// Constructs a BinaryExpr object.
  this(Expression lhs, Expression rhs, Token* optok)
  {
    addChildren([lhs, rhs]);
    this.lhs = lhs;
    this.rhs = rhs;
    this.optok = optok;
  }
  mixin(copyMethodBinaryExpr);
}

class CondExpr : BinaryExpr
{
  Expression condition;
  Token* ctok; // Colon token.
  this(Expression condition, Expression left, Expression right,
       Token* qtok, Token* ctok)
  {
    addChild(condition);
    super(left, right, qtok);
    mixin(set_kind);
    this.condition = condition;
    this.ctok = ctok;
  }
  mixin(copyMethod);
}

class CommaExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class OrOrExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class AndAndExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class OrExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class XorExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class AndExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

/// This class isn't strictly needed, just here for clarity.
abstract class CmpExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
  }
}

class EqualExpr : CmpExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

/// Expression "!"? "is" Expression
class IdentityExpr : CmpExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class RelExpr : CmpExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class InExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class LShiftExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class RShiftExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class URShiftExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class PlusExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class MinusExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class CatExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class MulExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class DivExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class ModExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

// D2
class PowExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

class AssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}
class LShiftAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}
class RShiftAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}
class URShiftAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}
class OrAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}
class AndAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}
class PlusAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}
class MinusAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}
class DivAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}
class MulAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}
class ModAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}
class XorAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}
class CatAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}
// D2
class PowAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
}

/*++++++++++++++++++++
+ Unary Expressions: +
++++++++++++++++++++*/

abstract class UnaryExpr : Expression
{
  Expression una;
  this(Expression e)
  {
    addChild(e);
    this.una = e;
  }
  mixin(copyMethodUnaryExpr);
}

class AddressExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class PreIncrExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class PreDecrExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class PostIncrExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class PostDecrExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class DerefExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class SignExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }

  bool isPos()
  {
    assert(begin !is null);
    return begin.kind == TOK.Plus;
  }

  bool isNeg()
  {
    assert(begin !is null);
    return begin.kind == TOK.Minus;
  }
}

class NotExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class CompExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class CallExpr : UnaryExpr
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

class NewExpr : Expression
{
  Expression frame; /// The frame or 'this' pointer.
  Expression[] newArgs;
  TypeNode type;
  Expression[] ctorArgs;
  this(Expression frame, Expression[] newArgs, TypeNode type,
    Expression[] ctorArgs)
  {
    mixin(set_kind);
    addOptChild(frame);
    addOptChildren(newArgs);
    addChild(type);
    addOptChildren(ctorArgs);
    this.newArgs = newArgs;
    this.type = type;
    this.ctorArgs = ctorArgs;
  }
  mixin(copyMethod);
}

class NewClassExpr : Expression
{
  Expression frame; /// The frame or 'this' pointer.
  Expression[] newArgs;
  BaseClassType[] bases;
  Expression[] ctorArgs;
  CompoundDecl decls;
  this(Expression frame, Expression[] newArgs, BaseClassType[] bases,
    Expression[] ctorArgs, CompoundDecl decls)
  {
    mixin(set_kind);
    addOptChild(frame);
    addOptChildren(newArgs);
    addOptChildren(bases);
    addOptChildren(ctorArgs);
    addChild(decls);

    this.newArgs = newArgs;
    this.bases = bases;
    this.ctorArgs = ctorArgs;
    this.decls = decls;
  }
  mixin(copyMethod);
}

class DeleteExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class CastExpr : UnaryExpr
{
  TypeNode type;
  this(Expression e, TypeNode type)
  {
    version(D2)
    addOptChild(type);
    else
    addChild(type); // Add type before super().
    super(e);
    mixin(set_kind);
    this.type = type;
  }
  mixin(copyMethod);
}

class IndexExpr : UnaryExpr
{
  Expression[] args;
  this(Expression e, Expression[] args)
  {
    super(e);
    mixin(set_kind);
    addChildren(args);
    this.args = args;
  }
  mixin(copyMethod);
}

class SliceExpr : UnaryExpr
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
  mixin(copyMethod);
}

/*++++++++++++++++++++++
+ Primary Expressions: +
++++++++++++++++++++++*/

class IdentifierExpr : Expression
{
  Expression next;
  Identifier* ident;
  this(Identifier* ident, Expression next = null)
  {
    mixin(set_kind);
    addOptChild(next);
    this.next = next;
    this.ident = ident;
  }

  Token* idToken()
  {
    assert(begin !is null);
    return begin;
  }

  mixin(copyMethod);
}

/// Module scope operator:
/// $(BNF ModuleScopeExpr := ".")
class ModuleScopeExpr : Expression
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
}

class TmplInstanceExpr : Expression
{
  Expression next;
  Identifier* ident;
  TemplateArguments targs;
  this(Identifier* ident, TemplateArguments targs, Expression next = null)
  {
    mixin(set_kind);
    addOptChild(targs);
    addOptChild(next);
    this.next = next;
    this.ident = ident;
    this.targs = targs;
  }

  Token* idToken()
  {
    assert(begin !is null);
    return begin;
  }

  mixin(copyMethod);
}

class SpecialTokenExpr : Expression
{
  Token* specialToken;
  this(Token* specialToken)
  {
    mixin(set_kind);
    this.specialToken = specialToken;
  }

  Expression value; /// The expression created in the semantic phase.

  mixin(copyMethod);
}

class ThisExpr : Expression
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
}

class SuperExpr : Expression
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
}

class NullExpr : Expression
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

  mixin(copyMethod);
}

class DollarExpr : Expression
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
}

class BoolExpr : Expression
{
  IntExpr value; /// IntExpr of type bool.

  this(bool value)
  {
    mixin(set_kind);
    // Some semantic computation here.
    this.value = new IntExpr(value, Types.Bool);
    this.type = Types.Bool;
  }

  bool toBool()
  {
    assert(begin !is null);
    return begin.kind == TOK.True ? true : false;
  }

  mixin(copyMethod);
}

class IntExpr : Expression
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
    // Some semantic computation here.
    auto type = Types.Int32; // Should be most common case.
    ulong number = token.uint_;
    switch (token.kind)
    {
    // case TOK.Int32:
    //   type = Types.Int32; break;
    case TOK.UInt32:
      type = Types.UInt32; break;
    case TOK.Int64:
      type = Types.Int64;  number = token.intval.ulong_; break;
    case TOK.UInt64:
      type = Types.UInt64; number = token.intval.ulong_; break;
    default:
      assert(token.kind == TOK.Int32);
    }
    this(number, type);
  }

  mixin(copyMethod);
}

/// Holds a Float number and may be a real or imaginary number.
class FloatExpr : Expression
{
  Float number;

  this(Float number, Type type)
  {
    mixin(set_kind);
    this.number = number;
    this.type = type;
  }

  this(Token* token)
  {
    // Some semantic computation here.
    auto type = Types.fromTOK(token.kind);
    this(token.mpfloat, type);
  }

  mixin(copyMethod);
}


/// This expression holds a complex number.
/// It is only created in the semantic phase.
class ComplexExpr : Expression
{
  Complex number;

  this(Complex number, Type type)
  {
    mixin(set_kind);
    this.number = number;
    this.type = type;
  }

  Float re()
  {
    return number.re;
  }
  Float im()
  {
    return number.im;
  }

  mixin(copyMethod);
}

class CharExpr : Expression
{
  IntExpr value; // IntExpr of type Char/Wchar/Dchar.
//  dchar character; // Replaced by value.
  this(dchar character)
  {
    mixin(set_kind);
//    this.character = character;
    // Some semantic computation here.
    if (character <= 0xFF)
      this.type = Types.Char;
    else if (character <= 0xFFFF)
      this.type = Types.WChar;
    else
      this.type = Types.DChar;

    this.value = new IntExpr(character, this.type);
  }
  mixin(copyMethod);
}

class StringExpr : Expression
{
  ubyte[] str;   /// The string data.
  Type charType; /// The character type of the string.

  this(ubyte[] str, Type charType)
  {
    mixin(set_kind);
    this.str = str;
    this.charType = charType;
    this.type = charType.arrayOf(str.length/charType.sizeOf());
  }

  this(ubyte[] str, char kind)
  {
    Type t = Types.Char;
    if (kind == 'w') t = Types.WChar;
    else if (kind == 'd') t = Types.DChar;
    this(str, t);
  }

  this(char[] str)
  {
    this(cast(ubyte[])str, Types.Char);
  }

  this(wchar[] str)
  {
    this(cast(ubyte[])str, Types.WChar);
  }

  this(dchar[] str)
  {
    this(cast(ubyte[])str, Types.DChar);
  }

  /// Returns the number of chars/wchar/dchars in this string.
  size_t length()
  {
    return type.to!(TypeSArray).dimension;
  }

  /// Returns the string excluding the terminating 0.
  char[] getString()
  {
    // TODO: convert to char[] if charType !is Types.Char.
    return cast(char[])str[0..$-1];
  }

  mixin(copyMethod);
}

class ArrayLiteralExpr : Expression
{
  Expression[] values;
  this(Expression[] values)
  {
    mixin(set_kind);
    addOptChildren(values);
    this.values = values;
  }
  mixin(copyMethod);
}

class AArrayLiteralExpr : Expression
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
  mixin(copyMethod);
}

class AssertExpr : Expression
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
  mixin(copyMethod);
}

class MixinExpr : Expression
{
  Expression expr;
  this(Expression expr)
  {
    mixin(set_kind);
    addChild(expr);
    this.expr = expr;
  }
  mixin(copyMethod);
}

class ImportExpr : Expression
{
  Expression expr;
  this(Expression expr)
  {
    mixin(set_kind);
    addChild(expr);
    this.expr = expr;
  }
  mixin(copyMethod);
}

class TypeofExpr : Expression
{
  TypeNode type;
  this(TypeNode type)
  {
    mixin(set_kind);
    addChild(type);
    this.type = type;
  }
  mixin(copyMethod);
}

class TypeDotIdExpr : Expression
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
  mixin(copyMethod);
}

class TypeidExpr : Expression
{
  TypeNode type;
  this(TypeNode type)
  {
    mixin(set_kind);
    addChild(type);
    this.type = type;
  }
  mixin(copyMethod);
}

class IsExpr : Expression
{
  TypeNode type;
  Token* ident;
  Token* opTok, specTok;
  TypeNode specType;
  TemplateParameters tparams; // D 2.0
  this(TypeNode type, Token* ident, Token* opTok, Token* specTok,
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
  mixin(copyMethod);
}

class FuncLiteralExpr : Expression
{
  TypeNode returnType;
  Parameters params;
  FuncBodyStmt funcBody;

  this()
  {
    mixin(set_kind);
    addOptChild(returnType);
    addOptChild(params);
    addChild(funcBody);
  }

  this(TypeNode returnType, Parameters params, FuncBodyStmt funcBody)
  {
    this.returnType = returnType;
    this.params = params;
    this.funcBody = funcBody;
    this();
  }

  this(FuncBodyStmt funcBody)
  {
    this.funcBody = funcBody;
    this();
  }

  mixin(copyMethod);
}

/// ParenthesisExpr := "(" Expression ")"
class ParenExpr : Expression
{
  Expression next;
  this(Expression next)
  {
    mixin(set_kind);
    addChild(next);
    this.next = next;
  }
  mixin(copyMethod);
}

// version(D2)
// {
class TraitsExpr : Expression
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
  mixin(copyMethod);
}
// }

class VoidInitExpr : Expression
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
}

class ArrayInitExpr : Expression
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
  mixin(copyMethod);
}

class StructInitExpr : Expression
{
  Token*[] idents;
  Expression[] values;
  this(Token*[] idents, Expression[] values)
  {
    assert(idents.length == values.length);
    mixin(set_kind);
    addOptChildren(values);
    this.idents = idents;
    this.values = values;
  }
  mixin(copyMethod);
}

class AsmTypeExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class AsmOffsetExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class AsmSegExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
}

class AsmPostBracketExpr : UnaryExpr
{
  Expression index; /// Expression in brackets: una [ index ]
  this(Expression e, Expression index)
  {
    super(e);
    mixin(set_kind);
    addChild(index);
    this.index = index;
  }
  mixin(copyMethod);
}

class AsmBracketExpr : Expression
{
  Expression expr;
  this(Expression e)
  {
    mixin(set_kind);
    addChild(e);
    this.expr = e;
  }
  mixin(copyMethod);
}

class AsmLocalSizeExpr : Expression
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
}

class AsmRegisterExpr : Expression
{
  Identifier* register; /// Name of the register.
  Expression number; /// ST(0) - ST(7) or FS:0, FS:4, FS:8
  this(Identifier* register, Expression number = null)
  {
    mixin(set_kind);
    addOptChild(number);
    this.register = register;
    this.number = number;
  }
  mixin(copyMethod);
}
