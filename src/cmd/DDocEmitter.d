/// Author: Aziz Köksal
/// License: GPL3
module cmd.DDocEmitter;

import cmd.Highlight;
import dil.doc.Parser,
       dil.doc.Macro,
       dil.doc.Doc;
import dil.ast.DefaultVisitor,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Statements,
       dil.ast.Expression,
       dil.ast.Parameters,
       dil.ast.Types;
import dil.lexer.Token,
       dil.lexer.Funcs;
import dil.semantic.Module;
import dil.Information;
import dil.SourceText;
import dil.Enums;
import common;

import tango.text.Ascii : toUpper, icompare;

/// Traverses the syntax tree and writes DDoc macros to a string buffer.
abstract class DDocEmitter : DefaultVisitor
{
  char[] text; /// The buffer that is written to.
  bool includeUndocumented;
  MacroTable mtable;
  Module modul;
  TokenHighlighter tokenHL;

  /// Constructs a DDocEmitter object.
  /// Params:
  ///   modul = the module to generate text for.
  ///   mtable = the macro table.
  ///   includeUndocumented = whether to include undocumented symbols.
  ///   tokenHL = used to highlight code sections.
  this(Module modul, MacroTable mtable, bool includeUndocumented,
       TokenHighlighter tokenHL)
  {
    this.mtable = mtable;
    this.includeUndocumented = includeUndocumented;
    this.modul = modul;
    this.tokenHL = tokenHL;
  }

  /// Entry method.
  char[] emit()
  {
    if (isDDocFile(modul))
    { // The module is actually a DDoc text file.
      auto c = getDDocComment(getDDocText(modul));
      foreach (s; c.sections)
      {
        if (s.Is("macros"))
        { // Declare the macros in this section.
          auto ms = new MacrosSection(s.name, s.text);
          mtable.insert(ms.macroNames, ms.macroTexts);
        }
        else
          write(s.wholeText);
      }
      return text;
    }
    // Handle as a normal D module with declarations.
    if (auto d = modul.moduleDecl)
    {
      if (ddoc(d))
      {
        if (auto copyright = cmnt.takeCopyright())
          mtable.insert("COPYRIGHT", copyright.text);
        writeComment();
      }
    }
    MEMBERS("MODULE", { visitD(modul.root); });
    return text;
  }

  /// Returns true if the source text starts with "Ddoc\n" (ignores letter case.)
  static bool isDDocFile(Module mod)
  {
    auto data = mod.sourceText.data;
    // 5 = "ddoc\n".length; +1 = trailing '\0' in data.
    if (data.length >= 5 + 1 && // Check for minimum length.
        icompare(data[0..4], "ddoc") == 0 && // Check first four characters.
        isNewline(data.ptr + 4)) // Check for a newline.
      return true;
    return false;
  }

  /// Returns the DDoc text of this module.
  static char[] getDDocText(Module mod)
  {
    auto data = mod.sourceText.data;
    char* p = data.ptr + "ddoc".length;
    if (scanNewline(p)) // Skip the newline.
      // Exclude preceding "Ddoc\n" and trailing '\0'.
      return data[p-data.ptr .. $-1];
    return null;
  }

  char[] textSpan(Token* left, Token* right)
  {
    //assert(left && right && (left.end <= right.start || left is right));
    //char[] result;
    //TODO: filter out whitespace tokens.
    return Token.textSpan(left, right);
  }

  TemplateParameters tparams; /// The template parameters of the current declaration.

  DDocComment cmnt; /// Current comment.
  DDocComment prevCmnt; /// Previous comment in scope.
  /// An empty comment. Used for undocumented symbols.
  static const DDocComment emptyCmnt;

  /// Initializes the empty comment.
  static this()
  {
    this.emptyCmnt = new DDocComment(null, null, null);
  }

