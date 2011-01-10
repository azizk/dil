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
    if (s.isVariable)
      // Append variable to fields.
      fields ~= cast(VariableSymbol)cast(void*)s;
    else if (s.isFunction)
      // Append function to funcs.
      funcs ~= cast(FunctionSymbol)cast(void*)s;
    super.insert(s, ident);
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
  LinkageType linkType; /// The linkage type.

  Type returnType;
  VariableSymbol[] params;

  this(Identifier* name, Node functionNode)
  {
    super(SYM.Function, name, functionNode);
  }
}

/// A variable symbol.
class VariableSymbol : Symbol
{
  Protection prot; /// The protection.
  StorageClass stcs; /// The storage classes.
  LinkageType linkType; /// The linkage type.

  Type type; /// The type of this variable.
  Expression value; /// The value of this variable.

  this(Identifier* name,
       Protection prot, StorageClass stcs, LinkageType linkType,
       Node variableNode)
  {
    super(SYM.Variable, name, variableNode);

    this.prot = prot;
    this.stcs = stcs;
    this.linkType = linkType;
  }
}

/// An enum member symbol.
class EnumMember : VariableSymbol
{
  this(Identifier* name,
       Protection prot, StorageClass stcs, LinkageType linkType,
       Node enumMemberNode)
  {
    super(name, prot, stcs, linkType, enumMemberNode);
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
