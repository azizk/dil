/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.semantic.Types;

import dil.semantic.Symbol,
       dil.semantic.TypesEnum;
import dil.lexer.Identifier,
       dil.lexer.Keywords,
       dil.lexer.IdTable,
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

  /// Returns the mangled TypeInfo identifier for this type.
  /// Params:
  ///   idtable = Inserts the returned id into this table.
  final Identifier* mangledTypeInfoIdent(IdTable idtable)
  {
    auto m = toMangle();
    m = "_D" ~ String(m.length+9) ~ "TypeInfo_" ~ m ~ "6__initZ";
    return idtable.lookup(m);
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

  /// Returns the type as a human-readable string.
  abstract string toString();

  /// Returns true if dynamic array type.
  final bool isDArray()
  {
    return tid == TYP.DArray;
  }

  /// Returns true if static array type.
  final bool isSArray()
  {
    return tid == TYP.SArray;
  }

  /// Returns true if associative array type.
  final bool isAArray()
  {
    return tid == TYP.AArray;
  }

  /// Returns true if parameter type.
  final bool isParameter()
  {
    return tid == TYP.Parameter;
  }

  /// Returns true if parameters type.
  final bool isParameters()
  {
    return tid == TYP.Parameters;
  }

  /// Returns true if enum type.
  final bool isEnum()
  {
    return tid == TYP.Enum;
  }

  /// Returns true if struct type.
  final bool isStruct()
  {
    return tid == TYP.Struct;
  }

  /// Returns true if class type.
  final bool isClass()
  {
    return tid == TYP.Struct;
  }

  /// Returns true if typedef type.
  final bool isTypedef()
  {
    return tid == TYP.Typedef;
  }

  /// Returns true if function type.
  final bool isFunction()
  {
    return tid == TYP.Function;
  }

  /// Returns true if Delegate type.
  final bool isDelegate()
  {
    return tid == TYP.Delegate;
  }

  /// Returns true if pointer type.
  final bool isPointer()
  {
    return tid == TYP.Pointer;
  }

  /// Returns true if reference type.
  final bool isReference()
  {
    return tid == TYP.Reference;
  }

  /// Returns true if identifier type.
  final bool isIdentifier()
  {
    return tid == TYP.Identifier;
  }

  /// Returns true if template instance type.
  final bool isTInstance()
  {
    return tid == TYP.TInstance;
  }

  /// Returns true if tuple type.
  final bool isTuple()
  {
    return tid == TYP.Tuple;
  }

  /// Returns true if const type.
  final bool isConst()
  {
    return tid == TYP.Const;
  }

  /// Returns true if invariant type.
  final bool isInvariant()
  {
    return tid == TYP.Invariant;
  }

  /// Returns true if dynamic or static array type.
  final bool isDorSArray()
  {
    return tid == TYP.DArray || tid == TYP.SArray;
  }

  /// Returns true if bool type.
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
  string toMangle()
  {
    if (mangled.length)
      return mangled;
    char[] m;
    m ~= mangleChar();
    if (next)
      m ~= next.toMangle();
    return m;
  }
}

/// The error type.
class TypeError : Type
{
  this()
  {
    super(null, TYP.Error);
  }

  string toString()
  {
    return "{TypeError}";
  }

  string toMangle()
  {
    return "{TypeError}";
  }
}

/// All basic types. E.g.: int, char, real etc.
class TypeBasic : Type
{
  Identifier* ident; /// Keyword identifier.

  this(Identifier* ident, TYP typ)
  {
    super(null, typ);
    this.ident = ident;
  }

  string toString()
  {
    return ident.str.dup;
  }
}

/// Dynamic array type.
class TypeDArray : Type
{
  this(Type next)
  {
    super(next, TYP.DArray);
  }

  string toString()
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

  string toString()
  {
    return next.toString() ~ "[" ~ keyType.toString() ~ "]";
  }

