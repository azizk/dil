/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.semantic.Symbols;

import dil.ast.Node,
       dil.ast.Expression;
import dil.semantic.Symbol,
       dil.semantic.SymbolTable,
       dil.semantic.Types;
import dil.lexer.IdTable,
       dil.lexer.Keywords,
       dil.lexer.Funcs : String;
import dil.Enums;
import common;

/// Declaration symbol.
abstract class DeclarationSymbol : Symbol
{
  Protection prot; /// The protection.
  StorageClass stcs; /// The storage classes.
  LinkageType linkage; /// The linkage type.

  this(SYM sid, Identifier* name, Node node)
  {
    super(sid, name, node);
  }

  string toMangle()
  {
    return toMangle(this, linkage);
  }

  static string toMangle(Symbol s, LinkageType linkage)
  {
    string toCppMangle(Symbol s){ /+TODO+/ return ""; }

    char[] m;
    if (!s.parent || s.parent.isModule())
      switch (linkage)
      {
      case LinkageType.D:
        break;
      case LinkageType.C:
      case LinkageType.Windows:
      case LinkageType.Pascal:
        m = s.name.str.dup;
        break;
      case LinkageType.Cpp:
        version(D2)version(Windows)
        goto case LinkageType.C; // D2 on Windows

        m = toCppMangle(s);
        break;
      case LinkageType.None:
        // TODO: issue forward declaration error?
        goto case LinkageType.C;
      default: assert(0);
      }
    if (!m)
      m = "_D" ~ toMangle2(s);
    return m;
  }

  static string toMangle2(Symbol s)
  { // Recursive function.
    string m;
    Symbol s2 = s;
    for (; s2; s2 = s2.parent)
      if (s2.name is Ident.Empty)
        m = "0" ~ m;
      else if (s2 !is s && s2.isFunction())
      {
        m = toMangle2(s2) ~ m; // Recursive call.
        break;
      }
      else
      {
        auto id = s2.name.str;
        m = String(id.length) ~ id ~ m;
      }

    auto fs = s.isFunction() ? s.to!(FunctionSymbol) : null;

    if (fs /+&& (fs.needThis() || fs.isNested())+/) // FIXME:
      m ~= 'M'; // Mangle char for member/nested functions.
    if (auto t = cast(Type)s.getType())
      if (t.mangled)
        m ~= t.mangled;

    return m;
  }
}

/// A symbol that has its own scope with a symbol table.
class ScopeSymbol : Symbol
{
  SymbolTable symbolTable; /// The symbol table.
  Symbol[] members; /// The member symbols (in lexical order.)

  /// Constructs a ScopeSymbol object.
  this(SYM sid, Identifier* name, Node node)
  {
    super(sid, name, node);
  }

  /// Constructs a ScopeSymbol object with the SYM.Scope ID.
  this(Identifier* name = Ident.Empty, Node node = null)
  {
    super(SYM.Scope, name, node);
  }

  /// Looks up name in the table.
  Symbol lookup(Identifier* name)
  {
    return symbolTable.lookup(name);
  }

  /// Looks up a symbol in the table using its string hash.
  Symbol lookup(hash_t hash)
  {
    return symbolTable.lookup(hash);
  }

  /// Inserts a symbol into the table.
  void insert(Symbol s, Identifier* name)
  {
    symbolTable.insert(s, name);
    members ~= s;
  }
}

/// A module symbol.
class ModuleSymbol : ScopeSymbol
{
  ModuleInfoSymbol varminfo; /// The ModuleInfo for this module.

  this(Identifier* name=null, Node node=null)
  {
    super(SYM.Module, name, node);
  }
}

/// A package symbol.
class PackageSymbol : ScopeSymbol
{
  this(Identifier* name=null, Node node=null)
  {
    super(SYM.Package, name, node);
  }
}

/// Aggregates have function and field members.
abstract class Aggregate : ScopeSymbol
{
  Type type;
  FunctionSymbol[] funcs;
  VariableSymbol[] fields;

