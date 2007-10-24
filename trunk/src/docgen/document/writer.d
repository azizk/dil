/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.writer;

public import docgen.misc.misc;
import tango.io.model.IConduit : OutputStream;
import tango.util.time.Date;
import tango.util.time.Clock;
import tango.text.convert.Sprint;
import tango.io.stream.FileStream;
import tango.io.Stdout;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;

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
  char[] fn = "docgen/templates/"~style~"/"~format~"/"~templateName~".tpl";
  
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

const templateNames = [ "firstpage"[], "graphics"[], "listing"[] ];
//const templateNames = [ "firstpage", "toc", "module", "depGraph", "graphics" ];

interface DocumentWriter {
  void generateDocument();
  
  /**
   * Writes a tag for the given image to the output stream
   */ 
  void addGraphics(char[] imageFile);
  
  /**
   * Writes a tag for the given source listing to the output stream;
   */
  void addListing(char[] moduleName, char[] contents, bool inline = true);
}

interface DocumentWriterFactory : WriterFactory {
  DocumentWriter createDocumentWriter(OutputStream[] outputs);
}

template AbstractDocumentWriter(int n, char[] format) {
  abstract class AbstractDocumentWriter : AbstractWriter!(DocumentWriterFactory, n), DocumentWriter {
    protected char[][char[]] templates;
         
    this(DocumentWriterFactory factory, OutputStream[] outputs) {
      super(factory, outputs);
    
      foreach(tpl; templateNames) {
        templates[tpl] = loadTemplate(factory.options.templates.templateStyle, format, tpl);
      }
    }
  
    void addGraphics(char[] imageFile) {
      auto print = new Print!(char)(new Layout!(char), outputs[0]);
    
      print.format(templates["graphics"], imageFile);
    }
    
    void addListing(char[] moduleName, char[] contents, bool inline) {
      auto print = new Print!(char)(new Layout!(char), outputs[0]);
    
      print.format(templates["listing"], moduleName, contents);
    }
  }
}