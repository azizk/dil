/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module trunk.src.tests;

import docgen.graphutils.writers;
import tango.io.Stdout;
import tango.io.FileConduit;

/**
 * A temporary test program for the docgen package.
 * I'll replace this with proper unittests in the future.
 *
 */
void main() {
    {
        auto a = new Vertex("mod_a", "path.to.mod_a", 1);
        auto b = new Vertex("mod_b", "path.to.mod_b", 2);
        auto c = new Vertex("mod_c", "path.to.mod_c", 3);

        auto d = new Vertex("mod_d", "path.to.mod_d", 4);
        auto e = new Vertex("mod_e", "path.to.mod_e", 5);
        auto f = new Vertex("mod_f", "path.to.mod_f", 6);
        auto g = new Vertex("mod_g", "path.to.mod_g", 7);

        Edge[] edges;
        //edges ~= a.addChild(b);
        //edges ~= b.addChild(c);
        //edges ~= c.addChild(a);
        edges ~= d.addChild(a);
        //edges ~= e.addChild(a);
        edges ~= b.addChild(d);
        edges ~= b.addChild(e);
        edges ~= g.addChild(a);
        edges ~= b.addChild(f);
        edges ~= g.addChild(f);
        edges ~= a.addChild(g);



        GraphOptions test;
        test.graphFormat = GraphFormat.Dot;
        test.HighlightCyclicVertices = true;
        //test.format = GraphOutputFormat.ModuleNames;
        //test.format = GraphOutputFormat.ModulePaths;
        test.depth = 5;
        //test.depth++;

        auto gwf = new DefaultGraphWriterFactory(test);
        auto writer = gwf.createGraphWriter([Stdout.stream, new FileConduit("test.dot", FileConduit.WriteCreate)]);

        writer([a,b,c,d,e,f,g], edges);
    }
}