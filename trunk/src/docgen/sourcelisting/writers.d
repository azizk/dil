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

  ListingWriter createListingWriter(DocumentWriter writer, DocFormat outputFormat) {
    switch (outputFormat) {
      case DocFormat.LaTeX:
        return new LaTeXWriter(this, writer);
      case DocFormat.XML:
        return new XMLWriter(this, writer);
      case DocFormat.HTML:
        return new HTMLWriter(this, writer);
      case DocFormat.PlainText:
        return new PlainTextWriter(this, writer);
      default:
        throw new Exception("Listing writer type does not exist!");
    }
  }
}
