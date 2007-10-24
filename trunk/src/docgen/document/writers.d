/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.writers;

public import docgen.document.writer;
import docgen.document.htmlwriter;
import docgen.document.xmlwriter;
import docgen.document.plaintextwriter;
import docgen.document.latexwriter;

class DefaultDocumentWriterFactory : AbstractWriterFactory, DocumentWriterFactory {
  this(DocGenerator generator) {
    super(generator);
  }

  DocumentWriter createDocumentWriter(OutputStream[] outputs) {
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
        throw new Exception("Document writer type does not exist!");
    }
  }
}