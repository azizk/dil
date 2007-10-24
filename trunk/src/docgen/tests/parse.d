/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.tests.parse;

import docgen.misc.parser;
import tango.io.FileConduit;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;

void saveToFile(char[] fname, void delegate(Print!(char) file) foo) {
  auto file = new FileConduit("docgen/teststuff/" ~ fname, FileConduit.WriteCreate);
  auto output = new Print!(char)(new Layout!(char), file);
  
  foo(output);
  
  file.close();
}

// load some test files
//@unittest
void parse1() {
  saveToFile("parse1.txt", (Print!(char) file){
    Module[] modules;
  
    Parser.loadModules(
      [ "c" ], [ "docgen/teststuff/" ],
      null, true, -1,
      (char[] fqn, char[] path, Module m) {
        file.format("{0} = {1}\n", fqn, path);
      },
      (Module imported, Module importer) {
        file.format("{0} <- {1}\n",
          imported ? imported.moduleFQN : "null"[],
          importer ? importer.moduleFQN : "null"[]
        );
      },
      modules
    );
  });
}

// load the imports of dil
//@unittest
void parse2() {
  saveToFile("parse2.txt", (Print!(char) file){
    Module[] modules;
    
    Parser.loadModules(
      [ "docgen/testsuite" ], [".", "/home/jm/d/tango/"],
      null, true, -1,
      (char[] fqn, char[] path, Module m) {
        file.format("{0} = {1}\n", fqn, path);
      },
      (Module imported, Module importer) {
        file.format("{0} <- {1}\n",
          imported ? imported.moduleFQN : "null"[],
          importer ? importer.moduleFQN : "null"[]
        );
      },
      modules
    );
  });
}
