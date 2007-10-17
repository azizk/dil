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

struct TemplateOptions {
  DocFormat docFormat;
  char[] title = "Test project";
  char[] versionString = "1.0";
  char[] copyright;
  char[] paperSize = "a4paper";
  bool literateStyle = true;
}

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

interface TemplateWriterFactory {
  TemplateOptions *options();
  TemplateWriter createTemplateWriter(OutputStream[] outputs);
}

abstract class AbstractTemplateWriterFactory : TemplateWriterFactory {
  protected TemplateOptions m_options;

  public TemplateOptions *options() {
    return &m_options;
  }
}

