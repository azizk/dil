/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.writer;

public import docgen.misc.misc;
import dil.Parser;
import tango.io.model.IConduit : OutputStream, InputStream;

interface ListingWriter {
  void generateListing(Parser parser);
  void generateListing(InputStream input);
}

interface ListingWriterFactory : WriterFactory {
  ListingWriter createListingWriter(OutputStream[] outputs);
}