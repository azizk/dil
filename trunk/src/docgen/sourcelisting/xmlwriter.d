/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.xmlwriter;

import docgen.sourcelisting.writer;
//import dil.Parser;

/**
 * TODO
 */
class XMLWriter : AbstractWriter!(ListingWriterFactory), ListingWriter {
  PageWriter writer;
  
  this(ListingWriterFactory factory, PageWriter writer) {
    super(factory);
    this.writer = writer;
  }

  //void generateListing(Parser parser) { /* TODO */ }
  void generateListing(InputStream input, OutputStream output, char[] moduleName) { /* TODO */ }
}
