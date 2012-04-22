/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.doc.DDocEmitter;

import dil.doc.Parser,
       dil.doc.Macro,
       dil.doc.Doc;
import dil.ast.DefaultVisitor,
       dil.ast.TypePrinter,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Statements,
       dil.ast.Expressions,
       dil.ast.Parameters,
       dil.ast.Types;
import dil.lexer.Token,
       dil.lexer.Funcs;
import dil.semantic.Module;
import dil.i18n.Messages;
import dil.Unicode : isUnicodeAlpha;
import dil.Highlighter,
       dil.Diagnostics,
       dil.SourceText,
       dil.Enums;
import common;

import tango.text.Ascii : toUpper, icompare;

/// Traverses the syntax tree and writes DDoc macros to a string buffer.
abstract class DDocEmitter : DefaultVisitor2
{
  char[] text; /// The buffer that is written to.
  bool includeUndocumented; /// Include undocumented symbols?
  bool includePrivate; /// Include symbols with private protection?
  MacroTable mtable; /// The macro table.
  Module modul; /// The module.
  Highlighter tokenHL; /// The token highlighter.
  Diagnostics reportDiag; /// Collects problem messages.
  TypePrinter typePrinter; /// Used to print type chains.
  /// Counts code examples in comments.
  /// This is used to make the code lines targetable in HTML.
  uint codeExamplesCounter;

  /// Constructs a DDocEmitter object.
  /// Params:
  ///   modul = The module to generate text for.
  ///   mtable = The macro table.
  ///   includeUndocumented = Whether to include undocumented symbols.
  ///   includePrivate = Whether to include private symbols.
  ///   tokenHL = Used to highlight code sections.
  this(Module modul, MacroTable mtable,
       bool includeUndocumented, bool includePrivate,
       Diagnostics reportDiag, Highlighter tokenHL)
  {
    this.mtable = mtable;
    this.includeUndocumented = includeUndocumented;
    this.includePrivate = includePrivate;
    this.modul = modul;
    this.tokenHL = tokenHL;
    this.reportDiag = reportDiag;
    this.typePrinter = new TypePrinter();
  }

  /// Entry method.
  char[] emit()
  {
    if (isDDocFile(modul))
    { // The module is actually a DDoc text file.
      auto c = DDocUtils.getDDocComment(getDDocText(modul));
      foreach (s; c.sections)
        if (s.Is("macros"))
        { // Declare the macros in this section.
          auto ms = new MacrosSection(s.name, s.text);
          mtable.insert(ms.macroNames, ms.macroTexts);
        }
        else
          write(s.wholeText);
      return text;
    }

    // Handle as a normal D module with declarations:

    // Initialize the root symbol in the symbol tree.
    auto lexer = modul.parser.lexer;
    symbolTree[0] = new DocSymbol(modul.moduleName, modul.getFQN(), K.Module,
      null,
      locationOf(lexer.firstToken()),
      locationOf(lexer.tail)
    ); // Root symbol.

    if (auto d = modul.moduleDecl)
      if (ddoc(d))
      {
        if (auto copyright = cmnt.takeCopyright())
          mtable.insert("COPYRIGHT", copyright.text);
        writeComment();
      }
    // Start traversing the tree and emitting macro text.
    MEMBERS("MODULE", "", modul.root);
    return text;
  }

  /// Returns the location of t.
  Location locationOf(Token* t, cstring filePath = null)
  {
    return t.getRealLocation(filePath ? filePath : modul.filePath);
  }

  /// Reports an undocumented symbol.
  void reportUndocumented()
  {
    if (reportDiag is null)
      return;
    auto loc = locationOf(currentDecl.begin, modul.getFQN());
    reportDDocProblem(loc, DDocProblem.Kind.UndocumentedSymbol,
      MID.UndocumentedSymbol);
  }

  /// Reports an empty comment.
  void reportEmptyComment()
  {
    if (reportDiag is null || !this.cmnt.isEmpty())
      return;
    auto loc = locationOf(currentDecl.begin, modul.getFQN());
    reportDDocProblem(loc, DDocProblem.Kind.EmptyComment, MID.EmptyDDocComment);
  }

