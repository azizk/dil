/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.modulenamewriter;
import docgen.graphutils.writer;

import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;

class ModuleNameWriter : AbstractGraphWriter {
  public:

  this(GraphWriterFactory factory, PageWriter writer) {
    super(factory, writer);
  }

  void generateDepGraph(DepGraph depGraph, OutputStream imageFile) {
    char[][] contents;

    auto edges = depGraph.edges;
    auto vertices = depGraph.vertices;

    void doList(DepGraph.Vertex[] v, uint level) {
      if (!level) return;

      contents ~= "(";

      foreach (vertex; v) {
        contents ~= vertex.name;
        if (vertex.outgoing.length)
          doList(vertex.outgoing, level-1);
      }

      contents ~= ")";
    }

    doList(vertices, factory.options.graph.depth);

    writer.addList(contents, false);
  }
}
