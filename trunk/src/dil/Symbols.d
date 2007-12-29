/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Symbols;

import dil.Symbol;
import dil.SymbolTable;
import dil.SyntaxTree;
import dil.Enums;
import dil.TypeSystem;
import dil.Identifier;
import common;

/// A symbol that has its own scope with a symbol table.
class ScopeSymbol : Symbol
{
  protected SymbolTable symbolTable; /// The symbol table.

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
  }
}

/// Aggregates have function and field members.
class Aggregate : ScopeSymbol
{
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
  this()
  {
    this.sid = SYM.Class;
  }
}

class Interface : Aggregate
{
  this()
  {
    this.sid = SYM.Interface;
  }
}

class Union : Aggregate
{
  this()
  {
    this.sid = SYM.Union;
  }
}

class Struct : Aggregate
{
  Identifier* ident;
  this(Identifier* ident)
  {
    this.sid = SYM.Struct;
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
