/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.docgen;

import docgen.sourcelisting.writers;
import docgen.document.writers;
import docgen.graphutils.writers;
import docgen.misc.misc;
import docgen.misc.parser;
import tango.core.Array;
import tango.io.stream.FileStream;
import tango.text.Ascii;
import tango.text.Util : replace;
debug import tango.io.Stdout;

abstract class DefaultDocGenerator : DocGenerator {
  DocGeneratorOptions m_options;
  DocumentWriter docWriter;
  GraphWriterFactory graphFactory;
  
  Module[] modules;
  Edge[] edges;
  Vertex[char[]] vertices;

  this(DocGeneratorOptions options) {
    m_options = options;
    parseSources();
    graphFactory = new DefaultGraphWriterFactory(this);
  }

  // TODO: constructor for situations where parsing has happened elsewhere

  char[] outPath(char[] file) {
    return options.outputDir ~ "/" ~ file;
  }

  void parseSources() {
    int id = 1;

    Parser.loadModules(
      options.parser.rootPaths, options.parser.importPaths,
      null, true, -1,
      (char[] fqn, char[] path, Module m) {
        if (m is null) {
          if (fqn in vertices) {
            debug Stdout.format("{} already set.\n", fqn);
            return;

          }
          auto vertex = new Vertex(fqn, path, id++);
          vertex.type = VertexType.UnlocatableModule;
          vertices[fqn] = vertex;
          debug Stdout.format("Setting {} = {}.\n", fqn, path);

        } else {
          vertices[m.moduleFQN] = new Vertex(m.moduleFQN, m.filePath, id++);
          debug Stdout.format("Setting {} = {}.\n", m.moduleFQN, m.filePath);
        }
      },
      (Module imported, Module importer) {
        debug Stdout.format("Connecting {} - {}.\n", imported.moduleFQN, importer.moduleFQN);
        edges ~= vertices[imported.moduleFQN].addChild(vertices[importer.moduleFQN]);
      },
      modules
    );
  }

  void createDepGraph(char[] depGraphFile) {
    auto imgFile = new FileOutput(outPath(depGraphFile));

    auto writer = graphFactory.createGraphWriter( docWriter );

    writer.generateGraph(vertices.values, edges, imgFile);

    imgFile.close();
  }

  public DocGeneratorOptions *options() {
    return &m_options;
  }
}


/**
 * Main routine for LaTeX doc generation.
 */
class LaTeXDocGenerator : DefaultDocGenerator {
  this(DocGeneratorOptions options) {
    super(options);
  }

  /**
   * Generates document skeleton.
   */
  void generateDoc(char[] docFileName) {
    auto ddf = new DefaultDocumentWriterFactory(this);

    auto docFile = new FileOutput(outPath(docFileName));
    docWriter = ddf.createDocumentWriter( [ docFile ] );

    docWriter.generateFirstPage();
    docWriter.generateTOC(modules);
    docWriter.generateModuleSection();
    docWriter.generateListingSection();
    docWriter.generateDepGraphSection();
    docWriter.generateIndexSection();
    docWriter.generateLastPage();

    docFile.close();
  }

  /**
   * Generates D language definition file.
   */
  void generateLangDef() {
    auto docFile = new FileOutput(outPath("lstlang0.sty"));
    docWriter.setOutput([docFile]);

    docWriter.generateLangDef();

    docFile.close();
  }

  /**
   * Generates "makefile" for processing the .dot and .tex files.
   */
  void generateMakeFile() {
    auto docFile = new FileOutput(outPath("make.sh"));
    docWriter.setOutput([docFile]);

    docWriter.generateMakeFile();

    docFile.close();
  }

  /**
   * Generates documentation for modules.
   */
  void generateModules(char[] modulesFile) {
    auto docFile = new FileOutput(outPath(modulesFile));
    docFile.close();
  }

  /**
   * Generates source file listings.
   */
  void generateListings(char[] listingsFile) {
    auto dlwf = new DefaultListingWriterFactory(this);
    auto docFile = new FileOutput(outPath(listingsFile));
    docWriter.setOutput([docFile]);
    auto writer = dlwf.createListingWriter(docWriter);

    /*modules.sort(
      (Module a, Module b){ return icompare(a.moduleFQN, b.moduleFQN); }
    );*/

    foreach(mod; modules) {
      auto dstFname = replace(mod.moduleFQN.dup, '.', '_') ~ ".d";
      
      auto srcFile = new FileInput(mod.filePath);
      auto dstFile = new FileOutput(outPath(dstFname));
      
      writer.generateListing(srcFile, dstFile, mod.moduleFQN);

      srcFile.close();
      dstFile.close();
    }
    
    docFile.close();
  }

  /**
   * Generates dependency graphs.
   */
  void generateDependencies(char[] depGraphTexFile, char[] depGraphFile) {
    auto docFile = new FileOutput(outPath(depGraphTexFile));
    docWriter.setOutput([docFile]);

    createDepGraph(depGraphFile);

    docFile.close();
  }

  public void generate() {
    auto docFileName = "document.tex";
    auto depGraphTexFile = "dependencies.tex";
    auto depGraphFile = "depgraph.dot";
    auto listingsFile = "files.tex";
    auto modulesFile = "modules.tex";

    generateDoc(docFileName);

    if (options.listings.enableListings)
      generateListings(listingsFile);

    generateModules(modulesFile);

    generateDependencies(depGraphTexFile, depGraphFile);

    generateLangDef();
    generateMakeFile();
  }
}

void main(char[][] args) {
  DocGeneratorOptions options;

  options.graph.graphFormat = GraphFormat.Dot;
  options.graph.imageFormat = ImageFormat.PS;
  options.graph.depth = 0;
  options.graph.nodeColor = "tomato";
  options.graph.cyclicNodeColor = "red";
  options.graph.unlocatableNodeColor = "gray";
  options.graph.clusterColor = "blue";
  options.graph.includeUnlocatableModules = true;
  options.graph.highlightCyclicEdges = true;
  options.graph.highlightCyclicVertices = true;
  options.graph.groupByPackageNames = false;
  options.graph.groupByFullPackageName = false;
  
  options.listings.literateStyle = true;
  options.listings.enableListings = true;

  options.templates.title = "Test project";
  options.templates.versionString = "1.0";
  options.templates.copyright = "(C) Me!";
  options.templates.paperSize = "a4paper";
  options.templates.shortFileNames = false;
  options.templates.templateStyle = "default";

  options.parser.importPaths = [ args[2] ];
  options.parser.rootPaths = [ args[1] ];
  options.parser.strRegexps = null;

  options.docFormat = DocFormat.LaTeX;
  options.commentFormat = CommentFormat.Doxygen;
  options.outputDir = args[3];
  

  auto generator = new LaTeXDocGenerator(options);

  generator.generate();
}