  /// Keeps track of previous comments in each scope.
  scope class DDocScope
  {
    DDocComment saved_prevCmnt;
    bool saved_cmntIsDitto;
    uint saved_prevDeclOffset;
    /// When constructed, variables are saved.
    this()
    { // Save the previous comment of the parent scope.
      saved_prevCmnt = this.outer.prevCmnt;
      saved_cmntIsDitto = this.outer.cmntIsDitto;
      saved_prevDeclOffset = this.outer.prevDeclOffset;
      // Entering a new scope. Clear variables.
      this.outer.prevCmnt = null;
      this.outer.cmntIsDitto = false;
      this.outer.prevDeclOffset = 0;
    }
    /// When destructed, variables are restored.
    ~this()
    { // Restore the previous comment of the parent scope.
      this.outer.prevCmnt = saved_prevCmnt;
      this.outer.cmntIsDitto = saved_cmntIsDitto;
      this.outer.prevDeclOffset = saved_prevDeclOffset;
    }
  }

  bool cmntIsDitto; /// True if current comment is "ditto".

  /// Sets some members and returns the DDocComment for node.
  DDocComment ddoc(Node node)
  {
    this.cmnt = getDDocComment(node);
    if (this.cmnt)
    {
      if (this.cmnt.isDitto) // A ditto comment.
        (this.cmnt = this.prevCmnt), (this.cmntIsDitto = true);
      else // A normal comment.
        (this.prevCmnt = this.cmnt), (this.cmntIsDitto = false);
    }
    else if (includeUndocumented)
      this.cmnt = this.emptyCmnt; // Assign special empty comment.
    return this.cmnt;
  }

  /// List of predefined, special sections.
  static char[][char[]] specialSections;
  static this()
  {
    foreach (name; ["AUTHORS", "BUGS", "COPYRIGHT", "DATE", "DEPRECATED",
                    "EXAMPLES", "HISTORY", "LICENSE", "RETURNS", "SEE_ALSO",
                    "STANDARDS", "THROWS", "VERSION"])
      specialSections[name] = name;
  }

  /// Writes the DDoc comment to the text buffer.
  void writeComment()
  {
    auto c = this.cmnt;
    assert(c !is null);
    write("$(DDOC_SECTIONS ");
      foreach (s; c.sections)
      {
        if (s is c.summary)
          write("\n$(DDOC_SUMMARY ");
        else if (s is c.description)
          write("\n$(DDOC_DESCRIPTION ");
        else if (auto name = toUpper(s.name.dup) in specialSections)
          write("\n$(DDOC_" ~ *name ~ " ");
        else if (s.Is("params"))
        { // Process parameters section.
          auto ps = new ParamsSection(s.name, s.text);
          write("\n$(DDOC_PARAMS ");
          foreach (i, paramName; ps.paramNames)
            write("\n$(DDOC_PARAM_ROW ",
                    "$(DDOC_PARAM_ID $(DDOC_PARAM ", paramName, "))",
                    "$(DDOC_PARAM_DESC ", ps.paramDescs[i], ")",
                  ")");
          write(")");
          continue;
        }
        else if (s.Is("macros"))
        { // Declare the macros in this section.
          auto ms = new MacrosSection(s.name, s.text);
          mtable.insert(ms.macroNames, ms.macroTexts);
          continue;
        }
        else
          // TODO: replace occurrences of '_' with ' ' in s.name.
          write("\n$(DDOC_SECTION $(DDOC_SECTION_H " ~ s.name ~ ":)");
        write(scanCommentText(s.text), ")");
      }
    write(")");
  }

