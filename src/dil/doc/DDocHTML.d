/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.doc.DDocHTML;

import dil.doc.DDocEmitter,
       dil.doc.Macro;
import dil.semantic.Module;
import dil.Highlighter,
       dil.Diagnostics;
import common;

/// Traverses the syntax tree and writes DDoc macros to a string buffer.
class DDocHTMLEmitter : DDocEmitter
{
  /// Constructs a DDocHTMLEmitter object.
  this(Module modul, MacroTable mtable,
       bool includeUndocumented, bool includePrivate,
       Diagnostics reportDiag, Highlighter tokenHL)
  {
    super(modul, mtable, includeUndocumented, includePrivate,
      reportDiag, tokenHL);
  }
}
