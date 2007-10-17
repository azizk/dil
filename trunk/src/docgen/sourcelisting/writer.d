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

abstract class AbstractListingWriter : ListingWriter {
  protected ListingWriterFactory factory;
  protected OutputStream[] outputs;

  this(ListingWriterFactory factory, OutputStream[] outputs) {
    this.factory = factory;
    this.outputs = outputs;
  }
}

interface ListingWriterFactory : WriterFactory {
  ListingWriter createListingWriter(OutputStream[] outputs);
}