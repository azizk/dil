/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.moduledoc.writers;

public import docgen.moduledoc.writer;
//import docgen.moduledoc.latexwriter;
import docgen.moduledoc.htmlwriter;
//import docgen.moduledoc.xmlwriter;

class DefaultModuleDocWriterFactory : AbstractWriterFactory, ModuleDocWriterFactory {
  this(DocGenerator generator) {
    super(generator);
  }

  ModuleDocWriter createModuleDocWriter(PageWriter writer, DocFormat outputFormat) {
    switch (outputFormat) {/*
      case DocFormat.LaTeX:
        return new LaTeXWriter(this, writer);
      case DocFormat.XML:
        return new XMLWriter(this, writer);*/
      case DocFormat.HTML:
        return new HTMLWriter(this, writer);
      default:
        throw new Exception("Moduledoc writer type does not exist!");
    }
  }
}

