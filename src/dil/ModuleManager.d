/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.ModuleManager;

import dil.semantic.Module,
       dil.semantic.Package,
       dil.semantic.Symbol;
import dil.lexer.Funcs : hashOf;
import dil.Compilation;
import dil.Diagnostics;
import dil.Messages;
import util.Path;
import common;

import tango.io.model.IFile;
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
  Package[hash_t] packageTable;
  /// Maps FQN paths to modules. E.g.: dil/ast/Node
  Module[hash_t] moduleFQNPathTable;
  /// Maps absolute file paths to modules. E.g.: /home/user/dil/src/main.d
  Module[hash_t] absFilePathTable;
  /// Loaded modules in sequential order.
  Module[] loadedModules;
  /// Loaded modules which are ordered according to the number of
  /// import statements in each module (ascending order.)
  Module[] orderedModules;
  /// Collects error messages.
  Diagnostics diag;
  /// Provides tables and compiler variables.
  CompilationContext cc;

  /// Constructs a ModuleManager object.
  this(CompilationContext cc)
  {
    this.rootPackage = new Package(null, cc.tables.idents);
    packageTable[0] = this.rootPackage;
    assert(hashOf("") == 0);
    this.cc = cc;
  }

  /// Looks up a module by its file path. E.g.: "src/dil/ModuleManager.d"
  /// Relative paths are made absolute.
  Module moduleByPath(string moduleFilePath)
  {
    auto absFilePath = absolutePath(moduleFilePath);
    if (auto existingModule = hashOf(absFilePath) in absFilePathTable)
      return *existingModule;
    return null;
  }

  /// Looks up a module by its f.q.n. path. E.g.: "dil/ModuleManager"
  Module moduleByFQN(string moduleFQNPath)
  {
    if (auto existingModule = hashOf(moduleFQNPath) in moduleFQNPathTable)
      return *existingModule;
    return null;
  }

  /// Loads and parses a module given a file path.
  /// Returns: A new Module instance or an existing one from the table.
  Module loadModuleFile(string moduleFilePath)
  {
    if (auto existingModule = moduleByPath(moduleFilePath))
      return existingModule;

    // Create a new module.
    auto newModule = new Module(moduleFilePath, cc, cc.diag);
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
    auto moduleFilePath = findModuleFile(moduleFQNPath);
    if (!moduleFilePath.length)
      return null; // No module found.

    // Load the module file.
    auto modul = loadModuleFile(moduleFilePath);

    if (getPackageFQN(modul.getFQNPath()) != getPackageFQN(moduleFQNPath))
    { // Error: the requested module is not in the correct package.
      auto location = getErrorLocation(modul);
      auto msg = Format(MSG.ModuleNotInPackage, getPackageFQN(moduleFQNPath));
      cc.diag ~= new SemanticError(location, msg);
    }

    return modul;
  }

  /// Returns the error location of the module's module declaration
  /// or the first token in the source text.
  Location getErrorLocation(Module m)
  {
    return m.getModuleDeclToken().getErrorLocation(m.filePath);
  }

  /// Inserts the given module into the tables.
  void addModule(Module newModule)
  {
    auto absFilePath = absolutePath(newModule.filePath());

    auto moduleFQNPath = newModule.getFQNPath();
    auto hash = hashOf(moduleFQNPath);
    if (auto existingModule = hash in moduleFQNPathTable)
    { // Error: two module files have the same f.q. module name.
      auto location = getErrorLocation(newModule);
      auto msg = Format(MSG.ConflictingModuleFiles, newModule.filePath());
      cc.diag ~= new SemanticError(location, msg);
      return; // Can't insert new module, so return.
    }

    // Insert into the tables.
    moduleFQNPathTable[hash] = newModule;
    absFilePathTable[hashOf(absFilePath)] = newModule;
    loadedModules ~= newModule;
    newModule.ID = loadedModules.length;
    insertOrdered(newModule);

    // Add the module to its package.
    auto pckg = getPackage(newModule.packageName);
    pckg.add(newModule);

    if (auto p = hashOf(newModule.getFQN()) in packageTable)
    { // Error: module and package share the same name.
      // Happens when: "src/dil/module.d", "src/dil.d"
      // There's a package dil and a module dil.
      auto location = getErrorLocation(newModule);
      auto msg = Format(MSG.ConflictingModuleAndPackage, newModule.getFQN());
      cc.diag ~= new SemanticError(location, msg);
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
    auto hash = hashOf(pckgFQN);
    if (auto pPckg = hash in packageTable)
      return *pPckg;

    string prevFQN, lastPckgName;
    // E.g.: pckgFQN = 'dil.ast', prevFQN = 'dil', lastPckgName = 'ast'
    splitPackageFQN(pckgFQN, prevFQN, lastPckgName);
    // Recursively build package hierarchy.
    auto parentPckg = getPackage(prevFQN); // E.g.: 'dil'

    // Create a new package.
    auto pckg = new Package(lastPckgName, cc.tables.idents); // E.g.: 'ast'
    parentPckg.add(pckg); // 'dil'.add('ast')

    // Insert the package into the table.
    packageTable[hash] = pckg;

    return pckg;
  }

  /// Splits e.g. 'dil.ast.xyz' into 'dil.ast' and 'xyz'.
  /// Params:
  ///   pckgFQN = The full package name to be split.
  ///   prevFQN = Set to 'dil.ast' in the example.
  ///   lastName = The last package name; set to 'xyz' in the example.
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
  /// Returns: The file path to the module, or null if it wasn't found.
  static string findModuleFile(string moduleFQNPath, string[] importPaths)
  {
    auto filePath = Path();
    foreach (importPath; importPaths)
    {
      filePath.set(importPath); // E.g.: src/
      filePath /= moduleFQNPath; // E.g.: dil/ast/Node
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

  /// ditto
  string findModuleFile(string moduleFQNPath)
  {
    return findModuleFile(moduleFQNPath, cc.importPaths);
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
