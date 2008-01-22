/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Scope;

import dil.semantic.Symbol;
import dil.semantic.Symbols;
import dil.lexer.Identifier;
import common;

class Scope
{
  Scope parent; /// The surrounding scope, or null if this is the root scope.

  ScopeSymbol symbol; /// The current symbol with the symbol table.

  this(Scope parent, ScopeSymbol symbol)
  {
    this.parent = parent;
    this.symbol = symbol;
  }

  /++
    Find a symbol in this scope.
    Params:
      name = the name of the symbol.
  +/
  Symbol lookup(Identifier* name)
  {
    return symbol.lookup(name);
  }

  /++
    Create a new inner scope and return that.
  +/
  Scope enter(ScopeSymbol symbol)
  {
    return new Scope(this, symbol);
  }

  /++
    Destroy this scope and return the outer scope.
  +/
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
