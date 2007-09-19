/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.primitives;

enum EdgeType {
  Unspecified,
  Aggregation,
  Association,
  Composition,
  CyclicDependency,
  Dependency,
  Generalization,
  Inheritance,
  Reserved // for the cycle algorithm
}

class Edge {
  Vertex outgoing;
  Vertex incoming;
  EdgeType type;

  this(Vertex o, Vertex i, EdgeType type = EdgeType.Unspecified) {
    this.outgoing = o;
    this.incoming = i;
    this.type = type;
  }

  bool isCyclic() {
    return type == EdgeType.CyclicDependency;
  }
}

enum VertexType {
  Module,
  Package,
  Class,
  Interface,
  Trait
}

class Vertex {
  char[] name;
  char[] location;
  uint id;

  Edge[] incomingEdges;
  Edge[] outgoingEdges;
  VertexType type;

  this(char[] name, char[] location, uint id = 0) {
    this.name = name;
    this.location = location;
    this.id = id;
  }

  Edge addChild(Vertex v, EdgeType type = EdgeType.Unspecified) {
    auto edge = new Edge(v, this, type);
    incomingEdges ~= edge;
    v.outgoingEdges ~= edge;
    return edge;
  }

  Edge addParent(Vertex v, EdgeType type = EdgeType.Unspecified) {
    return v.addChild(this, type);
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

  bool isCyclic() {
    foreach(edge; outgoingEdges)
      if (edge.isCyclic)
        return true;

    return false;
  }
}