/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.semantic.Types;

import dil.semantic.Symbol,
       dil.semantic.TypesEnum;
import dil.lexer.Identifier,
       dil.lexer.Keywords,
       dil.lexer.IdTable,
       dil.lexer.TokensEnum,
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
  /// Returns 0 if it could not be determined.
  /// Params:
  ///   tti = Contains target-dependent info.
  size_t sizeOf(TargetTInfo tti = null)
  {
    return MITable.getSize(this);
  }

  /// Returns the align size of this type.
  /// Returns 0 if it could not be determined.
  /// Params:
  ///   tti = Contains target-dependent info.
  size_t alignSizeOf(TargetTInfo tti = null)
  {
    return MITable.getAlignSize(this);
  }

  /// Returns the flags of this type.
  TypeFlags flagsOf()
  {
    return MITable.getFlags(this);
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

  /// Returns true if const type. D2.
  final bool isConst()
  {
    return tid == TYP.Const;
  }

  /// Returns true if immutable type. D2.
  final bool isImmutable()
  {
    return tid == TYP.Immutable;
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

  /// Returns true if the type is signed.
  final bool isSigned()
  {
    return MITable.getFlags(this).isSigned();
  }

  /// Returns true if the type is unsigned.
  final bool isUnsigned()
  {
    return MITable.getFlags(this).isUnsigned();
  }

  /// Returns true if this is a basic type.
  final bool isBasic()
  {
    return MITable.getFlags(this).isBasic();
  }

  /// Returns true if this type is an integral number type.
  final bool isIntegral()
  {
    return MITable.getFlags(this).isIntegral();
  }

  /// Returns true if this type is a floating point number type.
  final bool isFloating()
  {
    return MITable.getFlags(this).isFloating();
  }

  /// Like isFloating(). Also checks base types of typedef/enum.
  final bool isBaseFloating()
  {
    if (tid == TYP.Enum)
      return false; // Base type of enum can't be floating.
    if (tid == TYP.Typedef)
      return next.isBaseFloating();
    return isFloating();
  }

  /// Returns true if this type is a real number type.
  final bool isReal()
  {
    return MITable.getFlags(this).isReal();
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
    return MITable.getFlags(this).isImaginary();
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
    return MITable.getFlags(this).isComplex();
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
    return MITable.getFlags(this).isScalar();
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

  size_t alignSizeOf(TargetTInfo tti)
  { // TODO:
    return 0;
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

  size_t sizeOf(TargetTInfo tti)
  {
    return tti.ptrSize * 2;
  }

  size_t alignSizeOf(TargetTInfo tti)
  {
    return tti.ptrSize;
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

  size_t sizeOf(TargetTInfo tti)
  {
    return tti.ptrSize * 2;
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

  size_t sizeOf(TargetTInfo tti)
  {
    return tti.ptrSize * 2;
  }

  size_t alignSizeOf(TargetTInfo tti)
  {
    return next.alignSizeOf(tti);
  }

  TypeFlags flagsOf()
  { // TODO:
    auto tf = next.flagsOf();
    //if (symbol.isZeroInit())
      //tf |= TypeFlags.ZeroInit;
    return tf;
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

  size_t sizeOf(TargetTInfo tti)
  {
    return tti.ptrSize;
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

  size_t sizeOf(TargetTInfo tti)
  {
    return tti.ptrSize;
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
    // Use Types.DontKnowYet instead?
    super(Types.Int32, TYP.Enum);
    this.symbol = symbol;
  }

  /// Setter for the base type.
  void baseType(Type type)
  {
    next = type;
  }

  size_t sizeOf(TargetTInfo tti)
  { // TODO:
    return 0;
  }

  size_t alignSizeOf(TargetTInfo tti)
  {
    return next.sizeOf(tti);
  }

  TypeFlags flagsOf()
  { // TODO:
    auto tf = next.flagsOf();
    //if (symbol.isZeroInit())
      //tf |= TypeFlags.ZeroInit;
    return tf;
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

  size_t sizeOf(TargetTInfo tti)
  { // TODO:
    return 0;
  }

  size_t alignSizeOf(TargetTInfo tti)
  { // TODO:
    return 0;
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

  size_t sizeOf(TargetTInfo tti)
  {
    return tti.ptrSize;
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

  size_t sizeOf(TargetTInfo tti)
  {
    return next.sizeOf(tti);
  }

  size_t alignSizeOf(TargetTInfo tti)
  {
    return next.alignSizeOf(tti);
  }

  TypeFlags flagsOf()
  { // TODO:
    auto tf = next.flagsOf();
    //if (symbol.isZeroInit())
      //tf |= TypeFlags.ZeroInit;
    return tf;
  }

  string toString()
  {
    return next.toString();
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

/// A function type.
class TypeFunction : Type
{
  alias next retType;
  TypeParameters params; /// The parameter list.
  StorageClass stcs; /// The storage classes.
  LinkageType linkage; /// The linkage type.
  VariadicStyle variadic; /// Variadic style.

  this(Type retType, TypeParameters params, StorageClass stcs, LinkageType linkage)
  {
    super(retType, TYP.Function);
    this.params = params;
    this.stcs = stcs;
    this.linkage = linkage;
    this.variadic = params.getVariadic();
  }

  string toString()
  { // := ReturnType ParameterList
    return retType.toString() ~ params.toString();
  }

  string toMangle()
  { // := MangleChar LinkageChar ParamsMangle ReturnChar ReturnTypeMangle
    if (mangled.length)
      return mangled;
    char[] m;
    char mc = void;
    version(D2)
    m ~= modsToMangle();
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
    version(D2)
    m ~= attrsToMangle();
    m ~= params.toMangle();
    mc = 'Z' - variadic;
    assert(mc == 'X' || mc == 'Y' || mc == 'Z');
    m ~= mc; // Marks end of parameter list.
    m ~= retType.toMangle();
    return m;
  }

  version(D2)
  {
  /// Mangles the modifiers of this function.
  string modsToMangle()
  out(m) { assert(m in ["O"[]:1, "Ox":1, "ONg":1, "x":1, "y":1, "Ng":1]); }
  body
  {
    char[] m;
    if (stcs & StorageClass.Shared)
      m ~= "O";
    if (stcs & StorageClass.Const)
      m ~= "x";
    if (stcs & StorageClass.Immutable)
      m ~= "y";
    if (stcs & StorageClass.Wild)
      m ~= "Ng";
    return m;
  }

  /// Mangles the attributes of this function.
  string attrsToMangle()
  {
    char[] m;
    if (stcs & StorageClass.Pure)
      m ~= "Na";
    if (stcs & StorageClass.Nothrow)
      m ~= "Nb";
    if (stcs & StorageClass.Ref)
      m ~= "Nc";
    if (stcs & StorageClass.Property)
      m ~= "Nd";
    if (stcs & StorageClass.Trusted)
      m ~= "Ne";
    if (stcs & StorageClass.Safe)
      m ~= "Nf";
    return m;
  }
  } // version(D2)
}

/// Pointer to function type.
class TypeFuncPtr : Type
{
  this(TypeFunction func)
  {
    super(func, TYP.FuncPtr);
  }

  TypeFunction funcType()
  {
    return next.to!(TypeFunction);
  }

  size_t sizeOf(TargetTInfo tti)
  {
    return tti.ptrSize;
  }

  string toString()
  {
    auto f = funcType();
    return f.retType.toString() ~ " function" ~ f.params.toString();
  }

  string toMangle()
  {
    return mangleChar() ~ next.toMangle();
  }
}

/// Delegate type.
class TypeDelegate : Type
{
  this(TypeFunction func)
  {
    super(func, TYP.Delegate);
  }

  TypeFunction funcType()
  {
    return next.to!(TypeFunction);
  }

  size_t sizeOf(TargetTInfo tti)
  {
    return tti.ptrSize * 2;
  }

  size_t alignSizeOf(TargetTInfo tti)
  {
    return tti.ptrSize;
  }

  string toString()
  {
    auto f = funcType();
    return f.retType.toString() ~ " delegate" ~ f.params.toString();
  }

  string toMangle()
  {
    return mangleChar() ~ next.toMangle();
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

  size_t sizeOf(TargetTInfo tti)
  { // TODO:
    return 0;
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

  size_t sizeOf(TargetTInfo tti)
  { // TODO:
    return 0;
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

  size_t sizeOf(TargetTInfo tti)
  { // TODO:
    return 0;
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

  size_t sizeOf(TargetTInfo tti)
  {
    return next.sizeOf(tti);
  }

  string toString()
  {
    return "const(" ~ next.toString() ~ ")";
  }
}

/// Immutable type. D2.0
class TypeImmutable : Type
{
  this(Type next)
  {
    super(next, TYP.Immutable);
  }

  size_t sizeOf(TargetTInfo tti)
  {
    return next.sizeOf(tti);
  }

  string toString()
  {
    return "immutable(" ~ next.toString() ~ ")";
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
  /// The subtypes in the type chain are visited as well.
  /// The type is inserted into the table if not present.
  Type unique(Type t)
  {
    if (t.next) // Follow the type chain.
      t.next = unique(t.next);
    return unique2(t);
  }

  /// Same as unique(Type) but doesn't follow the type chain.
  Type unique2(Type t)
  { // Get the mangled string and look it up.
    if (!t.mangled.length)
      t.mangled = t.toMangle();
    auto m_hash = hashOf(t.mangled); // Only calculate once.
    if (auto t_intable = lookup(m_hash))
      t = t_intable; // Found.
    else // Insert new type.
      insert(t, m_hash);
    return t;
  }

  // TODO: change bool[string] to a different structure if necessary.
  /// Initializes the table and
  /// takes the target machine's properties into account.
  void init(bool[string] args)
  {
    synchronized Types.init();

    if("is64" in args) // Generate code for 64bit?
    {
      Size_t = Types.UInt64;
      Ptrdiff_t = Types.Int64;
    }
    else
    {
      Size_t = Types.UInt32;
      Ptrdiff_t = Types.Int32;
    }
    PtrSize = Ptrdiff_t.sizeOf();

    tti = new TargetTInfo;
    tti.ptrSize = PtrSize;
    tti.is64 = !!("is64" in args);
  }

  TargetTInfo tti; /// An instance used to calculate type sizes.

  TypeBasic Size_t; /// The size type.
  TypeBasic Ptrdiff_t; /// The pointer difference type.

  size_t PtrSize; /// The size of a pointer (dependent on the architecture.)

  /// Returns the byte size of t.
  size_t sizeOf(Type t)
  {
    return t.sizeOf(tti);
  }

  /// Returns the align size of t.
  size_t alignOf(Type t)
  {
    return t.alignSizeOf(tti);
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

/// A list of flags for types.
struct TypeFlags
{
  /// The actual flags.
  enum
  {
    None      = 0,      /// No flags are set.
    ZeroInit  = 1 << 0, /// All bytes of the type can be initialized to 0.
    Signed    = 1 << 1, /// Signed type.
    Unsigned  = 1 << 2, /// Unsigned type.
    Integral  = 1 << 3, /// Integral type.
    Floating  = 1 << 4, /// Floating point type.
    Real      = 1 << 5, /// Real part of a complex number.
    Imaginary = 1 << 6, /// Imaginary part of a complex number.
    Complex   = 1 << 7, /// Complex number type.
    Pointer   = 1 << 8, /// Pointer or function pointer type.
    BoolVal   = 1 << 9, /// Non-scalar type can be in a boolean expression.
    Basic     = Integral | Floating, /// Basic type.
    Scalar    = Basic | Pointer, /// Scalar type.
  }
  alias typeof(None) Flags; /// Alias to enum member.

  Flags flags; /// Holds a set of flags.

  /// Returns true if any bit from fs is set in flags.
  bool has(Flags fs){ return (flags & fs) != 0; }
  /// Returns true if all bits from fs are set in flags.
  bool hasAll(Flags fs){ return (flags & fs) == fs; }
  /// Returns true if zero init.
  bool isZeroInit() { return has(ZeroInit); }
  /// Returns true if signed.
  bool isSigned() { return has(Signed); }
  /// Returns true if unsigned.
  bool isUnsigned() { return has(Unsigned); }
  /// Returns true if integral.
  bool isIntegral() { return has(Integral); }
  /// Returns true if floating.
  bool isFloating() { return has(Floating); }
  /// Returns true if real.
  bool isReal() { return has(Real); }
  /// Returns true if imaginary.
  bool isImaginary() { return has(Imaginary); }
  /// Returns true if complex.
  bool isComplex() { return has(Complex); }
  /// Returns true if pointer.
  bool isPointer() { return has(Pointer); }
  /// Returns true if boolean value.
  bool isBoolVal() { return has(BoolVal | Scalar); }
  /// Returns true if basic.
  bool isBasic() { return has(Basic); }
  /// Returns true if scalar.
  bool isScalar() { return has(Scalar); }

  TypeFlags opOrAssign(TypeFlags tf)
  {
    flags |= tf.flags;
    return *this;
  }

  TypeFlags opOr(TypeFlags tf)
  {
    return *this |= tf;
  }

  TypeFlags opAndAssign(TypeFlags tf)
  {
    flags &= tf.flags;
    return *this;
  }

  TypeFlags opAnd(TypeFlags tf)
  {
    return *this &= tf;
  }
}

/// Target information for types.
class TargetTInfo
{
  size_t ptrSize; /// The size of a pointer.
  bool is64; /// Is it a 64bit CPU?
  bool isLE; /// Is it little-endian or big-endian?
}

/// Information related to a Type.
struct TypeMetaInfo
{
  char mangle; /// Mangle character of the type.
  ushort size; /// Byte size of the type.
  ushort alignsize; /// Align size of the type.
  Value* defaultInit; /// Default initialization value.
  TypeFlags.Flags flags; /// The flags of the type.
}

/// Namespace for the meta info table.
struct MITable
{
static:
  const ushort SIZE_NOT_AVAILABLE = 0; /// Size not available.
  const ushort ALIGN_NOT_AVAILABLE = 0; /// Align not available.
  const Value VZERO   = {int_:0}; /// Value 0.
  const Value VNULL   = {pvoid:null}; /// Value null.
  const Value V0xFF   = {dchar_:0xFF}; /// Value 0xFF.
  const Value V0xFFFF = {dchar_:0xFFFF}; /// Value 0xFFFF.
  const Value VFALSE  = {bool_:false}; /// Value false.
  const Value VNAN    = {float_:float.nan}; /// Value NAN.
  const Value VCNAN   = {creal_:creal.nan}; /// Value complex NAN.
  private
  {
  alias SIZE_NOT_AVAILABLE SNA;
  alias ALIGN_NOT_AVAILABLE ANA;
  const ushort PS = 0; // Used for documentation purposes below.
  alias TypeFlags TF;    /// Shortcuts.
  alias TF.ZeroInit Z;   /// ditto
  alias TF.Unsigned U;   /// ditto
  alias TF.Signed S;     /// ditto
  alias TF.Integral I;   /// ditto
  alias TF.Floating F;   /// ditto
  alias TF.Real Re;      /// ditto
  alias TF.Imaginary Im; /// ditto
  alias TF.Complex Cx;   /// ditto
  alias TF.Pointer P;    /// ditto
  alias TF.BoolVal BV;   /// ditto
  }
  /// The meta info table.
  private const TypeMetaInfo table[] = [
    {'?', SNA, ANA}, // Error

    {'a', 1, ANA, &V0xFF, I|U},    // Char
    {'u', 2, ANA, &V0xFFFF, I|U},  // WChar
    {'w', 4, ANA, &V0xFFFF, I|U},  // DChar
    {'b', 1, ANA, &VFALSE, I|U|Z}, // Bool
    {'g', 1, ANA, &VZERO, I|S|Z},  // Int8
    {'h', 1, ANA, &VZERO, I|U|Z},  // UInt8
    {'s', 2, ANA, &VZERO, I|S|Z},  // Int16
    {'t', 2, ANA, &VZERO, I|U|Z},  // UInt16
    {'i', 4, ANA, &VZERO, I|S|Z},  // Int32
    {'k', 4, ANA, &VZERO, I|U|Z},  // UInt32
    {'l', 8, ANA, &VZERO, I|S|Z},  // Int64
    {'m', 8, ANA, &VZERO, I|U|Z},  // UInt64
    {'?', 16, ANA, &VZERO, I|S|Z}, // Int128
    {'?', 16, ANA, &VZERO, I|U|Z}, // UInt128
    {'f', 4, ANA, &VNAN, F|Re},    // Float32
    {'d', 8, ANA, &VNAN, F|Re},    // Float64
    {'e', 10, ANA, &VNAN, F|Re},   // Float80
    {'o', 4, ANA, &VNAN, F|Im},    // IFloat32
    {'p', 8, ANA, &VNAN, F|Im},    // IFloat64
    {'j', 10, ANA, &VNAN, F|Im},   // IFloat80
    {'q', 8, ANA, &VCNAN, F|Cx},   // CFloat32
    {'r', 16, ANA, &VCNAN, F|Cx},  // CFloat64
    {'c', 20, ANA, &VCNAN, F|Cx},  // CFloat80
    {'v', 1, 1},                   // Void

    {'n', SNA, ANA}, // None

    {'?', SNA, ANA}, // Parameter
    {'?', SNA, ANA}, // Parameters

    {'A', PS*2, ANA, &VNULL, Z|BV}, // Dynamic array
    {'G', PS*2, ANA}, // Static array
    {'H', PS*2, ANA, &VNULL, Z|BV}, // Associative array

    {'E', SNA, ANA}, // Enum
    {'S', SNA, ANA}, // Struct
    {'C', PS, ANA, &VNULL, Z|BV}, // Class
    {'T', SNA, ANA}, // Typedef
    {'F', SNA, ANA}, // Function
    {'P', PS, ANA, &VNULL, Z|BV|P}, // FuncPtr
    {'D', PS*2, ANA, &VNULL, Z|BV}, // Delegate
    {'P', PS, ANA, &VNULL, Z|BV|P}, // Pointer
    {'R', PS, ANA, &VNULL, Z}, // Reference
    {'I', SNA, ANA}, // Identifier
    {'?', SNA, ANA}, // Template instance
    {'B', SNA, ANA}, // Tuple
    {'x', SNA, ANA}, // Const, D2
    {'y', SNA, ANA}, // Immutable, D2
  ];
  static assert(table.length == TYP.max+1);

  /// Returns the byte size of a type.
  size_t getSize(Type type)
  {
    return table[type.tid].size;
  }

  /// Returns the align size of a type.
  size_t getAlignSize(Type type)
  {
    return table[type.tid].size;
  }

  /// Returns the flags of a type.
  TypeFlags getFlags(Type type)
  {
    TypeFlags tf = {MITable.table[type.tid].flags};
    return tf;
  }

  /// Returns the mangle character of a type.
  char mangleChar(Type type)
  {
    return table[type.tid].mangle;
  }
}

/// Namespace for a set of predefined types.
struct Types
{
static:
  /// Predefined basic types.
  TypeBasic Char,     WChar,    DChar, Bool,
            Int8,     UInt8,    Int16, UInt16,
            Int32,    UInt32,   Int64, UInt64,
            Int128,   UInt128,
            Float32,  Float64,  Float80,
            IFloat32, IFloat64, IFloat80,
            CFloat32, CFloat64, CFloat80, Void;

  TypePointer Void_ptr; /// The void pointer type.
  TypeError Error; /// The error type.
  TypeError Undefined; /// The undefined type.
  TypeError DontKnowYet; /// The symbol is undefined but might be resolved.

  TypeFunction Void_0Args_DFunc; /// Type: extern(D) void X()

  // A table mapping the kind of a token to its corresponding semantic Type.
  TypeBasic[TOK] TOK2Type;

  /// Returns the corresponding Type instance for tok,
  /// or null if it does not apply.
  Type fromTOK(TOK tok)
  {
    auto ptype = tok in TOK2Type;
    return ptype ? *ptype : null;
  }

  /// Creates a list of statements for creating and initializing types.
  /// ---
  /// Int8 = new TypeBasic(Keyword.Byte, TYP.Int8);
  /// ---
  char[] createTypes(string[2][] typeNames)
  {
    char[] result;
    foreach (n; typeNames)
      result ~= n[0]~" = new TypeBasic(Keyword."~n[1]~", TYP."~n[0]~");";
    return result;
  }

  /// Initializes predefined types.
  /// NB: Not thread-safe.
  void init()
  {
    static bool initialized;
    if (initialized)
      return;
    initialized = true;

    mixin(createTypes([ // Pass tuples: (TypeName, KeywordName)
      ["Char", "Char"], ["WChar", "Wchar"], ["DChar", "Dchar"],
      ["Bool", "Bool"],
      ["Int8", "Byte"], ["UInt8", "Ubyte"],
      ["Int16", "Short"], ["UInt16", "Ushort"],
      ["Int32", "Int"], ["UInt32", "Uint"],
      ["Int64", "Long"], ["UInt64", "Ulong"],
      ["Int128", "Cent"], ["UInt128", "Ucent"],
      ["Float32", "Float"], ["Float64", "Double"], ["Float80", "Real"],
      ["IFloat32", "Ifloat"], ["IFloat64", "Idouble"], ["IFloat80", "Ireal"],
      ["CFloat32", "Cfloat"], ["CFloat64", "Cdouble"],
      ["CFloat80", "Creal"], ["Void", "Void"]
    ]));

    TOK2Type = [
      // Number literal TOKs:
      TOK.Int32 : Types.Int32, TOK.UInt32 : Types.UInt32,
      TOK.Int64 : Types.Int64, TOK.UInt64 : Types.UInt64,
      TOK.Float32 : Types.Float32, TOK.Float64 : Types.Float64,
      TOK.Float80 : Types.Float80, TOK.IFloat32 : Types.IFloat32,
      TOK.IFloat64 : Types.IFloat64, TOK.IFloat80 : Types.IFloat80,
      // Keyword TOKs:
      TOK.Char : Types.Char, TOK.Wchar : Types.WChar, TOK.Dchar : Types.DChar,
      TOK.Bool : Types.Bool,
      TOK.Byte : Types.Int8, TOK.Ubyte : Types.UInt8,
      TOK.Short : Types.Int16, TOK.Ushort : Types.UInt16,
      TOK.Int : Types.Int32, TOK.Uint : Types.UInt32,
      TOK.Long : Types.Int64, TOK.Ulong : Types.UInt64,
      TOK.Cent : Types.Int128, TOK.Ucent : Types.UInt128,
      TOK.Float : Types.Float32, TOK.Double : Types.Float64,
      TOK.Real : Types.Float80,
      TOK.Ifloat : Types.IFloat32, TOK.Idouble : Types.IFloat64,
      TOK.Ireal : Types.IFloat80,
      TOK.Cfloat : Types.CFloat32, TOK.Cdouble : Types.CFloat64,
      TOK.Creal : Types.CFloat80, TOK.Void : Types.Void
    ];

    Void_ptr = Void.ptrTo();
    Error = new TypeError();
    Undefined = new TypeError();
    DontKnowYet = new TypeError();

    // A function type that's frequently used.
    auto params = new TypeParameters(null);
    Void_0Args_DFunc = new TypeFunction(Types.Void, params,
      StorageClass.None, LinkageType.D);
  }
}
