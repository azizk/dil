/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.semantic.Scope;

import dil.semantic.Symbol,
       dil.semantic.Symbols;
import dil.lexer.Identifier;
import common;

/// Builds a hierarchy of environments.
class Scope
{
  Scope parent; /// The surrounding scope, or null if this is the root scope.

  ScopeSymbol symbol; /// The current symbol with the symbol table.

  this(Scope parent, ScopeSymbol symbol)
  {
    this.parent = parent;
    this.symbol = symbol;
  }

  /// Find a symbol in this scope.
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

  /// Create a new inner scope and return that.
  Scope enter(ScopeSymbol symbol)
  {
    return new Scope(this, symbol);
  }

  /// Destroy this scope and return the outer scope.
  Scope exit()
  {
    auto sc = parent;
    // delete this;
    return sc;
  }

  /// Search for the enclosing Class scope.
  Scope classScope()
  {
    auto scop = this;
    do
    {
      if (scop.symbol.isClass)
        return scop;
      scop = scop.parent;
    } while (scop)
    return null;
  }

  /// Search for the enclosing Module scope.
  Scope moduleScope()
  {
    auto scop = this;
    do
    {
      if (scop.symbol.isModule)
        return scop;
      scop = scop.parent;
    } while (scop)
    return null;
  }
}
