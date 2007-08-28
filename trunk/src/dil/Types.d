/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Types;
import dil.SyntaxTree;
import dil.Token;
import dil.Expressions;

class Linkage : Node
{
  enum Type
  {
    Extern,
    C,
    Cpp,
    D,
    Windows,
    Pascal,
    System
  }

  /++
    This enum is used by the parser to find redundant
    or conflicting extern attribute declarations.
  +/
  enum Category
  {
    Unset,
    ExternSymbol = 1<<1, /// Extern
    MangleSymbol = 1<<2  /// C, Cpp, D, Windows, Pascal, System
  }

  Linkage.Type type;

  this(typeof(type) type)
  {
    super(NodeCategory.Other);
    mixin(set_kind);
    this.type = type;
  }

  static Category getCategory(Linkage linkage)
  {
    if (linkage is null)
      return Category.ExternSymbol;
    else
      return Category.MangleSymbol;
  }
}

enum StorageClass
{
  None         = 0,
  Abstract     = 1,
  Auto         = 1<<2,
  Const        = 1<<3,
  Deprecated   = 1<<4,
  Extern       = 1<<5,
  Final        = 1<<6,
  Invariant    = 1<<7,
  Override     = 1<<8,
  Scope        = 1<<9,
  Static       = 1<<10,
  Synchronized = 1<<11,
  In           = 1<<12,
  Out          = 1<<13,
  Ref          = 1<<14,
  Lazy         = 1<<15,
  Variadic     = 1<<16,
}

class Parameter : Node
{
  StorageClass stc;
  Token* stcTok;
  Type type;
  Token* ident;
  Expression assignExpr;

  this(Token* stcTok, Type type, Token* ident, Expression assignExpr)
  {
    super(NodeCategory.Other);
    mixin(set_kind);
    if (type) // type can be null when param in foreach statement
      this.children = [type];
    if (assignExpr)
      this.children ~= assignExpr;

    StorageClass stc;
    if (stcTok !is null)
    {
      // NB: In D 2.0 StorageClass.In means final/scope/const
      switch (stcTok.type)
      {
      // TODO: D 2.0 invariant/const/final/scope
      case TOK.In:   stc = StorageClass.In;   break;
      case TOK.Out:  stc = StorageClass.Out;  break;
      case TOK.Inout:
      case TOK.Ref:  stc = StorageClass.Ref;  break;
      case TOK.Lazy: stc = StorageClass.Lazy; break;
      case TOK.Ellipses:
        stc = StorageClass.Variadic;
      default:
      }
    }

    this.stc = stc;
    this.stcTok = stcTok;
    this.type = type;
    this.ident = ident;
    this.assignExpr = assignExpr;
  }

  bool isVariadic()
  {
    return !!(stc & StorageClass.Variadic);
  }

  bool isOnlyVariadic()
  {
    return stc == StorageClass.Variadic;
  }
}

class Parameters : Node
{
  this()
  {
    super(NodeCategory.Other);
    mixin(set_kind);
  }

  bool hasVariadic()
  {
    if (children.length != 0)
      return items[$-1].isVariadic();
    return false;
  }

  void opCatAssign(Parameter param)
  { children ~= param; }

  Parameter[] items()
  { return cast(Parameter[])children; }

  size_t length()
  { return children.length; }
}


enum Protection
{
  None,
  Private   = 1,
  Protected = 1<<1,
  Package   = 1<<2,
  Public    = 1<<3,
  Export    = 1<<4
}

class BaseClass : Node
{
  Protection prot;
  Type type;
  this(Protection prot, Type type)
  {
    super(NodeCategory.Other);
    mixin(set_kind);
    this.children = [type];
    this.prot = prot;
    this.type = type;
  }
}

abstract class TemplateParameter : Node
{
  this()
  {
    super(NodeCategory.Other);
  }
}

class TemplateAliasParameter : TemplateParameter
{
  Token* ident;
  Type specType, defType;
  this(Token* ident, Type specType, Type defType)
  {
    mixin(set_kind);
    if (specType)
      this.children ~= specType;
    if (defType)
      this.children ~= defType;
    this.ident = ident;
    this.specType = specType;
    this.defType = defType;
  }
}

class TemplateTypeParameter : TemplateParameter
{
  Token* ident;
  Type specType, defType;
  this(Token* ident, Type specType, Type defType)
  {
    mixin(set_kind);
    if (specType)
      this.children ~= specType;
    if (defType)
      this.children ~= defType;
    this.ident = ident;
    this.specType = specType;
    this.defType = defType;
  }
}

class TemplateValueParameter : TemplateParameter
{
  Type valueType;
  Token* ident;
  Expression specValue, defValue;
  this(Type valueType, Token* ident, Expression specValue, Expression defValue)
  {
    mixin(set_kind);
    this.children ~= valueType;
    if (specValue)
      this.children ~= specValue;
    if (defValue)
      this.children ~= defValue;
    this.valueType = valueType;
    this.ident = ident;
    this.specValue = specValue;
    this.defValue = defValue;
  }
}

