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
       dil.ast.NodeCopier,
       dil.ast.Meta;
import dil.lexer.Identifier;
import dil.semantic.Types;
import dil.Float,
       dil.Complex,
       dil.String;
import common;

class IllegalExpr : Expression
{
  mixin(memberInfo());
  this()
  {
    mixin(set_kind);
  }
  mixin methods;
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

  mixin(memberInfo("lhs", "rhs", "optok"));

  /// Constructs a BinaryExpr object.
  this(Expression lhs, Expression rhs, Token* optok)
  {
    addChildren([lhs, rhs]);
    this.lhs = lhs;
    this.rhs = rhs;
    this.optok = optok;
  }
  mixin copyBinaryExprMethod;
}

class CondExpr : BinaryExpr
{
  Expression condition;
  Token* ctok; // Colon token.

  mixin(memberInfo("condition", "lhs", "rhs", "optok", "ctok"));

  this(Expression condition, Expression left, Expression right,
       Token* qtok, Token* ctok)
  {
    addChild(condition);
    super(left, right, qtok);
    mixin(set_kind);
    this.condition = condition;
    this.ctok = ctok;
  }
  mixin methods;
}

class CommaExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class OrOrExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class AndAndExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class OrExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class XorExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class AndExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
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
  mixin methods;
}

/// Expression "!"? "is" Expression
class IdentityExpr : CmpExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class RelExpr : CmpExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class InExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class LShiftExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class RShiftExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class URShiftExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class PlusExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class MinusExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class CatExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class MulExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class DivExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class ModExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

// D2
class PowExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

class AssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}
class LShiftAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}
class RShiftAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}
class URShiftAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}
class OrAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}
class AndAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}
class PlusAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}
class MinusAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}
class DivAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}
class MulAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}
class ModAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}
class XorAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}
class CatAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}
// D2
class PowAssignExpr : BinaryExpr
{
  this(Expression left, Expression right, Token* optok)
  {
    super(left, right, optok);
    mixin(set_kind);
  }
  mixin methods;
}

/*++++++++++++++++++++
+ Unary Expressions: +
++++++++++++++++++++*/

abstract class UnaryExpr : Expression
{
  Expression una;

  mixin(memberInfo("una"));

  this(Expression e)
  {
    addChild(e);
    this.una = e;
  }
  mixin copyUnaryExprMethod;
}

class AddressExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
  mixin methods;
}

class PreIncrExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
  mixin methods;
}

class PreDecrExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
  mixin methods;
}

class PostIncrExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
  mixin methods;
}

class PostDecrExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
  mixin methods;
}

class DerefExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
  mixin methods;
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
  mixin methods;
}

class NotExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
  mixin methods;
}

class CompExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
  mixin methods;
}

class CallExpr : UnaryExpr
{
  Expression[] args;
  mixin(memberInfo("una", "args"));
  this(Expression e, Expression[] args)
  {
    super(e);
    mixin(set_kind);
    addOptChildren(args);
    this.args = args;
  }
  mixin methods;
}

class NewExpr : Expression
{
  Expression frame; /// The frame or 'this' pointer.
  Expression[] newArgs;
  TypeNode type;
  Expression[] ctorArgs;

  mixin(memberInfo("frame", "newArgs", "type", "ctorArgs"));

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
  mixin methods;
}

class NewClassExpr : Expression
{
  Expression frame; /// The frame or 'this' pointer.
  Expression[] newArgs;
  Expression[] ctorArgs;
  BaseClassType[] bases;
  CompoundDecl decls;

  mixin(memberInfo("frame", "newArgs", "ctorArgs", "bases", "decls"));

  this(Expression frame, Expression[] newArgs, Expression[] ctorArgs,
       BaseClassType[] bases, CompoundDecl decls)
  {
    mixin(set_kind);
    addOptChild(frame);
    addOptChildren(newArgs);
    addOptChildren(ctorArgs);
    addOptChildren(bases);
    addChild(decls);

    this.newArgs = newArgs;
    this.ctorArgs = ctorArgs;
    this.bases = bases;
    this.decls = decls;
  }
  mixin methods;
}

class DeleteExpr : UnaryExpr
{
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
  mixin methods;
}

class CastExpr : UnaryExpr
{
  TypeNode type;
  mixin(memberInfo("una", "type"));
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
  mixin methods;
}

