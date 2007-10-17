/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.tests.listing;

import docgen.misc.parser;
import docgen.tests.common;
import docgen.sourcelisting.writers;
import dil.Module;
import tango.io.Stdout;
import tango.io.FileConduit;
import tango.text.Util;
import tango.io.protocol.Writer : Writer;

// doc template
//@unittest
void listing1() {
  auto gen = new TestDocGenerator;
  gen.options.docFormat = DocFormat.LaTeX;
  auto fname = "files.tex";
  
  auto gwf = new DefaultListingWriterFactory(gen);
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
    auto writer = gwf.createListingWriter( [ file, dstFile ] );
    
    writer.generateListing(srcFile, mod.moduleFQN);

    srcFile.close();
    dstFile.close();
  }
  
  file.close();
}