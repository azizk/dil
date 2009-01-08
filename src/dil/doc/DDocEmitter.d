/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.doc.DDocEmitter;

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
import dil.Highlighter;
import dil.Diagnostics;
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
  Highlighter tokenHL;

  /// Constructs a DDocEmitter object.
  /// Params:
  ///   modul = the module to generate text for.
  ///   mtable = the macro table.
  ///   includeUndocumented = whether to include undocumented symbols.
  ///   tokenHL = used to highlight code sections.
  this(Module modul, MacroTable mtable, bool includeUndocumented,
       Highlighter tokenHL)
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
      auto c = DDocUtils.getDDocComment(getDDocText(modul));
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
    MEMBERS("MODULE", "module", modul.root);
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

  /// The template parameters of the current declaration.
  TemplateParameters tparams;

  /// Reflects the fully qualified name of the current symbol's parent.
  /// A push occurs when entering a scope and a pop when exiting it.
  string[] fqnStack;
  /// Counts symbols with the same FQN.
  /// This is useful for anchor names that require unique strings.
  uint[string] fqnCount;

  /// Pushes an identifier onto the stack.
  void pushFQN(string fqn)
  {
    assert(fqn.length);
    fqnStack ~= fqn;
  }
  /// Pops an identifier from the stack.
  void popFQN()
  {
    assert(fqnStack.length);
    fqnStack = fqnStack[0..$-1];
  }

  /// Returns a unique, identifying string for the current symbol.
  string getSymbolFQN(string name)
  {
    char[] fqn;
    foreach (name_part; fqnStack[1..$]) // Exclude first item (="module".)
      fqn ~= name_part ~ ".";
    fqn ~= name;

    uint count;
    auto pfqn = fqn in fqnCount;
    if (pfqn)
      count = (*pfqn += 1); // Update counter.
    else
      fqnCount[fqn] = 1; // Start counting with 1.

    if (count > 1) // Ignore unique suffix for the value 1.
      fqn ~= Format(":{}", count);
    return fqn;
  }

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
    /// Params:
    ///   name = the name of the current symbol.
    this(string name)
    { // Save the previous comment of the parent scope.
      saved_prevCmnt = this.outer.prevCmnt;
      saved_cmntIsDitto = this.outer.cmntIsDitto;
      saved_prevDeclOffset = this.outer.prevDeclOffset;
      pushFQN(name);
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
      popFQN();
    }
  }

  bool cmntIsDitto; /// True if current comment is "ditto".

  /// Sets some members and returns the DDocComment for node.
  DDocComment ddoc(Node node)
  {
    this.cmnt = DDocUtils.getDDocComment(node);
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
                    "STANDARDS", "THROWS", "VERSION"] ~
                   ["AUTHOR"]) // Addition by dil.
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
          write("\n$(DDOC_", *name, " ");
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
          write("\n$(DDOC_SECTION $(DDOC_SECTION_H ", replace_(s.name), ":)");
        write(scanCommentText(s.text), ")");
      }
    write(")");
  }

  /// Replaces occurrences of '_' with ' ' in str.
  char[] replace_(char[] str)
  {
    foreach (ref c; str.dup)
      if (c == '_') c = ' ';
    return str;
  }

  /// Scans the comment text and:
  /// $(UL
  /// $(LI skips and leaves macro invocations unchanged)
  /// $(LI skips HTML tags)
  /// $(LI escapes '<', '>' and '&' with named HTML entities)
  /// $(LI inserts $&#40;LP&#41;/$&#40;RP&#41; in place of '('/')')
  /// $(LI inserts $&#40;DDOC_BLANKLINE&#41; in place of '\n\n')
  /// $(LI highlights the tokens in code sections)
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
            if (*p == '-' && p+2 < end && p[1] == '-' && p[2] == '>')
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
      case '(': result ~= "$(LP)"; break;
      case ')': result ~= "$(RP)"; break;
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
        result ~= "\n$(DDOC_BLANKLINE)\n";
        break;
      case '-':
        if (p+2 < end && p[1] == '-' && p[2] == '-')
        { // Found "---".
          while (p < end && *p == '-') // Skip leading dashes.
            p++;
          auto codeBegin = p;
          while (p < end && isspace(*p))
            p++;
          if (p < end && *p == '\n') // Skip first newline.
            codeBegin = ++p;
          // Find closing dashes.
          while (p < end && !(*p == '-' && p+2 < end &&
                            p[1] == '-' && p[2] == '-'))
            p++;
          // Remove last newline if present.
          auto codeEnd = p;
          while (isspace(*--codeEnd))
          {}
          if (*codeEnd != '\n') // Leaving the pointer on '\n' will exclude it.
            codeEnd++; // Include the non-newline character.
          if (codeBegin < codeEnd)
          { // Highlight the extracted source code.
            auto codeText = makeString(codeBegin, codeEnd);
            codeText = DDocUtils.unindentText(codeText);
            result ~= "$(D_CODE\n";
            result ~= tokenHL.highlightTokens(codeText, modul.getFQN());
            result ~= "\n)";
          }
          while (p < end && *p == '-') // Skip remaining dashes.
            p++;
          continue;
        }
        //goto default;
      default:
        result ~= *p;
      }
      p++;
    }
    assert(p is end);
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
    write("$(DIL_PARAMS ");
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
    auto text = textSpan(tparams.begin, tparams.end);
    text = escape(text)[1..$-1]; // Escape and remove '(', ')'.
    write("$(DIL_TEMPLATE_PARAMS ", text, ")");
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
    auto text = escape(textSpan(basesBegin, bases[$-1].end));
    write(" $(DIL_BASE_CLASSES ", text, ")");
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
      writeSemicolon && write("$(DIL_SC)");
      writeAttributes(d);
      write(" $(DIL_SYMEND ", currentSymbolParams, "))");
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

  /// Saves the current symbol parameters.
  string currentSymbolParams;

  /// Writes a symbol to the text buffer.
  /// E.g: &#36;(DIL_SYMBOL scan, Lexer.scan, func, 229, 646);
  void SYMBOL(string name, string kind, Declaration d)
  {
    auto fqn = getSymbolFQN(name);
    auto loc = d.begin.getRealLocation();
    auto loc_end = d.end.getRealLocation();
    currentSymbolParams = Format("{}, {}, {}, {}, {}",
      name, fqn, kind, loc.lineNum, loc_end.lineNum);
    write("$(DIL_SYMBOL ", currentSymbolParams, ")");
    // write("$(DDOC_PSYMBOL ", name, ")"); // DMD's macro with no info.
  }

  /// Wraps the DDOC_kind_MEMBERS macro around the text
  /// written by visit(members).
  void MEMBERS(D)(string kind, string name, D members)
  {
    scope s = new DDocScope(name);
    write("\n$(DDOC_"~kind~"_MEMBERS ");
    if (members !is null)
      super.visit(members);
    write(")");
  }

  /// Writes a class or interface declaration.
  void writeClassOrInterface(T)(T d)
  {
    if (!ddoc(d))
      return d;
    const kind = is(T == ClassDeclaration) ? "class" : "interface";
    const KIND = is(T == ClassDeclaration) ? "CLASS" : "INTERFACE";
    DECL({
      write(kind, " ");
      SYMBOL(d.name.str, kind, d);
      writeTemplateParams();
      writeInheritanceList(d.bases);
    }, d);
    DESC({ MEMBERS(KIND, d.name.str, d.decls); });
  }

  /// Writes a struct or union declaration.
  void writeStructOrUnion(T)(T d)
  {
    if (!ddoc(d))
      return d;
    const kind = is(T == StructDeclaration) ? "struct" : "union";
    const KIND = is(T == StructDeclaration) ? "STRUCT" : "UNION";
    string name = d.name ? d.name.str : kind;
    DECL({
      d.name && write(kind, " ");
      SYMBOL(name, kind, d);
      writeTemplateParams();
    }, d);
    DESC({ MEMBERS(KIND, name, d.decls); });
  }

  /// Writes an alias or typedef declaration.
  void writeAliasOrTypedef(T)(T d)
  {
    const kind = is(T == AliasDeclaration) ? "alias" : "typedef";
    if (auto vd = d.decl.Is!(VariablesDeclaration))
    {
      auto type = textSpan(vd.typeNode.baseType.begin, vd.typeNode.end);
      foreach (name; vd.names)
        DECL({ write(kind, " "); write(escape(type), " ");
          SYMBOL(name.str, kind, d);
        }, d);
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
      attributes ~= "$(DIL_PROT " ~ .toString(d.prot) ~ ")";

    auto stc = d.stc;
    stc &= ~StorageClass.Auto; // Ignore auto.
    foreach (stcStr; .toStrings(stc))
      attributes ~= "$(DIL_STC " ~ stcStr ~ ")";

    LinkageType ltype;
    if (auto vd = d.Is!(VariablesDeclaration))
      ltype = vd.linkageType;
    else if (auto fd = d.Is!(FunctionDeclaration))
      ltype = fd.linkageType;

    if (ltype != LinkageType.None)
      attributes ~= "$(DIL_LINKAGE extern(" ~ .toString(ltype) ~ "))";

    if (!attributes.length)
      return;

    write(" $(DIL_ATTRIBUTES ", attributes[0]);
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
    string name = d.name ? d.name.str : "enum";
    DECL({
      d.name && write("enum ");
      SYMBOL(name, "enum", d);
    }, d);
    DESC({ MEMBERS("ENUM", name, d); });
    return d;
  }

  D visit(EnumMemberDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL(d.name.str, "enummem", d); }, d, false);
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
      SYMBOL(d.name.str, "template", d);
      writeTemplateParams();
    }, d);
    DESC({ MEMBERS("TEMPLATE", d.name.str, d.decls); });
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
    DECL({ SYMBOL("this", "ctor", d); writeParams(d.params); }, d);
    DESC();
    return d;
  }

  D visit(StaticConstructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("static "); SYMBOL("this", "sctor", d); write("()"); }, d);
    DESC();
    return d;
  }

  D visit(DestructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL("~this", "dtor", d); write("()"); }, d);
    DESC();
    return d;
  }

  D visit(StaticDestructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("static "); SYMBOL("~this", "sdtor", d); write("()"); }, d);
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
      SYMBOL(d.name.str, "function", d);
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
    DECL({ SYMBOL("new", "new", d); writeParams(d.params); }, d);
    DESC();
    return d;
  }

  D visit(DeleteDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL("delete", "delete", d); writeParams(d.params); }, d);
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
      DECL({ write(escape(type), " "); SYMBOL(name.str, "variable", d); }, d);
    DESC();
    return d;
  }

  D visit(InvariantDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL("invariant", "invariant", d); }, d);
    DESC();
    return d;
  }

  D visit(UnittestDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL("unittest", "unittest", d); }, d);
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