  this(SYM sid, Identifier* name, Node node)
  {
    super(sid, name, node);
  }

  override void insert(Symbol s, Identifier* ident)
  {
    if (s.isVariable())
      // Append variable to fields.
      fields ~= s.to!(VariableSymbol);
    else if (s.isFunction())
      // Append function to funcs.
      funcs ~= s.to!(FunctionSymbol);
    super.insert(s, ident);
  }

  override Type getType()
  {
    return type;
  }

  string toMangle()
  {
    return Symbol.toMangle(this);
  }
}

/// A class symbol.
class ClassSymbol : Aggregate
{
  ClassSymbol base; /// The inherited base class.
  InterfaceSymbol[] ifaces; /// The inherited interfaces.

  TypeInfoSymbol vartinfo; /// The TypeInfo of this class.

  this(Identifier* name, Node classNode)
  {
    super(SYM.Class, name, classNode);
    this.type = new TypeClass(this);
  }
}

/// Special classes, e.g.: Object, ClassInfo, ModuleInfo etc.
class SpecialClassSymbol : ClassSymbol
{
  this(Identifier* name, Node classNode)
  {
    super(name, classNode);
  }

  /// Handle mangling differently for special classes.
  string toMangle()
  {
    auto parent_save = parent;
    parent = null;
    auto m = super.toMangle();
    parent = parent_save;
    return m;
  }
}

/// An interface symbol.
class InterfaceSymbol : ClassSymbol
{
  this(Identifier* name, Node interfaceNode)
  {
    super(name, interfaceNode);
    this.sid = SYM.Interface;
    this.type = new TypeClass(this);
  }
}

/// A struct symbol.
class StructSymbol : Aggregate
{
  bool isAnonymous;
  this(Identifier* name, Node structNode)
  {
    super(SYM.Struct, name, structNode);
    this.type = new TypeStruct(this);
    this.isAnonymous = name is null;
  }
}

/// A union symbol.
class UnionSymbol : StructSymbol
{
  bool isAnonymous;
  this(Identifier* name, Node unionNode)
  {
    super(name, unionNode);
    this.sid = SYM.Union;
    this.type = new TypeStruct(this);
    this.isAnonymous = name is null;
  }
}

/// An enum symbol.
class EnumSymbol : ScopeSymbol
{
  TypeEnum type;
  bool isAnonymous;
  this(Identifier* name, Node enumNode)
  {
    super(SYM.Enum, name, enumNode);
    this.type = new TypeEnum(this);
    this.isAnonymous = name is null;
  }

  void setType(TypeEnum type)
  {
    this.type = type;
  }

  override Type getType()
  {
    return type;
  }
}

/// A function symbol.
class FunctionSymbol : ScopeSymbol
{
  Protection prot; /// The protection.
  StorageClass stcs; /// The storage classes.
  LinkageType linkage; /// The linkage type.
  Type type; /// The type of this function.

  Type returnType;
  VariableSymbol[] params;

  this(Identifier* name, Node functionNode)
  {
    super(SYM.Function, name, functionNode);
  }

  Type getType()
  {
    return type;
  }

  string toMangle()
  {
    if (isDMain())
      return "_Dmain";
    if (isWinMain() || isDllMain())
      return name.str;
    return DeclarationSymbol.toMangle(this, linkage);
  }

  bool isDMain()
  {
    return name is Ident.main && linkage != LinkageType.C && !isMember();
  }

  bool isWinMain()
  {
    return name is Ident.WinMain && linkage != LinkageType.C && !isMember();
  }

  bool isDllMain()
  {
    return name is Ident.DllMain && linkage != LinkageType.C && !isMember();
  }

  bool isMember()
  { // TODO
    return false;
  }
}

