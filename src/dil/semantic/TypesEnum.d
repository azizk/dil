/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.semantic.TypesEnum;

/// Enumeration of Type IDs.
enum TYP
{
  Error,
  // Basic types.
  Char,     /// char
  WChar,    /// wchar
  DChar,    /// dchar
  Bool,     /// bool
  Int8,     /// byte
  UInt8,    /// ubyte
  Int16,    /// short
  UInt16,   /// ushort
  Int32,    /// int
  UInt32,   /// uint
  Int64,    /// long
  UInt64,   /// ulong
  Int128,   /// cent
  UInt128,  /// ucent
  Float32,  /// float
  Float64,  /// double
  Float80,  /// real
  IFloat32, /// ifloat
  IFloat64, /// idouble
  IFloat80, /// ireal
  CFloat32, /// cfloat
  CFloat64, /// cdouble
  CFloat80, /// creal
  Void,     /// void

  None,   /// TypeNone in the specs. Purpose?

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
  FuncPtr,    /// A function pointer.
  Delegate,   /// A delegate.
  Pointer,    /// A pointer.
  Reference,  /// A reference.
  Identifier, /// An identifier.
  TInstance,  /// A template instance.
  Tuple,      /// A template tuple.
  Const,      /// A constant type. D2.0
  Immutable,  /// An immutable type. D2.0
}
