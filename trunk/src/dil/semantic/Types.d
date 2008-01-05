/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Type;

import dil.Symbol;
import dil.TypesEnum;
import dil.CompilerInfo;
import dil.Identifier;

abstract class Type : Symbol
{
  Type next;
  TYP tid; /// The ID of the type.

  this(){}

  this(Type next, TYP tid)
  {
    this.sid = SYM.Type;

    this.next = next;
    this.tid = tid;
  }

  TypePointer ptrTo()
  {
    return new TypePointer(this);
  }

  /// Get byte size of this type.
  final size_t sizeOf()
  {
    return MITable.getSize(this);
  }

  /// Size is not in MITable. Find out via virtual method.
  size_t sizeOf_()
  {
    return sizeOf();
  }
}

class TypeBasic : Type
{
  this(TYP typ)
  {
    super(null, typ);
  }
}

class TypeDArray : Type
{
  this(Type next)
  {
    super(next, TYP.DArray);
  }
}

class TypeAArray : Type
{
  Type keyType;
  this(Type next, Type keyType)
  {
    super(next, TYP.AArray);
    this.keyType = keyType;
  }
}

class TypeSArray : Type
{
  size_t dimension;
  this(Type next, size_t dimension)
  {
    super(next, TYP.SArray);
    this.dimension = dimension;
  }
}

class TypePointer : Type
{
  this(Type next)
  {
    super(next, TYP.Pointer);
  }
}

class TypeReference : Type
{
  this(Type next)
  {
    super(next, TYP.Reference);
  }
}

class EnumType : Type
{
  this(Type baseType)
  {
    super(baseType, TYP.Enum);
  }

  Type baseType()
  {
    return next;
  }
}

class StructType : Type
{
  this()
  {
    super(null, TYP.Struct);
  }
}

class ClassType : Type
{
  this()
  {
    super(null, TYP.Class);
  }
}

class TypedefType : Type
{
  this(Type next)
  {
    super(next, TYP.Typedef);
  }
}

class FunctionType : Type
{
  this(Type next)
  {
    super(next, TYP.Function);
  }
}

class DelegateType : Type
{
  this(Type next)
  {
    super(next, TYP.Delegate);
  }
}

class IdentifierType : Type
{
  Identifier* ident;
  this(Identifier* ident)
  {
    super(null, TYP.Identifier);
  }
}

class TInstanceType : Type
{
  this()
  {
    super(null, TYP.TInstance);
  }
}

class TupleType : Type
{
  this(Type next)
  {
    super(next, TYP.Tuple);
  }
}

class ConstType : Type
{
  this(Type next)
  {
    super(next, TYP.Const);
  }
}

class InvariantType : Type
{
  this(Type next)
  {
    super(next, TYP.Const);
  }
}

/// Represents a value related to a type.
union Value
{
  void*  pvoid;
  bool   bool_;
  dchar  dchar_;
  long   long_;
  ulong  ulong_;
  int    int_;
  uint   uint_;
  float  float_;
  double double_;
  real   real_;
  creal  creal_;
}

struct TypeMetaInfo
{
  char mangle; /// Mangle character of the type.
  ushort size; /// Byte size of the type.
  Value* defaultInit; /// Default initialization value.
}

