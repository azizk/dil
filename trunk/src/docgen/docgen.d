/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.docgen;

import docgen.modulegraph.writer;

struct DocGeneratorOptions {
  GraphWriterOptions graph;
  ListingsOptions listings;
  CommentFormat commentFormat;
}

/**
 * Main routine for doc generation.
 */
class DocGenerator {
  public static void generate() {

  }
}