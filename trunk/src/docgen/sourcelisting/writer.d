/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.writer;

public import docgen.misc.misc;
public import docgen.document.writer;
import dil.Parser;
import tango.io.model.IConduit : OutputStream, InputStream;

interface ListingWriter {
  void generateListing(Parser parser);
  void generateListing(InputStream input, OutputStream output, char[] moduleName);
}

interface ListingWriterFactory : WriterFactory {
  ListingWriter createListingWriter(DocumentWriter writer);
}