/// The parameter symbol.
class ParameterSymbol : Symbol
{
  StorageClass stcs; /// Storage classes.
  VariadicStyle variadic; /// Variadic style.
  Type type; /// The parameter's type.
  Expression defValue; /// The default initialization value.

  this(Type type, Identifier* name,
    StorageClass stcs, VariadicStyle variadic, Node node)
  {
    super(SYM.Parameter, name, node);
    this.stcs = stcs;
    this.variadic = variadic;
    this.type = type;
  }

  char[] toString()
  { // := StorageClasses? ParamType? ParamName? (" = " DefaultValue)? "..."?
    char[] s;
    foreach (stc; EnumString.all(stcs))
      s ~= stc ~ " ";
    if (type)
      s ~= type.toString();
    if (name !is Ident.Empty)
      s ~= name.str;
    if (defValue)
      s ~= " = " ~ defValue.toText();
    else if (variadic)
      s ~= "...";
    assert(s.length, "empty parameter?");
    return s;
  }

  string toMangle()
  { // 1. Mangle storage class.
    char[] m;
    char mc = 0;
    if (stcs & StorageClass.Out)
      mc = 'J';
    else if (stcs & StorageClass.Ref)
      mc = 'K';
    else if (stcs & StorageClass.Lazy)
      mc = 'L';
    if (mc)
      m ~= mc;
    // 2. Mangle parameter type.
    if (type)
      m ~= type.toMangle();
    return m;
  }
}

/// A list of ParameterSymbol objects.
class ParametersSymbol : Symbol, IParameters
{
  ParameterSymbol[] params; /// The parameters.

  this(ParameterSymbol[] params, Node node=null)
  {
    super(SYM.Parameters, Ident.Empty, node);
    this.params = params;
  }

  /// Returns the variadic style of the last parameter.
  VariadicStyle getVariadic()
  {
    return params.length ? params[$-1].variadic : VariadicStyle.None;
  }

  char[] toString()
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
    char[] m;
    foreach (p; params)
      m ~= p.toMangle();
    return m;
  }
}

/// A variable symbol.
class VariableSymbol : Symbol
{
  Protection prot; /// The protection.
  StorageClass stcs; /// The storage classes.
  LinkageType linkage; /// The linkage type.

  Type type; /// The type of this variable.
  Expression value; /// The value of this variable.

  this(Identifier* name,
       Protection prot, StorageClass stcs, LinkageType linkage,
       Node variableNode)
  {
    super(SYM.Variable, name, variableNode);

    this.prot = prot;
    this.stcs = stcs;
    this.linkage = linkage;
  }

  this(Identifier* name, Node variableNode)
  {
    this(name, Protection.None, StorageClass.None, LinkageType.None, node);
  }
}

/// An enum member symbol.
class EnumMember : VariableSymbol
{
  this(Identifier* name,
       Protection prot, StorageClass stcs, LinkageType linkage,
       Node enumMemberNode)
  {
    super(name, prot, stcs, linkage, enumMemberNode);
    this.sid = SYM.EnumMember;
  }
}

/// A this-pointer symbol for member functions (or frame pointers.)
class ThisSymbol : VariableSymbol
{
  this(Type type, Node node)
  {
    super(Keyword.This, node);
    this.type = type;
  }
}

/// A ClassInfo variable symbol.
class ClassInfoSymbol : VariableSymbol
{
  ClassSymbol clas; /// The class to provide info for.
  /// Constructs a ClassInfoSymbol object.
  ///
  /// Params:
  ///   clas = ClassInfo for this class.
  ///   classClassInfo = The global ClassInfo class from object.d.
  this(ClassSymbol clas, ClassSymbol classClassInfo)
  {
    super(clas.name, clas.node);
    this.type = classClassInfo.type;
    this.clas = clas;
    this.stcs = StorageClass.Static;
  }

//   Something toSomething() // TODO:
//   { return null; }
}

