/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.writer;

public import docgen.misc.misc;
public import docgen.graphutils.primitives;
public import docgen.page.writer;
debug import tango.io.Stdout;

interface GraphWriter {
  void generateDepGraph(Vertex[] vertices, Edge[] edges, OutputStream imageFile);
}

interface GraphWriterFactory : WriterFactory {
  GraphWriter createGraphWriter(PageWriter writer, GraphFormat outputFormat);
}

interface CachingGraphWriterFactory : GraphWriterFactory {
  char[] getCachedGraph(Vertex[] vertices, Edge[] edges, GraphFormat format);
}

/**
 * Marks all cycles in the graph.
 *
 * May have bugs, but is a bit simpler than the previous version.
 */
void findCycles(Vertex[] vertices, Edge[] edges) {
  void p() {
    foreach(e; edges) Stderr(e.type)(" "c);
    Stderr.newline;
  }

  bool visit(Edge edge) {
    if (edge.type == EdgeType.Reserved) {
      edge.type = EdgeType.CyclicDependency;
      version(VerboseDebug) p();
      return true;
    }

    bool wasCyclic = edge.isCyclic();
    edge.type = EdgeType.Reserved;
    version(VerboseDebug) p();

    foreach(edge2; edge.incoming.outgoingEdges)
      if (visit(edge2)) {
        if (edge.isCyclic()) {
          edge.type = EdgeType.Reserved;
          wasCyclic = true;
          version(VerboseDebug) p();
          continue;
        }
        edge.type = EdgeType.CyclicDependency;
        return true;
      }

    edge.type = wasCyclic ? EdgeType.CyclicDependency : EdgeType.Dependency;
    version(VerboseDebug) p();
    return false;
  }

  foreach(vertex; vertices)
    foreach(edge; vertex.outgoingEdges)
      if (edge.type == EdgeType.Unspecified) {
        visit(edge);
        debug Stderr("*\n");
      }
}

abstract class AbstractGraphWriter : AbstractWriter!(GraphWriterFactory), GraphWriter {
  PageWriter writer;
  
  this(GraphWriterFactory factory, PageWriter writer) {
    super(factory);
    this.writer = writer;
  }
}
