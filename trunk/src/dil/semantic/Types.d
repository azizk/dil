/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Types;

import dil.semantic.Symbol;
import dil.semantic.TypesEnum;
import dil.lexer.Identifier;
import dil.CompilerInfo;

/// The base type for all type structures.
abstract class Type/* : Symbol*/
{
  Type next;     /// The next type in the type structure.
  TYP tid;       /// The ID of the type.
  Symbol symbol; /// Not null if this type has a symbol.

  this(){}

  /// Constructs a Type object.
  /// Params:
  ///   next = the type's next type.
  ///   tid = the type's ID.
  this(Type next, TYP tid)
  {
//     this.sid = SYM.Type;

    this.next = next;
    this.tid = tid;
  }

  /// Returns a pointer type to this type.
  TypePointer ptrTo()
  {
    return new TypePointer(this);
  }

  /// Returns the byte size of this type.
  final size_t sizeOf()
  {
    return MITable.getSize(this);
  }

  /// Size is not in MITable. Find out via virtual method.
  size_t sizeOf_()
  {
    return sizeOf();
  }

  /// Returns true if this type has a symbol.
  bool hasSymbol()
  {
    return symbol !is null;
  }
}

/// All basic types. E.g.: int, char, real etc.
class TypeBasic : Type
{
  this(TYP typ)
  {
    super(null, typ);
  }
}

/// Dynamic array type.
class TypeDArray : Type
{
  this(Type next)
  {
    super(next, TYP.DArray);
  }
}

/// Associative array type.
class TypeAArray : Type
{
  Type keyType;
  this(Type next, Type keyType)
  {
    super(next, TYP.AArray);
    this.keyType = keyType;
  }
}

/// Static array type.
class TypeSArray : Type
{
  size_t dimension;
  this(Type next, size_t dimension)
  {
    super(next, TYP.SArray);
    this.dimension = dimension;
  }
}

/// Pointer type.
class TypePointer : Type
{
  this(Type next)
  {
    super(next, TYP.Pointer);
  }
}

/// Reference type.
class TypeReference : Type
{
  this(Type next)
  {
    super(next, TYP.Reference);
  }
}

/// Enum type.
class TypeEnum : Type
{
  this(Symbol symbol, Type baseType)
  {
    super(baseType, TYP.Enum);
    this.symbol = symbol;
  }

  Type baseType()
  {
    return next;
  }
}

/// Struct type.
class TypeStruct : Type
{
  this(Symbol symbol)
  {
    super(null, TYP.Struct);
    this.symbol = symbol;
  }
}

/// Class type.
class TypeClass : Type
{
  this(Symbol symbol)
  {
    super(null, TYP.Class);
    this.symbol = symbol;
  }
}

/// Typedef type.
class TypeTypedef : Type
{
  this(Type next)
  {
    super(next, TYP.Typedef);
  }
}

/// Function type.
class TypeFunction : Type
{
  this(Type next)
  {
    super(next, TYP.Function);
  }
}

/// Delegate type.
class TypeDelegate : Type
{
  this(Type next)
  {
    super(next, TYP.Delegate);
  }
}

/// Identifier type.
class TypeIdentifier : Type
{
  Identifier* ident;
  this(Identifier* ident)
  {
    super(null, TYP.Identifier);
  }
}

/// Template instantiation type.
class TypeTemplInstance : Type
{
  this()
  {
    super(null, TYP.TInstance);
  }
}

/// Template tuple type.
class TypeTuple : Type
{
  this(Type next)
  {
    super(next, TYP.Tuple);
  }
}

/// Constant type. D2.0
class TypeConst : Type
{
  this(Type next)
  {
    super(next, TYP.Const);
  }
}

/// Invariant type. D2.0
class TypeInvariant : Type
{
  this(Type next)
  {
    super(next, TYP.Const);
  }
}

/// Represents a value related to a Type.
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

/// Information related to a Type.
struct TypeMetaInfo
{
  char mangle; /// Mangle character of the type.
  ushort size; /// Byte size of the type.
  Value* defaultInit; /// Default initialization value.
}

/// Namespace for the meta info table.
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
  /// The meta info table.
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

  /// Returns the size of a type.
  size_t getSize(Type type)
  {
    auto size = metaInfoTable[type.tid].size;
    if (size == SIZE_NOT_AVAILABLE)
      return type.sizeOf_();
    return size;
  }
}

/// Namespace for a set of predefined types.
struct Types
{
static:
  /// Predefined basic types.
  TypeBasic Char,   Wchar,   Dchar, Bool,
            Byte,   Ubyte,   Short, Ushort,
            Int,    Uint,    Long,  Ulong,
            Cent,   Ucent,
            Float,  Double,  Real,
            Ifloat, Idouble, Ireal,
            Cfloat, Cdouble, Creal, Void;

  TypeBasic Size_t; /// The size type.
  TypeBasic Ptrdiff_t; /// The pointer difference type.
  TypePointer Void_ptr; /// The void pointer type.
  TypeBasic Error; /// The error type.
  TypeBasic Undefined; /// The undefined type.

  /// Allocates an instance of TypeBasic and assigns it to typeName.
  template newTB(char[] typeName)
  {
    const newTB = mixin(typeName~" = new TypeBasic(TYP."~typeName~")");
  }

  /// Initializes predefined types.
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
