/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.tests.graphs;

import docgen.graphutils.writers;
import tango.io.Stdout;
import tango.io.FileConduit;

void saveDefaultGraph(Vertex[] vertices, Edge[] edges, char[] fname) {
  GraphOptions test;
  test.graphFormat = GraphFormat.Dot;
  test.HighlightCyclicVertices = true;
  //test.format = GraphOutputFormat.ModuleNames;
  //test.format = GraphOutputFormat.ModulePaths;
  test.depth = 5;
  
  auto gwf = new DefaultGraphWriterFactory(test);
  auto file = new FileConduit("docgen/teststuff/" ~ fname, FileConduit.WriteCreate);
  auto file2 = new FileConduit("docgen/teststuff/" ~ fname ~ "-2", FileConduit.WriteCreate);
  auto writer = gwf.createGraphWriter( [ file2, file] );
  
  writer(vertices, edges);
  
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