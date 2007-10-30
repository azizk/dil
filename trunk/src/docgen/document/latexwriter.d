/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.latexwriter;

import docgen.document.writer;
import tango.io.FileConduit : FileConduit;

/**
 * Writes a LaTeX document skeleton.
 */
class LaTeXWriter : AbstractDocumentWriter!(1, "latex") {
  this(DocumentWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
  }

  void generateFirstPage() {
    print.format(
      templates["firstpage"],
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
