/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ModuleManager;

import dil.semantic.Module;
import dil.Information;
import common;

import tango.io.FilePath;

/// Manages loaded modules in a table.
class ModuleManager
{
  /// Maps FQN paths to modules. E.g.: dil/ast/Node
  Module[string] modulesTable;
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
    auto modul = new Module(moduleFilePath, infoMan);
    modul.parse();
    auto moduleFQNPath = modul.getFQNPath();
    // Return the module if it's in the table already.
    // This can happen if the module file path has been defined
    // more than once on the command line.
    if (auto existingModule = moduleFQNPath in modulesTable)
    {
      // TODO: avoid parsing the module in the first place, by
      //       using another table mapping absolute file paths
      //       to modules.
      delete modul;
      return *existingModule;
    }
    // Insert new module.
    modulesTable[moduleFQNPath] = modul;
    loadedModules ~= modul;
    return modul;
  }

  /// Loads a module given an FQN path.
  Module loadModule(string moduleFQNPath)
  {
    // Look up in table if the module is already loaded.
    Module* pmodul = moduleFQNPath in modulesTable;
    if (pmodul)
      return *pmodul;
    // Locate the module in the file system.
    auto moduleFilePath = findModuleFilePath(moduleFQNPath,
                                             importPaths);
    if (moduleFilePath.length)
      return loadModuleFile(moduleFilePath);
    return null;
  }

  /// Searches for a module in the file system looking in importPaths.
  /// Returns: the file path to the module, or null if it wasn't found.
  static string findModuleFilePath(string moduleFQNPath, string[] importPaths)
  {
    auto filePath = new FilePath();
    foreach (importPath; importPaths)
    {
      filePath.set(importPath);
      filePath.append(moduleFQNPath);
      foreach (moduleSuffix; [".d", ".di"/*interface file*/])
      {
        filePath.suffix(moduleSuffix);
        if (filePath.exists())
          return filePath.toString();
      }
    }
    return null;
  }
}
