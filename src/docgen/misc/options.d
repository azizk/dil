/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.misc.options;

import docgen.misc.meta;

/** creates reflective enums, syntax: enum name + list of elements */
template optionEnum(char[] name, T...) {
  const optionEnum = createEnum!("_" ~ name, name, "__" ~ name, "___" ~ name, T);
}

/** Supported document output formats. */
mixin(optionEnum!("DocFormat", "LaTeX", "XML", "HTML", "PlainText"));

/**
 * Supported comment formats.
 * 
 * http://www.stack.nl/~dimitri/doxygen/docblocks.html
 * http://www.digitalmars.com/d/ddoc.html
 */
mixin(optionEnum!("CommentFormat", "Ddoc", "Doxygen"));

/** Supported image formats. */
mixin(optionEnum!("ImageFormat", "PNG", "SVG", "GIF", "PDF"));

/** Image format extensions. */
const imageFormatExts = [ "png", "svg", "gif", "pdf" ];

/** Supported graph writers. */
mixin(optionEnum!("GraphFormat", "Dot", "ModuleNames", "ModulePaths"));

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
  /// color of the dependencies
  char[] depColor;
  /// color of the dependencies in cyclic dep relation
  char[] cyclicDepColor;
  /// color of the public dependencies
  char[] publicDepColor;
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
  /// maximum depth of dependencies
  uint depth;
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

