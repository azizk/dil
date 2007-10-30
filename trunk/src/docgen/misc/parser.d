/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.misc.parser;

import dil.Parser;
import dil.Settings;
public import dil.Module;
import tango.text.Regex : RegExp = Regex;
import tango.io.FilePath;
import tango.text.Util;
debug import tango.io.Stdout;

alias void delegate (char[] fqn, char[] path, Module module_) modDg;
alias void delegate (Module imported, Module importer, bool isPublic) importDg;

class Parser {
  private static char[] findModulePath(char[] moduleFQN, char[][] importPaths) {
    char[] modulePath;

    foreach (path; importPaths) {
      modulePath = path ~ (path[$-1] == dirSep ? "" : [dirSep]) ~ moduleFQN ~ ".d";

      // TODO: also check for *.di?

      if ((new FilePath(modulePath)).exists()) {
        debug Stdout("  * File for ")(moduleFQN)(" found: ")(modulePath).newline;
        return modulePath;
      }
    }

    debug Stdout("  * ")(moduleFQN)(" does not exist in imports")().newline()();
    return null;
  }

  /**
   * Imports the transitive closure of imports starting from "filePath",
   * limited by recursionDepth.
   *
   * The search can be filtered by providing a list of regexps that match the
   * FQNs of modules to be ignored.
   *
   * Params:
   *     filePath = Path of the file to parse
   *     importPaths = Directories to look for imports
   *     strRegexps = Filter regexps
   *     IncludeUnlocatableModules = Call the delegate also for unlocatable files
   *     recursionDepth = How many levels of imports to follow (-1 = no limit)
   *     mdg = Delegate that gets called for every module found
   *     idg = Delegate that gets called for every import found
   *     modules = List of parsed modules
   */
  public static void loadModules(char[] filePath, char[][] importPaths, char[][] strRegexps,
                                 bool IncludeUnlocatableModules, int recursionDepth,
                                 modDg mdg, importDg idg, out Module[] modules) {

    loadModules([filePath], importPaths, strRegexps, IncludeUnlocatableModules,
      recursionDepth, mdg, idg, modules);
  }

  /**
   * Imports the transitive closure of imports starting from "filePath",
   * limited by recursionDepth.
   *
   * The search can be filtered by providing a list of regexps that match the
   * FQNs of modules to be ignored.
   *
   * Params:
   *     filePaths = Paths of the files to parse
   *     importPaths = Directories to look for imports
   *     strRegexps = Filter regexps
   *     IncludeUnlocatableModules = Call the delegate also for unlocatable files
   *     recursionDepth = How many levels of imports to follow (-1 = no limit)
   *     mdg = Delegate that gets called for every module found
   *     idg = Delegate that gets called for every import found
   *     modules = List of parsed modules
   */
  public static void loadModules(char[][] filePaths, char[][] importPaths, char[][] strRegexps,
                                 bool IncludeUnlocatableModules, int recursionDepth,
                                 modDg mdg, importDg idg, out Module[] modules) {
    // Initialize regular expressions.
    RegExp[] regexps;
    foreach (strRegexp; strRegexps)
      regexps ~= new RegExp(strRegexp);

    // Add directory of file and global directories to import paths.
    foreach(filePath; filePaths) {
      auto fileDir = (new FilePath(filePath)).folder();
      if (fileDir.length)
        importPaths ~= fileDir;
    }

    importPaths ~= GlobalSettings.importPaths;

    debug foreach(path; importPaths) {
      Stdout("Import path: ")(path).newline;
    }

    Module[char[]] loadedModules;

    Module loadModule(char[] moduleFQNPath, int depth) {
      if (depth == 0) return null;
      
      debug Stdout("Loading ")(moduleFQNPath).newline;

      // Return already loaded module.
      auto mod_ = moduleFQNPath in loadedModules;
      if (mod_ !is null) {
        debug Stdout("  Already loaded.")(moduleFQNPath).newline;
        return *mod_;
      }

      auto FQN = replace(moduleFQNPath.dup, dirSep, '.');
      
      // Ignore module names matching regular expressions.
      foreach (rx; regexps)
        if (rx.test(FQN)) return null;

      auto modulePath = findModulePath(moduleFQNPath, importPaths);
      //foreach(filePath; filePaths)
        //if (moduleFQNPath == filePath) modulePath = filePath;

      debug Stdout("  FQN ")(FQN).newline;
      debug Stdout("  Module path ")(modulePath).newline;

      Module mod = null;

      if (modulePath is null) {
        if (IncludeUnlocatableModules)
          mdg(FQN, moduleFQNPath, null);
      } else {
        mod = new Module(modulePath);
        loadedModules[moduleFQNPath] = mod;
        mod.parse();

        mdg(FQN, moduleFQNPath, mod);

        auto imports = mod.imports;

        // TODO: add public/private attribute to the dg parameters 
        foreach (importList; imports)
          foreach(moduleFQN_; importList.getModuleFQNs(dirSep)) {
            auto loaded_mod = loadModule(moduleFQN_, depth == -1 ? depth : depth-1);

            if (loaded_mod !is null) {
              idg(loaded_mod, mod, importList.isPublic());
            } else if (IncludeUnlocatableModules) {
              auto tmp = new Module(null, true);
              tmp.moduleFQN = replace(moduleFQN_.dup, dirSep, '.');
              idg(tmp, mod, importList.isPublic());
            }
          }
      }

      return mod;
    } // loadModule

    foreach(filePath; filePaths)
      loadModule(filePath, recursionDepth);

    // Finished loading modules.

    // Ordered list of loaded modules.
    modules = loadedModules.values;
  }
}
