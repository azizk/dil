/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.docgen;

import docgen.graphutils.writers;
import docgen.config.configurator;
import docgen.document.latexgenerator;
import docgen.document.htmlgenerator;
import docgen.document.xmlgenerator;
import docgen.document.plaintextgenerator;

import tango.core.Array;
import tango.text.Ascii;
import tango.io.Stdout;

void usage() {
  Stdout(
    "Usage: docgen rootpath importpath_1 ... importpath_n outputdir"
  ).newline;
}

void main(char[][] args) {
  Stdout(docgen_version).newline.newline;

  if (args.length<3) {
    usage();
    return;
  }

  Configurator config = new DefaultConfigurator();

  auto options = config.getConfiguration();
  options.parser.rootPaths = [ args[1] ];
  options.parser.importPaths = args[2..$-1];
  options.outputDir = args[$-1];

  Module[] cachedModules;
  Edge[] cachedEdges;
  Vertex[char[]] cachedVertices;

  void parser(ref Module[] modules, ref Edge[] edges, ref Vertex[char[]] vertices) {
    if (cachedModules != null) {
      modules = cachedModules;
      edges = cachedEdges;
      vertices = cachedVertices;
      return;
    }

    int id = 1;

    Parser.loadModules(
      options.parser.rootPaths,
      options.parser.importPaths,
      options.parser.strRegexps,
      options.graph.includeUnlocatableModules,
      options.parser.depth,
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
      (Module imported, Module importer, bool isPublic) {
        debug Stdout.format("Connecting {} - {}.\n", imported.moduleFQN, importer.moduleFQN);
        auto edge = vertices[imported.moduleFQN].addChild(vertices[importer.moduleFQN]);
        edge.type = isPublic ? EdgeType.PublicDependency : EdgeType.Dependency;
        edge.type = id % 2 ? EdgeType.PublicDependency : EdgeType.Dependency; // FIXME: temporary feature for demonstrating public imports
        edges ~= edge;
      },
      modules
    );

    modules.sort(
      (Module a, Module b){ return icompare(a.moduleFQN, b.moduleFQN); }
    );

    cachedVertices = vertices;
    cachedModules = modules;
    cachedEdges = edges;
  }
  
  GraphCache graphcache = new DefaultGraphCache();

  foreach(format; options.outputFormats) {
    DocGenerator generator;

    switch(format) {
      case DocFormat.LaTeX:
        Stdout("Generating LaTeX docs..");
        generator = new LaTeXDocGenerator(*options, &parser, graphcache);
        break;
      case DocFormat.HTML:
        Stdout("Generating HTML docs..");
        generator = new HTMLDocGenerator(*options, &parser, graphcache);
        break;
      case DocFormat.XML:
        Stdout("Generating XML docs..");
        generator = new XMLDocGenerator(*options, &parser);
        break;
      case DocFormat.PlainText:
        Stdout("Generating plain text docs..");
        generator = new PlainTextDocGenerator(*options, &parser, graphcache);
        break;
      default: throw new Exception("Format not supported");
    }

    generator.generate();
    Stdout("done.").newline;
  }
}
