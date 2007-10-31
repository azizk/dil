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
  private:

  char[] styleSheetFile;

  public:
  
  this(PageWriterFactory factory, OutputStream[] outputs) {
    super(factory);
  }

  override void generateClassSection() {
    // TODO
    print.format(getTemplate("classes"), factory.options.templates.title);
  }

  override void generateModuleSection(Module[] modules) {
    // TODO
    print.format(getTemplate("modules"), factory.options.templates.title);
  }

  override void generateListingSection(Module[] modules) {
    // TODO
    print.format(getTemplate("listings"), factory.options.templates.title);
  }

  override void generateDepGraphSection() {
    print.format(getTemplate("dependencies"), factory.options.templates.title);
  }

  void generateFirstPage() {
    print.format(
      getTemplate("firstpage"),
      factory.options.templates.title,
      factory.options.templates.versionString,
      factory.options.templates.copyright
    );

    footer();
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
      "firstpage"[], "toc"[], "classes"[], "modules"[], "listings"[],
      "dependencies"[], "lastpage"[] ]) {
      if (name == pageName) {
        auto sprint = new Sprint!(char)(5120);
        char[] title = factory.options.templates.title ~ " ";
        switch(name) {
          case "firstpage": title ~= "Documentation"; break;
          case "toc": title ~= "TOC"; break;
          case "classes": title ~= "Class index"; break;
          case "modules": title ~= "Module index"; break;
          case "listings": title ~= "File index"; break;
          case "dependencies": title ~="Dependencies"; break;
        }
        return
          sprint.format(super.getTemplate("pagetemplate"), styleSheetFile, title) ~
          content;
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

  protected:

  /**
   * Writes the page footer.
   */
  void footer() {
    print.format(getTemplate("pagetemplate2"), docgen_version);
  }
}
