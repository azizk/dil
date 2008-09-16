/// Author: Aziz Köksal
/// License: GPL3
module dil.ModuleManager;

import dil.semantic.Module,
       dil.semantic.Package;
import dil.Location;
import dil.Information;
import dil.Messages;
import common;

import tango.io.FilePath,
       tango.io.FileSystem,
       tango.io.model.IFile;
import tango.util.PathUtil : pathNormalize = normalize;

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
  Module[] loadedModules; /// Loaded modules in sequential order.
  string[] importPaths; /// Where to look for module files.
  InfoManager infoMan;

  /// Constructs a ModuleManager object.
  this(string[] importPaths, InfoManager infoMan)
  {
    this.rootPackage = new Package(null);
    packageTable[""] = this.rootPackage;
    this.importPaths = importPaths;
    this.infoMan = infoMan;
  }

  /// Loads a module given a file path.
  Module loadModuleFile(string moduleFilePath)
  {
    auto absFilePath = FileSystem.toAbsolute(moduleFilePath);
    // FIXME: normalize() doesn't simplify //. Handle the exception it throws.
    absFilePath = pathNormalize(absFilePath); // Remove ./ /. ../ and /..
    if (auto existingModule = absFilePath in absFilePathTable)
      return *existingModule;

    // Create a new module.
    auto newModule = new Module(moduleFilePath, infoMan);
    newModule.parse();

    auto moduleFQNPath = newModule.getFQNPath();
    if (auto existingModule = moduleFQNPath in moduleFQNPathTable)
    { // Error: two module files have the same f.q. module name.
      auto location = newModule.getModuleDeclToken().getErrorLocation();
      auto msg = Format(MSG.ConflictingModuleFiles, newModule.filePath());
      infoMan ~= new SemanticError(location, msg);
      return *existingModule;
    }

    // Insert new module.
    moduleFQNPathTable[moduleFQNPath] = newModule;
    absFilePathTable[absFilePath] = newModule;
    loadedModules ~= newModule;
    // Add the module to its package.
    auto pckg = getPackage(newModule.packageName);
    pckg.add(newModule);

    if (auto p = newModule.getFQN() in packageTable)
    { // Error: module and package share the same name.
      auto location = newModule.getModuleDeclToken().getErrorLocation();
      auto msg = Format(MSG.ConflictingModuleAndPackage, newModule.getFQN());
      infoMan ~= new SemanticError(location, msg);
    }

    return newModule;
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

  /// Loads a module given an FQN path.
  Module loadModule(string moduleFQNPath)
  {
    // Look up in table if the module is already loaded.
    Module* pModul = moduleFQNPath in moduleFQNPathTable;
    if (pModul)
      return *pModul;

    // Locate the module in the file system.
    auto moduleFilePath = findModuleFilePath(moduleFQNPath, importPaths);
    if (!moduleFilePath.length)
      return null;

    // Load the found module file.
    auto modul = loadModuleFile(moduleFilePath);
    if (modul.getFQNPath() != moduleFQNPath)
    { // Error: the requested module is not in the correct package.
      auto location = modul.getModuleDeclToken().getErrorLocation();
      auto msg = Format(MSG.ModuleNotInPackage, getPackageFQN(moduleFQNPath));
      infoMan ~= new SemanticError(location, msg);
    }

    return modul;
  }

  /// Returns e.g. 'dil.ast' for 'dil/ast/Node'.
  string getPackageFQN(string moduleFQNPath)
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
      foreach (moduleSuffix; [".d", ".di"/*interface file*/])
      {
        filePath.suffix(moduleSuffix);
        if (filePath.exists()) // E.g.: src/dil/ast/Node.d
          return filePath.toString();
      }
    }
    return null;
  }
}