struct MITable
{
static:
  const ushort SIZE_NOT_AVAILABLE = 0; /// Size not available.
  const Value VZERO = {int_:0}; /// Value 0.
  const Value VNULL = {pvoid:null}; /// Value null.
  const Value V0xFF = {dchar_:0xFF}; /// Value 0xFF.
  const Value V0xFFFF = {dchar_:0xFFFF}; /// Value 0xFFFF.
  const Value VFALSE = {bool_:false}; /// Value false.
  const Value VNAN = {float_:float.nan}; /// Value NAN.
  const Value VCNAN = {creal_:creal.nan}; /// Value complex NAN.
  private alias SIZE_NOT_AVAILABLE SNA;
  private alias PTR_SIZE PS;
  private const TypeMetaInfo metaInfoTable[] = [
    {'?', SNA}, // Error

    {'a', 1, &V0xFF},   // Char
    {'u', 2, &V0xFFFF},   // Wchar
    {'w', 4, &V0xFFFF},   // Dchar
    {'b', 1, &VFALSE},   // Bool
    {'g', 1, &VZERO},   // Byte
    {'h', 1, &VZERO},   // Ubyte
    {'s', 2, &VZERO},   // Short
    {'t', 2, &VZERO},   // Ushort
    {'i', 4, &VZERO},   // Int
    {'k', 4, &VZERO},   // Uint
    {'l', 8, &VZERO},   // Long
    {'m', 8, &VZERO},   // Ulong
    {'?', 16, &VZERO},  // Cent
    {'?', 16, &VZERO},  // Ucent
    {'f', 4, &VNAN},   // Float
    {'d', 8, &VNAN},   // Double
    {'e', 12, &VNAN},  // Real
    {'o', 4, &VNAN},   // Ifloat
    {'p', 8, &VNAN},   // Idouble
    {'j', 12, &VNAN},  // Ireal
    {'q', 8, &VCNAN},   // Cfloat
    {'r', 16, &VCNAN},  // Cdouble
    {'c', 24, &VCNAN},  // Creal
    {'v', 1},   // void

    {'n', SNA},  // None

    {'A', PS*2, &VNULL}, // Dynamic array
    {'G', PS*2, &VNULL}, // Static array
    {'H', PS*2, &VNULL}, // Associative array

    {'E', SNA}, // Enum
    {'S', SNA}, // Struct
    {'C', PS, &VNULL},  // Class
    {'T', SNA}, // Typedef
    {'F', PS},  // Function
    {'D', PS*2, &VNULL}, // Delegate
    {'P', PS, &VNULL},  // Pointer
    {'R', PS, &VNULL},  // Reference
    {'I', SNA}, // Identifier
    {'?', SNA}, // Template instance
    {'B', SNA}, // Tuple
    {'x', SNA}, // Const, D2
    {'y', SNA}, // Invariant, D2
  ];
  static assert(metaInfoTable.length == TYP.max+1);

  size_t getSize(Type type)
  {
    auto size = metaInfoTable[type.tid].size;
    if (size == SIZE_NOT_AVAILABLE)
      return type.sizeOf_();
    return size;
  }
}

/// A set of pre-defined types.
struct Types
{
static:
  TypeBasic Char,   Wchar,   Dchar, Bool,
            Byte,   Ubyte,   Short, Ushort,
            Int,    Uint,    Long,  Ulong,
            Cent,   Ucent,
            Float,  Double,  Real,
            Ifloat, Idouble, Ireal,
            Cfloat, Cdouble, Creal, Void;

  TypeBasic Size_t, Ptrdiff_t;
  TypePointer Void_ptr;
  TypeBasic Error, Undefined;

  /// Allocates an instance of TypeBasic and assigns it to typeName.
  template newTB(char[] typeName)
  {
    const TypeBasic newTB = mixin(typeName~" = new TypeBasic(TYP."~typeName~")");
  }

  static this()
  {
    newTB!("Char");
    newTB!("Wchar");
    newTB!("Dchar");
    newTB!("Bool");
    newTB!("Byte");
    newTB!("Ubyte");
    newTB!("Short");
    newTB!("Ushort");
    newTB!("Int");
    newTB!("Uint");
    newTB!("Long");
    newTB!("Ulong");
    newTB!("Cent");
    newTB!("Ucent");
    newTB!("Float");
    newTB!("Double");
    newTB!("Real");
    newTB!("Ifloat");
    newTB!("Idouble");
    newTB!("Ireal");
    newTB!("Cfloat");
    newTB!("Cdouble");
    newTB!("Creal");
    newTB!("Void");
    version(X86_64)
    {
      Size_t = Ulong;
      Ptrdiff_t = Long;
    }
    else
    {
      Size_t = Uint;
      Ptrdiff_t = Int;
    }
    Void_ptr = Void.ptrTo;
    Error = new TypeBasic(TYP.Error);
    Undefined = new TypeBasic(TYP.Error);
  }
}
