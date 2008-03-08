/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.moduledoc.writer;

import docgen.misc.misc;
public import docgen.page.writer;
import tango.io.model.IConduit : OutputStream, InputStream;

interface ModuleDocWriter {
  void generateModuleDoc(Module mod, OutputStream output);
}

interface ModuleDocWriterFactory : WriterFactory {
  ModuleDocWriter createModuleDocWriter(PageWriter writer, DocFormat outputFormat);
}
