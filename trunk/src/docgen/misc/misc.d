/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.misc.misc;
import docgen.misc.options;
import tango.io.model.IConduit : OutputStream;

char[] docgen_version = "Dil document generator 0.1";

interface DocGenerator {
  DocGeneratorOptions *options();
  void generate();
}

interface GraphCache {  
  char[] getCachedGraph(Object[] vertices, Object[] edges, GraphFormat format);
  void setCachedGraph(Object[] vertices, Object[] edges, GraphFormat format, char[] contents);
}

interface CachingDocGenerator : DocGenerator {
  GraphCache graphCache();
}

interface WriterFactory {
  DocGeneratorOptions *options();
}

abstract class AbstractWriterFactory : WriterFactory {
  protected DocGenerator generator;

  public:
  
  DocGeneratorOptions *options() {
    return generator.options;
  }

  this(DocGenerator generator) {
    this.generator = generator;
  }
}


template AbstractWriter(T, int n = 0) {
  abstract class AbstractWriter {
    protected T factory;
    protected OutputStream[] outputs;
  
    static if (n > 0) {
      this(T factory, OutputStream[] outputs) {
        this.factory = factory;
        this.outputs = outputs;
        assert(outputs.length == n, "Incorrect number of outputs");
      }
    }

    this(T factory) {
      this.factory = factory;
    }
  }
}
