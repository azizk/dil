/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.plaintextgenerator;

import docgen.document.generator;
import docgen.misc.misc;
import tango.io.stream.FileStream;
import tango.text.Util : replace;

class PlainTextDocGenerator : DefaultDocGenerator!("txt") {
  this(DocGeneratorOptions options, ParserDg parser) {
    super(options, parser);
  }
  public void generate() { /* TODO */ }
}
