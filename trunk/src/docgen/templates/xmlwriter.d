/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.templates.xmlwriter;

import docgen.templates.writer;
import tango.io.FileConduit : FileConduit;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;

/**
 * TODO
 */
class XMLWriter : AbstractTemplateWriter {
  this(TemplateWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
    assert(outputs.length == 1, "Wrong number of outputs");
  }

  void generateTemplate() { /* TODO */ }
}