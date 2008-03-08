/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.page.writers;

public import docgen.page.writer;
import docgen.page.htmlwriter;
import docgen.page.xmlwriter;
import docgen.page.plaintextwriter;
import docgen.page.latexwriter;

class DefaultPageWriterFactory : AbstractWriterFactory, PageWriterFactory {
  this(DocGenerator generator) {
    super(generator);
  }

  PageWriter createPageWriter(OutputStream[] outputs, DocFormat outputFormat) {
    switch (outputFormat) {
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
