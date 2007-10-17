/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.writers;

public import docgen.graphutils.writer;
import docgen.graphutils.dotwriter;
import docgen.graphutils.modulepathwriter;
import docgen.graphutils.modulenamewriter;

class DefaultGraphWriterFactory : AbstractWriterFactory, GraphWriterFactory {
  this(DocGenerator generator) {
    super(generator);
  }

  GraphWriterDg createGraphWriter(OutputStream[] outputs) {
    switch (options.graph.graphFormat) {
      case GraphFormat.Dot:
        return &((new DotWriter(this, outputs)).generateGraph);
      case GraphFormat.ModuleNames:
        return &((new ModuleNameWriter(this, outputs)).generateGraph);
      case GraphFormat.ModulePaths:
        return &((new ModulePathWriter(this, outputs)).generateGraph);
      default:
        throw new Exception("Graph writer type does not exist!");
    }
  }
}