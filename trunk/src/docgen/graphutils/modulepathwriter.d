/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.modulepathwriter;
import docgen.graphutils.writer;

import tango.io.FileConduit : FileConduit;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;

/**
 * TODO: add support for html/xml/latex?
 */
class ModulePathWriter : AbstractGraphWriter {
  this(GraphWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
    assert(outputs.length == 1, "Wrong number of outputs");
  }

  void generateGraph(Vertex[] vertices, Edge[] edges) {
    auto output = new Print!(char)(new Layout!(char), outputs[0]);

    void doPaths(Vertex[] v, uint level, char[] indent = "") {
      if (!level) return;

      foreach (vertex; v) {
        output(indent)(vertex.location).newline;
        if (vertex.outgoing.length)
          doPaths(vertex.outgoing, level-1, indent ~ "  ");
      }
    }

    doPaths(vertices, factory.options.depth);
  }
}