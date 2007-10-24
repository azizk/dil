/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.misc.misc;
import tango.io.model.IConduit : OutputStream;

char[] docgen_version = "Dil document generator 0.1";

/** Supported document output formats. */
enum DocFormat {
  LaTeX,
  XML,
  HTML,
  PlainText
}

/**
 * Supported comment formats.
 * 
 * http://www.stack.nl/~dimitri/doxygen/docblocks.html
 * http://www.digitalmars.com/d/ddoc.html
 */
enum CommentFormat {
  Ddoc,
  Doxygen
}

/** Supported image formats. */
enum ImageFormat {
  PNG,
  SVG,
  GIF,
  PS
}

/** Image format extensions. */
const imageFormatExts = [ "png", "svg", "gif", "ps" ];

/** Supported graph writers. */
enum GraphFormat {
  Dot,
  ModuleNames,
  ModulePaths
}

struct GraphOptions {
  GraphFormat graphFormat;
  ImageFormat imageFormat;
  uint depth;
  char[] nodeColor = "tomato";
  char[] cyclicNodeColor = "red";
  char[] clusterColor = "blue";
  bool includeUnlocatableModules;
  bool highlightCyclicEdges;
  bool highlightCyclicVertices;
  bool groupByPackageNames;
  bool groupByFullPackageName;
}

struct ListingOptions {
  /// use literate programming symbols [LaTeX]
  bool literateStyle = true;
  /// enable source code listings
  bool enableListings;
}

struct TemplateOptions {
  /// project title
  char[] title = "Test project";
  /// project version
  char[] versionString = "1.0";
  /// copyright notice
  char[] copyright;
  /// paper size [LaTeX]
  char[] paperSize = "a4paper";
  /// use short file names [HTML]
  bool shortFileNames;
  /// page template style to use, customizable via docgen/templates
  char[] templateStyle = "default";
}

struct ParserOptions {
  /// paths to search for imports 
  char[][] importPaths;
  /// paths to "root files"
  char[][] rootPaths;
  /// regexps for excluding modules
  char[][] strRegexps;
}

struct DocGeneratorOptions {
  /// location for the generated output
  char[] outputDir;

  DocFormat docFormat;
  CommentFormat commentFormat;
  
  GraphOptions graph;
  ListingOptions listings;
  TemplateOptions templates;
  ParserOptions parser;
}

// ---

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

template AbstractWriter(T, int n = 0) {
  abstract class AbstractWriter {
    protected T factory;
  
    static if (n > 0) {
      protected OutputStream[] outputs;
      
      this(T factory, OutputStream[] outputs) {
        this.factory = factory;
        this.outputs = outputs;
        assert(outputs.length == n, "Incorrect number of outputs");
      }
    } else {
      this(T factory) {
        this.factory = factory;
      }
    }
  }
}
