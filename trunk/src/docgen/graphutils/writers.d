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

  GraphWriter createGraphWriter(PageWriter writer, GraphFormat outputFormat) {
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

class DefaultCachingGraphWriterFactory : AbstractWriterFactory, GraphWriterFactory {
  CachingDocGenerator generator;

  this(CachingDocGenerator generator) {
    super(generator);
  }

  char[] getCachedGraph(Vertex[] vertices, Edge[] edges, GraphFormat format) {
    return generator.getCachedGraph(vertices, edges, format);
  }

  GraphWriter createGraphWriter(PageWriter writer, GraphFormat outputFormat) {
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
