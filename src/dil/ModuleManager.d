/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ModuleManager;

import dil.semantic.Module;
import dil.Location;
import dil.Information;
import dil.Messages;
import common;

import tango.io.FilePath;
import tango.io.FileSystem;
import tango.io.FileConst;

alias FileConst.PathSeparatorChar dirSep;

/// Manages loaded modules in a table.
class ModuleManager
{
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
    this.importPaths = importPaths;
    this.infoMan = infoMan;
  }

  /// Loads a module given a file path.
  Module loadModuleFile(string moduleFilePath)
  {
    auto absFilePath = FileSystem.toAbsolute(moduleFilePath);
    if (auto existingModule = absFilePath in absFilePathTable)
      return *existingModule;

    // Create a new module.
    auto newModule = new Module(moduleFilePath, infoMan);
    newModule.parse();

    auto moduleFQNPath = newModule.getFQNPath();
    if (auto existingModule = moduleFQNPath in moduleFQNPathTable)
    { // Error: two module files have the same f.q. module name.
      auto location = newModule.moduleDecl.begin.getErrorLocation();
      auto msg = Format(MSG.ConflictingModuleFiles, newModule.filePath());
      infoMan ~= new SemanticError(location, msg);
      return *existingModule;
    }
    // Insert new module.
    moduleFQNPathTable[moduleFQNPath] = newModule;
    absFilePathTable[absFilePath] = newModule;
    loadedModules ~= newModule;
    return newModule;
  }

  /// Loads a module given an FQN path.
  Module loadModule(string moduleFQNPath)
  {
    // Look up in table if the module is already loaded.
    Module* pmodul = moduleFQNPath in moduleFQNPathTable;
    if (pmodul)
      return *pmodul;
    // Locate the module in the file system.
    auto moduleFilePath = findModuleFilePath(moduleFQNPath, importPaths);
    if (moduleFilePath.length)
    { // Load the found module file.
      auto modul = loadModuleFile(moduleFilePath);
      if (modul.getFQNPath() != moduleFQNPath)
      { // Error: the requested module is not in the correct package.
        auto location = modul.moduleDecl.begin.getErrorLocation();
        auto msg = Format(MSG.ModuleNotInPackage, getPackage(moduleFQNPath));
        infoMan ~= new SemanticError(location, msg);
      }
      return modul;
    }
    return null;
  }

  /// Returns e.g. 'dil.ast' for 'dil/ast/Node'.
  string getPackage(string moduleFQNPath)
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
