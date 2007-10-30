/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.tests.listing;

import docgen.misc.parser;
import docgen.tests.common;
import docgen.sourcelisting.writers;
import docgen.page.writers;
import tango.io.FileConduit;
import tango.text.Util;

// doc template
//@unittest
void listing1() {
  auto gen = new TestDocGenerator;
  gen.options.outputFormats = [ DocFormat.LaTeX ];
  auto fname = "files.tex";
  
  auto ddf = new DefaultPageWriterFactory(gen);
  auto dlwf = new DefaultListingWriterFactory(gen);
  auto file = new FileConduit("docgen/teststuff/" ~ fname, FileConduit.WriteCreate);
  

  Module[] modules;

  Parser.loadModules(
    [ "c" ], [ "docgen/teststuff/" ],
    null, true, -1,
    (char[] fqn, char[] path, Module m) {},
    (Module imported, Module importer) {},
    modules
  );
  
  foreach(mod; modules) {
    auto dstFname = replace(mod.moduleFQN.dup, '.', '_');
    
    auto srcFile = new FileConduit(mod.filePath);
    auto dstFile = new FileConduit("docgen/teststuff/_" ~ dstFname ~ ".d", FileConduit.WriteCreate);
    auto writer = dlwf.createListingWriter( ddf.createPageWriter( [ file ],
          DocFormat.LaTeX ), DocFormat.LaTeX );
    
    writer.generateListing(srcFile, dstFile, mod.moduleFQN);

    srcFile.close();
    dstFile.close();
  }
  
  file.close();
}
