/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Symbols;

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

  this()
  {
  }

  /// Look up ident in the table.
  Symbol lookup(Identifier* ident)
  {
    return symbolTable.lookup(ident);
  }

  /// Insert a symbol into the table.
  void insert(Symbol s, Identifier* ident)
  {
    symbolTable.insert(s, ident);
    members ~= s;
  }
}

/// Aggregates have function and field members.
class Aggregate : ScopeSymbol
{
  Identifier* ident; /// The name of this aggregate.
  Function[] funcs;
  Variable[] fields;

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
  this(Identifier* ident, Node classNode)
  {
    this.sid = SYM.Class;
    this.ident = ident;
    this.node = classNode;
  }
}

class Interface : Aggregate
{
  this(Identifier* ident, Node interfaceNode)
  {
    this.sid = SYM.Interface;
    this.ident = ident;
    this.node = interfaceNode;
  }
}

class Union : Aggregate
{
  this(Identifier* ident, Node unionNode)
  {
    this.sid = SYM.Union;
    this.ident = ident;
    this.node = unionNode;
  }
}

class Struct : Aggregate
{
  this(Identifier* ident, Node structNode)
  {
    this.sid = SYM.Struct;
    this.ident = ident;
    this.node = structNode;
  }
}

class Enum : ScopeSymbol
{
  Identifier* ident;
  this(Identifier* ident, Node enumNode)
  {
    this.sid = SYM.Enum;
    this.ident = ident;
    this.node = enumNode;
  }
}

class Function : ScopeSymbol
{
  StorageClass stc;
  LinkageType linkType;

  Type returnType;
  Identifier* ident;
  Variable[] params;

  this()
  {
    this.sid = SYM.Function;
  }
}

class Variable : Symbol
{
  StorageClass stc;
  LinkageType linkType;

  Type type;
  Identifier* ident;

  this(StorageClass stc, LinkageType linkType,
       Type type, Identifier* ident, Node varDecl)
  {
    this.sid = SYM.Variable;

    this.stc = stc;
    this.linkType = linkType;
    this.type = type;
    this.ident = ident;
    this.node = varDecl;
  }
}
