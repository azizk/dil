/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.TypeSystem;

import dil.Symbol;
import dil.TypesEnum;
import dil.CompilerInfo;

abstract class Type : Symbol
{
  Type next;
  TYP typ;

  this(){}

  this(Type next, TYP typ)
  {
    this.next = next;
    this.typ = typ;
  }

  TypePointer ptrTo()
  {
    return new TypePointer(this);
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

}

class TypeAArray : Type
{

}

class TypeSArray : Type
{

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

}

struct TypeMetaInfo
{
  char mangle; /// Mangle character of the type.
  size_t size; /// Byte size of the type.
}

static const TypeMetaInfo metaInfoTable[] = [
  {'?', -1}, // Error

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

  {'n', -1},  // None

  {'A', PTR_SIZE*2}, // Dynamic array
  {'G', PTR_SIZE*2}, // Static array
  {'H', PTR_SIZE*2}, // Associative array

  {'E', -1}, // Enum
  {'S', -1}, // Struct
  {'C', PTR_SIZE}, // Class
  {'T', -1}, // Typedef
  {'F', PTR_SIZE}, // Function
  {'D', PTR_SIZE*2}, // Delegate
  {'P', PTR_SIZE}, // Pointer
  {'R', PTR_SIZE}, // Reference
  {'I', -1}, // Identifier
  {'?', -1}, // Template instance
  {'B', -1}, // Tuple
  {'x', -1}, // Const, D2
  {'y', -1}, // Invariant, D2
];

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
  }
}
