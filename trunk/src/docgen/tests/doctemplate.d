/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.tests.doctemplate;

import docgen.tests.common;
import docgen.document.writers;
import tango.io.Stdout;
import tango.io.FileConduit;
import tango.io.protocol.Writer : Writer;

// doc template
//@unittest
void doctemplate1() {
  auto gen = new TestDocGenerator;
  gen.options.docFormat = DocFormat.LaTeX;
  auto fname = "doctemplate.tex";
  
  auto gwf = new DefaultDocumentWriterFactory(gen);
  auto file = new FileConduit("docgen/teststuff/" ~ fname, FileConduit.WriteCreate);
  auto writer = gwf.createDocumentWriter( [ file ] );
  
  writer.generateDocument();
  
  file.close();
}