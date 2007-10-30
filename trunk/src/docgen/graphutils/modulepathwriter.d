/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.modulepathwriter;
import docgen.graphutils.writer;

import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;

class ModulePathWriter : AbstractGraphWriter {
  this(GraphWriterFactory factory, PageWriter writer) {
    super(factory, writer);
  }

  void generateDepGraph(Vertex[] vertices, Edge[] edges, OutputStream imageFile) {
    char[][] contents;

    void doList(Vertex[] v, uint level) {
      if (!level) return;

      contents ~= "(";

      foreach (vertex; v) {
        contents ~= vertex.location;
        if (vertex.outgoing.length)
          doList(vertex.outgoing, level-1);
      }

      contents ~= ")";
    }

    doList(vertices, factory.options.graph.depth);

    writer.addList(contents, false);
  }
}
