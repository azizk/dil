/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.writers;

public import docgen.sourcelisting.writer;
import dil.Parser;

class DefaultListingWriterFactory : AbstractListingWriterFactory {
  this(ListingOptions options) {
    m_options = options;
  }

  ListingWriter createListingWriter(OutputStream[] outputs) {
    switch (m_options.docFormat) {
      case DocFormat.LaTeX:
        return new LaTeXWriter(this, outputs);
      case DocFormat.XML:
        return new XMLWriter(this, outputs);
      case DocFormat.HTML:
        return new HTMLWriter(this, outputs);
      case DocFormat.PlainText:
        return new PlainTextWriter(this, outputs);
    }
  }
}


/**
 * TODO
 */
class LaTeXWriter : AbstractListingWriter {
  this(ListingWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
    assert(outputs.length == 2, "Wrong number of outputs");
  }

  void generateListing(Parser parser) { /* TODO */ }
  void generateListing(InputStream input) { /* TODO */ }
}


/**
 * TODO
 */
class XMLWriter : AbstractListingWriter {
  this(ListingWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
    assert(outputs.length == 2, "Wrong number of outputs");
  }

  void generateListing(Parser parser) { /* TODO */ }
  void generateListing(InputStream input) { /* TODO */ }
}


/**
 * TODO: add support for html/xml/latex?
 */
class HTMLWriter : AbstractListingWriter {
  this(ListingWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
    assert(outputs.length == 2, "Wrong number of outputs");
  }

  void generateListing(Parser parser) { /* TODO */ }
  void generateListing(InputStream input) { /* TODO */ }
}


/**
 * TODO
 */
class PlainTextWriter : AbstractListingWriter {
  this(ListingWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
    assert(outputs.length == 2, "Wrong number of outputs");
  }

  void generateListing(Parser parser) { /* TODO */ }
  void generateListing(InputStream input) { /* TODO */ }
}