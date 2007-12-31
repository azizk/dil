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
    {
      auto loc = sym.node.begin.getLocation();
      auto locString = Format("{}({},{})", loc.filePath, loc.lineNum, loc.colNum);
      error(var.node.begin, MSG.VariableConflictsWithDecl, var.ident.str, locString);
    }
    else
      symbol.insert(var, var.ident);
    // Set the current scope symbol as the parent.
    var.parent = symbol;
  }

  /++
    Create a new inner scope.
  +/
  Scope push(ScopeSymbol symbol)
  {
    auto sc = new Scope();
    sc.parent = this;
    sc.infoMan = this.infoMan;
    sc.symbol = symbol;
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

  bool isInterface()
  {
    return symbol.isInterface;
  }

  /// Search for the enclosing Class scope.
  Scope classScope()
  {
    auto scop = this;
    while (scop)
    {
      if (scop.symbol.isClass)
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
      if (scop.symbol.isModule)
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

  void error(Token* token, char[] formatMsg, ...)
  {
    auto location = token.getLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    infoMan ~= new SemanticError(location, msg);
  }
}
