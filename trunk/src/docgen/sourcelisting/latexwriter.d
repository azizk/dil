/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.latexwriter;

public import docgen.sourcelisting.writer;
import dil.Parser;
import tango.io.protocol.Writer : Writer;
import tango.io.FileConduit : FileConduit;
import tango.io.Buffer : Buffer;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;

/**
 * Adds a code listing section for the given file. 
 */
class LaTeXWriter : AbstractListingWriter {
  this(ListingWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
    assert(outputs.length == 2, "Wrong number of outputs");
  }

  void generateListing(Parser parser) {
    auto output2 = new Print!(char)(new Layout!(char), outputs[0]);
    auto output = new Print!(char)(new Layout!(char), outputs[1]);
    /* TODO */
  }
  
  void generateListing(InputStream input) {
    auto output2 = new Print!(char)(new Layout!(char), outputs[0]);

    if (cast(FileConduit)outputs[1]) {
      char[] fn = (cast(FileConduit)outputs[1]).toUtf8();
      output2.format("\\lstinputlisting[language=d]{{{0}}", fn);
    }
    
    auto buf = new Buffer(256);
    buf.output = outputs[1];
    buf.copy(input);
  }
}
