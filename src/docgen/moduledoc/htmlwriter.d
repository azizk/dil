/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.moduledoc.htmlwriter;

import docgen.moduledoc.writer;
import docgen.misc.textutils;


/**
 * TODO
 */
class HTMLWriter : AbstractWriter!(ModuleDocWriterFactory), ModuleDocWriter {
  PageWriter writer;
  
  this(ModuleDocWriterFactory factory, PageWriter writer) {
    super(factory);
    this.writer = writer;
  }
  
  void generateModuleDoc(Module mod, OutputStream output) {
    
					/*
    auto inputStream = cast(FileInput)input;
    auto content = new char[inputStream.length];
    auto bytesRead = inputStream.read (content);
    
    assert(bytesRead == inputStream.length, "Error reading source file");
    assert(output == null);
    
    writer.addListing(
      moduleName,
      xml_escape(content)
    );*/
  }
}

