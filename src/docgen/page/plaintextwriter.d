/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.page.plaintextwriter;

import docgen.page.writer;
import docgen.misc.textutils;
import tango.io.FileConduit : FileConduit;

/**
 * Writes a plain text document skeleton.
 */
class PlainTextWriter : AbstractPageWriter!("plaintext") {
  this(PageWriterFactory factory, OutputStream[] outputs) {
    super(factory);
  }

  override void generateTOC(Module[] modules) {
    print.format(getTemplate("toc"));
  }

  override void generateModuleSection(Module[] modules) {
    print.format(getTemplate("modules"));
  }

  override void generateListingSection(Module[] modules) {
    print.format(getTemplate("listings"));
  }

  void generateDepGraphSection() {
    print.format(getTemplate("dependencies"));
  }

  void generateFirstPage() {
    print.format(getTemplate("firstpage"),
      plainTextHeading(factory.options.templates.title ~ " Reference Manual"),
      factory.options.templates.versionString,
      docgen_version,
      timeNow()
    );
  }

  void addList(char[][] contents, bool ordered) {
    uint[] counters;
    foreach(item; contents) {
      switch(item) {
        case "(": counters ~= 1; continue;
        case ")": counters.length = counters.length - 1; continue;
        default:
        if (counters.length>0)
          for (int i=0; i <= counters.length; i++)
            print(" ");
        if (ordered)
          print(++counters[$-1])(". ")(item)(\n);
        else
          print("* ")(item)(\n);
      }
    }
  }
}
