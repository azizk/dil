/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.latexwriter;

public import docgen.sourcelisting.writer;
import dil.Parser;
import tango.io.protocol.Writer : Writer;
import tango.io.FileConduit : FileConduit;
import tango.io.Print: Print;
import tango.io.FilePath;
import tango.text.convert.Layout : Layout;

/**
 * Adds a code listing section for the given file. 
 */
class LaTeXWriter : AbstractWriter!(ListingWriterFactory), ListingWriter {
  DocumentWriter writer;
  
  this(ListingWriterFactory factory, DocumentWriter writer) {
    super(factory);
    this.writer = writer;
  }

  void generateListing(Parser parser) { /* TODO */ }
  
  void generateListing(InputStream input, OutputStream output, char[] moduleName) {
    output.copy(input);
    
    writer.addListing(
      moduleName,
      FilePath((cast(FileConduit)output.conduit).toUtf8()).file
    );
  }
}
