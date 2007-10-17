/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.latexwriter;

public import docgen.sourcelisting.writer;
import dil.Parser;
import tango.io.protocol.Writer : Writer;
import tango.io.FileConduit : FileConduit;
import tango.io.Print;
import tango.io.FilePath;
import tango.text.convert.Layout : Layout;

/**
 * Adds a code listing section for the given file. 
 */
class LaTeXWriter : AbstractWriter!(ListingWriterFactory, 2), ListingWriter {
  this(ListingWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
  }

  void generateListing(Parser parser) {
    auto output2 = new Print!(char)(new Layout!(char), outputs[0]);
    auto output = new Print!(char)(new Layout!(char), outputs[1]);
    /* TODO */
  }
  
  void generateListing(InputStream input, char[] moduleName) {
    auto output2 = new Print!(char)(new Layout!(char), outputs[0]);

    if (cast(FileConduit)outputs[1]) {
      char[] fn = (cast(FileConduit)outputs[1]).toUtf8();
      fn = FilePath(fn).file;
      output2.format("\\section{{Module {0}}\n", moduleName);
      output2.format("\\lstinputlisting[language=d]{{{0}}\n", fn);
    }
    outputs[1].copy(input);
  }
}
