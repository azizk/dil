/// Authors: Aziz Köksal, Jari-Matti Mäkelä
/// License: GPL3
/// $(Maturity average)
module dil.doc.DDocXML;

import dil.doc.DDocEmitter,
       dil.doc.Macro;
import dil.ast.Declarations;
import dil.semantic.Module;
import dil.Highlighter,
       dil.Diagnostics;
import common;

/// Traverses the syntax tree and writes DDoc macros to a string buffer.
class DDocXMLEmitter : DDocEmitter
{
  /// Constructs a DDocXMLEmitter object.
  this(Module modul, MacroTable mtable,
       bool includeUndocumented, bool includePrivate,
       Diagnostics reportDiag, Highlighter tokenHL)
  {
    super(modul, mtable, includeUndocumented, includePrivate,
      reportDiag, tokenHL);
  }

override:
  alias super.visit visit;

  void visit(FunctionDecl d)
  {
    if (!ddoc(d))
      return;
    DECL({
      write("function, ", "\1TYPE \1RETURNS");
      if (d.returnType) write(d.returnType);
      else write("auto");
      write("\2");
      writeTemplateParams();
      writeParams(d.params);
      write("\2");
      SYMBOL(d.name.text, K.Function, d);
    }, d);
    DESC();
  }

  void visit(VariablesDecl d)
  {
    if (!ddoc(d))
      return;
    foreach (name; d.names)
      DECL({
        write("variable, ", "\1TYPE ");
        if (d.typeNode) write(d.typeNode);
        else write("auto");
        write("\2 ");
        SYMBOL(name.text, K.Variable, d);
      }, d);
    DESC();
  }
}
