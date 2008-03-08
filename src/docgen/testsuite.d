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
  Stdout("Running..\n")();

  Stdout(" Test1\n")();
  graph1();
  Stdout(" Test2\n")();
  graph2();
  Stdout(" Test3\n")();
  graph3();
  Stdout(" Test4\n")();
  graph4();
  Stdout(" Test5\n")();
  graph5();
  Stdout(" Test6\n")();
  parse1();
  Stdout(" Test7\n")();
  parse2();
  Stdout(" Test8\n")();
  doctemplate1();
  Stdout(" Test9\n")();
  listing1();
//  loadConfig();
  Stdout("done.\n")();
}
