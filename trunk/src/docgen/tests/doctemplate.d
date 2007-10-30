/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.tests.doctemplate;

import docgen.tests.common;
import docgen.page.writers;
import tango.io.FileConduit;

// doc template
//@unittest
void doctemplate1() {
  auto gen = new TestDocGenerator;
  auto fname = "doctemplate.tex";
  
  auto gwf = new DefaultPageWriterFactory(gen);
  auto file = new FileConduit("docgen/teststuff/" ~ fname, FileConduit.WriteCreate);
  auto writer = gwf.createPageWriter( [ file ], DocFormat.LaTeX );
  
  writer.generateFirstPage();
  writer.generateTOC(null);
  writer.generateModuleSection();
  writer.generateListingSection();
  writer.generateDepGraphSection();
  writer.generateIndexSection();
  writer.generateLastPage();
  
  file.close();
}
