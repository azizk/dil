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

  GraphWriter createGraphWriter(DocumentWriter writer, GraphFormat outputFormat) {
    switch (outputFormat) {
      case GraphFormat.Dot:
        return new DotWriter(this, writer);
      case GraphFormat.ModuleNames:
        return new ModuleNameWriter(this, writer);
      case GraphFormat.ModulePaths:
        return new ModulePathWriter(this, writer);
      default:
        throw new Exception("Graph writer type does not exist!");
    }
  }
}
