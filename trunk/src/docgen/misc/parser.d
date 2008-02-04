/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.misc.parser;

import dil.parser.Parser;
import dil.parser.ImportParser;
import dil.File;
import dil.Settings;
public import dil.semantic.Module;
import tango.text.Regex : RegExp = Regex;
import tango.io.FilePath;
import tango.io.FileSystem;
import tango.core.Array : remove;
import tango.text.Util;
import docgen.misc.meta;
debug import tango.io.Stdout;

alias void delegate (char[] fqn, char[] path, Module module_) modDg;
alias void delegate (Module imported, Module importer, bool isPublic, bool isStatic) importDg;

class Parser {
  protected:

//  ParserOptions m_options;

    
  static char[] findModuleFilePath(char[] moduleFQNPath, char[][] importPaths) {
    auto filePath = new FilePath();
    foreach (importPath; importPaths) {
      filePath.set(importPath);
      filePath.append(moduleFQNPath);

      foreach (moduleSuffix; [".d", ".di"/*interface file*/])
      {
        filePath.suffix(moduleSuffix);
        debug Stdout("Trying ")(filePath.toString()).newline;
        if (filePath.exists())
          return filePath.toString();
      }
    }

    debug Stdout("  * ")(moduleFQNPath)(" does not exist in imports\n")();
    return null;
  }

  public:

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
  static void loadModules(char[] filePath, char[][] importPaths, char[][] strRegexps,
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
  static void loadModules(char[][] filePaths, char[][] importPaths, char[][] strRegexps,
                          bool IncludeUnlocatableModules, int recursionDepth,
                          modDg mdg, importDg idg, out Module[] modules) {

    // Initialize regular expressions.
    RegExp[] regexps;
    foreach (strRegexp; strRegexps)
      regexps ~= new RegExp(strRegexp);

    importPaths ~= ".";

    // Add directory of file and global directories to import paths.
    foreach(filePath; filePaths) {
      auto fileDir = (new FilePath(filePath)).folder();
      if (fileDir.length)
        importPaths ~= fileDir;
    }

//    importPaths ~= GlobalSettings.importPaths;

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

      auto moduleFilePath = findModuleFilePath(moduleFQNPath, importPaths);

      debug Stdout("  FQN ")(FQN).newline;
      debug Stdout("  Module path ")(moduleFilePath).newline;

      Module mod = null;

      if (moduleFilePath is null) {
        if (IncludeUnlocatableModules)
          mdg(FQN, moduleFQNPath, null);
      } else {
        mod = new Module(moduleFilePath);
        
        // Use lightweight ImportParser.
//        mod.parser = new ImportParser(loadFile(moduleFilePath), moduleFilePath);
        mod.parse();

        debug Stdout("  Parsed FQN ")(mod.getFQN()).newline;

        // autoinclude dirs (similar to Java)
        // running docgen in foo/bar/abc/ also finds foo/xyz/zzz.d if module names are right
        {
          // foo.bar.mod -> [ "foo", "bar" ]
          auto modPackage = split(mod.getFQN, ".")[0..$-1];
          auto modDir = split(FileSystem.toAbsolute(new FilePath(moduleFilePath)).standard().folder(), "/");
          auto modLocation = modDir[0..modDir.remove(".")];

          bool matches = false;
          int i;

          for(i = 1; i <= min(modPackage.length, modLocation.length); i++) {
            matches = true;
            debug Stdout("  Decl: ")(modPackage[$-i]).newline;
            debug Stdout("  Path: ")(modLocation[$-i]).newline;
            if (modPackage[$-i] != modLocation[$-i]) {
              matches = false;
              break;
            }
          }
          if (matches) {
            auto loc = modLocation[0..$-i+1].join("/");
            debug Stdout("  Autoadding import: ")(loc).newline;
            importPaths ~= loc;
          }
        }

        mdg(FQN, moduleFQNPath, mod);
        loadedModules[moduleFQNPath] = mod;

        foreach (importDecl; mod.imports)
          foreach(moduleFQN_; importDecl.getModuleFQNs(dirSep)) {
            auto loaded_mod = loadModule(moduleFQN_, depth == -1 ? depth : depth-1);

            if (loaded_mod !is null) {
              idg(loaded_mod, mod, importDecl.isPublic(), importDecl.isStatic());
            } else if (IncludeUnlocatableModules) {
              auto tmp = new Module(null);
              tmp.setFQN(replace(moduleFQN_.dup, dirSep, '.'));
              idg(tmp, mod, importDecl.isPublic(), importDecl.isStatic());
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
