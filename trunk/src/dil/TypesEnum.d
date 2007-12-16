/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.TypesEnum;

enum TYP
{
  Error,
  // Basic types.
  Char,    // char
  Wchar,   // wchar
  Dchar,   // dchar
  Bool,    // bool
  Byte,    // int8
  Ubyte,   // uint8
  Short,   // int16
  Ushort,  // uint16
  Int,     // int32
  Uint,    // uint32
  Long,    // int64
  Ulong,   // uint64
  Cent,    // int128
  Ucent,   // uint128
  Float,   // float32
  Double,  // float64
  Real,    // float80
  Ifloat,  // imaginary float32
  Idouble, // imaginary float64
  Ireal,   // imaginary float80
  Cfloat,  // complex float32
  Cdouble, // complex float64
  Creal,   // complex float80
  Void,    // void

  None,   // TypeNone in the specs. Why?

  DArray, // Dynamic
  SArray, // Static
  AArray, // Associative

  Enum,
  Struct,
  Class,
  Typedef,
  Function,
  Delegate,
  Pointer,
  Reference,
  Identifier,
  TInstance, // Template instance.
  Tuple,
  Const, // D2
  Invariant, // D2
}
