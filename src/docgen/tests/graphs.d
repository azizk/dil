/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.tests.graphs;

import docgen.tests.common;
import docgen.misc.parser;
import docgen.graphutils.writers;
import docgen.page.writers;
import tango.io.FileConduit;
import dil.semantic.Module;

alias DepGraph.Edge Edge;
alias DepGraph.Vertex Vertex;

void saveDefaultGraph(DepGraph depGraph, char[] fname) {
  auto gen = new TestDocGenerator;
  gen.options.graph.highlightCyclicVertices = true;
  gen.options.graph.imageFormat = ImageFormat.SVG;
  //gen.options.graph.graphFormat = GraphFormat.ModuleNames;
  //gen.options.graph.graphFormat = GraphFormat.ModulePaths;
  gen.options.graph.depth = 5;
  auto ddf = new DefaultPageWriterFactory(gen);
  auto gwf = new DefaultGraphWriterFactory(gen);
  auto file = new FileConduit("docgen/teststuff/" ~ fname, FileConduit.WriteCreate);
  auto file2 = new FileConduit("docgen/teststuff/" ~ fname ~ "-2", FileConduit.WriteCreate);

  auto writer = gwf.createGraphWriter(
    ddf.createPageWriter( [ file2 ], DocFormat.LaTeX),
    GraphFormat.Dot
  );
  
  writer.generateDepGraph(depGraph, file);
  
  file.close();
  file2.close();
}

// no edges
//@unittest
void graph1() {
  auto g = new DepGraph;
  g.add(new Vertex("mod_a", "path.to.mod_a", 1));
  g.add(new Vertex("mod_b", "path.to.mod_b", 2));
  g.add(new Vertex("mod_c", "path.to.mod_c", 3));
  
  saveDefaultGraph(g, "graph1.dot");
}


// simple tree structure
//@unittest
void graph2() {
  auto g = new DepGraph;
  g.add(new Vertex("mod_a", "path.to.mod_a", 1));
  g.add(new Vertex("mod_b", "path.to.mod_b", 2));
  g.add(new Vertex("mod_c", "path.to.mod_c", 3));
  g.add(new Vertex("mod_d", "path.to.mod_d", 4));

  g.connect(1, 0);
  g.connect(2, 0);
  g.connect(3, 2);
  
  saveDefaultGraph(g, "graph2.dot");
}

// circular imports
//@unittest
void graph3() {
  auto g = new DepGraph;
  g.add(new Vertex("mod_a", "path.to.mod_a", 1));
  g.add(new Vertex("mod_b", "path.to.mod_b", 2));
  g.add(new Vertex("mod_c", "path.to.mod_c", 3));
  g.add(new Vertex("mod_d", "path.to.mod_d", 4));

  g.connect(1, 0);
  g.connect(2, 1);
  g.connect(0, 2);
  
  saveDefaultGraph(g, "graph3.dot");
}

// more complex graph
//@unittest
void graph4() {
  auto g = new DepGraph;
  g.add(new Vertex("mod_a", "path.to.mod_a", 1));
  g.add(new Vertex("mod_b", "path.to.mod_b", 2));
  g.add(new Vertex("mod_c", "path.to.mod_c", 3));
  g.add(new Vertex("mod_d", "path.to.mod_d", 4));
  g.add(new Vertex("mod_e", "path.to.mod_e", 5));
  g.add(new Vertex("mod_f", "path.to.mod_f", 6));
  g.add(new Vertex("mod_g", "path.to.mod_g", 7));

  g.connect(1, 0);
  g.connect(2, 1);
  g.connect(0, 2); 
  g.connect(0, 3);
  g.connect(0, 4);
  g.connect(3, 1);
  g.connect(4, 1);
  g.connect(0, 6);
  g.connect(5, 1);
  g.connect(5, 6);
  g.connect(6, 0);

  saveDefaultGraph(g, "graph4.dot");
}


// parses the test modules and creates a dep graph
//@unittest
void graph5() {
  auto gen = new TestDocGenerator;
  gen.options.graph.highlightCyclicVertices = true;
  gen.options.graph.imageFormat = ImageFormat.PDF;
  gen.options.outputFormats = [ DocFormat.LaTeX ];
  auto fname = "dependencies.tex";
  auto imgFname = "depgraph.dot";
  
  auto ddf = new DefaultPageWriterFactory(gen);
  auto gwf = new DefaultGraphWriterFactory(gen);
  auto file = new FileConduit("docgen/teststuff/" ~ fname, FileConduit.WriteCreate);
  auto imgFile = new FileConduit("docgen/teststuff/" ~ imgFname, FileConduit.WriteCreate);
  
  Module[] modules;
  Edge[] edges;
  Vertex[char[]] vertices;
  int id = 1;
  
  Parser.loadModules(
    [ "c" ], [ "docgen/teststuff/" ],
    null, true, -1,
    (char[] fqn, char[] path, Module m) {
      vertices[m.moduleFQN] = new DepGraph.Vertex(m.moduleFQN, m.filePath, id++);
    },
    (Module imported, Module importer, bool isPublic, bool isStatic) {
      auto edge = vertices[imported.moduleFQN].addChild(vertices[importer.moduleFQN]);
      edge.isPublic = isPublic;
      edge.isStatic = isStatic;
      edges ~= edge;
    },
    modules
  );

  auto writer = gwf.createGraphWriter(
    ddf.createPageWriter( [ file ], DocFormat.LaTeX ),
    GraphFormat.Dot
  );
  
  auto graph = new DepGraph;
  graph.edges = edges;
  graph.vertices = vertices.values;

  writer.generateDepGraph(graph, imgFile);
  
  file.close();
  imgFile.close();
}
