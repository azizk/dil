/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.TypeSystem;

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

struct TypeMetaInfo
{
  char mangle; /// Mangle character of the type.
  size_t size; /// Byte size of the type.
}

struct MITable
{
static:
  const size_t SIZE_NOT_AVAILABLE = -1; /// Size not available.
  private alias SIZE_NOT_AVAILABLE SNA;
  private alias PTR_SIZE PS;
  private const TypeMetaInfo metaInfoTable[] = [
    {'?', SNA}, // Error

    {'a', 1},   // Char
    {'u', 2},   // Wchar
    {'w', 4},   // Dchar
    {'b', 1},   // Bool
    {'g', 1},   // Byte
    {'h', 1},   // Ubyte
    {'s', 2},   // Short
    {'t', 2},   // Ushort
    {'i', 4},   // Int
    {'k', 4},   // Uint
    {'l', 8},   // Long
    {'m', 8},   // Ulong
    {'?', 16},  // Cent
    {'?', 16},  // Ucent
    {'f', 4},   // Float
    {'d', 8},   // Double
    {'e', 12},  // Real
    {'o', 4},   // Ifloat
    {'p', 8},   // Idouble
    {'j', 12},  // Ireal
    {'q', 8},   // Cfloat
    {'r', 16},  // Cdouble
    {'c', 24},  // Creal
    {'v', 1},   // void

    {'n', SNA},  // None

    {'A', PS*2}, // Dynamic array
    {'G', PS*2}, // Static array
    {'H', PS*2}, // Associative array

    {'E', SNA}, // Enum
    {'S', SNA}, // Struct
    {'C', PS},  // Class
    {'T', SNA}, // Typedef
    {'F', PS},  // Function
    {'D', PS*2}, // Delegate
    {'P', PS},  // Pointer
    {'R', PS},  // Reference
    {'I', SNA}, // Identifier
    {'?', SNA}, // Template instance
    {'B', SNA}, // Tuple
    {'x', SNA}, // Const, D2
    {'y', SNA}, // Invariant, D2
  ];

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
  TypeBasic Undefined;

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
    Undefined = new TypeBasic(TYP.Error);
  }
}
