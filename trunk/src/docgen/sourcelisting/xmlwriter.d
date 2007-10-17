/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.xmlwriter;

public import docgen.sourcelisting.writer;
import dil.Parser;
import tango.io.protocol.Writer : Writer;
import tango.io.FileConduit : FileConduit;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;

/**
 * TODO
 */
class XMLWriter : AbstractWriter!(ListingWriterFactory, 2), ListingWriter {
  this(ListingWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
  }

  void generateListing(Parser parser) { /* TODO */ }
  void generateListing(InputStream input, char[] moduleName) { /* TODO */ }
}