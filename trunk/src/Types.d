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

class Type
{
  TOK type;
  Type next;

  this(TOK type)
  { this(type, null); }

  this(TOK type, Type next)
  {
    this.type = type;
    this.next = next;
  }
}

class IdentifierType : Type
{
  string[] idents;

  this(string[] idents)
  {
    super(TOK.Identifier, null);
    this.idents = idents;
  }

  this(TOK type)
  {
    super(type, null);
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
    super(TOK.Typeof);
    this.e = e;
  }
}

class PointerType : Type
{
  this(Type t)
  {
    super(TOK.Mul, t);
  }
}

class ArrayType : Type
{
  Expression e, e2;
  Type assocType;
  this(Type t)
  {
    super(TOK.Invalid, t);
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
    super(TOK.Invalid, null);
    this.specTok = specTok;
    this.tokType = tokType;
  }

  this(TOK specTok, Type type)
  {
    super(TOK.Invalid, null);
    this.specTok = specTok;
    this.type = type;
  }
}
