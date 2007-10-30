/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.page.writer;

public import docgen.misc.misc;
import tango.io.model.IConduit : OutputStream;
import tango.util.time.Date;
import tango.util.time.Clock;
import tango.text.convert.Sprint;
import tango.io.stream.FileStream;
import tango.io.Stdout;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;
public import docgen.misc.parser;

const templateDir = "docgen/templates/";

// template file names
const templateNames = [
  "firstpage"[], "toc"[], "modules"[],
  "listings"[], "dependencies"[], "index"[],
  "lastpage"[], "langdef"[], "makefile"[],
  "graphics"[], "listing"[]
];

/**
 * Writes the logical subcomponents of a document,
 * e.g. sections, embedded graphics, lists
 */
interface PageWriter {
  /**
   * Updates the outputstreams.
   */
  void setOutput(OutputStream[] outputs);

  /**
   * Generates the first page(s).
   */
  void generateFirstPage();

  /**
   * Generates table of contents.
   */
  void generateTOC(Module[] modules);

  /**
   * Generates module documentation section.
   */
  void generateModuleSection();

  /**
   * Generates source code listing section.
   */
  void generateListingSection();

  /**
   * Generates dependency graph section.
   */
  void generateDepGraphSection();

  /**
   * Generates an index section.
   */
  void generateIndexSection();

  /**
   * Generates the last page(s).
   */
  void generateLastPage();

  /**
   * Generates a language definition file [LaTeX].
   * Could be used for DTD too, I suppose.
   */
  void generateLangDef();

  /**
   * Generates a makefile used for document post-processing.
   */
  void generateMakeFile();
  
  // --- page components
  //
  /*
   * Adds an external graphics file. 
   */
  void addGraphics(char[] imageFile);
  
  /**
   * Adds a source code listing.
   */
  void addListing(char[] moduleName, char[] contents, bool inline = true);

  /**
   * Adds a list of items.
   */
  void addList(char[][] contents, bool ordered);
}

interface PageWriterFactory : WriterFactory {
  PageWriter createPageWriter(OutputStream[] outputs, DocFormat outputFormat);
}


char[] timeNow() {
  auto date = Clock.toDate;
  auto sprint = new Sprint!(char);
  return sprint.format("{0} {1} {2} {3}",
    date.asDay(),
    date.asMonth(),
    date.day,
    date.year);
}

char[] loadTemplate(char[] style, char[] format, char[] templateName) {
  char[] fn = templateDir~style~"/"~format~"/"~templateName~".tpl";
  
  scope(failure) {
    Stderr("Warning: error opening template "~fn~".");
    return null;
  }

  auto file = new FileInput(fn);
  auto content = new char[file.length];
  auto bytesRead = file.read(content);
  
  assert(bytesRead == file.length, "Error reading template");
  
  file.close();
  
  return content;
}

template AbstractPageWriter(int n, char[] format) {
  abstract class AbstractPageWriter : AbstractWriter!(PageWriterFactory, n), PageWriter {
    protected char[][char[]] templates;
    protected Print!(char) print;
         
    this(PageWriterFactory factory, OutputStream[] outputs) {
      super(factory, outputs);
      setOutput(outputs);
    
      foreach(tpl; templateNames) {
        templates[tpl] = loadTemplate(factory.options.templates.templateStyle, format, tpl);
      }
    }

    void setOutput(OutputStream[] outputs) {
      this.outputs = outputs;

      print = new Print!(char)(new Layout!(char), outputs[0]);
    }

    void generateTOC(Module[] modules) {
      print.format(templates["toc"]);
    }

    void generateModuleSection() {
      print.format(templates["modules"]);
    }

    void generateListingSection() {
      print.format(templates["listings"]);
    }

    void generateDepGraphSection() {
      print.format(templates["dependencies"]);
    }

    void generateIndexSection() {
      print.format(templates["index"]);
    }

    void generateLastPage() {
      print.format(templates["lastpage"]);
    }

    void generateLangDef() {
      print(templates["langdef"]);
    }

    void generateMakeFile() {
      print(templates["makefile"]);
    }


    void addGraphics(char[] imageFile) {
      print.format(templates["graphics"], imageFile);
    }
    
    void addListing(char[] moduleName, char[] contents, bool inline) {
      print.format(templates["listing"], moduleName, contents);
    }
  }
}
