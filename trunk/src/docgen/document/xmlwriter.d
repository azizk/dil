/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.xmlwriter;

import docgen.document.writer;
import tango.io.FileConduit : FileConduit;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;

//TODO: this is mostly broken now

/**
 * TODO
 */
class XMLWriter : AbstractDocumentWriter!(2, "xml") {
  this(DocumentWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
  }

  void generateTOC(Module[] modules) {
    // TODO
    auto print = new Print!(char)(new Layout!(char), outputs[0]);
  
    print.format(templates["toc"]);
  }

  void generateModuleSection() {
    // TODO
    auto print = new Print!(char)(new Layout!(char), outputs[0]);
  
    print.format(templates["modules"]);
  }

  void generateListingSection() {
    // TODO
    auto print = new Print!(char)(new Layout!(char), outputs[0]);
  
    print.format(templates["listings"]);
  }

  void generateDepGraphSection() {
    // TODO
    auto print = new Print!(char)(new Layout!(char), outputs[0]);
  
    print.format(templates["dependencies"]);
  }

  void generateIndexSection() { }

  void generateLastPage() { }

  void generateFirstPage() { }
}
