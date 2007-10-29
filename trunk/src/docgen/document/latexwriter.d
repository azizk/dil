/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.document.latexwriter;

import docgen.document.writer;
import tango.io.FileConduit : FileConduit;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;

/**
 * Writes a LaTeX document skeleton.
 */
class LaTeXWriter : AbstractDocumentWriter!(1, "latex") {
  this(DocumentWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
  }

  void generateFirstPage() {
    auto print = new Print!(char)(new Layout!(char), outputs[0]);
    
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
}
