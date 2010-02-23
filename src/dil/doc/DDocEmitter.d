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
       dil.ast.Expressions,
       dil.ast.Parameters,
       dil.ast.Types;
import dil.lexer.Token,
       dil.lexer.Funcs;
import dil.semantic.Module;
import dil.Highlighter,
       dil.Diagnostics,
       dil.SourceText,
       dil.Messages,
       dil.Enums;
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
  Diagnostics reportDiag; /// Collects problem messages.

  /// Constructs a DDocEmitter object.
  /// Params:
  ///   modul = the module to generate text for.
  ///   mtable = the macro table.
  ///   includeUndocumented = whether to include undocumented symbols.
  ///   tokenHL = used to highlight code sections.
  this(Module modul, MacroTable mtable, bool includeUndocumented,
       Diagnostics reportDiag, Highlighter tokenHL)
  {
    this.mtable = mtable;
    this.includeUndocumented = includeUndocumented;
    this.modul = modul;
    this.tokenHL = tokenHL;
    this.reportDiag = reportDiag;
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
    MEMBERS("MODULE", "", modul.root);
    return text;
  }

  /// Reports an undocumented symbol.
  void reportUndocumented()
  {
    if (reportDiag is null)
      return;
    auto loc = currentDecl.begin.getRealLocation();
    loc.setFilePath(modul.getFQN());
    auto kind = DDocProblem.Kind.UndocumentedSymbol;
    reportDiag ~= new DDocProblem(loc, kind, MSG.UndocumentedSymbol);
  }

  /// Reports an empty comment.
  void reportEmptyComment()
  {
    if (reportDiag is null || !this.cmnt.isEmpty())
      return;
    auto loc = currentDecl.begin.getRealLocation();
    loc.setFilePath(modul.getFQN());
    auto kind = DDocProblem.Kind.EmptyComment;
    reportDiag ~= new DDocProblem(loc, kind, MSG.EmptyDDocComment);
  }

  /// Reports a missing params section or undocumented parameters.
  void reportParameters(Parameters params)
  {
    if (reportDiag is null || cmntIsDitto || params.items.length == 0)
      return;
    Token*[] paramNames;
    foreach (param; params.items)
      if (param.hasName)
        paramNames ~= param.name;
    reportParameters(params.begin, paramNames);
  }

  /// ditto
  void reportParameters(TemplateParameters params)
  {
    if (reportDiag is null || cmntIsDitto || params.items.length == 0)
      return;
    Token*[] paramNames;
    foreach (param; params.items)
      paramNames ~= param.name;
    reportParameters(params.begin, paramNames);
  }

  /// Params:
  ///   paramsBegin = the left parenthesis of the parameter list.
  ///   params = the identifier tokens of the parameter names.
  void reportParameters(Token* paramsBegin, Token*[] params)
  {
    assert(currentDecl !is null);
    // TODO: exclude some functions? like "new"?
    // Search for the params section.
    Section paramsSection;
    foreach (s; this.cmnt.sections)
      if (s.Is("params"))
        paramsSection = s;
    if (paramsSection is null)
    {
      auto loc = paramsBegin.getRealLocation();
      loc.setFilePath(modul.getFQN());
      auto kind = DDocProblem.Kind.NoParamsSection;
      reportDiag ~= new DDocProblem(loc, kind, MSG.MissingParamsSection);
      return;
    }
    // Search for undocumented parameters.
    bool[string] documentedParams;
    auto ps = new ParamsSection(paramsSection.name, paramsSection.text);
    foreach (name; ps.paramNames) // Create set of documented parameters.
      documentedParams[name] = true;
    foreach (param; params) // Find undocumented parameters.
      if (!(param.ident.str in documentedParams))
      {
        auto loc = param.getRealLocation();
        loc.setFilePath(modul.getFQN());
        auto kind = DDocProblem.Kind.UndocumentedParam;
        auto msg = Format(MSG.MissingParamsSection, param);
        reportDiag ~= new DDocProblem(loc, kind, msg);
      }
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

  /// The current declaration.
  Node currentDecl;

  /// The template parameters of the current declaration.
  TemplateParameters tparams;

  /// Reflects the fully qualified name of the current symbol's parent.
  string parentFQN;
  /// Counts symbols with the same FQN.
  /// This is useful for anchor names that require unique strings.
  uint[string] fqnCount;

  static char[] toString(uint x)
  {
    char[] str;
    do
      str = cast(char)('0' + (x % 10)) ~ str;
    while (x /= 10)
    return str;
  }

  /// Appends to parentFQN.
  void pushFQN(string name)
  {
    if (parentFQN.length)
      parentFQN ~= ".";
    parentFQN ~= name;

    auto pfqn = parentFQN in fqnCount;
    uint count = pfqn ? *pfqn : 0;
    if (count > 1) // Start adding suffixes with 2.
      parentFQN ~= ":" ~ toString(count);
  }

  /// Returns a unique, identifying string for the current symbol.
  string getSymbolFQN(string name)
  {
    char[] fqn = parentFQN;
    if (fqn.length)
      fqn ~= ".";
    fqn ~= name;

    uint count;
    auto pfqn = fqn in fqnCount;
    if (pfqn)
      count = (*pfqn += 1); // Update counter.
    else
      fqnCount[fqn] = 1; // Start counting with 1.

    if (count > 1) // Start adding suffixes with 2.
      fqn ~= ":" ~ toString(count);
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
    char[] saved_parentFQN;
    /// When constructed, variables are saved.
    /// Params:
    ///   name = the name of the current symbol.
    this(string name)
    { // Save the previous comment of the parent scope.
      saved_prevCmnt = this.outer.prevCmnt;
      saved_cmntIsDitto = this.outer.cmntIsDitto;
      saved_prevDeclOffset = this.outer.prevDeclOffset;
      saved_parentFQN = this.outer.parentFQN;
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
      this.outer.parentFQN = saved_parentFQN;
    }
  }

  bool cmntIsDitto; /// True if current comment is "ditto".

  /// Sets some members and returns true if a comment was found.
  bool ddoc(Node node)
  {
    this.currentDecl = node;
    this.cmnt = DDocUtils.getDDocComment(node);
    if (this.cmnt)
    {
      if (this.cmnt.isDitto) // A ditto comment.
        (this.cmnt = this.prevCmnt), (this.cmntIsDitto = true);
      else // A normal comment.
      {
        reportEmptyComment();
        (this.prevCmnt = this.cmnt), (this.cmntIsDitto = false);
      }
    }
    else
    {
      reportUndocumented();
      if (includeUndocumented)
        this.cmnt = this.emptyCmnt; // Assign special empty comment.
    }
    return this.cmnt !is null;
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
                    "$(DDOC_PARAM_DESC ",
                      scanCommentText(ps.paramDescs[i]),
                    ")",
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
  /// $(LI skips HTML tags)
  /// $(LI escapes '&lt;', '&gt;' and '&amp;' with named HTML entities)
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
    uint level = 0; // Nesting level of macro invocations and
                    // the parentheses inside of them.
    while (p < end)
    {
      switch (*p)
      {
      case '$':
        auto macroBegin = p;
        if (p+2 < end && p[1] == '(')
          if ((p += 2), scanIdentifier(p, end))
          {
            level++;
            result ~= makeString(macroBegin, p); // Copy "$(MacroName".
            continue;
          }
        p = macroBegin;
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
      case '(':
        if (level)
          ++level, result ~= "(";
        else
          result ~= "$(LP)";
        break;
      case ')':
        if (level)
          --level, result ~= ")";
        else
          result ~= "$(RP)";
        break;
      // case '\'': result ~= "&apos;"; break; // &#39;
      // case '"': result ~= "&quot;"; break;
      case '>': result ~= "&gt;"; break;
      case '&':
        auto entityBegin = p;
        if (++p < end && (isalpha(*p) || *p == '#'))
        {
          if (*p == '#')
            while (++p < end && isdigit(*p)){} // Numerical entity.
          else
            while (++p < end && isalpha(*p)){} // Named entity.
          if (p < end && *p == ';') {
            result ~= makeString(entityBegin, ++p); // Copy valid entity.
            continue;
          }
          p = entityBegin + 1; // Reset. It's not a valid entity.
        }
        result ~= "&amp;";
        continue;
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
            uint lines; // Number of lines in the code text.

            codeText = DDocUtils.unindentText(codeText);
            codeText = tokenHL.highlightTokens(codeText, modul.getFQN(),
                                               lines);
            result ~= "$(D_CODE\n";
              result ~= "$(DIL_CODELINES ";
              for (auto line = 1; line <= lines; line++)
                result ~= Format("{}\n", line);
              result ~= "),$(DIL_CODETEXT " ~ escapeLPRP(codeText) ~ ")";
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
  /// Also escapes '(' and ')' with $&#40;LP&#41; and $&#40;RP&#41;.
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
        case '(': result ~= "$(LP)"; break;
        case ')': result ~= "$(RP)"; break;
        default:  result ~= c;
      }
    if (result.length != text.length)
      return result;
    // Nothing escaped. Return original text.
    delete result;
    return text;
  }

  /// Escapes '(' and ')' with $&#40;LP&#41; and $&#40;RP&#41;.
  char[] escapeLPRP(char[] text)
  {
    char[] result = new char[text.length]; // Reserve space.
    result.length = 0;
    foreach(c; text)
      if (c == '(')
        result ~= "$(LP)";
      else if (c == ')')
        result ~= "$(RP)";
      else
        result ~= c;
    if (result.length != text.length)
      return result;
    // Nothing escaped. Return original text.
    delete result;
    return text;
  }

  /// Returns the escaped text between begin and end.
  string escape(Token* begin, Token* end)
  {
    return this.escape(textSpan(begin, end));
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
    reportParameters(params);
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
        write(escape(typeBegin, param.type.end)); // Write type.
        if (param.hasName)
          write(" $(DDOC_PARAM ", param.nameStr, ")");
        if (param.isDVariadic)
          write("...");
        if (param.defValue)
          write(" = $(DIL_DEFVAL ",
                escape(param.defValue.begin, param.defValue.end), ")");
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
    reportParameters(tparams);
    write("$(DIL_TEMPLATE_PARAMS ");
    foreach (tparam; tparams.items)
    {
      void writeSpecDef(TypeNode spec, TypeNode def)
      {
        if (spec) write(" : ", escape(spec.baseType.begin, spec.end));
        if (def)  write(" = $(DIL_DEFVAL ",
                        escape(def.baseType.begin, def.end), ")");
      }
      void writeSpecDef2(Expression spec, Expression def)
      {
        if (spec) write(" : ", escape(spec.begin, spec.end));
        if (def)  write(" = $(DIL_DEFVAL ", escape(def.begin, def.end), ")");
      }
      if (auto p = tparam.Is!(TemplateAliasParameter))
        write("$(DIL_TPALIAS $(DIL_TPID ", p.nameStr, ")"),
        writeSpecDef(p.specType, p.defType),
        write(")");
      else if (auto p = tparam.Is!(TemplateTypeParameter))
        write("$(DIL_TPTYPE $(DIL_TPID ", p.nameStr, ")"),
        writeSpecDef(p.specType, p.defType),
        write(")");
      else if (auto p = tparam.Is!(TemplateTupleParameter))
        write("$(DIL_TPTUPLE $(DIL_TPID ", p.nameStr, "))");
      else if (auto p = tparam.Is!(TemplateValueParameter))
        write("$(DIL_TPVALUE "),
        write(escape(p.valueType.baseType.begin, p.valueType.end)),
        write(" $(DIL_TPID ", p.nameStr, ")"),
        writeSpecDef2(p.specValue, p.defValue),
        write(")");
      else if (auto p = tparam.Is!(TemplateThisParameter))
        write("$(DIL_TPTHIS $(DIL_TPID ", p.nameStr, ")"),
        writeSpecDef(p.specType, p.defType),
        write(")");
      write(", ");
    }
    if (tparams.items)
      text = text[0..$-2]; /// Slice off last ", ".
    write(")");
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
    auto text = escape(basesBegin, bases[$-1].end);
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
      // Handle undocumented symbols separately.
      // This way they don't interrupt consolidated declarations (via 'ditto'.)
      writeDECL();
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
    auto isEmpty = this.cmnt is this.emptyCmnt;
    if (cmntIsDitto && !isEmpty)
      return; // Don't write a description when we have a ditto-comment.
    write("\n$(DDOC_DECL_DD ");
    if (isEmpty)
      write("\n$(DIL_NOCMNT)");
    else
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
      return;
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
      return;
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
      auto type = escape(vd.typeNode.baseType.begin, vd.typeNode.end);
      foreach (name; vd.names)
        DECL({ write(kind, " "); write(type, " ");
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
    auto type = escape(d.returnType.baseType.begin, d.returnType.end);
    DECL({
      write("$(DIL_RETTYPE ", type, ") ");
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
      type = escape(d.typeNode.baseType.begin, d.typeNode.end);
    foreach (name; d.names)
      DECL({ write(type, " "); SYMBOL(name.str, "variable", d); }, d);
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
