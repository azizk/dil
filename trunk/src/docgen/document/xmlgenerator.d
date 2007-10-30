/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.xmlgenerator;

import docgen.document.generator;
import docgen.misc.misc;
import tango.io.stream.FileStream;
import tango.text.Util : replace;

class XMLDocGenerator : DefaultDocGenerator!("xml") {
  this(DocGeneratorOptions options, ParserDg parser) {
    super(options, parser);
  }
  public void generate() { /* TODO */ }
}
