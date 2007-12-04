/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Scope;
import dil.Symbol;
import dil.Information;
import common;

class Scope
{
  Scope parent; /// The surrounding scope.
  InformationManager infoMan; /// Collects errors reported during the semantic phase.

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

  import dil.Information;
  import dil.Messages;
  import dil.Token;
  void error(Token* token, MID mid)
  {
    auto location = token.getLocation();
    auto msg = GetMsg(mid);
    auto error = new Information(InfoType.Semantic, mid, location, msg);
//     infoMan.add(error);
  }
}
