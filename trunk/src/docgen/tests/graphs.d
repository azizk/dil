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

void saveDefaultGraph(Vertex[] vertices, Edge[] edges, char[] fname) {
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
  
  writer.generateDepGraph(vertices, edges, file);
  
  file.close();
  file2.close();
}

// no edges
//@unittest
void graph1() {
  auto a = new Vertex("mod_a", "path.to.mod_a", 1);
  auto b = new Vertex("mod_b", "path.to.mod_b", 2);
  auto c = new Vertex("mod_c", "path.to.mod_c", 3);
  
  saveDefaultGraph( [a,b,c], null, "graph1.dot" );
}


// simple tree structure
//@unittest
void graph2() {
  auto a = new Vertex("mod_a", "path.to.mod_a", 1);
  auto b = new Vertex("mod_b", "path.to.mod_b", 2);
  auto c = new Vertex("mod_c", "path.to.mod_c", 3);
  auto d = new Vertex("mod_d", "path.to.mod_d", 4);

  Edge[] edges;
  edges ~= a.addChild(b);
  edges ~= a.addChild(c);
  edges ~= c.addChild(d);
  
  saveDefaultGraph( [a,b,c,d], edges, "graph2.dot" );
}

// circular imports
//@unittest
void graph3() {
  auto a = new Vertex("mod_a", "path.to.mod_a", 1);
  auto b = new Vertex("mod_b", "path.to.mod_b", 2);
  auto c = new Vertex("mod_c", "path.to.mod_c", 3);
  auto d = new Vertex("mod_d", "path.to.mod_d", 4);

  Edge[] edges;
  edges ~= a.addChild(b);
  edges ~= b.addChild(c);
  edges ~= c.addChild(a);

  saveDefaultGraph( [a,b,c,d], edges, "graph3.dot" );
}

// more complex graph
//@unittest
void graph4() {
  auto a = new Vertex("mod_a", "path.to.mod_a", 1);
  auto b = new Vertex("mod_b", "path.to.mod_b", 2);
  auto c = new Vertex("mod_c", "path.to.mod_c", 3);
  auto d = new Vertex("mod_d", "path.to.mod_d", 4);
  auto e = new Vertex("mod_e", "path.to.mod_e", 5);
  auto f = new Vertex("mod_f", "path.to.mod_f", 6);
  auto g = new Vertex("mod_g", "path.to.mod_g", 7);

  Edge[] edges;
  edges ~= a.addChild(b);
  edges ~= b.addChild(c);
  edges ~= c.addChild(a);
  edges ~= d.addChild(a);
  edges ~= e.addChild(a);
  edges ~= b.addChild(d);
  edges ~= b.addChild(e);
  edges ~= g.addChild(a);
  edges ~= b.addChild(f);
  edges ~= g.addChild(f);
  edges ~= a.addChild(g);

  saveDefaultGraph( [a,b,c,d,e,f,g], edges, "graph4.dot" );
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
      vertices[m.moduleFQN] = new Vertex(m.moduleFQN, m.filePath, id++);
    },
    (Module imported, Module importer, bool isPublic) {
      auto edge = vertices[imported.moduleFQN].addChild(vertices[importer.moduleFQN]);
      edge.type = isPublic ? EdgeType.PublicDependency : EdgeType.Dependency;
      edges ~= edge;
    },
    modules
  );

  auto writer = gwf.createGraphWriter(
    ddf.createPageWriter( [ file ], DocFormat.LaTeX ),
    GraphFormat.Dot
  );
  
  writer.generateDepGraph(vertices.values, edges, imgFile);
  
  file.close();
  imgFile.close();
}