  string toMangle()
  {
    if (mangled.length)
      return mangled;
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

  string toString()
  {
    return next.toString() ~ "[" ~ String(dimension) ~ "]";
  }

  string toMangle()
  {
    if (mangled.length)
      return mangled;
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

  string toString()
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

  string toString()
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

  string toString()
  {
    return symbol.name.str;
  }

  string toMangle()
  {
    if (mangled.length)
      return mangled;
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

  string toString()
  {
    return symbol.name.str;
  }

  string toMangle()
  {
    if (mangled.length)
      return mangled;
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

  string toString()
  {
    return symbol.name.str;
  }

  string toMangle()
  {
    if (mangled.length)
      return mangled;
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

  string toString()
  { // TODO:
    return "typedef";
  }

  string toMangle()
  {
    if (mangled.length)
      return mangled;
    return mangleChar() ~ symbol.toMangle();
  }
}

/// Parameter type.
class TypeParameter : Type
{
  alias next type; /// Parameter's type.
  StorageClass stcs; /// Storage classes.
  VariadicStyle variadic; /// Variadic style.
  // TODO: add these?
  // They have no relevance for mangling,
  // because they don't affect the function signature,
  // and they will be null after a Type.merge().
  // Identifier* name;
  // Node defValue;

  this(Type type, StorageClass stcs, VariadicStyle variadic=VariadicStyle.None)
  {
    super(type, TYP.Parameter);
    this.stcs = stcs;
    this.variadic = variadic;
  }

  /// NB: the parameter's name and the optional default value are not printed.
  string toString()
  { // := StorageClasses? ParamType? "..."?
    char[] s;
    // TODO: exclude STC.In?
    foreach (stc; EnumString.all(stcs/+ & ~StorageClass.In+/))
      s ~= stc ~ " ";
    if (type)
      s ~= type.toString();
    else if (variadic)
      s ~= "...";
    assert(s.length, "empty parameter?");
    return s;
  }

  string toMangle()
  { // := StorageClassMangleChar TypeMangle
    if (mangled.length)
      return mangled;
    // 1. Mangle storage class.
    char[] m;
    char mc = 0;
    // TODO: D2 can have more than one stc. What to do?
    if (stcs & StorageClass.Out)
      mc = 'J';
    //else if (stcs & StorageClass.In)
      //mc = 0;
    else if (stcs & StorageClass.Ref)
      mc = 'K';
    else if (stcs & StorageClass.Lazy)
      mc = 'L';
    if (mc)
      m ~= mc;
    // 2. Mangle parameter type.
    if (type)
      m ~= type.toMangle();
    else
      assert(variadic == VariadicStyle.C);
    return m;
  }
}

/// A list of TypeParameter objects.
class TypeParameters : Type
{
  TypeParameter[] params; /// The parameters.

  this(TypeParameter[] params)
  {
    super(null, TYP.Parameters);
    this.params = params;
  }

  /// Returns the variadic style of the last parameter.
  VariadicStyle getVariadic()
  {
    return params.length ? params[$-1].variadic : VariadicStyle.None;
  }

  string toString()
  { // := "(" ParameterList ")"
    char[] s;
    s ~= "(";
    foreach (i, p; params) {
      if (i) s ~= ", "; // Append comma if more than one param.
      s ~= p.toString();
    }
    s ~= ")";
    return s;
  }

  string toMangle()
  {
    if (mangled.length)
      return mangled;
    char[] m;
    foreach (p; params)
      m ~= p.toMangle();
    return m;
  }
}

/// Abstract base class for TypeFunction and TypeDelegate.
abstract class TypeFuncBase : Type
{
  alias next retType;
  TypeParameters params; /// The parameter list.
  LinkageType linkage; /// The linkage type.
  VariadicStyle variadic; /// Variadic style.

  this(Type retType, TypeParameters params, LinkageType linkage, TYP tid)
  {
    super(retType, tid);
    this.params = params;
    this.linkage = linkage;
    this.variadic = params.getVariadic();
  }

  string toString()
  { // := ReturnType " " DelegateOrFunction ParameterList
    auto ident = (tid == TYP.Function) ? Keyword.Function : Keyword.Delegate;
    return retType.toString() ~ " " ~ ident.str ~ params.toString();
  }

  string toMangle()
  { // := MangleChar LinkageChar ParamsMangle ReturnChar ReturnTypeMangle
    if (mangled.length)
      return mangled;
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
    m ~= retType.toMangle();
    return m;
  }
}

/// Function type.
class TypeFunction : TypeFuncBase
{
  this(Type retType, TypeParameters params, LinkageType linkage)
  {
    super(retType, params, linkage, TYP.Function);
  }
}

/// Delegate type.
class TypeDelegate : TypeFuncBase
{
  this(Type retType, TypeParameters params, LinkageType linkage)
  {
    super(retType, params, linkage, TYP.Delegate);
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

  string toString()
  {
    return ident.str;
  }

  string toMangle()
  { // := MangleChar IDLength ID
    if (mangled.length)
      return mangled;
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

  string toString()
  { // TODO:
    return "tpl!()";
  }
}

/// Template tuple type.
class TypeTuple : Type
{
  Type[] types; /// The types inside this tuple.

  this(Type[] types)
  {
    super(null, TYP.Tuple);
    this.types = types;
  }

  string toString()
  { // := "(" TypeList ")"
    char[] s;
    s ~= "(";
    foreach (i, t; types) {
      if (i) s ~= ", "; // Append comma if more than one type.
      s ~= t.toString();
    }
    s ~= ")";
    return s;
  }

  string toMangle()
  { // := MangleChar TypesMangleLength TypesMangle
    if (mangled.length)
      return mangled;
    char[] tm;
    foreach (t; types)
      tm ~= t.toMangle();
    return mangleChar() ~ String(tm.length) ~ tm;
  }
}

/// Constant type. D2.0
class TypeConst : Type
{
  this(Type next)
  {
    super(next, TYP.Const);
  }

  string toString()
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

  string toString()
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
    insert(type, hashOf(type.mangled));
  }

  /// Inserts a type into the table by its hash.
  void insert(Type type, hash_t hash)
  {
    assert(type.mangled.length && hash == hashOf(type.mangled));
    table[hash] = type;
  }

  /// Returns the unique version of a type
  /// by looking up its mangled name.
  /// Inserts the type into the table if not present.
  Type unique(Type t)
  {
    if (t.mangled.length) // Already unique?
      assert(t is lookup(t.mangled),
        "the type in the table and the given type are not the same object");
    else
    {
      if (t.next) // Follow the type chain.
        t.next = unique(t.next);
      // Get the mangled string and look it up.
      auto m = t.toMangle();
      auto m_hash = hashOf(m); // Only calculate once.
      if (auto t_intable = lookup(m_hash))
        t = t_intable; // Found.
      else // Insert if not found.
        (t.mangled = m),
        insert(t, m_hash);
    }
    return t;
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
    {'?', SNA},  // Parameter
    {'?', SNA},  // Parameters

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
  TypeError Error; /// The error type.
  TypeError Undefined; /// The undefined type.
  TypeError DontKnowYet; /// The symbol is undefined but might be resolved.

  /// Creates a list of statements for creating and initializing types.
  char[] createTypes(string[] typeNames)
  {
    char[] result;
    foreach (n; typeNames)
      result ~= n~" = new TypeBasic(Keyword."~n~", TYP."~n~");";
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
    Error = new TypeError();
    Undefined = new TypeError();
    DontKnowYet = new TypeError();
  }
}
