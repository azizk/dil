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
class LaTeXDocGenerator : DefaultCachingDocGenerator {
  private:

  auto docFileName = "document.tex";
  auto depGraphDocFile = "dependencies.tex";
  auto depGraphFile = "depgraph.dot";
  auto listingFile = "files.tex";
  auto modulesFile = "modules.tex";
  auto langDefFile = "lstlang0.sty";

  public:

  this(DocGeneratorOptions options, ParserDg parser, GraphCache graphcache) {
    genDir = "latex";
    docFormat = DocFormat.LaTeX;

    super(options, parser, graphcache);
  }

  /**
   * Generates the documentation.
   */
  void generate() {
    parseSources();

    generateDoc();

    if (options.listing.enableListings)
      generateListings();

    generateClasses();
    generateModules();
    generateDependencies();
    generateLangDef();
    generateMakeFile(docFileName, "pdf");
  }

  protected:

  /**
   * Generates document skeleton.
   */
  void generateDoc() {
    auto docFile = outputFile(docFileName);
    docWriter = pageFactory.createPageWriter( [ docFile ], docFormat );

    docWriter.generateFirstPage();
    docWriter.generateTOC(modules);
    docWriter.generateClassSection();
    docWriter.generateModuleSection(modules);
    docWriter.generateListingSection(modules);
    docWriter.generateDepGraphSection();
    docWriter.generateIndexSection();
    docWriter.generateLastPage();

    docFile.close();
  }

  /**
   * Generates D language definition file.
   */
  void generateLangDef() {
    writeSimpleFile(langDefFile, { docWriter.generateCustomPage("langdef"); });
  }

  /**
   * Generates documentation for classes.
   */
  void generateClasses() {
    auto docFile = outputFile(modulesFile);
    docFile.close();
  }

  /**
   * Generates documentation for modules.
   */
  void generateModules() {
    auto docFile = outputFile(modulesFile);
    docFile.close();
  }

  /**
   * Generates source file listings.
   */
  void generateListings() {
    writeSimpleFile(listingFile, {
      auto writer = listingFactory.createListingWriter(docWriter, docFormat);

      foreach(mod; modules) {
        auto dstFname = replace(mod.moduleFQN.dup, '.', '_') ~ ".d";
        
        auto srcFile = new FileInput(mod.filePath);
        auto dstFile = outputFile(dstFname);
        
        writer.generateListing(srcFile, dstFile, mod.moduleFQN);

        srcFile.close();
        dstFile.close();
      }
    });
  }

  /**
   * Generates dependency graphs.
   */
  void generateDependencies() {
    writeSimpleFile(depGraphDocFile, {
      auto imgFile = outputFile(depGraphFile);

      auto writer = graphFactory.createGraphWriter( docWriter, GraphFormat.Dot );
      writer.generateDepGraph(vertices.values, edges, imgFile);

      imgFile.close();
    });
  }
}
