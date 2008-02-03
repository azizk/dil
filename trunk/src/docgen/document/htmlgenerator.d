/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.htmlgenerator;

import docgen.document.generator;
import docgen.misc.misc;
import tango.io.stream.FileStream;
import tango.text.Util : replace;

class HTMLDocGenerator : DefaultCachingDocGenerator {
  private:

  auto docFileNames = [
    "index.html"[], "toc.html"[], "classes.html"[],
    "modules.html"[], "files.html"[]
  ];

  auto depGraphFile = "depgraph.dot";
  auto depGraphDocFile = "depgraph.html";
  auto styleSheetFile = "default.css";

  public:

  this(DocGeneratorOptions options, ParserDg parser, GraphCache graphcache) {
    genDir = "html";
    docFormat = DocFormat.HTML;
    super(options, parser, graphcache);
  }

  /**
   * Generates the documentation.
   */
  void generate() {
    parseSources();

    docWriter = pageFactory.createPageWriter( null, docFormat );

    // stylesheet needs to be created first to propagate the css file name
    generateStyleSheet();

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
    /*
    writeSimpleFile(docFileNames[1], {
      docWriter.generateTOC(modules);
      docWriter.generateCustomPage("pagetemplate2", docgen_version);
    });*/
  }

  /**
   * Generates a global style sheet.
   */
  void generateStyleSheet() {
    writeSimpleFile(styleSheetFile, {
      docWriter.generateCustomPage("stylesheet");
    });
  }

  /**
   * Generates documentation for classes.
   */
  void generateClasses() {
    writeSimpleFile(docFileNames[2], {
      docWriter.generateClassSection();
      docWriter.generateCustomPage("pagetemplate2", docgen_version);
    });
  }

  /**
   * Generates documentation for modules.
   */
  void generateModules() {
    writeSimpleFile(docFileNames[3], {
      docWriter.generateModuleSection(modules);
      docWriter.generateCustomPage("pagetemplate2", docgen_version);
    });
    
//    auto mdw = moduleDocFactory.createModuleDocWriter(docWriter, docFormat);

  }

  /**
   * Generates source file listings.
   */
  void generateListings() {
    writeSimpleFile(docFileNames[4], {
      docWriter.generateListingSection(modules);

      char[][] contents;

      contents ~= "(";

      foreach(mod; modules) {
        auto FQN = mod.moduleFQN;
        auto dstFname = replace(mod.moduleFQN.dup, '.', '_') ~ ".html";
        contents ~= `<a href="` ~ dstFname ~ `">` ~ FQN ~ "</a>";
      }

      contents ~= ")";

      docWriter.addList(contents, false);

      docWriter.generateCustomPage("pagetemplate2", docgen_version);
    });

    auto writer = listingFactory.createListingWriter(docWriter, docFormat);

    foreach(mod; modules) {
      auto dstFname = replace(mod.moduleFQN.dup, '.', '_') ~ ".html";

      writeSimpleFile(dstFname, {
        auto srcFile = new FileInput(mod.filePath);
        writer.generateListing(srcFile, null, mod.moduleFQN);
        srcFile.close();
      });
    }
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

      docWriter.generateCustomPage("pagetemplate2", docgen_version);
    });
  }
}
