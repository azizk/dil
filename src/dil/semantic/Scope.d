/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.semantic.Scope;

import dil.semantic.Symbol,
       dil.semantic.Symbols;
import dil.lexer.Identifier;
import common;

/// Models a hierarchy of environments.
class Scope
{
  Scope parent; /// The surrounding scope, or null if this is the root scope.

  ScopeSymbol symbol; /// The current symbol with the symbol table.

  /// Constructs a Scope.
  this(Scope parent, ScopeSymbol symbol)
  {
    this.parent = parent;
    this.symbol = symbol;
  }

  /// Finds a symbol in this scope.
  /// Params:
  ///   name = The name of the symbol.
  Symbol lookup(Identifier* name)
  {
    return symbol.lookup(name);
  }

  /// Searches for a symbol in this scope and all enclosing scopes.
  /// Params:
  ///   name = The name of the symbol.
  Symbol search(Identifier* name)
  {
    Symbol symbol;
    for (auto sc = this; sc; sc = sc.parent)
    {
      symbol = sc.lookup(name);
      if (symbol !is null)
        break;
    }
    return symbol;
  }

  /// Searches for a symbol in this scope and all enclosing scopes.
  /// Params:
  ///   name = The name of the symbol.
  ///   ignoreSymbol = The symbol that must be skipped.
  Symbol search(Identifier* name, Symbol ignoreSymbol)
  {
    Symbol symbol;
    for (auto sc = this; sc; sc = sc.parent)
    {
      symbol = sc.lookup(name);
      if (symbol !is null && symbol !is ignoreSymbol)
        break;
    }
    return symbol;
  }

  /// Creates a new inner scope and returns that.
  Scope enter(ScopeSymbol symbol)
  {
    return new Scope(this, symbol);
  }

  /// Destroys this scope and returns the outer scope.
  Scope exit()
  {
    auto sc = parent;
    parent = null;
    symbol = null;
    return sc;
  }

  /// Searches for a scope matching type sid.
  Scope findScope(SYM sid)
  {
    auto s = this;
    do
      if (s.symbol.sid == sid)
        break;
    while ((s = s.parent) !is null);
    return s;
  }

  /// Searches for the enclosing Class scope.
  Scope classScope()
  {
    return findScope(SYM.Class);
  }

  /// Searches for the enclosing Module scope.
  Scope moduleScope()
  {
    return findScope(SYM.Module);
  }
}
