/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.writer;

public import docgen.misc.misc;
public import docgen.graphutils.primitives;
public import docgen.document.writer;
debug import tango.io.Stdout;

interface GraphWriter {
  void generateDepGraph(Vertex[] vertices, Edge[] edges, OutputStream imageFile);
}

/**
 * Marks all cycles in the graph.
 *
 * May have bugs, but is a bit simpler than the previous version.
 */
void findCycles(Vertex[] vertices, Edge[] edges) {
  debug void p() {
    foreach(e; edges) Stderr(e.type)(" "c);
    Stderr.newline;
  }

  bool visit(Edge edge) {
    if (edge.type == EdgeType.Reserved) {
      edge.type = EdgeType.CyclicDependency;
      debug p();
      return true;
    }

    bool wasCyclic = edge.isCyclic();
    edge.type = EdgeType.Reserved;
    debug p();

    foreach(edge2; edge.incoming.outgoingEdges)
      if (visit(edge2)) {
        if (edge.isCyclic()) {
          edge.type = EdgeType.Reserved;
          wasCyclic = true;
          debug p();
          continue;
        }
        edge.type = EdgeType.CyclicDependency;
        return true;
      }

    edge.type = wasCyclic ? EdgeType.CyclicDependency : EdgeType.Dependency;
    debug p();
    return false;
  }

  foreach(vertex; vertices)
    foreach(edge; vertex.outgoingEdges)
      if (edge.type == EdgeType.Unspecified) {
        visit(edge);
        debug Stderr("*\n");
      }
}

interface GraphWriterFactory : WriterFactory {
  GraphWriter createGraphWriter(DocumentWriter writer, GraphFormat outputFormat);
}

abstract class AbstractGraphWriter : AbstractWriter!(GraphWriterFactory), GraphWriter {
  DocumentWriter writer;
  
  this(GraphWriterFactory factory, DocumentWriter writer) {
    super(factory);
    this.writer = writer;
  }
}
