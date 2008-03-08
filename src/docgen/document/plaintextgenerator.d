/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.plaintextgenerator;

import docgen.document.generator;
import docgen.misc.misc;
import tango.io.stream.FileStream;
import tango.io.FilePath;
import tango.text.Util : replace;

class PlainTextDocGenerator : DefaultCachingDocGenerator {
  private:

  auto docFileNames = [
    "index.txt"[], "toc.txt"[], "classes.txt"[],
    "modules.txt"[], "files.txt"[]
  ];

  auto depGraphFile = "depgraph.dot";
  auto depGraphDocFile = "depgraph.txt";

  public:

  this(DocGeneratorOptions options, ParserDg parser, GraphCache graphcache) {
    genDir = "txt";
    docFormat = DocFormat.PlainText;
    
    super(options, parser, graphcache);
  }

  /**
   * Generates the documentation.
   */
  void generate() {
    parseSources();

    docWriter = pageFactory.createPageWriter( null, docFormat );

    generateDoc();

    if (options.listing.enableListings)
      generateListings();

    generateClasses();
    generateModules();
    generateDependencies();
    generateMakeFile(imageFormatExts[options.graph.imageFormat]);
  }

  protected:

  /**
   * Generates document skeleton.
   */
  void generateDoc() {
    writeSimpleFile(docFileNames[0], {
      docWriter.generateFirstPage();
    });
    
    writeSimpleFile(docFileNames[1], {
      docWriter.generateTOC(modules);
    });
  }

  /**
   * Generates documentation for classes.
   */
  void generateClasses() {
    writeSimpleFile(docFileNames[2], {
      docWriter.generateClassSection();
    });
  }

  /**
   * Generates documentation for modules.
   */
  void generateModules() {
    writeSimpleFile(docFileNames[3], {
      docWriter.generateModuleSection(modules);
    });
  }

  /**
   * Generates source file listings.
   */
  void generateListings() {
    writeSimpleFile(docFileNames[4], {
      docWriter.generateListingSection(modules);

      char[][] contents;

      foreach(mod; modules) {
        auto FQN = mod.moduleFQN;
        contents ~= FQN ~ " (see " ~ replace(FQN.dup, '.', '_') ~ ".d)";
      }

      docWriter.addList(contents, false);
    });

    foreach(mod; modules)
      (new FilePath(outPath(replace(mod.moduleFQN.dup, '.', '_') ~ ".d"))).copy(mod.filePath);
  }

  /**
   * Generates dependency graphs.
   */
  void generateDependencies() {
    writeSimpleFile(depGraphDocFile, {
      docWriter.generateDepGraphSection();

      auto imgFile = outputFile(depGraphFile);

      auto writer = graphFactory.createGraphWriter( docWriter, GraphFormat.Dot );
      writer.generateDepGraph(depGraph, imgFile);

      imgFile.close();
    });
  }
}
