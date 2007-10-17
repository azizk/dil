/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.docgen;

import docgen.modulegraph.writer;
import docgen.sourcelisting.writer;
import docgen.templates.writer;
import docgen.graphutils.writer;

struct DocGeneratorOptions {
  GraphOptions graph;
  ListingOptions listings;
  TemplateOptions templates;
  CommentFormat commentFormat;
}

/**
 * Main routine for doc generation.
 */
class DocGenerator {
  public static void generate() {

  }
}