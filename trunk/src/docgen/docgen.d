/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.docgen;

import docgen.modulegraph.writer;
import docgen.sourcelisting.writer;
import docgen.templates.writer;
import docgen.graphutils.writer;
import docgen.misc.misc;


/**
 * Main routine for doc generation.
 */
class DefaultDocGenerator : DocGenerator {
  DocGeneratorOptions m_options;
  
  public void generate() {

  }
  
  public DocGeneratorOptions *options() {
    return &m_options;
  }
}