  /// Reports a problem.
  void reportDDocProblem(Location loc, DDocProblem.Kind kind, MID mid, ...)
  {
    reportDiag ~= new DDocProblem(loc, kind,
      reportDiag.formatMsg(mid, _arguments, _argptr));
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
  ///   paramsBegin = The left parenthesis of the parameter list.
  ///   params = The identifier tokens of the parameter names.
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
      auto loc = locationOf(paramsBegin, modul.getFQN());
      reportDDocProblem(loc, DDocProblem.Kind.NoParamsSection,
        MID.MissingParamsSection);
      return;
    }
    // Search for undocumented parameters.
    bool[hash_t] documentedParams;
    auto ps = new ParamsSection(paramsSection.name, paramsSection.text);
    foreach (name; ps.paramNames) // Create set of documented parameters.
      documentedParams[hashOf(name)] = true;
    foreach (param; params) // Find undocumented parameters.
      if (!(hashOf(param.ident.str) in documentedParams))
      {
        auto loc = locationOf(param, modul.getFQN());
        reportDDocProblem(loc, DDocProblem.Kind.UndocumentedParam,
          MID.UndocumentedParam, param);
      }
  }

  /// Returns true if the source text starts with "Ddoc\n" (ignores letter case.)
  static bool isDDocFile(Module mod)
  {
    auto text = mod.sourceText.text();
    if (text.length >= "ddoc\n".length && // Check for minimum length.
        icompare(text[0..4], "ddoc") == 0 && // Check first four characters.
        isNewline(text.ptr + 4)) // Check for a newline.
      return true;
    return false;
  }

  /// Returns the DDoc text of this module.
  static cstring getDDocText(Module mod)
  {
    auto text = mod.sourceText.text();
    auto p = text.ptr + "ddoc".length;
    if (scanNewline(p)) // Skip the newline.
      // Exclude preceding "Ddoc\n".
      return text[p-text.ptr .. $];
    return null;
  }
/+
  char[] textSpan(Token* left, Token* right)
  {
    //assert(left && right && (left.end <= right.start || left is right));
    //char[] result;
    //TODO: filter out whitespace tokens.
    return Token.textSpan(left, right);
  }
