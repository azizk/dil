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
import docgen.config.configurator;
import tango.core.Array;
import tango.io.stream.FileStream;
import tango.text.Ascii;
import tango.text.Util : replace;
import tango.io.FilePath;
debug import tango.io.Stdout;

template DefaultDocGenerator(char[] genDir) {
  abstract class DefaultDocGenerator : DocGenerator {
    DocGeneratorOptions m_options;
    DocumentWriter docWriter;
    GraphWriterFactory graphFactory;
    
    Module[] modules;
    Edge[] edges;
    Vertex[char[]] vertices;

    this(DocGeneratorOptions options) {
      m_options = options;
      graphFactory = new DefaultGraphWriterFactory(this);

      // create output dir
      (new FilePath(options.outputDir ~ "/" ~ genDir)).create();
    }

    // TODO: constructor for situations where parsing has happened elsewhere

    char[] outPath(char[] file) {
      return options.outputDir ~ "/" ~ genDir ~ "/" ~ file;
    }

    void parseSources() {
      int id = 1;

      Parser.loadModules(
        options.parser.rootPaths,
        options.parser.importPaths,
        options.parser.strRegexps,
        options.graph.includeUnlocatableModules,
        options.graph.depth,
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

      auto writer = graphFactory.createGraphWriter( docWriter, GraphFormat.Dot );

      writer.generateDepGraph(vertices.values, edges, imgFile);

      imgFile.close();
    }

    public DocGeneratorOptions *options() {
      return &m_options;
    }
}
}

/**
 * Main routine for LaTeX doc generation.
 */
class LaTeXDocGenerator : DefaultDocGenerator!("latex") {
  this(DocGeneratorOptions options) {
    super(options);
  }

  /**
   * Generates document skeleton.
   */
  void generateDoc(char[] docFileName) {
    auto ddf = new DefaultDocumentWriterFactory(this);

    auto docFile = new FileOutput(outPath(docFileName));
    docWriter = ddf.createDocumentWriter( [ docFile ], DocFormat.LaTeX );

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
    auto writer = dlwf.createListingWriter(docWriter, DocFormat.LaTeX);

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
    auto listingFile = "files.tex";
    auto modulesFile = "modules.tex";

    parseSources();

    generateDoc(docFileName);

    if (options.listing.enableListings)
      generateListings(listingFile);

    generateModules(modulesFile);

    generateDependencies(depGraphTexFile, depGraphFile);

    generateLangDef();
    generateMakeFile();
  }
}

void main(char[][] args) {
  Configurator config = new DefaultConfigurator();

  auto options = config.getConfiguration();
  options.parser.rootPaths = [ args[1] ];
  options.parser.importPaths = [ args[2] ];
  options.outputDir = args[3];

  auto generator = new LaTeXDocGenerator(*options);

  generator.generate();
}
