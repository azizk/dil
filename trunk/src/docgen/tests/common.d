/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.tests.common;

import docgen.misc.misc;

class TestDocGenerator : DocGenerator {
  DocGeneratorOptions m_options;
  
  public void generate() {

  }
  
  public DocGeneratorOptions *options() {
    return &m_options;
  }
}