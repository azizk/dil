/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.TypeSystem;

import dil.Symbol;
import dil.TypesEnum;

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
}

class TypeBasic : Type
{

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

  {'A', 8}, // Dynamic array
  {'G', 8}, // Static array
  {'H', 8}, // Associative array

  {'E', -1}, // Enum
  {'S', -1}, // Struct
  {'C', -1}, // Class
  {'T', -1}, // Typedef
  {'F', -1}, // Function
  {'D', -1}, // Delegate
  {'P', -1}, // Pointer
  {'R', -1}, // Reference
  {'I', -1}, // Identifier
  {'?', -1}, // Template instance
  {'B', -1}, // Tuple
  {'x', -1}, // Const, D2
  {'y', -1}, // Invariant, D2
];
