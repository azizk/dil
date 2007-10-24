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
class XMLWriter : AbstractWriter!(ListingWriterFactory), ListingWriter {
  DocumentWriter writer;
  
  this(ListingWriterFactory factory, DocumentWriter writer) {
    super(factory);
    this.writer = writer;
  }

  void generateListing(Parser parser) { /* TODO */ }
  void generateListing(InputStream input, OutputStream output, char[] moduleName) { /* TODO */ }
}