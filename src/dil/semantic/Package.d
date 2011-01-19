/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.semantic.Package;

import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Module;
import dil.lexer.IdTable;
import common;

/// A package groups modules and other packages.
class Package : PackageSymbol
{
  string pckgName;    /// The name of the package. E.g.: 'dil'.
  Package[] packages; /// The sub-packages contained in this package.
  Module[] modules;   /// The modules contained in this package.

  /// Constructs a Package object.
  this(string pckgName, IdTable idtable)
  {
    auto name = idtable.lookup(pckgName);
    super(name);
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

  /// Returns a list of all modules in this package tree.
  Module[] getModuleList()
  {
    auto list = modules.dup;
    foreach (pckg; packages)
      list ~= pckg.getModuleList();
    return list;
  }
}
