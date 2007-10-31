/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.page.xmlwriter;

import docgen.page.writer;
import docgen.misc.textutils;
import tango.io.FileConduit : FileConduit;

//TODO: this is mostly broken now

/**
 * TODO
 */
class XMLWriter : AbstractPageWriter!("xml", 1) {
  this(PageWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
  }

  void generateTOC(Module[] modules) {
    // TODO
    print.format(getTemplate("toc"));
  }

  void generateModuleSection() {
    // TODO
    print.format(getTemplate("modules"));
  }

  void generateListingSection() {
    // TODO
    print.format(getTemplate("listings"));
  }

  void generateDepGraphSection() {
    // TODO
    print.format(getTemplate("dependencies"));
  }

  void generateIndexSection() { }

  void generateLastPage() { }

  void generateFirstPage() { }

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
