/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.tests.common;

import docgen.misc.misc;
import docgen.misc.options;
import docgen.config.configurator;

class TestDocGenerator : DocGenerator {
  Configurator config;

  this() {
    config = new DefaultConfigurator();
  }

  public void generate() {

  }
  
  public DocGeneratorOptions *options() {
    return config.getConfiguration();
  }
}
