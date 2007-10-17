/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.htmlwriter;

public import docgen.sourcelisting.writer;
import dil.Parser;
import tango.io.protocol.Writer : Writer;
import tango.io.FileConduit : FileConduit;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;


/**
 * TODO
 */
class HTMLWriter : AbstractListingWriter {
  this(ListingWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
    assert(outputs.length == 2, "Wrong number of outputs");
  }

  void generateListing(Parser parser) { /* TODO */ }
  void generateListing(InputStream input) { /* TODO */ }
}