/// Authors: Aziz Köksal, Jari-Matti Mäkelä
/// License: GPL3
module cmd.DDocXML;

import cmd.Highlight,
       cmd.DDocEmitter;
import dil.doc.Macro;
import dil.ast.Declarations;
import dil.semantic.Module;
import common;

/// Traverses the syntax tree and writes DDoc macros to a string buffer.
class DDocXMLEmitter : DDocEmitter
{
  /// Constructs a DDocXMLEmitter object.
  this(Module modul, MacroTable mtable, bool includeUndocumented,
       TokenHighlighter tokenHL)
  {
    super(modul, mtable, includeUndocumented, tokenHL);
  }

  alias Declaration D;

override:
  D visit(FunctionDeclaration d)
  {
    if (!ddoc(d))
      return d;
    auto type = textSpan(d.returnType.baseType.begin, d.returnType.end);
    DECL({
      write("function, ");
      write("$(TYPE ");
      write("$(RETURNS ", escape(type), ")");
      writeTemplateParams();
      writeParams(d.params);
      write(")");
      SYMBOL(d.name.str, d);
    }, d);
    DESC();
    return d;
  }

  D visit(VariablesDeclaration d)
  {
    if (!ddoc(d))
      return d;
    char[] type = "auto";
    if (d.typeNode)
      type = textSpan(d.typeNode.baseType.begin, d.typeNode.end);
    foreach (name; d.names)
      DECL({ write("variable, "); write("$(TYPE ", escape(type), ")"); SYMBOL(name.str, d); }, d);
    DESC();
    return d;
  }
}
