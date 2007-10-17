/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.tests.doctemplate;

import docgen.templates.writers;
import tango.io.Stdout;
import tango.io.FileConduit;
import tango.io.protocol.Writer : Writer;


// doc template
//@unittest
void doctemplate1() {
  TemplateOptions test;
  test.docFormat = DocFormat.LaTeX;
  auto fname = "doctemplate.tex";
  
  auto gwf = new DefaultTemplateWriterFactory(test);
  auto file = new FileConduit("docgen/teststuff/" ~ fname, FileConduit.WriteCreate);
  auto writer = gwf.createTemplateWriter( [ file ] );
  
  writer.generateTemplate();
  
  file.close();
}