/// A ModuleInfo variable symbol.
class ModuleInfoSymbol : VariableSymbol
{
  ModuleSymbol modul; /// The module to provide info for.
  /// Constructs a ModuleInfoSymbol object.
  ///
  /// Params:
  ///   modul = ModuleInfo for this module.
  ///   classModuleInfo = The global ModuleInfo class from object.d.
  this(ModuleSymbol modul, ClassSymbol classModuleInfo)
  {
    super(modul.name, modul.node);
    this.type = classModuleInfo.type;
    this.modul = modul;
    this.stcs = StorageClass.Static;
  }

//   Something toSomething() // TODO:
//   { return null; }
}

/// A TypeInfo variable symbol.
class TypeInfoSymbol : VariableSymbol
{
  Type titype; /// The type to provide info for.
  /// Constructs a TypeInfo object.
  ///
  /// The variable is of type TypeInfo and its name is mangled.
  /// E.g.:
  /// ---
  /// TypeInfo _D10TypeInfo_a6__initZ; // For type "char".
  /// ---
  /// Params:
  ///   titype = TypeInfo for this type.
  ///   name  = The mangled name of this variable.
  ///   classTypeInfo = The global TypeInfo class from object.d.
  this(Type titype, Identifier* name, ClassSymbol classTypeInfo)
  { // FIXME: provide the node of TypeInfo for now.
    // titype has no node; should every Type get one?
    super(name, classTypeInfo.node);
    this.type = classTypeInfo.type;
    this.titype = titype;
    this.stcs = StorageClass.Static;
    this.prot = Protection.Public;
    this.linkage = LinkageType.C;
  }

//   Something toSomething() // TODO:
//   {
//     switch (titype.tid)
//     {
//     case TYP.Char: break;
//     case TYP.Function: break;
//     // etc.
//     default:
//     }
//     return null;
//   }
}

/// An alias symbol.
class AliasSymbol : Symbol
{
  Type aliasType;
  Symbol aliasSym;

  this(Identifier* name, Node aliasNode)
  {
    super(SYM.Alias, name, aliasNode);
  }
}

/// A typedef symbol.
class TypedefSymbol : Symbol
{
  this(Identifier* name, Node aliasNode)
  {
    super(SYM.Typedef, name, aliasNode);
  }

  string toMangle()
  {
    return Symbol.toMangle(this);
  }
}

/// A template symbol.
class TemplateSymbol : ScopeSymbol
{
  this(Identifier* name, Node node)
  {
    super(SYM.Template, name, node);
  }
}

/// A template instance symbol.
class TemplInstanceSymbol : ScopeSymbol
{
  // TemplArgSymbol[] tiArgs;
  TemplateSymbol tplSymbol;
  this(Identifier* name, Node node)
  {
    super(SYM.TemplateInstance, name, node);
  }

  string toMangle()
  { // := ParentMangle? NameMangleLength NameMangle
    if (name is Ident.Empty)
    {} // TODO: ?
    string pm; // Parent mangle.
    if (!tplSymbol)
    {} // Error: undefined
    else if (tplSymbol.parent)
    {
      pm = tplSymbol.parent.toMangle();
      if (pm.length >= 2 && pm[0..2] == "_D")
        pm = pm[2..$]; // Skip the prefix.
    }
    string id = name.str;
    return pm ~ String(id.length) ~ id;
  }
}

/// A template mixin symbol.
class TemplMixinSymbol : TemplInstanceSymbol
{
  this(Identifier* name, Node node)
  {
    super(name, node);
    this.sid = SYM.TemplateMixin;
  }

  string toMangle()
  {
    return Symbol.toMangle(this);
  }
}

/// A list of symbols that share the same identifier.
///
/// These can be functions, templates and aggregates with template parameter lists.
class OverloadSet : Symbol
{
  Symbol[] symbols;

  this(Identifier* name, Node node)
  {
    super(SYM.OverloadSet, name, node);
  }

  void add(Symbol s)
  {
    symbols ~= s;
  }
}
