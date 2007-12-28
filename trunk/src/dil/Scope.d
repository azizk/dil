/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Scope;

import dil.Symbol;
import dil.Symbols;
import dil.Information;
import dil.Messages;
import dil.Token;
import common;

class Scope
{
  Scope parent; /// The surrounding scope.
  InfoManager infoMan; /// Collects errors reported during the semantic phase.

  ScopeSymbol symbol; /// The current symbol with the symbol table.

  this()
  {
  }

  /++
    Find an identifier in this scope.
  +/
  Symbol find(char[] ident)
  {
    return null;
  }

  /++
    Add a symbol to this scope.
  +/
  void add(Symbol sym)
  {

  }

  /// Insert a new variable symbol into this scope.
  void insert(Variable var)
  {
    auto sym = symbol.lookup(var.ident);
    if (sym)
      error("variable '"~var.ident.str~"' conflicts with another definition in its scope");
    else
      symbol.insert(var, var.ident);
  }

  /++
    Create a new inner scope.
  +/
  Scope push()
  {
    auto sc = new Scope();
    sc.parent = this;
    return sc;
  }

  /++
    Destroy this scope and return the outer scope.
  +/
  Scope pop()
  {
    auto sc = parent;
    // delete this;
    return sc;
  }

  /// Search for the enclosing Class scope.
  Scope classScope()
  {
    auto scop = this;
    while (scop)
    {
      if (scop.symbol.sid == SYM.Class)
        return scop;
      scop = scop.parent;
    }
    return null;
  }

  /// Search for the enclosing Module scope.
  Scope moduleScope()
  {
    auto scop = this;
    while (scop)
    {
      if (scop.symbol.sid == SYM.Module)
        return scop;
      scop = scop.parent;
    }
    return null;
  }

  void error(Token* token, MID mid)
  {
    auto location = token.getLocation();
    infoMan ~= new SemanticError(location, GetMsg(mid));
  }

  void error(char[] msg)
  {
    auto location = new Location("", 0);
    infoMan ~= new SemanticError(location, msg);
  }
}
