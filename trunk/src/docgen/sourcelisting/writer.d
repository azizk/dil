/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.writer;

public import docgen.misc.misc;
import dil.Parser;
import tango.io.model.IConduit : OutputStream, InputStream;

struct ListingOptions {
  DocFormat docFormat;
}

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

interface ListingWriterFactory {
  ListingOptions *options();
  ListingWriter createListingWriter(OutputStream[] outputs);
}

abstract class AbstractListingWriterFactory : ListingWriterFactory {
  protected ListingOptions m_options;

  public ListingOptions *options() {
    return &m_options;
  }
}