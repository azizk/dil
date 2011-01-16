/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.semantic.Types;

import dil.semantic.Symbol,
       dil.semantic.TypesEnum;
import dil.lexer.Identifier,
       dil.lexer.Funcs : hashOf, String;
import dil.CompilerInfo,
       dil.Enums;

import common;

/// The base type for all type structures.
abstract class Type/* : Symbol*/
{
  Type next;     /// The next type in the type structure.
  TYP tid;       /// The ID of the type.
  Symbol symbol; /// Not null if this type has a symbol.
  string mangled; /// The mangled identifier of the type.

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

  /// Casts the type to Class.
  Class to(Class)()
  { // [4..$] is there for slicing off "Type" from the class name.
    assert(this.tid == mixin("TYP." ~ Class.stringof[4..$]) ||
           Class.stringof == "TypeBasic" && this.isBasic());
    return cast(Class)cast(void*)this;
  }

  /// Returns the unique version of this type from the type table.
  /// Inserts this type into the table if not yet existant.
  Type unique(TypeTable tt)
  {
    // TODO:
    if (!mangled.length)
    {}
    return this;
  }

  /// Returns the base type if this is an enum or typedef, or itself otherwise.
  Type baseType()
  {
    auto t = this;
    for (; t.hasBaseType(); t = t.next)
      assert(t !is null);
    return t;
  }

  /// Returns true if this type has a base type (enum or typedef.)
  final bool hasBaseType()
  {
    return tid == TYP.Enum || tid == TYP.Typedef;
  }

  /// Returns true if this type equals the other one.
  bool opEquals(Type other)
  {
    if (this.next is null && other.next is null)
      return this.tid == other.tid;
    // TODO:
    return false;
  }

  /// Returns a pointer type to this type.
  TypePointer ptrTo()
  {
    return new TypePointer(this);
  }

  /// Returns a dynamic array type using this type as its base.
  TypeDArray arrayOf()
  {
    return new TypeDArray(this);
  }

  /// Returns an associative array type using this type as its base.
  /// Params:
  ///   key = the key type.
  TypeAArray arrayOf(Type key)
  {
    return new TypeAArray(this, key);
  }

  /// Returns a static array type using this type as its base.
  /// Params:
  ///   size = the number of elements in the array.
  TypeSArray arrayOf(size_t size)
  {
    return new TypeSArray(this, size);
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
  final bool hasSymbol()
  {
    return symbol !is null;
  }

  /// Returns the type as a string.
  abstract char[] toString();

  /// Returns true if this type is a pointer type.
  final bool isPointer()
  {
    return tid == TYP.Pointer;
  }

  // Returns true if this is a dynamic array type.
  final bool isDArray()
  {
    return tid == TYP.DArray;
  }

  // Returns true if this is a static array type.
  final bool isSArray()
  {
    return tid == TYP.SArray;
  }

  // Returns true if this is a associative array type.
  final bool isAArray()
  {
    return tid == TYP.AArray;
  }

  // Returns true if this is a dynamic or static array type.
  final bool isDorSArray()
  {
    return tid == TYP.DArray || tid == TYP.SArray;
  }

  /// Returns true if this type is a bool type.
  final bool isBool()
  {
    return tid == TYP.Bool;
  }

  /// Like isBool(). Also checks base types of typedef/enum.
  final bool isBaseBool()
  {
    if (hasBaseType())
      return next.isBool(); // Check base type.
    return isBool();
  }

  /// Returns true if this is a basic type.
  final bool isBasic()
  {
    return isIntegral() || isFloating();
  }

  /// Returns true if this type is an integral number type.
  final bool isIntegral()
  {
    switch (tid)
    {
    case TYP.Char, TYP.Wchar, TYP.Dchar, TYP.Bool, TYP.Byte, TYP.Ubyte,
         TYP.Short, TYP.Ushort, TYP.Int, TYP.Uint, TYP.Long, TYP.Ulong,
         TYP.Cent, TYP.Ucent:
      return true;
    default:
      return false;
    }
  }

  /// Returns true if this type is a floating point number type.
  final bool isFloating()
  {
    return isReal() || isImaginary() || isComplex();
  }

  /// Like isFloating(). Also checks base types of typedef/enum.
  final bool isBaseFloating()
  {
    if (tid == TYP.Enum)
      return false; // Base type of enum can't be floating.
    if (tid == TYP.Typedef)
      return next.isBaseFloating();
    return isReal() || isImaginary() || isComplex();
  }

  /// Returns true if this type is a real number type.
  final bool isReal()
  {
    return tid == TYP.Float || tid == TYP.Double || tid == TYP.Real;
  }

  /// Like isReal(). Also checks base types of typedef/enum.
  final bool isBaseReal()
  {
    if (tid == TYP.Enum)
      return false; // Base type of enum can't be real.
    if (tid == TYP.Typedef)
      return next.isBaseReal();
    return isReal();
  }

  /// Returns true if this type is an imaginary number type.
  final bool isImaginary()
  {
    return tid == TYP.Ifloat || tid == TYP.Idouble || tid == TYP.Ireal;
  }

  /// Like isImaginary(). Also checks base types of typedef/enum.
  final bool isBaseImaginary()
  {
    if (tid == TYP.Enum)
      return false; // Base type of enum can't be imaginary.
    if (tid == TYP.Typedef)
      return next.isBaseImaginary();
    return isImaginary();
  }

  /// Returns true if this type is a complex number type.
  final bool isComplex()
  {
    return tid == TYP.Cfloat || tid == TYP.Cdouble || tid == TYP.Creal;
  }

  /// Like isComplex(). Also checks base types of typedef/enum.
  final bool isBaseComplex()
  {
    if (tid == TYP.Enum)
      return false; // Base type of enum can't be complex.
    if (tid == TYP.Typedef)
      return next.isBaseComplex();
    return isComplex();
  }

  /// Returns true for scalar types.
  final bool isScalar()
  {
    return isPointer() || isBasic();
  }

  /// Like isScalar(). Also checks base types of typedef/enum.
  final bool isBaseScalar()
  {
    if (tid == TYP.Enum)
      return true; // Base type of enum can only be scalar.
    if (tid == TYP.Typedef)
      return next.isScalar(); // Check base type.
    return isScalar();
  }

  /// Returns the mangle character for this type.
  final char mangleChar()
  {
    return MITable.mangleChar(this);
  }

  /// Returns the mangled name of this type.
  char[] toMangle()
  {
    char[] m;
    m ~= mangleChar();
    if (next)
      m ~= next.toMangle();
    return m;
  }
}

/// All basic types. E.g.: int, char, real etc.
class TypeBasic : Type
{
  this(TYP typ)
  {
    super(null, typ);
  }

