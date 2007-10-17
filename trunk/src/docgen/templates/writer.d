/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.templates.writer;

public import docgen.misc.misc;
import tango.io.model.IConduit : OutputStream, InputStream;
import tango.util.time.Date;
import tango.util.time.Clock;
import tango.text.convert.Sprint;

interface TemplateWriter {
  void generateTemplate();
}

abstract class AbstractTemplateWriter : TemplateWriter {
  protected TemplateWriterFactory factory;
  protected OutputStream[] outputs;

  this(TemplateWriterFactory factory, OutputStream[] outputs) {
    this.factory = factory;
    this.outputs = outputs;
  }
  
  protected static char[] timeNow() {
    auto date = Clock.toDate;
    auto sprint = new Sprint!(char);
    return sprint.format("{0} {1} {2} {3}",
      date.asDay(),
      date.asMonth(),
      date.day,
      date.year).dup;
  }
}

interface TemplateWriterFactory : WriterFactory {
  TemplateWriter createTemplateWriter(OutputStream[] outputs);
}