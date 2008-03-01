/++
  Authors: Aziz Köksal & Jari-Matti Mäkelä
  License: GPL3
+/
module cmd.DDocXML;

import cmd.DDoc;
import cmd.Generate;
import dil.doc.Parser;
import dil.doc.Macro;
import dil.doc.Doc;
import dil.ast.Node;
import dil.ast.Declarations,
       dil.ast.Statements,
       dil.ast.Expression,
       dil.ast.Parameters,
       dil.ast.Types;
import dil.ast.DefaultVisitor;
import dil.lexer.Token;
import dil.lexer.Funcs;
import dil.semantic.Module;
import dil.semantic.Pass1;
import dil.semantic.Symbol;
import dil.semantic.Symbols;
import dil.Compilation;
import dil.Information;
import dil.Converter;
import dil.SourceText;
import dil.Enums;
import dil.Time;
import common;

import tango.text.Ascii : toUpper;
import tango.io.File;
import tango.io.FilePath;

/// Traverses the syntax tree and writes DDoc macros to a string buffer.
class DDocXMLEmitter : DDocEmitter
{
  this(Module modul, MacroTable mtable, bool includeUndocumented,
       TokenHighlighter tokenHL)
  {
    super(modul, mtable, includeUndocumented, tokenHL);
  }

  /// Writes params to the text buffer.
  void writeParams(Parameters params)
  {
    if (!params.items.length)
      return;

    write("$(PARAMS ");
    auto lastParam = params.items[$-1];
    foreach (param; params.items)
    {
      if (param.isCVariadic)
        write("...");
      else
      {
        assert(param.type);
        // Write storage classes.
        auto typeBegin = param.type.baseType.begin;
        if (typeBegin !is param.begin) // Write storage classes.
          write(textSpan(param.begin, typeBegin.prevNWS), " ");
        write(escape(textSpan(typeBegin, param.type.end))); // Write type.
        if (param.name)
          write(" $(DDOC_PARAM ", param.name.str, ")");
        if (param.isDVariadic)
          write("...");
        if (param.defValue)
          write(" = ", escape(textSpan(param.defValue.begin, param.defValue.end)));
      }
      if (param !is lastParam)
        write(", ");
    }
    write(")");
  }

  /// Writes the current template parameters to the text buffer.
  void writeTemplateParams()
  {
    if (!tparams)
      return;
    write("$(TEMPLATE_PARAMS ", escape(textSpan(tparams.begin, tparams.end))[1..$-1], ")");
    tparams = null;
  }

  /// Writes bases to the text buffer.
  void writeInheritanceList(BaseClassType[] bases)
  {
    if (bases.length == 0)
      return;
    auto basesBegin = bases[0].begin.prevNWS;
    if (basesBegin.kind == TOK.Colon)
      basesBegin = bases[0].begin;
    write("$(PARENTS ", escape(textSpan(basesBegin, bases[$-1].end)), ")");
  }

  /// Writes a symbol to the text buffer. E.g: $&#40;SYMBOL Buffer, 123&#41;
  void SYMBOL(char[] name, Declaration d)
  {
    auto loc = d.begin.getRealLocation();
    auto str = Format("$(SYMBOL {}, {})", name, loc.lineNum);
    write(str);
    // write("$(DDOC_PSYMBOL ", name, ")");
  }

  /// Writes a declaration to the text buffer.
  void DECL(void delegate() dg, Declaration d, bool writeSemicolon = true)
  {
    if (cmntIsDitto)
    { alias prevDeclOffset offs;
      assert(offs != 0);
      auto savedText = text;
      text = "";
      write("\n$(DDOC_DECL ");
      dg();
      writeAttributes(d);
      write(")");
      // Insert text at offset.
      auto len = text.length;
      text = savedText[0..offs] ~ text ~ savedText[offs..$];
      offs += len; // Add length of the inserted text to the offset.
      return;
    }
    write("\n$(DDOC_DECL ");
    dg();
    writeAttributes(d);
    write(")");
    prevDeclOffset = text.length;
  }


  /// Writes a class or interface declaration.
  void writeClassOrInterface(T)(T d)
  {
    if (!ddoc(d))
      return d;
    DECL({
      write(d.begin.srcText, ", ");
      SYMBOL(d.name.str, d);
      writeTemplateParams();
      writeInheritanceList(d.bases);
    }, d);
    DESC({
      writeComment();
      MEMBERS(is(T == ClassDeclaration) ? "CLASS" : "INTERFACE", {
        scope s = new Scope();
        d.decls && DefaultVisitor.visit(d.decls);
      });
    });
  }

  // templated decls are not virtual so we need these:

  /// Writes a class declaration.
  void writeClass(ClassDeclaration d) {
    writeClassOrInterface(d);
  }

  /// Writes an interface declaration.
  void writeInterface(InterfaceDeclaration d) {
    writeClassOrInterface(d);
  }

