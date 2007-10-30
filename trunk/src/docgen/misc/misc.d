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
  PDF
}

/** Image format extensions. */
const imageFormatExts = [ "png", "svg", "gif", "pdf" ];

/** Supported graph writers. */
enum GraphFormat {
  Dot,
  ModuleNames,
  ModulePaths
}

struct GraphOptions {
  /// image format to use for graphs
  ImageFormat imageFormat;
  /// maximum depth of dependencies in graphs
  uint depth;
  /// color of normal modules
  char[] nodeColor;
  /// color of the modules in cyclic dep relation
  char[] cyclicNodeColor;
  /// unlocatable module color
  char[] unlocatableNodeColor;
  /// package color
  char[] clusterColor;
  /// include unlocatable modules to the dep graph
  bool includeUnlocatableModules;
  /// highlight imports in cyclic dep relation
  bool highlightCyclicEdges;
  /// highlight modules in cyclic dep relation
  bool highlightCyclicVertices;
  /// group modules by package names in dep graph
  bool groupByPackageNames;
  /// group modules hierarchically or by full package name
  bool groupByFullPackageName;
}

struct ListingOptions {
  /// use literate programming symbols [LaTeX]
  bool literateStyle;
  /// enable source code listings
  bool enableListings;
}

struct TemplateOptions {
  /// project title
  char[] title;
  /// project version
  char[] versionString;
  /// copyright notice
  char[] copyright;
  /// paper size [LaTeX]
  char[] paperSize;
  /// use short file names [HTML]
  bool shortFileNames;
  /// page template style to use, customizable via docgen/templates
  char[] templateStyle;
}

struct ParserOptions {
  /// paths to search for imports 
  char[][] importPaths;
  /// paths to "root files"
  char[][] rootPaths;
  /// regexps for excluding modules
  char[][] strRegexps;
  /// comment format [comment parser]
  CommentFormat commentFormat;
}

struct DocGeneratorOptions {
  /// location for the generated output
  char[] outputDir;

  /// list of document formats to be generated
  DocFormat[] outputFormats;
  
  GraphOptions graph;
  ListingOptions listing;
  TemplateOptions templates;
  ParserOptions parser;
}

// ---

interface DocGenerator {
  DocGeneratorOptions *options();
  void generate();
}

interface GraphCache {  
  char[] getCachedGraph(Object[] vertices, Object[] edges, GraphFormat format);
  void setCachedGraph(Object[] vertices, Object[] edges, GraphFormat format, char[] contents);
}

interface CachingDocGenerator : DocGenerator {
  GraphCache graphCache();
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
