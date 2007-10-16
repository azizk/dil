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

  /**
   * TODO
   */
  static void generateGraph(GraphOptions *options) {
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
