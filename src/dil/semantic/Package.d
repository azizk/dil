/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Package;

import dil.semantic.Symbol;
import dil.semantic.Symbols;
import dil.semantic.Module;
import dil.lexer.IdTable;
import common;

/// A package groups modules and other packages.
class Package : ScopeSymbol
{
  string pckgName;    /// The name of the package. E.g.: 'dil'.
  Package[] packages; /// The sub-packages contained in this package.
  Module[] modules;   /// The modules contained in this package.

  /// Constructs a Package object.
  this(string pckgName)
  {
    auto ident = IdTable.lookup(pckgName);
    super(SYM.Package, ident, null);
    this.pckgName = pckgName;
  }

  /// Returns true if this is the root package.
  bool isRoot()
  {
    return parent is null;
  }

  /// Returns the parent package or null if this is the root.
  Package parentPackage()
  {
    if (isRoot())
      return null;
    assert(parent.isPackage);
    return parent.to!(Package);
  }

  /// Adds a module to this package.
  void add(Module modul)
  {
    modul.parent = this;
    modules ~= modul;
    insert(modul, modul.name);
  }

  /// Adds a package to this package.
  void add(Package pckg)
  {
    pckg.parent = this;
    packages ~= pckg;
    insert(pckg, pckg.name);
  }
}
