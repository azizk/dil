/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.writers;

public import docgen.graphutils.writer;
import docgen.graphutils.dotwriter;
import docgen.graphutils.modulepathwriter;
import docgen.graphutils.modulenamewriter;

class DefaultGraphWriterFactory : AbstractGraphWriterFactory {
  this(GraphOptions options) {
    m_options = options;
  }

  GraphWriterDg createGraphWriter(OutputStream[] outputs) {
    switch (m_options.graphFormat) {
      case GraphFormat.Dot:
        return &((new DotWriter(this, outputs)).generateGraph);
      case GraphFormat.ModuleNames:
        return &((new ModuleNameWriter(this, outputs)).generateGraph);
      case GraphFormat.ModulePaths:
        return &((new ModulePathWriter(this, outputs)).generateGraph);
    }
  }
}