module docgen.document.generator;

import docgen.sourcelisting.writers;
import docgen.page.writers;
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
    PageWriter docWriter;

    GraphWriterFactory graphFactory;
    PageWriterFactory pageFactory;
    
    Module[] modules;
    Edge[] edges;
    Vertex[char[]] vertices;

    this(DocGeneratorOptions options) {
      m_options = options;

      createGraphWriterFactory();
      createPageWriterFactory();

      // create output dir
      (new FilePath(options.outputDir ~ "/" ~ genDir)).create();
    }

    // TODO: constructor for situations where parsing has happened elsewhere

    protected void createGraphWriterFactory() {
      graphFactory = new DefaultGraphWriterFactory(this);
    }

    protected void createPageWriterFactory() {
      pageFactory = new DefaultPageWriterFactory(this);
    }

    protected char[] outPath(char[] file) {
      return options.outputDir ~ "/" ~ genDir ~ "/" ~ file;
    }

    protected void parseSources() {
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

      modules.sort(
        (Module a, Module b){ return icompare(a.moduleFQN, b.moduleFQN); }
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

template DefaultCachingDocGenerator(char[] genDir) {
  abstract class DefaultCachingDocGenerator : DefaultDocGenerator!(genDir), CachingDocGenerator {
    this(DocGeneratorOptions options) {
      super(options);
    }
    
    private char[][Object[]][Object[]][GraphFormat] m_graphCache;

    char[] getCachedGraph(Object[] vertices, Object[] edges, GraphFormat format) {
      auto lookup1 = format in m_graphCache;
      if (lookup1) {
        auto lookup2 = edges in *lookup1;
        if (lookup2) {
          auto lookup3 = vertices in *lookup2;
          if (lookup3)
            return *lookup3;
        }
      }
      return null;
    }

    protected void createGraphWriterFactory() {
      graphFactory = new DefaultCachingGraphWriterFactory(this);
    }
  }
}