  char[] toString()
  {
    return [
      TYP.Char : "char"[], TYP.Wchar : "wchar", TYP.Dchar : "dchar",
      TYP.Bool : "bool", TYP.Byte : "byte", TYP.Ubyte : "ubyte",
      TYP.Short : "short", TYP.Ushort : "ushort", TYP.Int : "int",
      TYP.Uint : "uint", TYP.Long : "long", TYP.Ulong : "ulong",
      TYP.Cent : "cent", TYP.Ucent : "ucent", TYP.Float : "float",
      TYP.Double : "double", TYP.Real : "real", TYP.Ifloat : "ifloat",
      TYP.Idouble : "idouble", TYP.Ireal : "ireal", TYP.Cfloat : "cfloat",
      TYP.Cdouble : "cdouble", TYP.Creal : "creal"
    ][this.tid];
  }
}

/// Dynamic array type.
class TypeDArray : Type
{
  this(Type next)
  {
    super(next, TYP.DArray);
  }

  char[] toString()
  {
    return next.toString() ~ "[]";
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

  char[] toString()
  {
    return next.toString() ~ "[" ~ keyType.toString() ~ "]";
  }

  char[] toMangle()
  {
    return mangleChar() ~ keyType.toMangle() ~ next.toMangle();
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

  char[] toString()
  {
    return next.toString() ~ "[" ~ String(dimension) ~ "]";
  }

  char[] toMangle()
  {
    return mangleChar() ~ String(dimension) ~ next.toMangle();
  }
}

/// Pointer type.
class TypePointer : Type
{
  this(Type next)
  {
    super(next, TYP.Pointer);
  }

  char[] toString()
  {
    return next.toString() ~ "*";
  }
}

/// Reference type.
class TypeReference : Type
{
  this(Type next)
  {
    super(next, TYP.Reference);
  }

  char[] toString()
  { // FIXME: this is probably wrong.
    return next.toString() ~ "&";
  }
}

/// Enum type.
class TypeEnum : Type
{
  this(Symbol symbol)
  {
    // FIXME: pass int as the base type for the time being.
    super(Types.Int, TYP.Enum);
    this.symbol = symbol;
  }

  /// Setter for the base type.
  void baseType(Type type)
  {
    next = type;
  }

  char[] toString()
  {
    return symbol.name.str;
  }

  char[] toMangle()
  {
    return mangleChar() ~ symbol.toMangle();
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

  char[] toString()
  {
    return symbol.name.str;
  }

  char[] toMangle()
  {
    return mangleChar() ~ symbol.toMangle();
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

  char[] toString()
  {
    return symbol.name.str;
  }

  char[] toMangle()
  {
    return mangleChar() ~ symbol.toMangle();
  }
}

/// Typedef type.
class TypeTypedef : Type
{
  this(Type next)
  {
    super(next, TYP.Typedef);
  }

  char[] toString()
  { // TODO:
    return "typedef";
  }

  char[] toMangle()
  {
    return mangleChar() ~ symbol.toMangle();
  }
}


/// Using this interface avoids circular imports.
interface IParameters
{
  VariadicStyle getVariadic();
}

/// Abstract base class for TypeFunction and TypeDelegate.
abstract class TypeFuncBase : Type
{
  alias symbol params; /// The parameter list.
  LinkageType linkage; /// The linkage type.
  VariadicStyle variadic; /// Variadic style.

  this(Type retType, Symbol params, LinkageType linkage, TYP tid)
  {
    assert(params.isParameters());
    super(retType, tid);
    this.params = params;
    this.linkage = linkage;
    this.variadic = iparams().getVariadic();
  }

  final IParameters iparams()
  {
    return cast(IParameters)cast(void*)params;
  }

  final char[] toString(string keyword)
  { // := ReturnType " " DelegateOrFunction ParameterList
    return next.toString() ~ " " ~ keyword ~ params.toString();
  }

  char[] toMangle()
  { // := MangleChar LinkageChar ParamsMangle ReturnChar ReturnTypeMangle
    char[] m;
    char mc = void;
    // 'P' for functions and 'D' for delegates.
    m ~= (tid == TYP.Function) ? 'P' : 'D';
    switch (linkage)
    {
    case LinkageType.C:       mc = 'U'; break;
    case LinkageType.D:       mc = 'F'; break;
    case LinkageType.Cpp:     mc = 'R'; break;
    case LinkageType.Windows: mc = 'W'; break;
    case LinkageType.Pascal:  mc = 'V'; break;
    default: assert(0);
    }
    m ~= mc;
    m ~= params.toMangle();
    mc = 'Z' - variadic;
    assert(mc == 'X' || mc == 'Y' || mc == 'Z');
    m ~= mc; // Marks end of parameter list.
    m ~= next.toMangle();
    return m;
  }
}

/// Function type.
class TypeFunction : TypeFuncBase
{
  this(Type retType, Symbol params, LinkageType linkage)
  {
    super(retType, params, linkage, TYP.Function);
  }

  char[] toString()
  {
    return super.toString("function");
  }
}

/// Delegate type.
class TypeDelegate : TypeFuncBase
{
  this(Type retType, Symbol params, LinkageType linkage)
  {
    super(retType, params, linkage, TYP.Delegate);
  }

  char[] toString()
  {
    return super.toString("delegate");
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

  char[] toString()
  {
    return ident.str;
  }

  char[] toMangle()
  { // := MangleChar IDLength ID
    auto id = ident.str;
    return mangleChar() ~ String(id.length) ~ id;
  }
}

/// Template instantiation type.
class TypeTemplInstance : Type
{
  this()
  {
    super(null, TYP.TInstance);
  }

  char[] toString()
  { // TODO:
    return "tpl!()";
  }
}

/// Template tuple type.
class TypeTuple : Type
{
  alias symbol params;

  this(Symbol params)
  {
    assert(params.isParameters());
    super(null, TYP.Tuple);
    this.params = params;
  }

  char[] toString()
  {
    return params.toString();
  }

  char[] toMangle()
  { // := MangleChar ParamsMangleLength ParamsMangle
    char[] params = params.toMangle();
    return mangleChar() ~ String(params.length) ~ params;
  }
}

/// Constant type. D2.0
class TypeConst : Type
{
  this(Type next)
  {
    super(next, TYP.Const);
  }

  char[] toString()
  {
    return "const(" ~ next.toString() ~ ")";
  }
}

/// Invariant type. D2.0
class TypeInvariant : Type
{
  this(Type next)
  {
    super(next, TYP.Const);
  }

  char[] toString()
  {
    return "invariant(" ~ next.toString() ~ ")";
  }
}

/// Maps mangled type identifiers to Type objects.
class TypeTable
{
  Type[hash_t] table; /// The table data structure.

  /// Looks up a type by its mangled id.
  /// Returns: the symbol if there, otherwise null.
  Type lookup(string mangled)
  {
    assert(mangled.length);
    return lookup(hashOf(mangled));
  }

  /// Looks up a type by the hash of its mangled id.
  Type lookup(hash_t hash)
  {
    auto ptype = hash in table;
    return ptype ? *ptype : null;
  }

  /// Inserts a type into the table.
  void insert(Type type)
  {
    assert(type.mangled.length);
    table[hashOf(type.mangled)] = type;
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

  /// Returns the mangle character of a type.
  char mangleChar(Type type)
  {
    return metaInfoTable[type.tid].mangle;
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
  TypeBasic DontKnowYet; /// The symbol is undefined but might be resolved.

  /// Creates a list of statements for creating and initializing types.
  char[] createTypes(char[][] typeNames)
  {
    char[] result;
    foreach (typeName; typeNames)
      result ~= typeName~" = new TypeBasic(TYP."~typeName~");";
    return result;
  }

  /// Initializes predefined types.
  static this()
  {
    mixin(createTypes(["Char", "Wchar", "Dchar", "Bool", "Byte", "Ubyte",
      "Short", "Ushort", "Int", "Uint", "Long", "Ulong", "Cent", "Ucent",
      "Float", "Double", "Real", "Ifloat", "Idouble", "Ireal", "Cfloat",
      "Cdouble", "Creal", "Void"]));
    // FIXME: Size_t and Ptrdiff_t should depend on the platform
    // the code is generated for.
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
    DontKnowYet = new TypeBasic(TYP.Error);
  }
}