  /// Scans the comment text and:
  /// $(UL
  /// $(LI skips and leaves macro invocations unchanged)
  /// $(LI skips HTML tags)
  /// $(LI escapes '(', ')', '<', '>' and '&')
  /// $(LI inserts $&#40;DDOC_BLANKLINE&#41; in place of \n\n)
  /// $(LI highlights code in code sections)
  /// )
  char[] scanCommentText(char[] text)
  {
    char* p = text.ptr;
    char* end = p + text.length;
    char[] result = new char[text.length]; // Reserve space.
    result.length = 0;

    while (p < end)
    {
      switch (*p)
      {
      case '$':
        if (auto macroEnd = MacroParser.scanMacro(p, end))
        {
          result ~= makeString(p, macroEnd); // Copy macro invocation as is.
          p = macroEnd;
          continue;
        }
        goto default;
      case '<':
        auto begin = p;
        p++;
        if (p+2 < end && *p == '!' && p[1] == '-' && p[2] == '-') // <!--
        {
          p += 2; // Point to 2nd '-'.
          // Scan to closing "-->".
          while (++p < end)
            if (p+2 < end && *p == '-' && p[1] == '-' && p[2] == '>')
            {
              p += 3; // Point one past '>'.
              break;
            }
          result ~= makeString(begin, p);
        } // <tag ...> or </tag>
        else if (p < end && (isalpha(*p) || *p == '/'))
        {
          while (++p < end && *p != '>') // Skip to closing '>'.
          {}
          if (p == end)
          { // No closing '>' found.
            p = begin + 1;
            result ~= "&lt;";
            continue;
          }
          p++; // Skip '>'.
          result ~= makeString(begin, p);
        }
        else
          result ~= "&lt;";
        continue;
      case '(': result ~= "&#40;"; break;
      case ')': result ~= "&#41;"; break;
      // case '\'': result ~= "&apos;"; break; // &#39;
      // case '"': result ~= "&quot;"; break;
      case '>': result ~= "&gt;"; break;
      case '&':
        if (p+1 < end && (isalpha(p[1]) || p[1] == '#'))
          goto default;
        result ~= "&amp;";
        break;
      case '\n':
        if (!(p+1 < end && p[1] == '\n'))
          goto default;
        ++p;
        result ~= "$(DDOC_BLANKLINE)";
        break;
      case '-':
        if (p+2 < end && p[1] == '-' && p[2] == '-')
        {
          while (p < end && *p == '-')
            p++;
          auto codeBegin = p;
          p--;
          while (++p < end)
            if (p+2 < end && *p == '-' && p[1] == '-' && p[2] == '-')
              break;
          auto codeText = makeString(codeBegin, p);
          result ~= tokenHL.highlight(codeText, modul.filePath);
          while (p < end && *p == '-')
            p++;
          continue;
        }
        //goto default;
      default:
        result ~= *p;
      }
      p++;
    }
    return result;
  }

  /// Escapes '<', '>' and '&' with named HTML entities.
  char[] escape(char[] text)
  {
    char[] result = new char[text.length]; // Reserve space.
    result.length = 0;
    foreach(c; text)
      switch(c)
      {
        case '<': result ~= "&lt;";  break;
        case '>': result ~= "&gt;";  break;
        case '&': result ~= "&amp;"; break;
        default:  result ~= c;
      }
    if (result.length != text.length)
      return result;
    // Nothing escaped. Return original text.
    delete result;
    return text;
  }

  /// Writes an array of strings to the text buffer.
  void write(char[][] strings...)
  {
    foreach (s; strings)
      text ~= s;
  }

