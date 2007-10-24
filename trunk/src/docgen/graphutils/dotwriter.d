/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.dotwriter;
import docgen.graphutils.writer;

import tango.io.FileConduit : FileConduit;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;
import tango.io.FilePath;

/**
 * Creates a graph rule file for the dot utility.
 */
class DotWriter : AbstractGraphWriter {
  this(GraphWriterFactory factory, DocumentWriter writer) {
    super(factory, writer);
  }

  void generateGraph(Vertex[] vertices, Edge[] edges, OutputStream imageFile) {
    auto image = new Print!(char)(new Layout!(char), imageFile);

    Vertex[][char[]] verticesByPckgName;
    if (factory.options.graph.groupByFullPackageName)
      foreach (module_; vertices)
        verticesByPckgName[module_.name] ~= module_; // FIXME: is it name or loc?

    if (factory.options.graph.highlightCyclicVertices ||
        factory.options.graph.highlightCyclicEdges)
      findCycles(vertices, edges);

    if (cast(FileConduit)imageFile.conduit) {
      // name of the .dot file
      char[] fn = (cast(FileConduit)imageFile.conduit).toUtf8();
      fn = FilePath(fn).file;

      fn = fn[0..$-4];
      
      writer.addGraphics(fn);
    }
    
    image("Digraph ModuleDependencies {\n");

    if (factory.options.graph.highlightCyclicVertices)
      foreach (module_; vertices)
        image.format(
          `  n{0} [label="{1}"{2}];`\n,
          module_.id,
          module_.name,
          (module_.isCyclic ? ",style=filled,fillcolor=" ~ factory.options.graph.nodeColor : "")
        );
    else
        foreach (i, module_; vertices)
            image.format(`  n{0} [label="{1}"];`, i, module_.name);

    foreach (edge; edges)
      image.format(
        `  n{0} -> n{1}{2};`\n,
        edge.outgoing.id,
        edge.incoming.id,
        (edge.isCyclic ? "[color=" ~ factory.options.graph.cyclicNodeColor ~ "]" : "")
      );

    if (factory.options.graph.groupByFullPackageName)
      foreach (packageName, vertices; verticesByPckgName) {
        image.format(
          `  subgraph "cluster_{0}" {{`\n`    label="{0}";color=`
          ~ factory.options.graph.clusterColor ~ `;`\n`    `,
          packageName,
          packageName
        );

        foreach (module_; vertices)
          image.format(`n{0};`, module_.id);
        image("\n  }\n");
      }

    image("}");
  }
}
