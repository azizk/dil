/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.modulegraph.writer;

import docgen.graphutils.writers;

import dil.Parser;
import dil.Module;
import dil.Settings;
import tango.text.Regex : RegExp = Regex;
import tango.io.FilePath;
import tango.io.FileConst;
import tango.text.Util;
import common;

alias FileConst.PathSeparatorChar dirSep;

class ModuleGraphGenerator {
  private static string findModulePath(string moduleFQN, string[] importPaths) {
    string modulePath;

    foreach (path; importPaths) {
      modulePath = path ~ (path[$-1] == dirSep ? "" : [dirSep])
                        ~ moduleFQN ~ ".d";

      // TODO: also check for *.di?
      if ((new FilePath(modulePath)).exists())
        return modulePath;
    }

    return null;
  }

  /**
   * Imports the transitive closure of imports starting from "filePath".
   *
   * The search can be filtered by providing a list of regexps that match the
   * FQNs of modules to be ignored.
   *
   * TODO: integrate better with the docgen stuff - there's no need to
   * scan&parse several times
   */
  public static void loadModules(string filePath, string[] importPaths,
                                 string[] strRegexps,
                                 bool IncludeUnlocatableModules,
                                 out Vertex[] vertices, out Edge[] edges,
                                 out Module[] modules) {
    // Init regular expressions.
    RegExp[] regexps;
    foreach (strRegexp; strRegexps)
      regexps ~= new RegExp(strRegexp);

    // Add directory of file and global directories to import paths.
    auto fileDir = (new FilePath(filePath)).folder();
    if (fileDir.length)
      importPaths ~= fileDir;
    importPaths ~= GlobalSettings.importPaths;

    Vertex[string] loadedModules;
    Edge[] _edges;
    Module[] _modules;

    int modCounter = 0;

    void addModule(Vertex mod) {
      assert(!(mod.location in loadedModules));

      mod.id = modCounter++;
      loadedModules[mod.location] = mod;
    }

    Vertex loadModule(string moduleFQNPath) {
      // Return already loaded module.
      auto mod_ = moduleFQNPath in loadedModules;
      if (mod_ !is null) return *mod_;

      // Ignore module names matching regular expressions.
      foreach (rx; regexps)
      if (rx.test(replace(moduleFQNPath, dirSep, '.')))
        return null;

      auto modulePath = findModulePath(moduleFQNPath, importPaths);
      if (moduleFQNPath == filePath) modulePath = filePath;
      auto FQN = replace(moduleFQNPath, dirSep, '.');

      Vertex mod;

      if (modulePath is null) {
        if (IncludeUnlocatableModules) {
          mod = new Vertex(FQN, moduleFQNPath);
          addModule(mod);
        }
      } else {
        mod = new Vertex(FQN, moduleFQNPath);
        addModule(mod);

        auto m = new Module(modulePath);
        _modules ~= m;
        m.parse();

        auto moduleFQNs = m.getImports();

        foreach (moduleFQN_; moduleFQNs) {
          auto loaded_mod = loadModule(moduleFQN_);

          if (loaded_mod !is null)
            loaded_mod.addChild(mod);
        }
      }

      return mod;
    } // loadModule

    loadModule(filePath);

    // Finished loading modules.

    // Ordered list of loaded modules.
    vertices = loadedModules.values;
    edges = _edges;
    modules = _modules;
  }

  /**
   * TODO
   */
  static void generateGraph(GraphWriterOptions *options) {
    auto gwf = new DefaultGraphWriterFactory(*options);

    auto writer = gwf.createGraphWriter([Stdout.stream]);

    Edge[] edges;
    Vertex[] vertices;

    loadModules(null, null, null,
      gwf.options.IncludeUnlocatableModules,
      vertices, edges);

    writer(vertices, edges);
  }
}
