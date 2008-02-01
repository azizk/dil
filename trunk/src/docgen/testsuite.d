/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.testsuite;

import docgen.tests.graphs;
import docgen.tests.parse;
import docgen.tests.doctemplate;
import docgen.tests.listing;
//import docgen.tests.sexp;
import tango.io.Stdout;

/**
 * A temporary test program for the docgen package.
 * I'll replace this with proper unittests in the future.
 *
 */
void main() {
  Stdout("Running..");

  graph1();
  graph2();
  graph3();
  graph4();
  graph5();
  parse1();
  parse2();
  doctemplate1();
  listing1();
//  loadConfig();
  Stdout("done.\n");
}
