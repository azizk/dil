/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.latexgenerator;

import docgen.document.generator;
import docgen.misc.misc;
import tango.io.stream.FileStream;
import tango.text.Util : replace;

/**
 * Main routine for LaTeX doc generation.
 */
class LaTeXDocGenerator : DefaultCachingDocGenerator!("latex") {
  auto docFileName = "document.tex";
  auto depGraphTexFile = "dependencies.tex";
  auto depGraphFile = "depgraph.dot";
  auto listingFile = "files.tex";
  auto modulesFile = "modules.tex";
  auto langDefFile = "lstlang0.sty";
  auto makeFile = "make.sh";

  this(DocGeneratorOptions options, ParserDg parser, GraphCache graphcache) {
    super(options, parser, graphcache);
  }

  /**
   * Generates document skeleton.
   */
  void generateDoc(char[] docFileName) {
    auto docFile = new FileOutput(outPath(docFileName));
    docWriter = pageFactory.createPageWriter( [ docFile ], DocFormat.LaTeX );

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
    auto docFile = new FileOutput(outPath(langDefFile));

    docWriter.setOutput([docFile]);
    docWriter.generateLangDef();

    docFile.close();
  }

  /**
   * Generates "makefile" for processing the .dot and .tex files.
   */
  void generateMakeFile() {
    auto docFile = new FileOutput(outPath(makeFile));

    docWriter.setOutput([docFile]);
    docWriter.generateMakeFile();

    docFile.close();
  }

  /**
   * Generates documentation for modules.
   */
  void generateModules() {
    auto docFile = new FileOutput(outPath(modulesFile));
    docFile.close();
  }

  /**
   * Generates source file listings.
   */
  void generateListings() {
    auto docFile = new FileOutput(outPath(listingFile));

    docWriter.setOutput([docFile]);
    auto writer = listingFactory.createListingWriter(docWriter, DocFormat.LaTeX);

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
  void generateDependencies() {
    auto docFile = new FileOutput(outPath(depGraphTexFile));

    docWriter.setOutput([docFile]);
    createDepGraph(depGraphFile);

    docFile.close();
  }

  /**
   * Generates the documentation.
   */
  public void generate() {
    parseSources();

    generateDoc(docFileName);

    if (options.listing.enableListings)
      generateListings();

    generateModules();
    generateDependencies();
    generateLangDef();
    generateMakeFile();
  }
}
