/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.plaintextwriter;

import docgen.sourcelisting.writer;
import docgen.misc.textutils;
//import dil.Parser;
import tango.io.FilePath;

/**
 * TODO
 */
class PlainTextWriter : AbstractWriter!(ListingWriterFactory), ListingWriter {
  PageWriter writer;
  
  this(ListingWriterFactory factory, PageWriter writer) {
    super(factory);
    this.writer = writer;
  }

  //void generateListing(Parser parser) { /* TODO */ }
  
  void generateListing(InputStream input, OutputStream output, char[] moduleName) {
    output.copy(input);
    
    writer.addListing(
      moduleName,
      FilePath((cast(Object)output.conduit).toUtf8()).file
    );
  }
}
