/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.templates.xmlwriter;

import docgen.templates.writer;
import tango.io.FileConduit : FileConduit;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;

//TODO: this is mostly broken now

/**
 * TODO
 */
class XMLWriter : AbstractWriter!(TemplateWriterFactory, 1), TemplateWriter {
  this(TemplateWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
  }

  void generateTemplate() { /* TODO */ }
}