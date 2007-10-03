/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Scope;
import dil.Symbol;
import common;

class Scope
{
  Scope parent; /// The surrounding scope.

  this()
  {
  }

  /++
    Find an identifier in this scope.
  +/
  Symbol find(char[] ident)
  {

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
}
