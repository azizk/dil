/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.writers;

public import docgen.sourcelisting.writer;
import docgen.sourcelisting.latexwriter;
import docgen.sourcelisting.htmlwriter;
import docgen.sourcelisting.xmlwriter;
import docgen.sourcelisting.plaintextwriter;

class DefaultListingWriterFactory : AbstractWriterFactory, ListingWriterFactory {
  this(DocGenerator generator) {
    super(generator);
  }

  ListingWriter createListingWriter(OutputStream[] outputs) {
    switch (options.docFormat) {
      case DocFormat.LaTeX:
        return new LaTeXWriter(this, outputs);
      case DocFormat.XML:
        return new XMLWriter(this, outputs);
      case DocFormat.HTML:
        return new HTMLWriter(this, outputs);
      case DocFormat.PlainText:
        return new PlainTextWriter(this, outputs);
      default:
        throw new Exception("Listing writer type does not exist!");
    }
  }
}