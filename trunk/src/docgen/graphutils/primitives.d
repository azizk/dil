/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.primitives;

/**
 * Extendible graph class. Should support separation of concerns now better with mixins.
 * Provides a method for cycle marking.
 */
class Graph(alias V, alias E, int capacity = 1) {
  static class Edge {
    Vertex outgoing, incoming;
    //bool cyclic = true;

    this(Vertex o, Vertex i) {
      outgoing = o;
      incoming = i;
      o.outgoingEdges ~= this;
      i.incomingEdges ~= this;
    }

    bool cyclic() {
      return outgoing.cyclic && incoming.cyclic;
    }

    mixin E;
  }

  static class Vertex {
    Edge[] incomingEdges;
    Edge[] outgoingEdges;
    bool cyclic = true;

    Edge addChild(Vertex v) {
      return new Edge(v, this);
    }

    Edge addParent(Vertex v) {
      return v.addChild(this);
    }

    Vertex[] incoming() {
      Vertex[] tmp;

      foreach(edge; incomingEdges)
        tmp ~= edge.outgoing;

      return tmp;
    }

    Vertex[] outgoing() {
      Vertex[] tmp;

      foreach(edge; outgoingEdges)
        tmp ~= edge.incoming;

      return tmp;
    }

    mixin V;
  }

  Vertex[] vertices;
  Edge[] edges;

  this() {
    vertices.length = capacity;
    vertices.length = 0;
    edges.length = capacity;
    edges.length = 0;
  }

  void add(Vertex vertex) { vertices ~= vertex; }

  void add(Edge edge) { edges ~= edge; }

  void connect(Vertex from, Vertex to) { edges ~= from.addParent(to); }

  void connect(int from, int to) { connect(vertices[from], vertices[to]); }

  /**
   * Starts from non-cyclic nodes and propagates two both directions.
   * Bugs: marks non-cyclic imports between two cycles as cyclic. Could be fixed later if it's really needed (slow)
   */
  void markCycles() {
    void mark(Vertex v) {
      v.cyclic = false;
      foreach(o; v.outgoing) {
        if (!o.cyclic) continue;

        // propagate
        bool cyclic = false;
        foreach(p; o.incoming) if (p.cyclic) { cyclic = true; break; }
        if (!cyclic) mark(o);
      }
    }

    void mark2(Vertex v) {
      v.cyclic = false;
      foreach(o; v.incoming) {
        if (!o.cyclic) continue;

        // propagate
        bool cyclic = false;
        foreach(p; o.outgoing) if (p.cyclic) { cyclic = true; break; }
        if (!cyclic) mark2(o);
      }
    }

    foreach(e; vertices)
      if (e.cyclic) {
        if (!e.incoming.length) mark(e);
        if (!e.outgoing.length) mark2(e);
      }
  }
}

template Empty() {}


// graph elements used in dep graphs


template DepEdge() {
  bool isPublic; /// Public import.
  bool isStatic; /// Static import.
}

template DepVertex() {
  char[] name;
  char[] location;
  uint id;

  this(char[] name, char[] location, uint id = 0) {
    this.name = name;
    this.location = location;
    this.id = id;
  }
}

alias Graph!(DepVertex, DepEdge, 100) DepGraph;