  /// Writes params to the text buffer.
  void writeParams(Parameters params)
  {
    write("$(PARAMS ");
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
      write(", ");
    }
    if (params.items)
      text = text[0..$-2]; /// Slice off last ", ".
    write(")");
  }

  /// Writes the current template parameters to the text buffer.
  void writeTemplateParams()
  {
    if (!tparams)
      return;
    write("$(TEMPLATE_PARAMS ",
          escape(textSpan(tparams.begin, tparams.end))[1..$-1], // Remove ().
          ")");
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
    write(" $(BASE_CLASSES ", escape(textSpan(basesBegin, bases[$-1].end)), ")");
  }

  /// Writes a symbol to the text buffer. E.g: $&#40;SYMBOL Buffer, 123&#41;
  void SYMBOL(char[] name, Declaration d)
  {
    auto loc = d.begin.getRealLocation();
    auto str = Format("$(SYMBOL {}, {})", name, loc.lineNum);
    write(str);
    // write("$(DDOC_PSYMBOL ", name, ")");
  }

  /// Offset at which to insert a declaration with a "ditto" comment.
  uint prevDeclOffset;

  /// Writes a declaration to the text buffer.
  void DECL(void delegate() dg, Declaration d, bool writeSemicolon = true)
  {
    void writeDECL()
    {
      write("\n$(DDOC_DECL ");
      dg();
      writeSemicolon && write(";");
      writeAttributes(d);
      write(")");
    }

    if (/+includeUndocumented &&+/ this.cmnt is this.emptyCmnt)
    { // Handle undocumented symbols separately.
      // This way they don't interrupt consolidated declarations.
      writeDECL();
      // Write an empty DDOC_DECL_DD.
      // The method DESC() does not emit anything when cmntIsDitto is true.
      cmntIsDitto && write("\n$(DDOC_DECL_DD)");
    }
    else if (cmntIsDitto)
    { // The declaration has a ditto comment.
      alias prevDeclOffset offs;
      assert(offs != 0);
      auto savedText = text;
      text = "";
      writeDECL();
      // Insert text at offset.
      auto len = text.length;
      text = savedText[0..offs] ~ text ~ savedText[offs..$];
      offs += len; // Add length of the inserted text to the offset.
    }
    else
    {
      writeDECL();
      // Set the offset. At this offset other declarations with a ditto
      // comment will be inserted, if present.
      prevDeclOffset = text.length;
    }
  }

  /// Wraps the DDOC_DECL_DD macro around the text written by dg().
  /// Writes the comment before dg() is called.
  void DESC(void delegate() dg = null)
  {
    if (cmntIsDitto)
      return; // Don't write a description when we have a ditto declaration.
    write("\n$(DDOC_DECL_DD ");
    writeComment();
    dg && dg();
    write(")");
  }

  /// Wraps the DDOC_kind_MEMBERS macro around the text written by dg().
  void MEMBERS(char[] kind, void delegate() dg)
  {
    write("\n$(DDOC_"~kind~"_MEMBERS ");
    dg();
    write(")");
  }

  /// Writes a class or interface declaration.
  void writeClassOrInterface(T)(T d)
  {
    if (!ddoc(d))
      return d;
    DECL({
      write(is(T == ClassDeclaration) ? "class" : "interface", " ");
      SYMBOL(d.name.str, d);
      writeTemplateParams();
      writeInheritanceList(d.bases);
    }, d);
    DESC({
      MEMBERS(is(T == ClassDeclaration) ? "CLASS" : "INTERFACE", {
        scope s = new DDocScope();
        d.decls && super.visit(d.decls);
      });
    });
  }

  /// Writes a struct or union declaration.
  void writeStructOrUnion(T)(T d)
  {
    if (!ddoc(d))
      return d;
    DECL({
      write(is(T == StructDeclaration) ? "struct" : "union", d.name ? " " : "");
      if (d.name)
        SYMBOL(d.name.str, d);
      writeTemplateParams();
    }, d);
    DESC({
      MEMBERS(is(T == StructDeclaration) ? "STRUCT" : "UNION", {
        scope s = new DDocScope();
        d.decls && super.visit(d.decls);
      });
    });
  }

  /// Writes an alias or typedef declaration.
  void writeAliasOrTypedef(T)(T d)
  {
    auto prefix = is(T == AliasDeclaration) ? "alias " : "typedef ";
    if (auto vd = d.decl.Is!(VariablesDeclaration))
    {
      auto type = textSpan(vd.typeNode.baseType.begin, vd.typeNode.end);
      foreach (name; vd.names)
        DECL({ write(prefix); write(escape(type), " "); SYMBOL(name.str, d); }, d);
    }
    else if (auto fd = d.decl.Is!(FunctionDeclaration))
    {}
    // DECL({ write(textSpan(d.begin, d.end)); }, false);
    DESC();
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

    write(" $(ATTRIBUTES ", attributes[0]);
    foreach (attribute; attributes[1..$])
      write(", ", attribute);
    write(")");
  }

  alias Declaration D;

