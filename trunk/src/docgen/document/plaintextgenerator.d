/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.plaintextgenerator;

import docgen.document.generator;
import docgen.misc.misc;
import tango.io.stream.FileStream;
import tango.text.Util : replace;

class PlainTextDocGenerator : DefaultDocGenerator {
  public:

  this(DocGeneratorOptions options, ParserDg parser) {
    genDir = "txt";
    docFormat = DocFormat.PlainText;
    
    super(options, parser);
  }

  void generate() { /* TODO */ }
}
