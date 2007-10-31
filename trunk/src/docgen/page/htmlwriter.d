/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.page.htmlwriter;

import docgen.page.writer;
import docgen.misc.textutils;
import tango.io.FileConduit : FileConduit;
import tango.text.convert.Sprint;
import tango.io.FilePath;

// TODO: this is mostly broken now

/**
 * Writes a HTML document skeleton.
 */
class HTMLWriter : AbstractPageWriter!("html") {
  char[] styleSheetFile;
  
  this(PageWriterFactory factory, OutputStream[] outputs) {
    super(factory);
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

  void generateFirstPage() {
    print.format(
      getTemplate("firstpage"),
      factory.options.templates.title,
      factory.options.templates.versionString,
      docgen_version,
      factory.options.templates.copyright
    );
  }
  
  /**
   * A hack for figuring out the stylesheet file name.
   */
  void generateCustomPage(char[] name, char[][] args ...) {
    super.generateCustomPage(name, args);

    if (name == "stylesheet") {
      styleSheetFile = (new FilePath(
        (cast(Object)outputs[0].conduit).toUtf8())).file();
    }
  }

  /**
   * Overrides the default template fetcher in order to
   * provide a consistent layout for all pages.
   */
  override char[] getTemplate(char[] name) {
    auto content = super.getTemplate(name);

    foreach(pageName; [
      "firstpage"[], "toc"[], "classes"[], "modules"[], "files"[],
      "dependencies"[], "index"[], "lastpage"[] ]) {
      if (name == pageName) {
        auto sprint = new Sprint!(char)(5120);
        return sprint.format(
          super.getTemplate("pagetemplate"),
          styleSheetFile,
          name, // FIXME
          content,
          docgen_version);
      }
    }

    return content;
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
