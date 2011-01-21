/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.semantic.TypesEnum;

/// Enumeration of Type IDs.
enum TYP
{
  Error,
  // Basic types.
  Char,    /// char
  Wchar,   /// wchar
  Dchar,   /// dchar
  Bool,    /// bool
  Byte,    /// int8
  Ubyte,   /// uint8
  Short,   /// int16
  Ushort,  /// uint16
  Int,     /// int32
  Uint,    /// uint32
  Long,    /// int64
  Ulong,   /// uint64
  Cent,    /// int128
  Ucent,   /// uint128
  Float,   /// float32
  Double,  /// float64
  Real,    /// float80
  Ifloat,  /// imaginary float32
  Idouble, /// imaginary float64
  Ireal,   /// imaginary float80
  Cfloat,  /// complex float32
  Cdouble, /// complex float64
  Creal,   /// complex float80
  Void,    /// void

  None,   /// TypeNone in the specs. Why?

  Parameter, /// Function parameter.
  Parameters, /// List of function parameters.

  DArray, /// Dynamic array.
  SArray, /// Static array.
  AArray, /// Associative array.

  Enum,       /// An enum.
  Struct,     /// A struct.
  Class,      /// A class.
  Typedef,    /// A typedef.
  Function,   /// A function.
  Delegate,   /// A delegate.
  Pointer,    /// A pointer.
  Reference,  /// A reference.
  Identifier, /// An identifier.
  TInstance,  /// Template instance.
  Tuple,      /// A template tuple.
  Const,      /// A constant type. D2.0
  Invariant,  /// An invariant type. D2.0
}
