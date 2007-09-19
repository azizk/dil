/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.writer;

public import docgen.misc.misc;
public import docgen.graphutils.primitives;
import tango.io.model.IConduit : OutputStream;
debug import tango.io.Stdout;

enum ImageFormat {
  PNG,
  SVG,
  GIF
}

const imageFormatExts = [ "png", "svg", "gif" ];

enum GraphFormat {
  Dot,
  ModuleNames,
  ModulePaths
}

struct GraphOptions {
  GraphFormat graphFormat;
  ImageFormat imageFormat;
  DocFormat docFormat;
  uint depth;
  bool IncludeUnlocatableModules;
  bool HighlightCyclicEdges;
  bool HighlightCyclicVertices;
  bool GroupByPackageNames;
  bool GroupByFullPackageName;
}

interface GraphWriter {
  void generateGraph(Vertex[], Edge[]);
}

alias void delegate(Vertex[], Edge[]) GraphWriterDg;

abstract class AbstractGraphWriter : GraphWriter {
  protected GraphWriterFactory factory;
  protected OutputStream[] outputs;

  this(GraphWriterFactory factory, OutputStream[] outputs) {
    this.factory = factory;
    this.outputs = outputs;
  }

  /**
   * Marks all cycles in the graph.
   *
   * May have bugs, but is a bit simpler than the previous version.
   */
  protected static void findCycles(Vertex[] vertices, Edge[] edges) {
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

    /+
    void analyzeGraph(Vertex[] vertices, Edge[] edges)
    {
    void recursive(Vertex[] modules)
    {
      foreach (idx, vertex; vertices)
      {
        uint outgoing, incoming;
        foreach (j, edge; edges)
        {
          if (edge.outgoing is vertex)
            outgoing++;
          if (edge.incoming is vertex)
            incoming++;
        }

        if (outgoing == 0)
        {
          if (incoming != 0)
          {
            // Vertex is a sink.
            alias outgoing i; // Reuse
            alias incoming j; // Reuse
            // Remove edges.
            for (i=j=0; i < edges.length; i++)
              if (edges[i].incoming !is vertex)
                edges[j++] = edges[i];
            edges.length = j;
            vertices = vertices[0..idx] ~ vertices[idx+1..$];
            return recursive(modules);
          }
          else
            assert(0, "orphaned module: "~vertex.getFQN()~" (has no edges in graph)"); // orphaned vertex (module) in graph
        }
        else if (incoming == 0)
        {
          // Vertex is a source
          alias outgoing i; // Reuse
          alias incoming j; // Reuse
          // Remove edges.
          for (i=j=0; i < edges.length; i++)
            if (edges[i].outgoing !is vertex)
              edges[j++] = edges[i];
          edges.length = j;
          vertices = vertices[0..idx] ~ vertices[idx+1..$];
          return recursive(modules);
        }
//         else
//         {
//           // source && sink
//         }
      }

      // When reaching this point it means only cylic edges and vertices are left.
      foreach (vertex; vertices)
        vertex.isCyclic = true;
      foreach (edge; edges)
        if (edge)
          edge.isCyclic = true;
    }
    recursive(vertices);
    }
    +/
}

interface GraphWriterFactory {
  GraphOptions *options();
  GraphWriterDg createGraphWriter(OutputStream[] outputs);
}

abstract class AbstractGraphWriterFactory : GraphWriterFactory {
  protected GraphOptions m_options;

  public GraphOptions *options() {
    return &m_options;
  }
}