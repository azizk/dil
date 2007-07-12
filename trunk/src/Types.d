/++
  Author: Aziz Köksal
  License: GPL2
+/
module Types;
import Token;
import Expressions;

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

class Parameter
{
  StorageClass stc;
  Type type;
  string ident;
  Expression assignExpr;

  this(StorageClass stc, Type type, string ident, Expression assignExpr)
  {
    this.stc = stc;
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

struct Parameters
{
  Parameter[] items;

  bool hasVariadic()
  {
    if (items.length != 0)
      return items[$-1].isVariadic();
    return false;
  }

  void opCatAssign(Parameter param)
  { items ~= param; }

  size_t length()
  { return items.length; }
}

enum TP
{
  Type,
  Value,
  Alias,
  Tuple
}

class TemplateParameter
{
  TP tp;
  Type valueType;
  string ident;
  Type specType, defType;
  Expression specValue, defValue;
  this(TP tp, Type valueType, string ident, Type specType, Type defType, Expression specValue, Expression defValue)
  {
    this.tp = tp;
    this.valueType = valueType;
    this.ident = ident;
    this.specType = specType;
    this.defType = defType;
    this.specValue = specValue;
    this.defValue = defValue;
  }
}

typedef Object[] TemplateArguments;

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
  IdentifierList,
  Identifier,
  Typeof,
  TemplateInstance,
  Specialization,
}

class Type
{
  TID tid;
  Type next;

  this(TOK tok)
  {
    this.tid = cast(TID)tok;
  }

  this(TID tid)
  { this(tid, null); }

  this(TID tid, Type next)
  {
    this.tid = tid;
    this.next = next;
  }
}

class UndefinedType : Type
{
  this()
  {
    super(TID.Undefined, null);
  }
}

class IdentifierListType : Type
{
  Type[] identList;
  this(Type[] identList)
  {
    super(TID.IdentifierList, null);
  }
}

class IdentifierType : Type
{
  string[] idents;

  this(string[] idents)
  {
    super(TID.Identifier, null);
    this.idents = idents;
  }

  this(string ident)
  {
    super(TID.Identifier, null);
  }

  this(TID tid)
  {
    super(tid);
  }

  void opCatAssign(string ident)
  {
    this.idents ~= ident;
  }
}

class TypeofType : IdentifierType
{
  Expression e;
  this(Expression e)
  {
    super(TID.Typeof);
    this.e = e;
  }
}

class TemplateInstanceType : Type
{
  string ident;
  TemplateArguments targs;
  this(string ident, TemplateArguments targs)
  {
    super(TID.TemplateInstance, null);
    this.ident = ident;
    this.targs = targs;
  }
}

class PointerType : Type
{
  this(Type t)
  {
    super(TID.Pointer, t);
  }
}

class ArrayType : Type
{
  Expression e, e2;
  Type assocType;
  this(Type t)
  {
    super(TID.Array, t);
  }
  this(Type t, Expression e, Expression e2)
  {
    this(t);
    this.e = e;
    this.e2 = e2;
  }
  this(Type t, Type assocType)
  {
    this(t);
    this.assocType = assocType;
  }
}

class SpecializationType : Type
{
  TOK specTok; // Colon|Equal
  Type type;
  TOK tokType; // Typedef|Struct|Union|Class|Interface|
               // Enum|Function|Delegate|Super|Return

  this(TOK specTok, TOK tokType)
  {
    super(TID.Specialization, null);
    this.specTok = specTok;
    this.tokType = tokType;
  }

  this(TOK specTok, Type type)
  {
    super(TID.Specialization, null);
    this.specTok = specTok;
    this.type = type;
  }
}

class FunctionType : Type
{
  Type returnType;
  Parameters parameters;
  this(Type returnType, Parameters parameters)
  {
    super(TID.Function, null);
    this.returnType = returnType;
    this.parameters = parameters;
  }
}

class DelegateType : Type
{
  this(Type func)
  {
    super(TID.Delegate, func);
  }
}
