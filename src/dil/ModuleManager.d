/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.ModuleManager;

import dil.semantic.Module,
       dil.semantic.Package,
       dil.semantic.Symbol;
import dil.Diagnostics;
import dil.Messages;
import common;

import tango.io.FilePath,
       tango.io.model.IFile;
import tango.io.Path : pathNormalize = normalize;
import tango.core.Array : lbound, sort;
import tango.text.Ascii : icompare;
import tango.sys.Environment;

alias FileConst.PathSeparatorChar dirSep;

/// Manages loaded modules in a table.
class ModuleManager
{
  /// The root package. Contains all other modules and packages.
  Package rootPackage;
  /// Maps full package names to packages. E.g.: dil.ast
  Package[string] packageTable;
  /// Maps FQN paths to modules. E.g.: dil/ast/Node
  Module[string] moduleFQNPathTable;
  /// Maps absolute file paths to modules. E.g.: /home/user/dil/src/main.d
  Module[string] absFilePathTable;
  /// Loaded modules in sequential order.
  Module[] loadedModules;
  /// Loaded modules which are ordered according to the number of
  /// import statements in each module (ascending order.)
  Module[] orderedModules;
  /// Where to look for module files.
  string[] importPaths;
  /// Collects error messages.
  Diagnostics diag;

  /// Constructs a ModuleManager object.
  this(string[] importPaths, Diagnostics diag)
  {
    this.rootPackage = new Package(null);
    packageTable[""] = this.rootPackage;
    this.importPaths = importPaths;
    this.diag = diag;
  }

  /// Looks up a module by its file path. E.g.: "src/dil/ModuleManager.d"
  /// Relative paths are made absolute.
  Module moduleByPath(string moduleFilePath)
  {
    auto absFilePath = absolutePath(moduleFilePath);
    if (auto existingModule = absFilePath in absFilePathTable)
      return *existingModule;
    return null;
  }

  /// Looks up a module by its f.q.n. path. E.g.: "dil/ModuleManager"
  Module moduleByFQN(string moduleFQNPath)
  {
    if (auto existingModule = moduleFQNPath in moduleFQNPathTable)
      return *existingModule;
    return null;
  }

  /// Loads a module given a file path.
  Module loadModuleFile(string moduleFilePath)
  {
    if (auto existingModule = moduleByPath(moduleFilePath))
      return existingModule;

    // Create a new module.
    auto newModule = new Module(moduleFilePath, diag);
    newModule.parse();

    addModule(newModule);

    return newModule;
  }

  /// Loads a module given an FQN path. Searches import paths.
  Module loadModule(string moduleFQNPath)
  {
    // Look up in table if the module is already loaded.
    if (auto existingModule = moduleByFQN(moduleFQNPath))
      return existingModule;

    // Locate the module in the file system.
    auto moduleFilePath = findModuleFilePath(moduleFQNPath, importPaths);
    if (!moduleFilePath.length)
      return null; // No module found.

    // Load the module file.
    auto modul = loadModuleFile(moduleFilePath);

    if (getPackageFQN(modul.getFQNPath()) != getPackageFQN(moduleFQNPath))
    { // Error: the requested module is not in the correct package.
      auto location = modul.getModuleDeclToken().getErrorLocation();
      auto msg = Format(MSG.ModuleNotInPackage, getPackageFQN(moduleFQNPath));
      diag ~= new SemanticError(location, msg);
    }

    return modul;
  }

  /// Inserts the given module into the tables.
  void addModule(Module newModule)
  {
    auto absFilePath = absolutePath(newModule.filePath());

    auto moduleFQNPath = newModule.getFQNPath();
    if (auto existingModule = moduleFQNPath in moduleFQNPathTable)
    { // Error: two module files have the same f.q. module name.
      auto location = newModule.getModuleDeclToken().getErrorLocation();
      auto msg = Format(MSG.ConflictingModuleFiles, newModule.filePath());
      diag ~= new SemanticError(location, msg);
      return; // Can't insert new module, so return.
    }

    // Insert into the tables.
    moduleFQNPathTable[moduleFQNPath] = newModule;
    absFilePathTable[absFilePath] = newModule;
    loadedModules ~= newModule;
    newModule.ID = loadedModules.length;
    insertOrdered(newModule);

    // Add the module to its package.
    auto pckg = getPackage(newModule.packageName);
    pckg.add(newModule);

    if (auto p = newModule.getFQN() in packageTable)
    { // Error: module and package share the same name.
      // Happens when: "src/dil/module.d", "src/dil.d"
      // There's a package dil and a module dil.
      auto location = newModule.getModuleDeclToken().getErrorLocation();
      auto msg = Format(MSG.ConflictingModuleAndPackage, newModule.getFQN());
      diag ~= new SemanticError(location, msg);
    }
  }