class TemplateTupleParameter : TemplateParameter
{
  Token* ident;
  this(Token* ident)
  {
    mixin(set_kind);
    this.ident = ident;
  }
}

class TemplateParameters : Node
{
  this()
  {
    super(NodeCategory.Other);
    mixin(set_kind);
  }

  void opCatAssign(TemplateParameter parameter)
  {
    this.children ~= parameter;
  }

  TemplateParameter[] items()
  {
    return cast(TemplateParameter[])children;
  }
}

class TemplateArguments : Node
{
  this()
  {
    super(NodeCategory.Other);
    mixin(set_kind);
  }

  void opCatAssign(Node argument)
  {
    this.children ~= argument;
  }
}

enum TID
{
  Void    = TOK.Void,
  Char    = TOK.Char,
  Wchar   = TOK.Wchar,
  Dchar   = TOK.Dchar,
  Bool    = TOK.Bool,
  Byte    = TOK.Byte,
  Ubyte   = TOK.Ubyte,
  Short   = TOK.Short,
  Ushort  = TOK.Ushort,
  Int     = TOK.Int,
  Uint    = TOK.Uint,
  Long    = TOK.Long,
  Ulong   = TOK.Ulong,
  Float   = TOK.Float,
  Double  = TOK.Double,
  Real    = TOK.Real,
  Ifloat  = TOK.Ifloat,
  Idouble = TOK.Idouble,
  Ireal   = TOK.Ireal,
  Cfloat  = TOK.Cfloat,
  Cdouble = TOK.Cdouble,
  Creal   = TOK.Creal,

  Undefined,
  Function,
  Delegate,
  Pointer,
  Array,
  DotList,
  Identifier,
  Typeof,
  TemplateInstance,
  Const, // D2
  Invariant, // D2
}

abstract class Type : Node
{
  TID tid;
  Type next;

  this(TID tid)
  {
    this(tid, null);
  }

  this(TID tid, Type next)
  {
    super(NodeCategory.Type);
    if (next)
      this.children ~= next;
    this.tid = tid;
    this.next = next;
  }
}

class IntegralType : Type
{
  this(TOK tok)
  {
    super(cast(TID)tok);
    mixin(set_kind);
  }
}

class UndefinedType : Type
{
  this()
  {
    super(TID.Undefined);
    mixin(set_kind);
  }
}

class DotListType : Type
{
  Type[] dotList;
  this(Type[] dotList)
  {
    super(TID.DotList);
    mixin(set_kind);
    this.children ~= dotList;
    this.dotList = dotList;
  }
}

class IdentifierType : Type
{
  Token* ident;
  this(Token* ident)
  {
    super(TID.Identifier);
    mixin(set_kind);
    this.ident = ident;
  }
}

class TypeofType : Type
{
  Expression e;
  this(Expression e)
  {
    super(TID.Typeof);
    mixin(set_kind);
    this.children ~= e;
    this.e = e;
  }
}

class TemplateInstanceType : Type
{
  Token* ident;
  TemplateArguments targs;
  this(Token* ident, TemplateArguments targs)
  {
    super(TID.TemplateInstance);
    mixin(set_kind);
    this.children ~= targs;
    this.ident = ident;
    this.targs = targs;
  }
}

class PointerType : Type
{
  this(Type t)
  {
    super(TID.Pointer, t);
    mixin(set_kind);
  }
}

class ArrayType : Type
{
  Expression e, e2;
  Type assocType;
  this(Type t)
  {
    super(TID.Array, t);
    mixin(set_kind);
  }
  this(Type t, Expression e, Expression e2)
  {
    this.children = [e];
    if (e2)
      this.children ~= e2;
    this.e = e;
    this.e2 = e2;
    this(t);
  }
  this(Type t, Type assocType)
  {
    this.children = [assocType];
    this.assocType = assocType;
    this(t);
  }
}

class FunctionType : Type
{
  Type returnType;
  Parameters parameters;
  this(Type returnType, Parameters parameters)
  {
    super(TID.Function);
    mixin(set_kind);
    this.children = [cast(Node)returnType, parameters];
    this.returnType = returnType;
    this.parameters = parameters;
  }
}

class DelegateType : Type
{
  Type returnType;
  Parameters parameters;
  this(Type returnType, Parameters parameters)
  {
    super(TID.Delegate);
    mixin(set_kind);
    this.children = [cast(Node)returnType, parameters];
    this.returnType = returnType;
    this.parameters = parameters;
  }
}

version(D2)
{
class ConstType : Type
{
  this(Type t)
  {
    // If t is null: cast(const)
    super(TID.Const, t);
    mixin(set_kind);
  }
}

class InvariantType : Type
{
  this(Type t)
  {
    // If t is null: cast(invariant)
    super(TID.Invariant, t);
    mixin(set_kind);
  }
}
} // version(D2)
