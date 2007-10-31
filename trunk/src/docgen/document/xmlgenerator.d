/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.xmlgenerator;

import docgen.document.generator;
import docgen.misc.misc;
import tango.io.stream.FileStream;
import tango.text.Util : replace;

class XMLDocGenerator : DefaultDocGenerator {
  public:

  this(DocGeneratorOptions options, ParserDg parser) {
    genDir = "xml";
    docFormat = DocFormat.XML;

    super(options, parser);
  }

  void generate() { /* TODO */ }
}