class IndexExpr : UnaryExpr
{
  Expression[] args;
  mixin(memberInfo("una", "args"));
  this(Expression e, Expression[] args)
  {
    super(e);
    mixin(set_kind);
    addChildren(args);
    this.args = args;
  }
  mixin methods;
}

class SliceExpr : UnaryExpr
{
  Expression left, right;
  mixin(memberInfo("una", "left", "right"));
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
  mixin methods;
}

/*++++++++++++++++++++++
+ Primary Expressions: +
++++++++++++++++++++++*/

class IdentifierExpr : Expression
{
  Expression next;
  Token* ident;
  mixin(memberInfo("ident", "next"));
  this(Token* ident, Expression next = null)
  {
    mixin(set_kind);
    addOptChild(next);
    this.next = next;
    this.ident = ident;
  }

  @property Identifier* id()
  {
    return ident.ident;
  }

  mixin methods;
}

/// Module scope operator:
/// $(BNF ModuleScopeExpr := ".")
class ModuleScopeExpr : Expression
{
  mixin(memberInfo());
  this()
  {
    mixin(set_kind);
  }
  mixin methods;
}

class TmplInstanceExpr : Expression
{
  Expression next;
  Token* ident;
  TemplateArguments targs;
  mixin(memberInfo("ident", "targs", "next"));
  this(Token* ident, TemplateArguments targs, Expression next = null)
  {
    mixin(set_kind);
    addOptChild(targs);
    addOptChild(next);
    this.next = next;
    this.ident = ident;
    this.targs = targs;
  }

  @property Identifier* id()
  {
    return ident.ident;
  }

  mixin methods;
}

class SpecialTokenExpr : Expression
{
  Token* specialToken;
  mixin(memberInfo("specialToken"));
  this(Token* specialToken)
  {
    mixin(set_kind);
    this.specialToken = specialToken;
  }

  Expression value; /// The expression created in the semantic phase.

  mixin methods;
}

class ThisExpr : Expression
{
  mixin(memberInfo());
  this()
  {
    mixin(set_kind);
  }
  mixin methods;
}

class SuperExpr : Expression
{
  mixin(memberInfo());
  this()
  {
    mixin(set_kind);
  }
  mixin methods;
}

class NullExpr : Expression
{
  mixin(memberInfo());
  this()
  {
    mixin(set_kind);
  }

  // For semantic analysis.
  this(Type type)
  {
    this();
    this.type = type;
  }

  mixin methods;
}

class DollarExpr : Expression
{
  mixin(memberInfo());
  this()
  {
    mixin(set_kind);
  }
  mixin methods;
}

class BoolExpr : Expression
{
  IntExpr value; /// IntExpr of type bool.

  mixin(memberInfo("begin"));
  this(bool value)
  {
    mixin(set_kind);
    // Some semantic computation here.
    this.value = new IntExpr(value, Types.Bool);
    this.type = Types.Bool;
  }

  /// For ASTSerializer.
  this(Token* t)
  {
    this(t.kind == TOK.True ? true : false);
  }

  bool toBool()
  {
    assert(begin !is null);
    return begin.kind == TOK.True ? true : false;
  }

  mixin methods;
}

class IntExpr : Expression
{
  ulong number;

  mixin(memberInfo("begin"));

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

  mixin methods;
}

/// Holds a Float number and may be a real or imaginary number.
class FloatExpr : Expression
{
  Float number;

  mixin(memberInfo("begin"));

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

  mixin methods;
}


/// This expression holds a complex number.
/// It is only created in the semantic phase.
class ComplexExpr : Expression
{
  Complex number;

  mixin(memberInfo("begin"));
  this(Complex number, Type type)
  {
    mixin(set_kind);
    this.number = number;
    this.type = type;
  }

  /// For ASTSerializer.
  this(Token*)
  {
    assert(0, "can't serialize ComplexExpr atm");
  }

  Float re()
  {
    return number.re;
  }
  Float im()
  {
    return number.im;
  }

  mixin methods;
}

class CharExpr : Expression
{
  IntExpr value; // IntExpr of type Char/Wchar/Dchar.

  mixin(memberInfo("begin"));

  this(Token* chartok)
  {
    mixin(set_kind);
    const character = chartok.dchar_;
    // Some semantic computation here.
    if (character <= 0xFF)
      this.type = Types.Char;
    else if (character <= 0xFFFF)
      this.type = Types.WChar;
    else
      this.type = Types.DChar;

    this.value = new IntExpr(character, this.type);
  }
  mixin methods;
}

