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
import tango.io.FilePath;
import tango.io.FileScan;
public import docgen.misc.parser;

const templateDir = "docgen/templates/";

const formatDirs = [ "latex"[], "xml"[], "html"[], "plaintext"[] ];

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
   * Generates class documentation section.
   */
  void generateClassSection();

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
   * Generates a page using a custom template file.
   *
   * Some examples: style sheet, DTD files, makefiles.
   */
  void generateCustomPage(char[] name, char[][] args ...);
  
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

template AbstractPageWriter(char[] format, int n = 0) {
  abstract class AbstractPageWriter : AbstractWriter!(PageWriterFactory, n), PageWriter {
    protected:

    char[][char[]] m_templates;
    Print!(char) print;

    public:
         
    this(PageWriterFactory factory, OutputStream[] outputs) {
      this(factory);
      setOutput(outputs);
    }

    void setOutput(OutputStream[] outputs) {
      this.outputs = outputs;
      static if (n > 0)
        assert(outputs.length == n, "Incorrect number of outputs");

      print = new Print!(char)(new Layout!(char), outputs[0]);
    }

    void generateTOC(Module[] modules) {
      print.format(getTemplate("toc"));
    }

    void generateClassSection() {
      print.format(getTemplate("classes"));
    }

    void generateModuleSection() {
      print.format(getTemplate("modules"));
    }

    void generateListingSection() {
      print.format(getTemplate("listings"));
    }

    void generateDepGraphSection() {
      print.format(getTemplate("dependencies"));
    }

    void generateIndexSection() {
      print.format(getTemplate("index"));
    }

    void generateLastPage() {
      print.format(getTemplate("lastpage"));
    }

    void generateCustomPage(char[] name, char[][] args ...) {
      print.format(getTemplate(name), args);
    }

    //---

    void addGraphics(char[] imageFile) {
      print.format(getTemplate("graphics"), imageFile);
    }
    
    void addListing(char[] moduleName, char[] contents, bool inline) {
      print.format(getTemplate("listing"), moduleName, contents);
    }

    protected:

    this(PageWriterFactory factory) {
      super(factory);
    
      auto scan = new FileScan();
      scan(templateDir~factory.options.templates.templateStyle~"/"~format~"/", ".tpl");

      debug Stdout(scan.files.length)(" template files loaded.\n");

      foreach(tpl; scan.files) {
        m_templates[tpl.name] = loadTemplate(tpl.toUtf8());
      }
    }

    char[] getTemplate(char[] name) {
      auto tpl = name in m_templates;
      assert(tpl, "Error: template ["~format~"/"~name~"] not found!");
      return *tpl;
    }

    char[] loadTemplate(char[] fn) {
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
    
    char[] timeNow() {
      auto date = Clock.toDate;
      auto sprint = new Sprint!(char);
      return sprint.format("{0} {1} {2} {3}",
        date.asDay(),
        date.asMonth(),
        date.day,
        date.year);
    }
  }
}
