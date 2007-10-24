/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.modulepathwriter;
import docgen.graphutils.writer;

import tango.io.FileConduit : FileConduit;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;

class ModulePathWriter : AbstractGraphWriter {
  this(GraphWriterFactory factory, DocumentWriter writer) {
    super(factory, writer);
  }

  void generateGraph(Vertex[] vertices, Edge[] edges, OutputStream imageFile) {

    void doPaths(Vertex[] v, uint level, char[] indent = "") {
      if (!level) return;

      foreach (vertex; v) {
        // TODO: output(indent)(vertex.location).newline;
        if (vertex.outgoing.length)
          doPaths(vertex.outgoing, level-1, indent ~ "  ");
      }
    }

    doPaths(vertices, factory.options.graph.depth);
  }
}