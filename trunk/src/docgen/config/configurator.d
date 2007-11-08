/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.config.configurator;

import docgen.config.reader;
import docgen.misc.options;

import Integer = tango.text.convert.Integer;
import tango.io.stream.FileStream;
import tango.io.Stdout;

/**
 * Class for handling and merging doc generator options.
 */
interface Configurator {
  /**
   * Merges configuration options from the given file.
   */
  void mergeConfiguration(char[] cfgFile);
  
  /**
   * Returns a hierarchical structure of configuration options.
   */
  DocGeneratorOptions *getConfiguration();
}

// ugly piece of crap begins.

char[] _wrong(char[] key) {
  return `if (val.length != 1) throw new Exception(
    "Wrong number of arguments for `~key~`");`;
}

char[] _switch(char[] stuff) {
  return "switch(key) {" ~ stuff ~ "}";
}

char[] _parseI(char[] key) {
  return `case "` ~ key ~ `":` ~ _wrong(key) ~ key ~
    "= Integer.parse(val[0]); continue;";
}

char[] _parseS(char[] key) {
  return `case "` ~ key ~ `":` ~ _wrong(key) ~ key ~
    "= val[0]; continue;";
}

char[] _parseB(char[] key) {
  return `case "` ~ key ~ `":` ~ _wrong(key) ~ key ~
    `= val[0] == "true" ? true : val[0] == "false" ? false : err(); continue;`;
}

char[] _parseList(char[] key) {
  return `case "` ~ key ~ `":foreach(v; val) ` ~
    key ~ `~= v; continue;`;
}

template _parseEnum_(bool list, char[] key, V...) {
  static if (V.length>1)
    const char[] _parseEnum_ =
      `case "` ~ V[0] ~ `":` ~ key ~ (list ? "~" : "") ~ `=` ~ V[1] ~ `; continue;` \n ~
      _parseEnum_!(list, key, V[2..$]);
  else
    const char[] _parseEnum_ = "";
}

template _parseEnum(char[] key, V...) {
  const char[] _parseEnum = `case "` ~ key ~
    `":` ~ _wrong(key) ~ `switch(val[0]) {` ~
    _parseEnum_!(false, key, V) ~
      `default: err(); } continue;`;
}

template _parseEnumList(char[] key, V...) {
  const char[] _parseEnumList = `case "` ~ key ~
    `":` ~ `foreach (item; val) switch(item) {` ~
    _parseEnum_!(true, key, V) ~
      `default: err(); } continue;`;
}

class DefaultConfigurator : Configurator {
  private:
    
  DocGeneratorOptions options;

  public:

  const defaultProfileLocation = "docgen/config/default.cfg";

  this() {
    mergeConfiguration(defaultProfileLocation);
  }

  this(char[] cfgFile) {
    this();
    mergeConfiguration(cfgFile);
  }

  void mergeConfiguration(char[] cfgFile) {
    
    auto inputStream = new FileInput(cfgFile);
    auto content = new char[inputStream.length];
    auto bytesRead = inputStream.read (content);
    
    assert(bytesRead == inputStream.length, "Error reading configuration file");

    auto tokens = lex(content);
    auto configuration = parse(tokens);

    foreach(key, val; configuration) {
      bool err() {
        throw new Exception(
          "Configurator: Invalid key-val pair " ~ key ~
          "=" ~ (val.length ? val[0] : "null"));
      }

      mixin(_switch(
        _parseEnum!("options.graph.imageFormat",
          "PDF", "ImageFormat.PDF",
          "SVG", "ImageFormat.SVG",
          "PNG", "ImageFormat.PNG",
          "GIF", "ImageFormat.GIF"
        ) ~
        _parseI("options.graph.depth") ~
        _parseS("options.graph.nodeColor") ~
        _parseS("options.graph.cyclicNodeColor") ~
        _parseS("options.graph.unlocatableNodeColor") ~
        _parseS("options.graph.depColor") ~
        _parseS("options.graph.cyclicDepColor") ~
        _parseS("options.graph.publicDepColor") ~
        _parseS("options.graph.clusterColor") ~
        _parseB("options.graph.includeUnlocatableModules") ~
        _parseB("options.graph.highlightCyclicEdges") ~
        _parseB("options.graph.highlightCyclicVertices") ~
        _parseB("options.graph.groupByPackageNames") ~
        _parseB("options.graph.groupByFullPackageName") ~
        _parseB("options.listing.literateStyle") ~
        _parseB("options.listing.enableListings") ~
        _parseS("options.templates.title") ~
        _parseS("options.templates.versionString") ~
        _parseS("options.templates.copyright") ~
        _parseS("options.templates.paperSize") ~
        _parseB("options.templates.shortFileNames") ~
        _parseS("options.templates.templateStyle") ~
        _parseList("options.parser.importPaths") ~
        _parseList("options.parser.rootPaths") ~
        _parseList("options.parser.strRegexps") ~
        _parseEnum!("options.parser.commentFormat",
            "Doxygen", "CommentFormat.Doxygen",
            "Ddoc", "CommentFormat.Ddoc"
        ) ~
        _parseI("options.parser.depth") ~
        _parseEnumList!("options.outputFormats",
            "LaTeX", "DocFormat.LaTeX",
            "HTML", "DocFormat.HTML",
            "XML", "DocFormat.XML",
            "PlainText", "DocFormat.PlainText"
        ) ~
        _parseS("options.outputDir") ~
        `default: throw new Exception("Illegal configuration key " ~ key);`
      ));
    }
  }

  DocGeneratorOptions *getConfiguration() {
    return &options;
  }
}
