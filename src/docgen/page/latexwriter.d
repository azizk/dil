/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.page.latexwriter;

import docgen.page.writer;
import tango.io.FileConduit : FileConduit;

/**
 * Writes a LaTeX document skeleton.
 */
class LaTeXWriter : AbstractPageWriter!("latex", 1) {
  this(PageWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
  }

  void generateFirstPage() {
    print.format(
      getTemplate("firstpage"),
      factory.options.templates.paperSize,
      factory.options.templates.title,
      factory.options.templates.versionString,
      docgen_version,
      timeNow(),
      factory.options.listing.literateStyle ? "" : "%"
    );
  }

  void addList(char[][] contents, bool ordered) {
    foreach(item; contents) {
      switch(item) {
        case "(": print(ordered ? "\\begin{enumerate}" : "\\begin{itemize}"); continue;
        case ")": print(ordered ? "\\end{enumerate}" : "\\end{itemize}"); continue;
        default: print("\\item")(item)(\n);
      }
    }
  }
}
