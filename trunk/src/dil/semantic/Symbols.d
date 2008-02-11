/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Symbols;

import dil.ast.Expression;
import dil.semantic.Symbol;
import dil.semantic.SymbolTable;
import dil.semantic.Types;
import dil.ast.Node;
import dil.lexer.Identifier;
import dil.Enums;
import common;

/// A symbol that has its own scope with a symbol table.
class ScopeSymbol : Symbol
{
  SymbolTable symbolTable; /// The symbol table.
  Symbol[] members; /// The member symbols (in lexical order.)

  this(SYM sid, Identifier* name, Node node)
  {
    super(sid, name, node);
  }

  /// Look up name in the table.
  Symbol lookup(Identifier* name)
  {
    return symbolTable.lookup(name);
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

class Class : Aggregate
{
  this(Identifier* name, Node classNode)
  {
    super(SYM.Class, name, classNode);
  }
}

class Interface : Aggregate
{
  this(Identifier* name, Node interfaceNode)
  {
    super(SYM.Interface, name, interfaceNode);
  }
}

class Union : Aggregate
{
  this(Identifier* name, Node unionNode)
  {
    super(SYM.Union, name, unionNode);
  }
}

class Struct : Aggregate
{
  this(Identifier* name, Node structNode)
  {
    super(SYM.Struct, name, structNode);
  }
}

class Enum : ScopeSymbol
{
  TypeEnum type;
  this(Identifier* name, Node enumNode)
  {
    super(SYM.Enum, name, enumNode);
  }

  void setType(TypeEnum type)
  {
    this.type = type;
  }
}

class Template : ScopeSymbol
{
  this(Identifier* name, Node templateNode)
  {
    super(SYM.Template, name, templateNode);
  }
}

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

class Alias : Symbol
{
  this(Identifier* name, Node aliasNode)
  {
    super(SYM.Alias, name, aliasNode);
  }
}

/++
  A list of symbols that share the same identifier.
  These can be functions, templates and aggregates with template parameter lists.
+/
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
