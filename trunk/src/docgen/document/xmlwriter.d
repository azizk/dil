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

  void generateDocument() { /* TODO */ }
}