/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.docgen;

import docgen.document.generator;

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

import tango.io.Stdout;


class HTMLDocGenerator : DefaultDocGenerator!("html") {
  this(DocGeneratorOptions options) {
    super(options);
  }
  public void generate() { /* TODO */ }
}
class XMLDocGenerator : DefaultDocGenerator!("xml") {
  this(DocGeneratorOptions options) {
    super(options);
  }
  public void generate() { /* TODO */ }
}
class PlainTextDocGenerator : DefaultDocGenerator!("txt") {
  this(DocGeneratorOptions options) {
    super(options);
  }
  public void generate() { /* TODO */ }
}

/**
 * Main routine for LaTeX doc generation.
 */
class LaTeXDocGenerator : DefaultCachingDocGenerator!("latex") {
  this(DocGeneratorOptions options) {
    super(options);
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

  foreach(format; options.outputFormats) {
    DocGenerator generator;

    switch(format) {
      case DocFormat.LaTeX:
        generator = new LaTeXDocGenerator(*options);
        Stdout("Generating LaTeX docs..");
        break;
      case DocFormat.HTML:
        generator = new HTMLDocGenerator(*options);
        Stdout("Generating HTML docs..");
        break;
      case DocFormat.XML:
        generator = new XMLDocGenerator(*options);
        Stdout("Generating XML docs..");
        break;
      case DocFormat.PlainText:
        generator = new PlainTextDocGenerator(*options);
        Stdout("Generating plain text docs..");
        break;
      default: throw new Exception("Format not supported");
    }

    generator.generate();
    Stdout("done.").newline;
  }
}
