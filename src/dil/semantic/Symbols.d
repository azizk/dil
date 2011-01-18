/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.semantic.Symbols;

import dil.ast.Node,
       dil.ast.Expression;
import dil.semantic.Symbol,
       dil.semantic.SymbolTable,
       dil.semantic.Types;
import dil.lexer.IdTable;
import dil.Enums;
import common;

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
}

/// A class symbol.
class ClassSymbol : Aggregate
{
  this(Identifier* name, Node classNode)
  {
    super(SYM.Class, name, classNode);
    this.type = new TypeClass(this);
  }
}

/// An interface symbol.
class InterfaceSymbol : Aggregate
{
  this(Identifier* name, Node interfaceNode)
  {
    super(SYM.Interface, name, interfaceNode);
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
class UnionSymbol : Aggregate
{
  bool isAnonymous;
  this(Identifier* name, Node unionNode)
  {
    super(SYM.Union, name, unionNode);
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

/// A template symbol.
class TemplateSymbol : ScopeSymbol
{
  this(Identifier* name, Node templateNode)
  {
    super(SYM.Template, name, templateNode);
  }
}

/// A function symbol.
class FunctionSymbol : ScopeSymbol
{
  Protection prot; /// The protection.
  StorageClass stcs; /// The storage classes.
  LinkageType linkage; /// The linkage type.

  Type returnType;
  VariableSymbol[] params;

  this(Identifier* name, Node functionNode)
  {
    super(SYM.Function, name, functionNode);
  }
}

/// The parameter symbol.
class ParameterSymbol : Symbol
{
  StorageClass stcs; /// Storage classes.
  VariadicStyle variadic; /// Variadic style.
  Type type; /// The parameter's type.
  Expression defValue; /// The default initialization value.

  this(Identifier* name, StorageClass stcs, Node node)
  {
    super(SYM.Parameter, name, node);
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

  char[] toMangle()
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

  char[] toMangle()
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

/// An alias symbol.
class AliasSymbol : Symbol
{
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
