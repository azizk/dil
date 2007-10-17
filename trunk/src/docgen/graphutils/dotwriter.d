/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.dotwriter;
import docgen.graphutils.writer;

import tango.io.FileConduit : FileConduit;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;


/**
 * Creates a graph rule file for the dot utility.
 *
 * TODO: support changing colors / graph style?
 */
class DotWriter : AbstractGraphWriter {
  this(GraphWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
    assert(outputs.length == 2, "Wrong number of outputs");
  }

  void generateGraph(Vertex[] vertices, Edge[] edges) {
    auto output2 = new Print!(char)(new Layout!(char), outputs[0]);
    auto output = new Print!(char)(new Layout!(char), outputs[1]);

    Vertex[][char[]] verticesByPckgName;
    if (factory.options.GroupByFullPackageName)
      foreach (module_; vertices)
        verticesByPckgName[module_.name] ~= module_; // FIXME: is it name or loc?

    if (factory.options.HighlightCyclicVertices ||
        factory.options.HighlightCyclicEdges)
      findCycles(vertices, edges);

    if (cast(FileConduit)outputs[1]) {
      // name of the .dot file
      char[] fn = (cast(FileConduit)outputs[1]).toUtf8();

      // .dot -> .svg/.png/.gif/...
      fn = fn[0..$-3] ~ imageFormatExts[factory.options.imageFormat];

      switch(factory.options.docFormat) {
        case DocFormat.LaTeX:
          output2.format("\\includegraphics{{{0}}", fn);
          break;
        case DocFormat.XML:
          // TODO
          break;
        case DocFormat.HTML:
          output2.format(`<img src="{0}" />`, fn);
          break;
        case DocFormat.PlainText:
          throw new Exception("Dot output is not supported in plain text mode.");
      }
    }

    output("Digraph ModuleDependencies {\n");

    if (factory.options.HighlightCyclicVertices)
      foreach (module_; vertices)
        output.format(
          `  n{0} [label="{1}"{2}];`\n,
          module_.id,
          module_.name,
          (module_.isCyclic ? ",style=filled,fillcolor=tomato" : "")
        );
    else
        foreach (i, module_; vertices)
            output.format(`  n{0} [label="{1}"];`, i, module_.name);

    foreach (edge; edges)
      output.format(
        `  n{0} -> n{1}{2};`\n,
        edge.outgoing.id,
        edge.incoming.id,
        (edge.isCyclic ? "[color=red]" : "")
      );

    if (factory.options.GroupByFullPackageName)
      foreach (packageName, vertices; verticesByPckgName) {
        output.format(
          `  subgraph "cluster_{0}" {{`\n`    label="{0}";color=blue;`\n`    `,
          packageName,
          packageName
        );

        foreach (module_; vertices)
          output.format(`n{0};`, module_.id);
        output("\n  }\n");
      }

    output("}");
  }
}