class StringExpr : Expression
{
  const(ubyte)[] data; /// The string data (includes terminating zero(s).)
  Type charType; /// The character type of the string.

  this(const(ubyte)[] data, Type charType)
  {
    mixin(set_kind);
    this.data = data;
    this.charType = charType;
    this.type = charType.arrayOf(data.length/charType.sizeOf());
  }

  this(const(ubyte)[] data, char kind)
  {
    Type t = Types.Char;
    if (kind == 'w') t = Types.WChar;
    else if (kind == 'd') t = Types.DChar;
    this(data, t);
  }

  this(cstring str)
  {
    this(cast(typeof(data))str, Types.Char);
  }

  this(cwstring str)
  {
    this(cast(typeof(data))str, Types.WChar);
  }

  this(cdstring str)
  {
    this(cast(typeof(data))str, Types.DChar);
  }

  /// For ASTSerializer.
  this(Token*[] tokens)
  {
    assert(tokens.length >= 1);
    cstring str = tokens[0].strval.str;
    char postfix = tokens[0].strval.pf;
    // Concatenate adjacent string literals.
    foreach (token; tokens[1..$])
    {
      auto pf = token.strval.pf;
      assert(!(pf && pf != postfix), "StringPostfixMismatch");
      str.length = str.length - 1; // Exclude '\0'.
      str ~= token.strval.str;
    }
    assert(str[$-1] == 0);

    auto bin_str = cast(const(ubyte)[])str;
    if (postfix == 'w')      // Convert to UTF16.
      bin_str = cast(typeof(bin_str))dil.Unicode.toUTF16(str);
    else if (postfix == 'd') // Convert to UTF32.
      bin_str = cast(typeof(bin_str))dil.Unicode.toUTF32(str);
    //else // FIXME: insert into table if multiple literals.
    //  if (tokens.length > 1) // Multiple string literals?
    //    bin_str = cast(typeof(bin_str))lexer.lookupString(str[0..$-1]);

    this(bin_str, postfix);
  }

  /// Returns the tokens this literal comprises.
  Token*[] tokens() @property
  {
    assert(begin && end);
    Token*[] ts;
    for (auto t = begin; t !is end; t = t.next)
      if (t.kind == TOK.String)
        ts ~= t;
    return ts ? ts : [begin];
  }

  mixin(memberInfo("tokens"));

  /// Returns the number of chars/wchar/dchars in this string.
  size_t length()
  {
    return type.to!(TypeSArray).dimension;
  }

  /// Returns the string excluding the terminating 0.
  cstring getString()
  {
    // TODO: convert to char[] if charType !is Types.Char.
    return (cast(cstring)data)[0..$-1];
  }

  /// Returns the string excluding the terminating 0.
  cwstring getWString()
  {
    assert(charType is Types.WChar);
    return (cast(cwstring)data)[0..$-1];
  }

  /// Returns the string excluding the terminating 0.
  cdstring getDString()
  {
    assert(charType is Types.DChar);
    return (cast(cdstring)data)[0..$-1];
  }

  mixin methods;
}

class ArrayLiteralExpr : Expression
{
  Expression[] values;
  mixin(memberInfo("values"));
  this(Expression[] values)
  {
    mixin(set_kind);
    addOptChildren(values);
    this.values = values;
  }
  mixin methods;
}

class AArrayLiteralExpr : Expression
{
  Expression[] keys, values;
  mixin(memberInfo("keys", "values"));
  this(Expression[] keys, Expression[] values)
  {
    assert(keys.length == values.length);
    mixin(set_kind);
    foreach (i, key; keys)
      addChildren([key, values[i]]);
    this.keys = keys;
    this.values = values;
  }
  mixin methods;
}

class AssertExpr : Expression
{
  Expression expr, msg;
  mixin(memberInfo("expr", "msg"));
  this(Expression expr, Expression msg)
  {
    mixin(set_kind);
    addChild(expr);
    addOptChild(msg);
    this.expr = expr;
    this.msg = msg;
  }
  mixin methods;
}

class MixinExpr : Expression
{
  Expression expr;
  mixin(memberInfo("expr"));
  this(Expression expr)
  {
    mixin(set_kind);
    addChild(expr);
    this.expr = expr;
  }
  mixin methods;
}

class ImportExpr : Expression
{
  Expression expr;
  mixin(memberInfo("expr"));
  this(Expression expr)
  {
    mixin(set_kind);
    addChild(expr);
    this.expr = expr;
  }
  mixin methods;
}