+/
  /// The current declaration.
  Node currentDecl;

  /// The template parameters of the current declaration.
  TemplateParameters currentTParams;

  /// Reflects the fully qualified name of the current symbol's parent.
  cstring parentFQN;
  /// Counts symbols with the same FQN.
  /// This is useful for anchor names that require unique strings.
  uint[hash_t] fqnCount;

  /// Appends to parentFQN.
  void pushFQN(cstring name)
  {
    if (parentFQN.length)
      parentFQN ~= ".";
    parentFQN ~= name;

    auto pfqn = hashOf(parentFQN) in fqnCount;
    uint count = pfqn ? *pfqn : 0;
    if (count > 1) // Start adding suffixes with 2.
      parentFQN ~= ":" ~ String(count);
  }

  /// Returns a unique, identifying string for the current symbol.
  cstring getSymbolFQN(cstring name)
  {
    char[] fqn = parentFQN.dup;
    if (fqn.length)
      fqn ~= ".";
    fqn ~= name;

    uint count;
    auto hash = hashOf(fqn);
    auto pfqn = hash in fqnCount;
    if (pfqn)
      count = (*pfqn += 1); // Update counter.
    else
      fqnCount[hash] = 1; // Start counting with 1.

    if (count > 1) // Start adding suffixes with 2.
      fqn ~= ":" ~ String(count);
    return fqn;
  }

  DDocComment cmnt; /// Current comment.
  DDocComment prevCmnt; /// Previous comment in scope.
  /// An empty comment. Used for undocumented symbols.
  static DDocComment emptyCmnt;

  /// Initializes the empty comment.
  static this()
  {
    emptyCmnt = new DDocComment(null, null, null);
  }

  /// Keeps track of previous comments in each scope.
  scope class DDocScope
  {
    DDocComment saved_prevCmnt;
    bool saved_cmntIsDitto;
    size_t saved_prevDeclOffset;
    cstring saved_parentFQN;
    /// When constructed, variables are saved.
    /// Params:
    ///   name = The name of the current symbol.
    this(cstring name)
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
  bool ddoc(Declaration node)
  {
    if (!includePrivate && node.prot == Protection.Private)
      return false;
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
  static string[hash_t] specialSections;
  static this()
  {
    foreach (name; ["AUTHORS", "BUGS", "COPYRIGHT", "DATE", "DEPRECATED",
                    "EXAMPLES", "HISTORY", "LICENSE", "RETURNS", "SEE_ALSO",
                    "STANDARDS", "THROWS", "VERSION"] ~
                   ["AUTHOR"]) // Addition by dil.
      specialSections[hashOf(name)] = name;
  }

  /// Writes the DDoc comment to the text buffer.
  void writeComment()
  {
    auto c = this.cmnt;
    assert(c !is null);
    write("\1DDOC_SECTIONS ");
      foreach (s; c.sections)
      {
        if (s is c.summary)
          write("\n\1DDOC_SUMMARY ");
        else if (s is c.description)
          write("\n\1DDOC_DESCRIPTION ");
        else if (auto name = hashOf(toUpper(s.name.dup)) in specialSections)
          write("\n\1DDOC_", *name, " ");
        else if (s.Is("params"))
        { // Process parameters section.
          auto ps = new ParamsSection(s.name, s.text);
          write("\n\1DDOC_PARAMS ");
          foreach (i, paramName; ps.paramNames)
            write("\n\1DDOC_PARAM_ROW "
                    "\1DDOC_PARAM_ID \1DDOC_PARAM ", paramName, "\2\2",
                    "\1DDOC_PARAM_DESC ",
                      scanCommentText(ps.paramDescs[i]),
                    "\2"
                  "\2");
          write("\2");
          continue;
        }
        else if (s.Is("macros"))
        { // Declare the macros in this section.
          auto ms = new MacrosSection(s.name, s.text);
          mtable.insert(ms.macroNames, ms.macroTexts);
          continue;
        }
        else
          write("\n\1DDOC_SECTION "
            "\1DDOC_SECTION_H ", s.name.replace('_', ' '), ":\2");
        write("\1DIL_CMT ", scanCommentText(s.text), "\2\2");
      }
    write("\2");
  }

  /// Scans the comment text and:
  /// $(UL
  /// $(LI skips HTML tags)
  /// $(LI escapes '&lt;', '&gt;' and '&amp;' with named HTML entities)
  /// $(LI inserts $&#40;DDOC_BLANKLINE&#41; in place of '\n\n')
  /// $(LI highlights the tokens in code sections)
  /// )
  cstring scanCommentText(cstring text)
  {
    auto p = text.ptr;
    auto lastLineEnd = p; // The position of the last \n seen.
    auto end = p + text.length;
    char[] result = new char[text.length]; // Reserve space.
    result.length = 0;
    uint level = 0; // Nesting level of macro invocations and
                    // the parentheses inside of them.
    char[] parens; // Stack of parentheses and markers.
    while (p < end)
    {
      switch (*p)
      {
      case '$':
        auto p2 = p+2;
        if (p2 < end && p[1] == '(' &&
            (isidbeg(*p2) || isUnicodeAlpha(p2, end))) // IdStart
        {
          parens ~= Macro.Marker.Closing;
          result ~= Macro.Marker.Opening; // Relace "$(".
          p = p2; // Skip "$(".
        }
        goto default;
      case '(':
        if (parens.length) parens ~= ')'; goto default;
      case ')':
        if (!parens.length) goto default;
        auto closing_char = parens[$-1];
        result ~= closing_char; // Replace ')'.
        parens = parens[0..$-1]; // Pop one char.
        break;
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
          result ~= String(begin, p);
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
          result ~= String(begin, p);
        }
        else
          result ~= "&lt;";
        continue;
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
            result ~= String(entityBegin, ++p); // Copy valid entity.
            continue;
          }
          p = entityBegin + 1; // Reset. It's not a valid entity.
        }
        result ~= "&amp;";
        continue;
      case '\n':
        if (!(p+1 < end && p[1] == '\n'))
        {
          lastLineEnd = p;
          goto default;
        }
        ++p;
        result ~= "\n\1DDOC_BLANKLINE\2\n";
        lastLineEnd = p;
        break;
      case '-':
        if (p+2 < end && p[1] == '-' && p[2] == '-' &&
            isAllSpace(lastLineEnd + 1, p))
        { // Found "---" at start of line.
          while (p < end && *p == '-') // Skip trailing dashes.
            p++;
          auto codeBegin = p;
          while (p < end && isspace(*p)) // Skip whitespace.
            p++;
          if (p < end && *p == '\n') // Skip first newline.
            codeBegin = ++p;
          // Find closing dashes.
          while (p < end && !(*p == '-' && p+2 < end &&
                            p[1] == '-' && p[2] == '-' &&
                            isAllSpace(lastLineEnd + 1, p)))
          {
            if (*p == '\n')
              lastLineEnd = p;
            p++;
          }

          // Remove last newline if present.
          auto codeEnd = p;
          while (isspace(*--codeEnd))
          {}
          if (*codeEnd != '\n') // Leaving the pointer on '\n' will exclude it.
            codeEnd++; // Include the non-newline character.
          if (codeBegin < codeEnd)
          { // Highlight the extracted source code.
            cstring codeText = String(codeBegin, codeEnd);
            uint lines; // Number of lines in the code text.

            codeExamplesCounter++; // Found a code section. Increment counter.

            codeText = DDocUtils.unindentText(codeText);
            codeText = tokenHL.highlightTokens(codeText, modul.getFQN(), lines);
            result ~= "\1D_CODE\n"
              "\1DIL_CODELINES ";
              for (uint num = 1; num <= lines; num++)
              {
                auto numtxt = String(num);
                auto id = "L"~numtxt~"_ex"~String(codeExamplesCounter);
                result ~= `<a href="#`~id~`" name="`~id~`">`;
                result ~= numtxt;
                result ~= `</a>`"\n";
              }
              result ~= "\2,\1DIL_CODETEXT \4" ~ codeText ~ "\2"
            "\n\2";
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
    foreach (c; parens)
      if (c == Macro.Marker.Closing) // Unclosed macros?
        result ~= Macro.Marker.Unclosed; // Add marker for errors.
    return result;
  }

  /// Writes an array of strings to the text buffer.
  void write(cstring[] strings...)
  {
    foreach (s; strings)
      text ~= s;
  }

  /// Writes a type chain to the buffer.
  void write(TypeNode type)
  {
    text ~= xml_escape(typePrinter.print(type));
  }

  /// Writes an expression to the buffer.
  void writeE(Expression e)
  {
    text ~= tokenHL.highlightTokens(e.begin, e.end, true);
  }

  /// Writes params to the text buffer.
  void writeParams(Parameters params)
  {
    reportParameters(params);
    write("\1DIL_PARAMS ");
    auto item_count = params.items.length;
    foreach (param; params.items)
    {
      if (param.isCVariadic)
        write("...");
      else
      {
        assert(param.type);
        // Write storage class(es).
        auto lastSTC = param.tokenOfLastSTC();
        if (lastSTC) // Write storage classes.
          write(tokenHL.highlightTokens(param.begin, lastSTC, true), " ");
        write(param.type); // Write the type.
        if (param.hasName)
          write(" \1DDOC_PARAM ", param.nameStr, "\2");
        if (param.isDVariadic)
          write("...");
        if (param.defValue)
          write(" = \1DIL_DEFVAL "), writeE(param.defValue), write("\2");
      }
      --item_count && (text ~= ", "); // Skip for last item.
    }
    write("\2");
  }

  /// Writes the current template parameters to the text buffer.
  void writeTemplateParams()
  {
    if (!currentTParams)
      return;

    void writeTorE(Node n)
    {
      n.isType() ? write(n.to!(TypeNode)) : writeE(n.to!(Expression));
    }
    void writeSpecDef(Node spec, Node def)
    {
      if (spec) write(" : \1DIL_SPEC "), writeTorE(spec), write("\2");
      if (def)  write(" = \1DIL_DEFVAL "), writeTorE(def), write("\2");
    }

    reportParameters(currentTParams);
    write("\1DIL_TEMPLATE_PARAMS ");
    auto item_count = currentTParams.items.length;
    foreach (tparam; currentTParams.items)
    {
      if (auto p = tparam.Is!(TemplateAliasParam))
        write("\1DIL_TPALIAS \1DIL_TPID ", p.nameStr, "\2"),
        writeSpecDef(p.spec, p.def),
        write("\2");
      else if (auto p = tparam.Is!(TemplateTypeParam))
        write("\1DIL_TPTYPE \1DIL_TPID ", p.nameStr, "\2"),
        writeSpecDef(p.specType, p.defType),
        write("\2");
      else if (auto p = tparam.Is!(TemplateTupleParam))
        write("\1DIL_TPTUPLE \1DIL_TPID ", p.nameStr, "\2\2");
      else if (auto p = tparam.Is!(TemplateValueParam))
        write("\1DIL_TPVALUE "),
        write(p.valueType),
        write(" \1DIL_TPID ", p.nameStr, "\2"),
        writeSpecDef(p.specValue, p.defValue),
        write("\2");
      else if (auto p = tparam.Is!(TemplateThisParam))
        write("\1DIL_TPTHIS \1DIL_TPID ", p.nameStr, "\2"),
        writeSpecDef(p.specType, p.defType),
        write("\2");
      --item_count && write(", ");
    }
    write("\2");
    currentTParams = null;
  }

  /// Writes bases to the text buffer.
  void writeInheritanceList(BaseClassType[] bases)
  {
    auto item_count = bases.length;
    if (item_count == 0)
      return;
    write(" \1DIL_BASECLASSES ");
    foreach (base; bases)
      write("\1DIL_BASECLASS "), write(base),
      write(--item_count ? "\2, " : "\2");
    write("\2");
  }

  /// Offset at which to insert a declaration with a "ditto" comment.
  size_t prevDeclOffset;

  /// Writes a declaration to the text buffer.
  void DECL(void delegate() dg, Declaration d, bool writeSemicolon = true)
  {
    void writeDECL()
    {
      write("\n\1DDOC_DECL ");
      dg();
      writeSemicolon && write("\1DIL_SC\2");
      writeAttributes(d);
      write(" \1DIL_SYMEND ", currentSymbolParams, "\2\2");
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
      text = null;
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
    write("\n\1DDOC_DECL_DD ");
    if (isEmpty)
      write("\1DIL_NOCMNT\2");
    else
      writeComment();
    dg && dg();
    write("\2");
  }

  /// Saves the attributes of the current symbol.
  cstring currentSymbolParams;

  /// Writes a symbol to the text buffer.
  /// E.g: &#36;(DIL_SYMBOL scan, Lexer.scan, func, 229, 646);
  void SYMBOL(cstring name, K kind, Declaration d)
  {
    auto kindStr = DocSymbol.kindIDToStr[kind];
    auto fqn = getSymbolFQN(name);
    auto loc = locationOf(d.begin);
    auto loc_end = locationOf(d.end);
    storeAttributes(d);
    addSymbol(name, fqn, kind, loc, loc_end);
    currentSymbolParams = Format("{}, {}, {}, {}, {}",
      name, fqn, kindStr, loc.lineNum, loc_end.lineNum);
    write("\1DIL_SYMBOL ", currentSymbolParams, "\2");
    // write("\1DDOC_PSYMBOL ", name, "\2"); // DMD's macro with no info.
  }

  /// The symbols that will appear in the result document.
  DocSymbol[hash_t] symbolTree;

  /// Adds a symbol to the symbol tree.
  void addSymbol(cstring name, cstring fqn, K kind,
    Location begin, Location end)
  {
    auto attrs = currentAttributes.asArray();
    auto symbol = new DocSymbol(name, fqn, kind, attrs, begin, end);
    symbolTree[hashOf(fqn)] = symbol; // Add the symbol itself.
    symbolTree[hashOf(parentFQN)].members ~= symbol; // Append as a child to parent.
  }

  /// Wraps the DDOC_kind_MEMBERS macro around the text
  /// written by visit(members).
  void MEMBERS(D)(cstring kind, cstring name, D members)
  {
    scope s = new DDocScope(name);
    write("\n\1DDOC_"~kind~"_MEMBERS ");
    if (members !is null)
      super.visit(members);
    write("\2");
  }

  /// Writes a class or interface declaration.
  void writeClassOrInterface(T)(T d)
  {
    if (!ddoc(d))
      return;
    const kind = is(T == ClassDecl) ? "class" : "interface";
    const kindID = is(T == ClassDecl) ? K.Class : K.Interface;
    const KIND = is(T == ClassDecl) ? "CLASS" : "INTERFACE";
    DECL({
      write("\1DIL_KW ", kind, "\2 ");
      SYMBOL(d.name.text, kindID, d);
      writeTemplateParams();
      writeInheritanceList(d.bases);
    }, d);
    DESC({ MEMBERS(KIND, d.name.text, d.decls); });
  }

  /// Writes a struct or union declaration.
  void writeStructOrUnion(T)(T d)
  {
    if (!ddoc(d))
      return;
    const kind = is(T == StructDecl) ? "struct" : "union";
    const kindID = is(T == StructDecl) ? K.Struct : K.Union;
    const KIND = is(T == StructDecl) ? "STRUCT" : "UNION";
    cstring name = d.name ? d.name.text : kind;
    DECL({
      d.name && write("\1DIL_KW ", kind, "\2 ");
      SYMBOL(name, kindID, d);
      writeTemplateParams();
    }, d);
    DESC({ MEMBERS(KIND, name, d.decls); });
  }

  /// Writes an alias or typedef declaration.
  void writeAliasOrTypedef(T)(T d)
  {
    const kind = is(T == AliasDecl) ? "alias" : "typedef";
    const kindID = is(T == AliasDecl) ? K.Alias : K.Typedef;
    if (auto vd = d.vardecl.Is!(VariablesDecl))
      foreach (name; vd.names)
        DECL({
          write("\1DIL_KW ", kind, "\2 "); write(vd.typeNode); write(" ");
          auto saved_begin = vd.begin;
          // 'vd' instead of 'd' is passed to SYMBOL, because it
          // has a linkageType member, which has to appear in the docs.
          vd.begin = d.begin; // Use the begin token of the outer declaration.
          SYMBOL(name.text, kindID, vd);
          vd.begin = saved_begin; // Restore to the old value.
        }, d);
    else
      assert(0, "unhandled case");
    DESC();
  }

  /// All attributes a symbol can have.
  struct SymbolAttributes
  {
    string prot;   /// Protection attribute.
    string[] stcs; /// Storage classes.
    string link;   /// Linkage type.
    /// Returns all attributes in an array.
    string[] asArray()
    {
      string[] attrs;
      if (prot.length)
        attrs = [prot];
      attrs ~= stcs;
      if (link.length)
        attrs ~= link;
      return attrs;
    }
  }

  /// The attributes of the current symbol.
  SymbolAttributes currentAttributes;

  /// Stores the attributes of the current symbol.
  void storeAttributes(Declaration d)
  {
    alias currentAttributes attrs;
    attrs.prot = d.prot == Protection.None ? null : EnumString(d.prot);

    auto stcs = d.stcs;
    stcs &= ~StorageClass.Auto; // Ignore "auto".
    attrs.stcs = EnumString.all(stcs);

    LinkageType ltype;
    if (auto vd = d.Is!(VariablesDecl))
      ltype = vd.linkageType;
    else if (auto fd = d.Is!(FunctionDecl))
      ltype = fd.linkageType;

    attrs.link = ltype == LinkageType.None ? null : EnumString(ltype);
  }

  /// Writes the attributes of a declaration in brackets.
  void writeAttributes(Declaration d)
  {
    string[] attributes;

    if (currentAttributes.prot.length)
      attributes ~= "\1DIL_PROT " ~ currentAttributes.prot ~ "\2";

    foreach (stcString; currentAttributes.stcs)
      attributes ~= "\1DIL_STC " ~ stcString ~ "\2";

    if (currentAttributes.link.length)
      attributes ~= "\1DIL_LINKAGE extern(" ~ currentAttributes.link ~ ")\2";

    if (!attributes.length)
      return;

    write(" \1DIL_ATTRIBUTES ", attributes[0]);
    foreach (attribute; attributes[1..$])
      write(", ", attribute);
    write("\2");
  }

  alias DocSymbol.Kind K;

override:
  alias super.visit visit;

  void visit(AliasDecl d)
  {
    if (ddoc(d))
      writeAliasOrTypedef(d);
  }

  void visit(TypedefDecl d)
  {
    if (ddoc(d))
      writeAliasOrTypedef(d);
  }

  void visit(EnumDecl d)
  {
    if (!ddoc(d))
      return;
    cstring name = d.name ? d.name.text : "enum";
    DECL({
      d.name && write("\1DIL_KW enum\2 ");
      SYMBOL(name, K.Enum, d);
      d.baseType && (write(" : "), write(d.baseType));
    }, d);
    DESC({ MEMBERS("ENUM", name, d); });
  }

  void visit(EnumMemberDecl d)
  {
    if (!ddoc(d))
      return;
    // TODO: emit d.type (D2).
    DECL({ SYMBOL(d.name.text, K.Enummem, d); }, d, false);
    DESC();
  }

  void visit(TemplateDecl d)
  {
    this.currentTParams = d.tparams;
    if (d.isWrapper())
    { // This is a templatized class/interface/struct/union/function.
      super.visit(d.decls);
      this.currentTParams = null;
      return;
    }
    if (!ddoc(d))
      return;
    DECL({
      version(D2)
      if (d.isMixin) write("\1DIL_KW mixin\2 ");
      write("\1DIL_KW template\2 ");
      SYMBOL(d.name.text, K.Template, d);
      writeTemplateParams();
    }, d);
    DESC({ MEMBERS("TEMPLATE", d.name.text, d.decls); });
  }

  void visit(ClassDecl d)
  {
    writeClassOrInterface(d);
  }

  void visit(InterfaceDecl d)
  {
    writeClassOrInterface(d);
  }

  void visit(StructDecl d)
  {
    writeStructOrUnion(d);
  }

  void visit(UnionDecl d)
  {
    writeStructOrUnion(d);
  }

  void visit(ConstructorDecl d)
  {
    if (!ddoc(d))
      return;
    DECL({ SYMBOL("this", K.Ctor, d);
      version(D2)
      writeTemplateParams();
      writeParams(d.params);
    }, d);
    DESC();
  }

  void visit(StaticCtorDecl d)
  {
    if (!ddoc(d))
      return;
    DECL({ write("\1DIL_KW static\2 ");
      SYMBOL("this", K.Sctor, d); write("()"); }, d);
    DESC();
  }

  void visit(DestructorDecl d)
  {
    if (!ddoc(d))
      return;
    DECL({ SYMBOL("~this", K.Dtor, d); write("()"); }, d);
    DESC();
  }

  void visit(StaticDtorDecl d)
  {
    if (!ddoc(d))
      return;
    DECL({ write("\1DIL_KW static\2 ");
      SYMBOL("~this", K.Sdtor, d); write("()"); }, d);
    DESC();
  }

  void visit(FunctionDecl d)
  {
    if (!ddoc(d))
      return;
    DECL({
      if (d.returnType)
        write("\1DIL_RETTYPE "), write(d.returnType), write("\2 ");
      else write("\1DIL_KW auto\2 ");
      SYMBOL(d.name.text, K.Function, d);
      writeTemplateParams();
      writeParams(d.params);
    }, d);
    DESC();
  }

  void visit(NewDecl d)
  {
    if (!ddoc(d))
      return;
    DECL({ SYMBOL("new", K.New, d); writeParams(d.params); }, d);
    DESC();
  }

  void visit(DeleteDecl d)
  {
    if (!ddoc(d))
      return;
    DECL({ SYMBOL("delete", K.Delete, d); writeParams(d.params); }, d);
    DESC();
  }

  void visit(VariablesDecl d)
  {
    if (!ddoc(d))
      return;
    foreach (name; d.names)
      DECL({
        if (d.typeNode) write(d.typeNode);
        else write("\1DIL_KW auto\2");
        write(" ");
        SYMBOL(name.text, K.Variable, d);
      }, d);
    DESC();
  }

  void visit(InvariantDecl d)
  {
    if (!ddoc(d))
      return;
    DECL({ SYMBOL("invariant", K.Invariant, d); }, d);
    DESC();
  }

  void visit(UnittestDecl d)
  {
    if (!ddoc(d))
      return;
    DECL({ SYMBOL("unittest", K.Unittest, d); }, d);
    DESC();
  }

  void visit(DebugDecl d)
  {
    d.compiledDecls && visitD(d.compiledDecls);
  }

  void visit(VersionDecl d)
  {
    d.compiledDecls && visitD(d.compiledDecls);
  }

  void visit(StaticIfDecl d)
  {
    d.ifDecls && visitD(d.ifDecls);
  }
}

/// A class that holds some info about a symbol.
class DocSymbol
{
  /// Enum of symbol kinds.
  static enum Kind
  {
    Package, Module, Template, Class, Interface, Struct,
    Union, Alias, Typedef, Enum, Enummem, Variable, Function,
    Invariant, New, Delete, Unittest, Ctor, Dtor, Sctor, Sdtor
  }

  cstring name, fqn; /// Name and fully qualified name.
  Kind kind; /// The kind of this symbol.
  Location begin, end; /// Beginning and end locations.
  DocSymbol[] members; /// All symbol members.
  string[] attrs; /// All attributes of this symbol.

  /// Constructs a DocSymbol object.
  this(cstring name, cstring fqn, Kind kind, string[] attrs,
    Location begin, Location end)
  {
    this.name = name;
    this.fqn = fqn;
    this.kind = kind;
    this.attrs = attrs;
    this.begin = begin;
    this.end = end;
  }

  /// Symbol kinds as strings.
  static string[] kindIDToStr = ["package", "module", "template",
    "class", "interface", "struct", "union", "alias", "typedef",
    "enum", "enummem", "variable", "function", "invariant", "new",
    "delete", "unittest", "ctor", "dtor", "sctor", "sdtor"];

  /// Maps the kind of a symbol to its ID.
  /// Must match the list in "kandil/js/symbols.js".
  static uint[hash_t] kindStrToID;
  /// Maps the attribute of a symbol to its ID.
  /// Must match the list in "kandil/js/symbols.js".
  static uint[hash_t] attrToID;
  /// Initialize the associative arrays.
  static this()
  {
    foreach (i, kind; kindIDToStr)
      kindStrToID[hashOf(kind)] = i;

    // Combine attributes and add them to attrToID.
    auto attrs = EnumString.prots[1..$] ~
      EnumString.stcs[1..$] ~ EnumString.ltypes[1..$];
    foreach (i, attr; attrs)
      attrToID[hashOf(attr)] = i;
  }

  /// Return the attributes as IDs. E.g.: "[1,9,22]"
  cstring formatAttrsAsIDs()
  {
    if (!attrs.length)
      return "[]";
    char[] result = "[".dup;
    foreach (attr; attrs)
      result ~= String(attrToID[hashOf(attr)]) ~ ",";
    result[$-1] = ']';
    return result;
  }
}
