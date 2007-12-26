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
  SymbolTable symbolTable; /// The symbol table.

  this()
  {
    symbolTable = new SymbolTable;
  }
}

/// Aggregates have function and field members.
class Aggregate : ScopeSymbol
{
  Function[] funcs;
  Variable[] fields;
}

class Class : Aggregate
{
  this()
  {
    this.sid = SYM.Class;
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
  this()
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
  Node varDecl; /// The VariableDeclaration or Parameter node - for source code location.

  this(StorageClass stc, LinkageType linkType,
       Type type, Identifier* ident, Node varDecl)
  {
    this.sid = SYM.Variable;

    this.stc = stc;
    this.linkType = linkType;
    this.type = type;
    this.ident = ident;
    this.varDecl = varDecl;
  }
}
