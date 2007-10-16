/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.testsuite;

import docgen.tests.graphs;
import docgen.tests.parse;
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
  parse1();
  parse2();
  Stdout("done.\n");
}
