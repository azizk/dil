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
    print.format(getTemplate("classes"), factory.options.templates.title);
  }

  override void generateModuleSection(Module[] modules) {
    print.format(getTemplate("modules"), factory.options.templates.title);
  }

  override void generateListingSection(Module[] modules) {
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
  override void generateCustomPage(char[] name, char[][] args ...) {
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
      "firstpage"[], "toc"[], "classes"[], "modules"[], "listing"[],
      "listings"[], "dependencies"[], "lastpage"[] ]) {
      if (name == pageName) {
        auto sprint = new Sprint!(char)(5120);
        char[] title = factory.options.templates.title ~ " ";
        switch(name) {
          case "firstpage": title ~= "Documentation"; break;
          case "toc": title ~= "TOC"; break;
          case "classes": title ~= "Class index"; break;
          case "modules": title ~= "Module index"; break;
          case "listing": title ~= "File contents"; break;
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
        default: print("<li>")(item)("</li>");
      }
    }
  }

  override void addListing(char[] moduleName, char[] contents, bool inline) {
    print.format(getTemplate("listing"), moduleName, contents);

    footer();
  }

  protected:

  /**
   * Writes the page footer.
   */
  void footer() {
    print.format(getTemplate("pagetemplate2"), docgen_version);
  }
}
