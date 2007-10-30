/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.htmlwriter;

import docgen.document.writer;
import docgen.misc.textutils;
import tango.io.FileConduit : FileConduit;

// TODO: this is mostly broken now

/**
 * Writes a HTML document skeleton.
 */
class HTMLWriter : AbstractDocumentWriter!(2, "html") {
  this(DocumentWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
  }

  void generateTOC(Module[] modules) {
    // TODO
    print.format(templates["toc"]);
  }

  void generateModuleSection() {
    // TODO
    print.format(templates["modules"]);
  }

  void generateListingSection() {
    // TODO
    print.format(templates["listings"]);
  }

  void generateDepGraphSection() {
    // TODO
    print.format(templates["dependencies"]);
  }

  void generateIndexSection() { }

  void generateLastPage() { }

  void generateFirstPage() {
    print.format(
      templates["firstpage"],
      factory.options.templates.title,
      factory.options.templates.copyright,
      factory.options.templates.versionString,
      docgen_version
    );
  }

  void addList(char[][] contents, bool ordered) {
    foreach(item; contents) {
      switch(item) {
        case "(": print(ordered ? "<ol>" : "<ul>"); continue;
        case ")": print(ordered ? "</ol>" : "</ul>"); continue;
        default: print("<li>")(xml_escape(item))("</li>");
      }
    }
  }
}
