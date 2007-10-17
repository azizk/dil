/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.templates.writers;

public import docgen.templates.writer;
import docgen.templates.htmlwriter;
import docgen.templates.xmlwriter;
import docgen.templates.plaintextwriter;
import docgen.templates.latexwriter;

class DefaultTemplateWriterFactory : AbstractWriterFactory, TemplateWriterFactory {
  this(DocGenerator generator) {
    super(generator);
  }

  TemplateWriter createTemplateWriter(OutputStream[] outputs) {
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
        throw new Exception("Template writer type does not exist!");
    }
  }
}