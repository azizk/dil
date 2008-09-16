/// Author: Aziz Köksal
/// License: GPL3
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

  /// Look up name in the table.
  Symbol lookup(Identifier* name)
  {
    return symbolTable.lookup(name);
  }

  /// Look up name in the table.
  Symbol lookup(string name)
  {
    auto id = IdTable.lookup(name);
    return id ? symbolTable.lookup(id) : null;
  }

  /// Insert a symbol into the table.
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
  Function[] funcs;
  Variable[] fields;

  this(SYM sid, Identifier* name, Node node)
  {
    super(sid, name, node);
  }

  override void insert(Symbol s, Identifier* ident)
  {
    if (s.isVariable)
      // Append variable to fields.
      fields ~= cast(Variable)cast(void*)s;
    else if (s.isFunction)
      // Append function to funcs.
      funcs ~= cast(Function)cast(void*)s;
    super.insert(s, ident);
  }
}

/// A class symbol.
class Class : Aggregate
{
  this(Identifier* name, Node classNode)
  {
    super(SYM.Class, name, classNode);
    this.type = new TypeClass(this);
  }
}

/// An interface symbol.
class Interface : Aggregate
{
  this(Identifier* name, Node interfaceNode)
  {
    super(SYM.Interface, name, interfaceNode);
    this.type = new TypeClass(this);
  }
}

/// A struct symbol.
class Struct : Aggregate
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
class Union : Aggregate
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
class Enum : ScopeSymbol
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
class Template : ScopeSymbol
{
  this(Identifier* name, Node templateNode)
  {
    super(SYM.Template, name, templateNode);
  }
}

/// A function symbol.
class Function : ScopeSymbol
{
  Protection prot; /// The protection.
  StorageClass stc; /// The storage classes.
  LinkageType linkType; /// The linkage type.

  Type returnType;
  Variable[] params;

  this(Identifier* name, Node functionNode)
  {
    super(SYM.Function, name, functionNode);
  }
}

/// A variable symbol.
class Variable : Symbol
{
  Protection prot; /// The protection.
  StorageClass stc; /// The storage classes.
  LinkageType linkType; /// The linkage type.

  Type type; /// The type of this variable.
  Expression value; /// The value of this variable.

  this(Identifier* name,
       Protection prot, StorageClass stc, LinkageType linkType,
       Node variableNode)
  {
    super(SYM.Variable, name, variableNode);

    this.prot = prot;
    this.stc = stc;
    this.linkType = linkType;
  }
}

/// An enum member symbol.
class EnumMember : Variable
{
  this(Identifier* name,
       Protection prot, StorageClass stc, LinkageType linkType,
       Node enumMemberNode)
  {
    super(name, prot, stc, linkType, enumMemberNode);
    this.sid = SYM.EnumMember;
  }
}

/// An alias symbol.
class Alias : Symbol
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
