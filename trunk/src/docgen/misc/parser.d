/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.misc.parser;

import docgen.graphutils.writers;

import dil.Parser;
import dil.Module;
import dil.Settings;
import tango.text.Regex : RegExp = Regex;
import tango.io.FilePath;
import tango.io.FileConst;
import tango.text.Util;
import common;
debug import tango.io.Stdout;

class Parser {
  private static string findModulePath(string moduleFQN, string[] importPaths) {
    string modulePath;

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
  public static void loadModules(string filePath, string[] importPaths, string[] strRegexps,
                                 bool IncludeUnlocatableModules, int recursionDepth,
                                 void delegate (string fqn, string path, Module) mdg,
                                 void delegate (Module imported, Module importer) idg,
                                 out Module[] modules) {

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
  public static void loadModules(string[] filePaths, string[] importPaths, string[] strRegexps,
                                 bool IncludeUnlocatableModules, int recursionDepth,
                                 void delegate (string fqn, string path, Module) mdg,
                                 void delegate (Module imported, Module importer) idg,
                                 out Module[] modules) {
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

    Module[string] loadedModules;

    Module loadModule(string moduleFQNPath, int depth) {
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

        auto moduleFQNs = mod.getImports();

        // TODO: add public/private attribute to the dg parameters 
        foreach (moduleFQN_; moduleFQNs) {
          auto loaded_mod = loadModule(moduleFQN_, depth == -1 ? depth : depth-1);

          if (loaded_mod !is null)
            idg(loaded_mod, mod);
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