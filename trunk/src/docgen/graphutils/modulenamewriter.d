/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.modulenamewriter;
import docgen.graphutils.writer;

import tango.io.FileConduit : FileConduit;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;

class ModuleNameWriter : AbstractGraphWriter {
  this(GraphWriterFactory factory, DocumentWriter writer) {
    super(factory, writer);
  }

  void generateGraph(Vertex[] vertices, Edge[] edges, OutputStream imageFile) {

    void doList(Vertex[] v, uint level, char[] indent = "") {
      if (!level) return;

      foreach (vertex; v) {
        // TODO: output(indent)(vertex.name).newline;
        if (vertex.outgoing.length)
          doList(vertex.outgoing, level-1, indent ~ "  ");
      }
    }

    doList(vertices, factory.options.graph.depth);
  }
}