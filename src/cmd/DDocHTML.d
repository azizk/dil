/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module cmd.DDocHTML;

import cmd.Highlight,
       cmd.DDocEmitter;
import dil.doc.Macro;
import dil.semantic.Module;
import common;

/// Traverses the syntax tree and writes DDoc macros to a string buffer.
class DDocHTMLEmitter : DDocEmitter
{
  /// Constructs a DDocHTMLEmitter object.
  this(Module modul, MacroTable mtable, bool includeUndocumented,
       TokenHighlighter tokenHL)
  {
    super(modul, mtable, includeUndocumented, tokenHL);
  }
}
