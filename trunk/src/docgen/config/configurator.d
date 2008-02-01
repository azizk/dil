/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.config.configurator;

import docgen.config.reader;
import docgen.config.reflection;
import docgen.misc.options;

import Integer = tango.text.convert.Integer;
import tango.io.stream.FileStream;
import tango.io.Stdout;

/**
 * Class for handling and merging doc generator options.
 */
interface Configurator {
  /**
   * Merges configuration options from the given file.
   */
  void mergeConfiguration(char[] cfgFile);
  
  /**
   * Returns a hierarchical structure of configuration options.
   */
  DocGeneratorOptions *getConfiguration();
}

private DocGeneratorOptions options;
private Struct!(options) opt;
private const cases = makeTypeStringForStruct!(opt);

class DefaultConfigurator : Configurator {
  private:
    
  DocGeneratorOptions options;

  public:

  const defaultProfileLocation = "docgen/config/default.cfg";

  this() {
    mergeConfiguration(defaultProfileLocation);
  }

  this(char[] cfgFile) {
    this();
    mergeConfiguration(cfgFile);
  }

  void mergeConfiguration(char[] cfgFile) {
    
    auto inputStream = new FileInput(cfgFile);
    auto content = new char[inputStream.length];
    auto bytesRead = inputStream.read (content);
    
    assert(bytesRead == inputStream.length, "Error reading configuration file");

    auto tokens = lex(content);
    auto configuration = parse(tokens);

    foreach(key, val; configuration) {
      bool err() {
        throw new Exception(
          "Configurator: Invalid key-val pair " ~ key ~
          "=" ~ (val.length ? val[0] : "null"));
      }

      // cuteness, lul
      mixin(_switch(
        mixin(cases) ~
        `default: throw new Exception("Illegal configuration key " ~ key);`
      ));
    }
  }

  DocGeneratorOptions *getConfiguration() {
    return &options;
  }
}
