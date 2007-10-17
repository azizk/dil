/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.misc.misc;
import tango.io.model.IConduit : OutputStream;

char[] docgen_version = "Dil document generator 0.1";

enum DocFormat {
  LaTeX,
  XML,
  HTML,
  PlainText
}

enum CommentFormat {
  Ddoc,
  Doxygen
}

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
  uint depth;
  bool IncludeUnlocatableModules;
  bool HighlightCyclicEdges;
  bool HighlightCyclicVertices;
  bool GroupByPackageNames;
  bool GroupByFullPackageName;
}

struct ListingOptions {
  bool literateStyle = true;
  bool enableListings;
}

struct TemplateOptions {
  char[] title = "Test project";
  char[] versionString = "1.0";
  char[] copyright;
  char[] paperSize = "a4paper";
}

struct DocGeneratorOptions {
  
  GraphOptions graph;
  ListingOptions listings;
  TemplateOptions templates;
  DocFormat docFormat;
  CommentFormat commentFormat;
}

interface DocGenerator {
  DocGeneratorOptions *options();
  void generate();
}

interface WriterFactory {
  DocGeneratorOptions *options();
}

abstract class AbstractWriterFactory : WriterFactory {
  protected DocGenerator generator;

  public DocGeneratorOptions *options() {
    return generator.options;
  }

  this(DocGenerator generator) {
    this.generator = generator;
  }
}

template AbstractWriter(T, int n = -1) {
  abstract class AbstractWriter {
    protected T factory;
    protected OutputStream[] outputs;
  
    this(T factory, OutputStream[] outputs) {
      this.factory = factory;
      this.outputs = outputs;
      static if (n > -1)
        assert(outputs.length == n, "Incorrect number of outputs");
    }
  }
}