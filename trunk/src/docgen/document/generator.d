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
debug import tango.io.Stdout;

alias void delegate(ref Module[], ref Edge[], ref Vertex[char[]]) ParserDg;

template DefaultDocGenerator(char[] genDir) {
  abstract class DefaultDocGenerator : DocGenerator {
    DocGeneratorOptions m_options;
    ParserDg m_parser;
    PageWriter docWriter;

    GraphWriterFactory graphFactory;
    PageWriterFactory pageFactory;
    DefaultListingWriterFactory listingFactory;
    
    Module[] modules;
    Edge[] edges;
    Vertex[char[]] vertices;

    this(DocGeneratorOptions options, ParserDg parser) {
      m_options = options;
      m_parser = parser;

      createGraphWriterFactory();
      createPageWriterFactory();
      createListingWriterFactory();

      // create output dir
      (new FilePath(options.outputDir ~ "/" ~ genDir)).create();
    }

    protected void createGraphWriterFactory() {
      graphFactory = new DefaultGraphWriterFactory(this);
    }

    protected void createPageWriterFactory() {
      pageFactory = new DefaultPageWriterFactory(this);
    }

    protected void createListingWriterFactory() {
      listingFactory = new DefaultListingWriterFactory(this);
    }

    protected char[] outPath(char[] file) {
      return options.outputDir ~ "/" ~ genDir ~ "/" ~ file;
    }

    protected void parseSources() {
      m_parser(modules, edges, vertices);
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

template DefaultCachingDocGenerator(char[] genDir) {
  abstract class DefaultCachingDocGenerator : DefaultDocGenerator!(genDir), CachingDocGenerator {
    GraphCache m_graphCache;

    this(DocGeneratorOptions options, ParserDg parser, GraphCache graphCache) {
      super(options, parser);
      m_graphCache = graphCache;
    }
    
    GraphCache graphCache() {
      return m_graphCache;
    }

    protected void createGraphWriterFactory() {
      graphFactory = new DefaultCachingGraphWriterFactory(this);
    }
  }
}