override:
  D visit(AliasDeclaration d)
  {
    if (ddoc(d))
      writeAliasOrTypedef(d);
    return d;
  }

  D visit(TypedefDeclaration d)
  {
    if (ddoc(d))
      writeAliasOrTypedef(d);
    return d;
  }

  D visit(EnumDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({
      write("enum", d.name ? " " : "");
      d.name && SYMBOL(d.name.str, d);
    }, d);
    DESC({ MEMBERS("ENUM", { scope s = new DDocScope(); super.visit(d); }); });
    return d;
  }

  D visit(EnumMemberDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL(d.name.str, d); }, d, false);
    DESC();
    return d;
  }

  D visit(TemplateDeclaration d)
  {
    this.tparams = d.tparams;
    if (d.begin.kind != TOK.Template)
    { // This is a templatized class/interface/struct/union/function.
      super.visit(d.decls);
      this.tparams = null;
      return d;
    }
    if (!ddoc(d))
      return d;
    DECL({
      write("template ");
      SYMBOL(d.name.str, d);
      writeTemplateParams();
    }, d);
    DESC({
      MEMBERS("TEMPLATE", {
        scope s = new DDocScope();
        super.visit(d.decls);
      });
    });
    return d;
  }

  D visit(ClassDeclaration d)
  {
    writeClassOrInterface(d);
    return d;
  }

  D visit(InterfaceDeclaration d)
  {
    writeClassOrInterface(d);
    return d;
  }

  D visit(StructDeclaration d)
  {
    writeStructOrUnion(d);
    return d;
  }

  D visit(UnionDeclaration d)
  {
    writeStructOrUnion(d);
    return d;
  }

  D visit(ConstructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL("this", d); writeParams(d.params); }, d);
    DESC();
    return d;
  }

  D visit(StaticConstructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("static "); SYMBOL("this", d); write("()"); }, d);
    DESC();
    return d;
  }

  D visit(DestructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("~"); SYMBOL("this", d); write("()"); }, d);
    DESC();
    return d;
  }

  D visit(StaticDestructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("static ~"); SYMBOL("this", d); write("()"); }, d);
    DESC();
    return d;
  }

  D visit(FunctionDeclaration d)
  {
    if (!ddoc(d))
      return d;
    auto type = textSpan(d.returnType.baseType.begin, d.returnType.end);
    DECL({
      write(escape(type), " ");
      SYMBOL(d.name.str, d);
      writeTemplateParams();
      writeParams(d.params);
    }, d);
    DESC();
    return d;
  }

  D visit(NewDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL("new", d); writeParams(d.params); }, d);
    DESC();
    return d;
  }

  D visit(DeleteDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL("delete", d); writeParams(d.params); }, d);
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
      DECL({ write(escape(type), " "); SYMBOL(name.str, d); }, d);
    DESC();
    return d;
  }

  D visit(InvariantDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL("invariant", d); }, d);
    DESC();
    return d;
  }

  D visit(UnittestDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL("unittest", d); }, d);
    DESC();
    return d;
  }

  D visit(DebugDeclaration d)
  {
    d.compiledDecls && visitD(d.compiledDecls);
    return d;
  }

  D visit(VersionDeclaration d)
  {
    d.compiledDecls && visitD(d.compiledDecls);
    return d;
  }

  D visit(StaticIfDeclaration d)
  {
    d.ifDecls && visitD(d.ifDecls);
    return d;
  }
}
