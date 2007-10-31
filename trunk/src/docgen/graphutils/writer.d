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
  GraphCache graphCache();
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
    if (edge.cycleType == CycleType.Reserved) {
      edge.cycleType = CycleType.Cyclic;
      version(VerboseDebug) p();
      return true;
    }

    bool wasCyclic = edge.isCyclic();
    edge.cycleType = CycleType.Reserved;
    version(VerboseDebug) p();

    foreach(edge2; edge.incoming.outgoingEdges)
      if (visit(edge2)) {
        if (edge.isCyclic()) {
          edge.cycleType = CycleType.Reserved;
          wasCyclic = true;
          version(VerboseDebug) p();
          continue;
        }
        edge.cycleType = CycleType.Cyclic;
        return true;
      }

    edge.cycleType = wasCyclic ? CycleType.Cyclic : CycleType.Cyclefree;
    version(VerboseDebug) p();
    return false;
  }

  foreach(vertex; vertices)
    foreach(edge; vertex.outgoingEdges)
      if (edge.cycleType == CycleType.Unspecified) {
        visit(edge);
        debug Stderr("*\n");
      }
}

abstract class AbstractGraphWriter : AbstractWriter!(GraphWriterFactory), GraphWriter {
  protected:

  PageWriter writer;
  
  public:

  this(GraphWriterFactory factory, PageWriter writer) {
    super(factory);
    this.writer = writer;
  }
}

class DefaultGraphCache : GraphCache {
  private:
    
  char[][Object[]][Object[]][GraphFormat] m_graphCache;

  public:

  char[] getCachedGraph(Object[] vertices, Object[] edges, GraphFormat format) {
    debug Stdout("Starting graph lookup\n");
    debug Stdout(&vertices, &edges, format).newline;
    debug Stdout(&m_graphCache).newline;
    
    auto lookup1 = format in m_graphCache;
    if (lookup1) {
      auto lookup2 = edges in *lookup1;
      if (lookup2) {
        auto lookup3 = vertices in *lookup2;
        if (lookup3)
          return *lookup3;
      }
    }
    debug Stdout("Graph cache miss!\n");
    return null;
  }

  void setCachedGraph(Object[] vertices, Object[] edges, GraphFormat format, char[]
      contents) {
    m_graphCache[format][edges][vertices] = contents;
    debug Stdout("Graph cache updated!\n");
  }
}
