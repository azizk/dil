/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.sourcelisting.htmlwriter;

import docgen.sourcelisting.writer;
import docgen.misc.textutils;
//import dil.Parser;
import tango.io.stream.FileStream;


/**
 * TODO
 */
class HTMLWriter : AbstractWriter!(ListingWriterFactory), ListingWriter {
  DocumentWriter writer;
  
  this(ListingWriterFactory factory, DocumentWriter writer) {
    super(factory);
    this.writer = writer;
  }
  
  //void generateListing(Parser parser) { /* TODO */ }
  
  void generateListing(InputStream input, OutputStream output, char[] moduleName) {
    auto inputStream = cast(FileInput)input;
    auto content = new char[inputStream.length];
    auto bytesRead = inputStream.read (content);
    
    assert(bytesRead == inputStream.length, "Error reading source file");
    
    writer.addListing(
      moduleName,
      xml_escape(content)
    );
  }
}