  /// Writes a struct or union declaration.
  void writeStructOrUnion(T)(T d)
  {
    if (!ddoc(d))
      return d;
    DECL({
      write(d.begin.srcText, d.name ? ", " : "");
      if (d.name)
        SYMBOL(d.name.str, d);
      writeTemplateParams();
    }, d);
    DESC({
      writeComment();
      MEMBERS(is(T == StructDeclaration) ? "STRUCT" : "UNION", {
        scope s = new Scope();
        d.decls && DefaultVisitor.visit(d.decls);
      });
    });
  }

  // templated decls are not virtual so we need these:

  /// Writes a struct declaration.
  void writeStruct(StructDeclaration d) {
    writeStructOrUnion(d);
  }

  /// Writes an union declaration.
  void writeUnion(UnionDeclaration d) {
    writeStructOrUnion(d);
  }

  /// Writes an alias or typedef declaration.
  void writeAliasOrTypedef(T)(T d)
  {
    auto prefix = is(T == AliasDeclaration) ? "alias " : "typedef ";
    if (auto vd = d.decl.Is!(VariablesDeclaration))
    {
      auto type = textSpan(vd.typeNode.baseType.begin, vd.typeNode.end);
      foreach (name; vd.names)
        DECL({ write(prefix, ", "); write(escape(type), " "); SYMBOL(name.str, d); }, d);
    }
    else if (auto fd = d.decl.Is!(FunctionDeclaration))
    {}
    // DECL({ write(textSpan(d.begin, d.end)); }, false);
    DESC({ writeComment(); });
  }


  /// Writes the attributes of a declaration in brackets.
  void writeAttributes(Declaration d)
  {
    char[][] attributes;

    if (d.prot != Protection.None)
      attributes ~= "$(PROT " ~ .toString(d.prot) ~ ")";

    auto stc = d.stc;
    stc &= ~StorageClass.Auto; // Ignore auto.
    foreach (stcStr; .toStrings(stc))
      attributes ~= "$(STC " ~ stcStr ~ ")";

    LinkageType ltype;
    if (auto vd = d.Is!(VariablesDeclaration))
      ltype = vd.linkageType;
    else if (auto fd = d.Is!(FunctionDeclaration))
      ltype = fd.linkageType;

    if (ltype != LinkageType.None)
      attributes ~= "$(LINKAGE extern(" ~ .toString(ltype) ~ "))";

    if (!attributes.length)
      return;

    write("$(ATTRIBUTES ");
    foreach (attribute; attributes)
      write(attribute);
    write(")");
  }

  alias Declaration D;

  alias DDocEmitter.visit visit;

  D visit(EnumDeclaration d)
  {
      /+ FIXME: broken, infinite recursion :/
    if (!ddoc(d))
      return d;
    DECL({
      write("enum, ", d.name ? " " : "");
      d.name && SYMBOL(d.name.str, d);
    }, d);
    DESC({
      writeComment();
      Stdout("help\n");
///*FIXME*/      MEMBERS("ENUM", { scope s = new Scope(); DDocEmitter.visit(d); });
    });
    +/
    return d;
  }

  D visit(EnumMemberDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("member, "); SYMBOL(d.name.str, d); }, d, false);
    DESC({ writeComment(); });
    return d;
  }

  D visit(TemplateDeclaration d)
  {
    this.tparams = d.tparams;
    if (d.begin.kind != TOK.Template)
    { // This is a templatized class/interface/struct/union/function.
      DefaultVisitor.visit(d.decls);
      this.tparams = null;
      return d;
    }
    if (!ddoc(d))
      return d;
    DECL({
      write("template, ");
      SYMBOL(d.name.str, d);
      writeTemplateParams();
    }, d);
    DESC({
      writeComment();
      MEMBERS("TEMPLATE", {
        scope s = new Scope();
        DefaultVisitor.visit(d.decls);
      });
    });
    return d;
  }

  D visit(ConstructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("constructor, "); SYMBOL("this", d); writeParams(d.params); }, d);
    DESC({ writeComment(); });
    return d;
  }

  D visit(StaticConstructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("static constructor, "); SYMBOL("this", d); write("()"); }, d);
    DESC({ writeComment(); });
    return d;
  }

  D visit(DestructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("destructor, ~"); SYMBOL("this", d); }, d);
    DESC({ writeComment(); });
    return d;
  }

  D visit(StaticDestructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("static destructor, ~"); SYMBOL("this", d); }, d);
    DESC({ writeComment(); });
    return d;
  }

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
    DESC({ writeComment(); });
    return d;
  }

  D visit(NewDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("new, "); SYMBOL("new", d); writeParams(d.params); }, d);
    DESC({ writeComment(); });
    return d;
  }

  D visit(DeleteDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("delete, "); SYMBOL("delete", d); writeParams(d.params); }, d);
    DESC({ writeComment(); });
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
    DESC({ writeComment(); });
    return d;
  }

  D visit(InvariantDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("invariant, "); SYMBOL("invariant", d); }, d);
    DESC({ writeComment(); });
    return d;
  }

  D visit(UnittestDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("unittest, "); SYMBOL("unittest", d); }, d);
    DESC({ writeComment(); });
    return d;
  }

}
