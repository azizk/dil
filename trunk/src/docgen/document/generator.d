/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.generator;

import docgen.sourcelisting.writers;
import docgen.page.writers;
import docgen.graphutils.writers;
import docgen.misc.misc;
import docgen.misc.parser;
import docgen.config.configurator;
import tango.io.stream.FileStream;
import tango.io.FilePath;
import tango.io.FileScan;
debug import tango.io.Stdout;


alias void delegate(ref Module[], ref Edge[], ref Vertex[char[]]) ParserDg;

abstract class DefaultDocGenerator : DocGenerator {
  protected:

  DocFormat docFormat;
  auto makeFile = "make.sh";
  char[] genDir;

  DocGeneratorOptions m_options;
  ParserDg m_parser;
  PageWriter docWriter;

  GraphWriterFactory graphFactory;
  PageWriterFactory pageFactory;
  DefaultListingWriterFactory listingFactory;
  
  Module[] modules;
  Edge[] edges;
  Vertex[char[]] vertices;

  public:

  this(DocGeneratorOptions options, ParserDg parser) {
    m_options = options;
    m_parser = parser;

    createGraphWriterFactory();
    createPageWriterFactory();
    createListingWriterFactory();

    // create output dir
    (new FilePath(options.outputDir ~ "/" ~ genDir)).create();

    // copy static files
    copyStaticContent();
  }

  DocGeneratorOptions *options() {
    return &m_options;
  }

  protected:

  void createGraphWriterFactory() {
    graphFactory = new DefaultGraphWriterFactory(this);
  }

  void createPageWriterFactory() {
    pageFactory = new DefaultPageWriterFactory(this);
  }

  void createListingWriterFactory() {
    listingFactory = new DefaultListingWriterFactory(this);
  }

  char[] outPath(char[] file) {
    return options.outputDir ~ "/" ~ genDir ~ "/" ~ file;
  }

  void copyStaticContent() {
    auto scan = new FileScan();
    scan(templateDir~options.templates.templateStyle~"/"~formatDirs[docFormat]~"/static/");

    foreach(filePath; scan.files) {
      (new FilePath(outPath(filePath.file))).copy(filePath.toUtf8());
    }

    debug Stdout(scan.files.length)(" static files copied.\n");
  }

  FileOutput outputFile(char[] fname) {
    return new FileOutput(outPath(fname));
  }

  void parseSources() {
    m_parser(modules, edges, vertices);
  }

  //---

  void writeSimpleFile(char[] fname, void delegate() dg) {
    auto docFile = outputFile(fname);

    docWriter.setOutput([docFile]);
    dg();

    docFile.close();
  }

  /**
   * Generates "makefile" for processing e.g. .dot files.
   */
  void generateMakeFile(char[][] args ...) {
    writeSimpleFile(makeFile, { docWriter.generateCustomPage("makefile", args); } );
  }
  
}

abstract class DefaultCachingDocGenerator : DefaultDocGenerator, CachingDocGenerator {
  private:
    
  GraphCache m_graphCache;

  public:

  this(DocGeneratorOptions options, ParserDg parser, GraphCache graphCache) {
    super(options, parser);
    m_graphCache = graphCache;
  }
  
  GraphCache graphCache() {
    return m_graphCache;
  }

  protected:

  void createGraphWriterFactory() {
    graphFactory = new DefaultCachingGraphWriterFactory(this);
  }
}