  /// Compares the number of imports of two modules.
  /// Returns: true if a imports less than b.
  static bool compareImports(Module a, Module b)
  {
    return a.imports.length < b.imports.length;
  }

  /// Insert a module into the ordered list.
  void insertOrdered(Module newModule)
  {
    auto i = orderedModules.lbound(newModule, &compareImports);
    if (i == orderedModules.length)
      orderedModules ~= newModule;
    else
      orderedModules = orderedModules[0..i] ~ newModule ~ orderedModules[i..$];
  }

  /// Returns the package given a f.q. package name.
  /// Returns the root package for an empty string.
  Package getPackage(string pckgFQN)
  {
    auto pPckg = pckgFQN in packageTable;
    if (pPckg)
      return *pPckg;

    string prevFQN, lastPckgName;
    // E.g.: pckgFQN = 'dil.ast', prevFQN = 'dil', lastPckgName = 'ast'
    splitPackageFQN(pckgFQN, prevFQN, lastPckgName);
    // Recursively build package hierarchy.
    auto parentPckg = getPackage(prevFQN); // E.g.: 'dil'

    // Create a new package.
    auto pckg = new Package(lastPckgName); // E.g.: 'ast'
    parentPckg.add(pckg); // 'dil'.add('ast')

    // Insert the package into the table.
    packageTable[pckgFQN] = pckg;

    return pckg;
  }

  /// Splits e.g. 'dil.ast.xyz' into 'dil.ast' and 'xyz'.
  /// Params:
  ///   pckgFQN = the full package name to be split.
  ///   prevFQN = set to 'dil.ast' in the example.
  ///   lastName = the last package name; set to 'xyz' in the example.
  void splitPackageFQN(string pckgFQN, ref string prevFQN, ref string lastName)
  {
    uint lastDotIndex;
    foreach_reverse (i, c; pckgFQN)
      if (c == '.')
      { lastDotIndex = i; break; } // Found last dot.
    if (lastDotIndex == 0)
      lastName = pckgFQN; // Special case - no dot found.
    else
    {
      prevFQN = pckgFQN[0..lastDotIndex];
      lastName = pckgFQN[lastDotIndex+1..$];
    }
  }

  /// Returns e.g. 'dil.ast' for 'dil/ast/Node'.
  static string getPackageFQN(string moduleFQNPath)
  {
    string pckg = moduleFQNPath.dup;
    uint lastDirSep;
    foreach (i, c; pckg)
      if (c == dirSep)
        (pckg[i] = '.'), (lastDirSep = i);
    return pckg[0..lastDirSep];
  }

  /// Searches for a module in the file system looking in importPaths.
  /// Returns: the file path to the module, or null if it wasn't found.
  static string findModuleFilePath(string moduleFQNPath, string[] importPaths)
  {
    auto filePath = new FilePath();
    foreach (importPath; importPaths)
    {
      filePath.set(importPath); // E.g.: src/
      filePath.append(moduleFQNPath); // E.g.: dil/ast/Node
      filePath.suffix(".d"); // E.g.: src/dil/ast/Node.d
      if (!filePath.exists())
      {
        filePath.suffix(".di"); // E.g.: src/dil/ast/Node.di
        if (!filePath.exists())
          continue;
      }
      return filePath.toString();
    }
    return null;
  }

  /// A predicate for sorting symbols in ascending order.
  /// Compares symbol names ignoring case.
  static bool compareSymbolNames(Symbol a, Symbol b)
  {
    return icompare(a.name.str, b.name.str) < 0;
  }

  /// Sorts the the subpackages and submodules of pckg.
  void sortPackageTree(Package pckg)
  {
    pckg.packages.sort(&compareSymbolNames);
    pckg.modules.sort(&compareSymbolNames);
    foreach (subpckg; pckg.packages)
      sortPackageTree(subpckg);
  }

  /// Calls sortPackageTree() with this.rootPackage.
  void sortPackageTree()
  {
    sortPackageTree(rootPackage);
  }

  /// Returns a normalized, absolute path.
  static string absolutePath(string path)
  {
    path = Environment.toAbsolute(path);
    return pathNormalize(path); // Remove './' and '../' parts.
  }
}
