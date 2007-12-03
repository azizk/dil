/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Types;
import dil.SyntaxTree;
import dil.Token;
import dil.Expressions;
import dil.Enums;

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
    // type can be null when param in foreach statement
    addOptChild(type);
    addOptChild(assignExpr);

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
  { addChild(param); }

  Parameter[] items()
  { return cast(Parameter[])children; }

  size_t length()
  { return children.length; }
}

class BaseClass : Node
{
  Protection prot;
  Type type;
  this(Protection prot, Type type)
  {
    super(NodeCategory.Other);
    mixin(set_kind);
    addChild(type);
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
    addOptChild(specType);
    addOptChild(defType);
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
    addOptChild(specType);
    addOptChild(defType);
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
    addChild(valueType);
    addOptChild(specValue);
    addOptChild(defValue);
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
    addChild(parameter);
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
    addChild(argument);
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
  CFuncPointer,
  Array,
  Dot,
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
    addOptChild(next);
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
    addChildren(dotList);
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

class DotType : Type
{
  this()
  {
    super(TID.Dot);
    mixin(set_kind);
  }
}

class TypeofType : Type
{
  Expression e;
  this(Expression e)
  {
    super(TID.Typeof);
    mixin(set_kind);
    addChild(e);
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
    addOptChild(targs);
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
    addChild(e);
    addOptChild(e2);
    this.e = e;
    this.e2 = e2;
    this(t);
  }

  this(Type t, Type assocType)
  {
    addChild(assocType);
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
    addChild(returnType);
    addChild(parameters);
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
    addChild(returnType);
    addChild(parameters);
    this.returnType = returnType;
    this.parameters = parameters;
  }
}

class CFuncPointerType : Type
{
  Parameters params;
  this(Type type, Parameters params)
  {
    super(TID.CFuncPointer, type);
    mixin(set_kind);
    addOptChild(params);
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
