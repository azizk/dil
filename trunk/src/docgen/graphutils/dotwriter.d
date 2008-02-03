/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.dotwriter;
import docgen.graphutils.writer;

import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;
import tango.io.FilePath;
import tango.text.Util;
import tango.text.convert.Sprint;
debug import tango.io.Stdout;

/**
 * Creates a graph rule file for the dot utility.
 */
class DotWriter : AbstractGraphWriter {
  public:

  this(GraphWriterFactory factory, PageWriter writer) {
    super(factory, writer);
  }

  void generateDepGraph(DepGraph depGraph, OutputStream imageFile) {
    generateImageTag(imageFile);
    
    auto image = generateDepImageFile(depGraph);
    auto printer = new Print!(char)(new Layout!(char), imageFile);
    printer(image);
  }

  protected:

  char[] generateDepImageFile(DepGraph depGraph) {
    char[] image;
    auto sprint = new Sprint!(char);
    
    auto edges = depGraph.edges;
    auto vertices = depGraph.vertices;

    DepGraph.Vertex[][char[]] verticesByPckgName;
    if (factory.options.graph.groupByFullPackageName ||
        factory.options.graph.groupByPackageNames) {
      foreach (mod; vertices) {
        auto parts = mod.name.delimit(".");

        if (parts.length>1) {
          auto pkg = parts[0..$-1].join(".");
          verticesByPckgName[pkg] ~= mod;
        }
      }
    }

    if (factory.options.graph.highlightCyclicVertices ||
        factory.options.graph.highlightCyclicEdges)
      depGraph.markCycles();

    image ~= "Digraph ModuleDependencies {\n";

    foreach (module_; vertices) {
      auto nodeName = 
        factory.options.graph.groupByPackageNames ?
        module_.name.split(".")[$-1] :
        module_.name;

      image ~= sprint.format(
        `  n{} [label="{}",style=filled,fillcolor={}];`\n,
        module_.id,
        nodeName,
        module_.cyclic && factory.options.graph.highlightCyclicVertices ?
          factory.options.graph.cyclicNodeColor :
        module_.incoming.length == 0 && module_.outgoing.length == 0 ?
          factory.options.graph.unlocatableNodeColor :
          factory.options.graph.nodeColor
      );
    }

    foreach (edge; edges)
      image ~= sprint.format(
        `  n{} -> n{}[color={}];`\n,
        edge.outgoing.id,
        edge.incoming.id,
        edge.cyclic ?
          factory.options.graph.cyclicDepColor :
        edge.isPublic ?
          factory.options.graph.publicDepColor ~ ",style=bold" :
          factory.options.graph.depColor
      );

    if (factory.options.graph.groupByPackageNames)

      if (!factory.options.graph.groupByFullPackageName) {
        foreach (packageName, vertices; verticesByPckgName) {
          auto name = packageName.split(".");

          if (name.length > 1) {
            char[] pkg;
            foreach(part; name) {
              pkg ~= part ~ ".";
              image ~= sprint.format(
                `subgraph "cluster_{0}" {{`\n`  label="{0}"`\n,
                pkg[0..$-1],
                pkg[0..$-1]
              );
            }
            for (int i=0; i< name.length; i++) {
              image ~= "}\n";
            }
          }
        }
      }
      foreach (packageName, vertices; verticesByPckgName) {
        image ~= sprint.format(
          `  subgraph "cluster_{0}" {{`\n`  label="{0}";color=`
          ~ factory.options.graph.clusterColor ~ `;`\n`  `,
          packageName,
          packageName
        );

        foreach (module_; vertices)
          image ~= sprint.format(`n{0};`, module_.id);
        image ~= "\n  }\n";
      }

    image ~= "}";

    return image;
  }
        
  void generateImageTag(OutputStream imageFile) {
    // name of the .dot file
    char[] fn = (cast(Object)imageFile.conduit).toString();
    fn = FilePath(fn).file;

    fn = fn[0..$-3] ~ imageFormatExts[factory.options.graph.imageFormat];
    
    writer.addGraphics(fn);
  } 
}

class CachingDotWriter : DotWriter {
  private:

  CachingGraphWriterFactory factory;

  public:

  this(CachingGraphWriterFactory factory, PageWriter writer) {
    super(factory, writer);
    this.factory = factory;
  }

  override void generateDepGraph(DepGraph depGraph, OutputStream imageFile) {
    generateImageTag(imageFile);

    auto cached = factory.graphCache.getCachedGraph(depGraph, GraphFormat.Dot);

    auto printer = new Print!(char)(new Layout!(char), imageFile);
    
    if (cached) {
      printer(cached);
    } else {
      auto image = generateDepImageFile(depGraph);
      factory.graphCache.setCachedGraph(depGraph, GraphFormat.Dot, image);
      printer(image);
    }
  }
}