class TypeofExpr : Expression
{
  TypeNode type;
  mixin(memberInfo("type"));
  this(TypeNode type)
  {
    mixin(set_kind);
    addChild(type);
    this.type = type;
  }
  mixin methods;
}

class TypeDotIdExpr : Expression
{
  TypeNode type;
  Token* ident;
  mixin(memberInfo("type", "ident"));
  this(TypeNode type, Token* ident)
  {
    mixin(set_kind);
    addChild(type);
    this.type = type;
    this.ident = ident;
  }
  mixin methods;
}

class TypeidExpr : Expression
{
  TypeNode type;
  mixin(memberInfo("type"));
  this(TypeNode type)
  {
    mixin(set_kind);
    addChild(type);
    this.type = type;
  }
  mixin methods;
}

class IsExpr : Expression
{
  TypeNode type;
  Token* ident;
  Token* opTok, specTok;
  TypeNode specType;
  TemplateParameters tparams; // D 2.0
  mixin(memberInfo("type", "ident", "opTok", "specTok", "specType", "tparams"));

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
  mixin methods;
}

class FuncLiteralExpr : Expression
{
  TypeNode returnType;
  Parameters params;
  FuncBodyStmt funcBody;
  mixin(memberInfo("returnType", "params", "funcBody"));

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

  mixin methods;
}

/// ParenthesisExpr := "(" Expression ")"
class ParenExpr : Expression
{
  Expression next;
  mixin(memberInfo("next"));
  this(Expression next)
  {
    mixin(set_kind);
    addChild(next);
    this.next = next;
  }
  mixin methods;
}

// version(D2)
// {
class TraitsExpr : Expression
{
  Token* ident;
  TemplateArguments targs;
  mixin(memberInfo("ident", "targs"));
  this(typeof(ident) ident, typeof(targs) targs)
  {
    mixin(set_kind);
    addOptChild(targs);
    this.ident = ident;
    this.targs = targs;
  }
  mixin methods;
}
// }

class VoidInitExpr : Expression
{
  mixin(memberInfo());
  this()
  {
    mixin(set_kind);
  }
  mixin methods;
}

class ArrayInitExpr : Expression
{
  Expression[] keys;
  Expression[] values;
  mixin(memberInfo("keys", "values"));
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
  mixin methods;
}

class StructInitExpr : Expression
{
  Token*[] idents;
  Expression[] values;
  mixin(memberInfo("idents", "values"));
  this(Token*[] idents, Expression[] values)
  {
    assert(idents.length == values.length);
    mixin(set_kind);
    addOptChildren(values);
    this.idents = idents;
    this.values = values;
  }
  mixin methods;
}

class AsmTypeExpr : UnaryExpr
{
  Token* prefix;
  mixin(memberInfo("prefix", "una"));
  this(Token* prefix, Expression e)
  {
    super(e);
    mixin(set_kind);
  }
  mixin methods;
}

class AsmOffsetExpr : UnaryExpr
{
  mixin(memberInfo("una"));
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
  mixin methods;
}

class AsmSegExpr : UnaryExpr
{
  mixin(memberInfo("una"));
  this(Expression e)
  {
    super(e);
    mixin(set_kind);
  }
  mixin methods;
}

class AsmPostBracketExpr : UnaryExpr
{
  Expression index; /// Expression in brackets: una [ index ]
  mixin(memberInfo("una", "index"));
  this(Expression e, Expression index)
  {
    super(e);
    mixin(set_kind);
    addChild(index);
    this.index = index;
  }
  mixin methods;
}

class AsmBracketExpr : Expression
{
  Expression expr;
  mixin(memberInfo("expr"));
  this(Expression e)
  {
    mixin(set_kind);
    addChild(e);
    this.expr = e;
  }
  mixin methods;
}

class AsmLocalSizeExpr : Expression
{
  mixin(memberInfo());
  this()
  {
    mixin(set_kind);
  }
  mixin methods;
}

class AsmRegisterExpr : Expression
{
  Token* register; /// Name of the register.
  Expression number; /// ST(0) - ST(7) or FS:0, FS:4, FS:8
  mixin(memberInfo("register", "number"));
  this(Token* register, Expression number = null)
  {
    mixin(set_kind);
    addOptChild(number);
    this.register = register;
    this.number = number;
  }
  mixin methods;
}
