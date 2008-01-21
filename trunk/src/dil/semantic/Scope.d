/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Scope;

import dil.semantic.Symbol;
import dil.semantic.Symbols;
import dil.lexer.Token;
import dil.lexer.Identifier;
import dil.Information;
import dil.Messages;
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

  /// Insert a symbol into this scope.
  void insert(Symbol sym, Identifier* ident)
  {
    auto sym2 = symbol.lookup(ident);
    if (sym2)
    {
      auto loc = sym2.node.begin.getErrorLocation();
      auto locString = Format("{}({},{})", loc.filePath, loc.lineNum, loc.colNum);
      error(sym.node.begin, MSG.DeclConflictsWithDecl, ident.str, locString);
    }
    else
      symbol.insert(sym, ident);
    // Set the current scope symbol as the parent.
    sym.parent = symbol;
  }

  /// Insert a new variable symbol into this scope.
  void insert(Variable var)
  {
    auto sym = symbol.lookup(var.name);
    if (sym)
    {
      auto loc = sym.node.begin.getErrorLocation();
      auto locString = Format("{}({},{})", loc.filePath, loc.lineNum, loc.colNum);
      error(var.node.begin, MSG.VariableConflictsWithDecl, var.name.str, locString);
    }
    else
      symbol.insert(var, var.name);
    // Set the current scope symbol as the parent.
    var.parent = symbol;
  }

  /++
    Create and enter a new inner scope.
  +/
  Scope enter(ScopeSymbol symbol)
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
  Scope exit()
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
    auto location = token.getErrorLocation();
    infoMan ~= new SemanticError(location, GetMsg(mid));
  }

  void error(Token* token, char[] formatMsg, ...)
  {
    auto location = token.getErrorLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    infoMan ~= new SemanticError(location, msg);
  }
}
