/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Types;

import dil.ast.Node;
import dil.ast.Expressions;
import dil.ast.Parameter;
import dil.lexer.Identifier;
import dil.Enums;
import dil.semantic.Scope;
import dil.semantic.Types;

class BaseClass : Node
{
  Protection prot;
  TypeNode type;
  this(Protection prot, TypeNode type)
  {
    super(NodeCategory.Other);
    mixin(set_kind);
    addChild(type);
    this.prot = prot;
    this.type = type;
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
  Cent    = TOK.Cent,
  Ucent   = TOK.Ucent,

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

abstract class TypeNode : Node
{
  TID tid;
  TypeNode next;

  this(TID tid)
  {
    this(tid, null);
  }

  this(TID tid, TypeNode next)
  {
    super(NodeCategory.Type);
    addOptChild(next);
    this.tid = tid;
    this.next = next;
  }

  Type semantic(Scope scop)
  {
    return Types.Error;
  }
}

class IntegralType : TypeNode
{
  this(TOK tok)
  {
    super(cast(TID)tok);
    mixin(set_kind);
  }
}

class UndefinedType : TypeNode
{
  this()
  {
    super(TID.Undefined);
    mixin(set_kind);
  }
}

class DotListType : TypeNode
{
  TypeNode[] dotList;
  this(TypeNode[] dotList)
  {
    super(TID.DotList);
    mixin(set_kind);
    addChildren(dotList);
    this.dotList = dotList;
  }
}

class IdentifierType : TypeNode
{
  Identifier* ident;
  this(Identifier* ident)
  {
    super(TID.Identifier);
    mixin(set_kind);
    this.ident = ident;
  }
}

class DotType : TypeNode
{
  this()
  {
    super(TID.Dot);
    mixin(set_kind);
  }
}

class TypeofType : TypeNode
{
  Expression e;
  this(Expression e)
  {
    this();
    addChild(e);
    this.e = e;
  }

  this()
  {
    super(TID.Typeof);
    mixin(set_kind);
  }

  bool isTypeofReturn()
  {
    return e is null;
  }
}

class TemplateInstanceType : TypeNode
{
  Identifier* ident;
  TemplateArguments targs;
  this(Identifier* ident, TemplateArguments targs)
  {
    super(TID.TemplateInstance);
    mixin(set_kind);
    addOptChild(targs);
    this.ident = ident;
    this.targs = targs;
  }
}

class PointerType : TypeNode
{
  this(TypeNode t)
  {
    super(TID.Pointer, t);
    mixin(set_kind);
  }
}

class ArrayType : TypeNode
{
  Expression e, e2;
  TypeNode assocType;

  this(TypeNode t)
  {
    super(TID.Array, t);
    mixin(set_kind);
  }

  this(TypeNode t, Expression e, Expression e2)
  {
    addChild(e);
    addOptChild(e2);
    this.e = e;
    this.e2 = e2;
    this(t);
  }

  this(TypeNode t, TypeNode assocType)
  {
    addChild(assocType);
    this.assocType = assocType;
    this(t);
  }
}

class FunctionType : TypeNode
{
  TypeNode returnType;
  Parameters parameters;
  this(TypeNode returnType, Parameters parameters)
  {
    super(TID.Function);
    mixin(set_kind);
    addChild(returnType);
    addChild(parameters);
    this.returnType = returnType;
    this.parameters = parameters;
  }
}

class DelegateType : TypeNode
{
  TypeNode returnType;
  Parameters parameters;
  this(TypeNode returnType, Parameters parameters)
  {
    super(TID.Delegate);
    mixin(set_kind);
    addChild(returnType);
    addChild(parameters);
    this.returnType = returnType;
    this.parameters = parameters;
  }
}

class CFuncPointerType : TypeNode
{
  Parameters params;
  this(TypeNode type, Parameters params)
  {
    super(TID.CFuncPointer, type);
    mixin(set_kind);
    addOptChild(params);
  }
}

version(D2)
{
class ConstType : TypeNode
{
  this(TypeNode t)
  {
    // If t is null: cast(const)
    super(TID.Const, t);
    mixin(set_kind);
  }
}

class InvariantType : TypeNode
{
  this(TypeNode t)
  {
    // If t is null: cast(invariant)
    super(TID.Invariant, t);
    mixin(set_kind);
  }
}
} // version(D2)
