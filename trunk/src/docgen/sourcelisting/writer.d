/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.writer;

import docgen.misc.misc;
public import docgen.page.writer;
//import dil.Parser;
import tango.io.model.IConduit : OutputStream, InputStream;

interface ListingWriter {
  //void generateListing(Parser parser);
  void generateListing(InputStream input, OutputStream output, char[] moduleName);
}

interface ListingWriterFactory : WriterFactory {
  ListingWriter createListingWriter(PageWriter writer, DocFormat outputFormat);
}
