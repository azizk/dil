/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.DDoc;

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
import dil.Information;
import dil.Converter;
import dil.SourceText;
import common;

import tango.stdc.time : time_t, time, ctime;
import tango.stdc.string : strlen;
import tango.text.Ascii : toUpper;
import tango.io.File;
import tango.io.FilePath;

void execute(string[] filePaths, string destDir, string[] macroPaths,
             bool incUndoc, bool verbose, InfoManager infoMan)
{
  // Parse macro files.
  MacroTable mtable;
  MacroParser mparser;
  foreach (macroPath; macroPaths)
  {
    auto macros = mparser.parse(loadMacroFile(macroPath, infoMan));
    mtable = new MacroTable(mtable);
    mtable.insert(macros);
  }

//   foreach (k, v; mtable.table)
//     Stdout(k)("=")(v.text);

  auto tokenHL = new TokenHighlighter(infoMan); // For DDoc code sections.

  // Process D files.
  foreach (filePath; filePaths)
  {
    auto mod = new Module(filePath, infoMan);
    // Parse the file.
    mod.parse();
    if (mod.hasErrors)
      continue;

    // Start semantic analysis.
    auto pass1 = new SemanticPass1(mod);
    pass1.start();

    // Generate documentation.
    auto dest = new FilePath(destDir);
    dest.append(mod.getFQN() ~ ".html");

    InfoManager infoMan2; // Collects warnings from the macro expander.
    if (verbose)
    {
      Stdout.formatln("{} > {}", mod.filePath, dest);
      infoMan2 = new InfoManager();
    }

    writeDocFile(dest.toString(), mod, mtable, incUndoc, tokenHL, infoMan2);

    if (infoMan2)
      infoMan ~= infoMan2.info;
  }
}

void writeDocFile(string dest, Module mod, MacroTable mtable, bool incUndoc,
                  TokenHighlighter tokenHL, InfoManager infoMan)
{
  // Create a macro environment for this module.
  mtable = new MacroTable(mtable);
  // Define runtime macros.
  mtable.insert("TITLE", mod.getFQN());
  mtable.insert("DOCFILENAME", mod.getFQN());

  time_t time_val;
  time(&time_val);
  char* str = ctime(&time_val);
  char[] time_str = str[0 .. strlen(str)-1]; // -1 removes trailing '\n'.
  mtable.insert("DATETIME", time_str.dup);
  mtable.insert("YEAR", time_str[20..24].dup);

  auto doc = new DDocEmitter(mtable, incUndoc, mod, tokenHL);
  doc.emit();
  // Set BODY macro to the text produced by the DDocEmitter.
  mtable.insert("BODY", doc.text);
  // Do the macro expansion pass.
  auto fileText = MacroExpander.expand(mtable, "$(DDOC)", mod.filePath, infoMan);
// fileText ~= "\n<pre>\n" ~ doc.text ~ "\n</pre>";
  // Finally write the file out to the harddisk.
  auto file = new File(dest);
  file.write(fileText);
}

string loadMacroFile(string filePath, InfoManager infoMan)
{
  auto src = new SourceText(filePath);
  src.load(infoMan);
  auto text = src.data[0..$-1]; // Exclude '\0'.
  return sanitizeText(text);
}

/// Traverses the syntax tree and writes DDoc macros to a string buffer.
class DDocEmitter : DefaultVisitor
{
  char[] text;
  bool includeUndocumented;
  MacroTable mtable;
  Module modul;
  TokenHighlighter tokenHL;

  this(MacroTable mtable, bool includeUndocumented, Module modul,
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
    if (auto d = modul.moduleDecl)
    {
      if (ddoc(d))
      {
        if (auto copyright = cmnt.takeCopyright())
          mtable.insert(new Macro("COPYRIGHT", copyright.text));
        DESC({ writeComment(); });
      }
    }
    MEMBERS("MODULE", { visitD(modul.root); });
    write(\n);
    return text;
  }

  char[] textSpan(Token* left, Token* right)
  {
    //assert(left && right && (left.end <= right.start || left is right));
    //char[] result;
    //TODO: filter out whitespace tokens.
    return Token.textSpan(left, right);
  }

  TemplateParameters tparams; /// The template parameters of the declaration.

  DDocComment cmnt; /// Current comment.
  DDocComment prevCmnt; /// Previous comment in scope.
  /// An empty comment. Used for undocumented symbols.
  static const DDocComment emptyCmnt;

  static this()
  {
    this.emptyCmnt = new DDocComment(null, null, null);
  }

  /// Keeps track of previous comments in each scope.
  scope class Scope
  {
    DDocComment saved_prevCmnt;
    bool saved_cmntIsDitto;
    uint saved_prevDeclOffset;
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

    ~this()
    { // Restore the previous comment of the parent scope.
      this.outer.prevCmnt = saved_prevCmnt;
      this.outer.cmntIsDitto = saved_cmntIsDitto;
      this.outer.prevDeclOffset = saved_prevDeclOffset;
    }
  }

  bool cmntIsDitto;

  DDocComment ddoc(Node node)
  {
    auto c = getDDocComment(node);
    this.cmnt = null;
    if (c)
    {
      if (c.isDitto)
      {
        this.cmnt = this.prevCmnt;
        this.cmntIsDitto = true;
      }
      else
      {
        this.cmntIsDitto = false;
        this.cmnt = c;
        this.prevCmnt = c;
      }
    }
    else if (includeUndocumented)
      this.cmnt = this.emptyCmnt;
    return this.cmnt;
  }

  static char[][char[]] specialSections;
  static this()
  {
    foreach (name; ["AUTHORS", "BUGS", "COPYRIGHT", "DATE", "DEPRECATED",
                    "EXAMPLES", "HISTORY", "LICENSE", "RETURNS", "SEE_ALSO",
                    "STANDARDS", "THROWS", "VERSION"])
      specialSections[name] = name;
  }

  void writeComment()
  {
    auto c = this.cmnt;
    assert(c !is null);
    if (c.sections.length == 0)
      return;
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
          write("\n$(DDOC_SECTION $(DDOC_SECTION_H " ~ s.name ~ ":)");
        write(scanCommentText(s.text), ")");
      }
    write(")");
  }

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

  void writeParams(Parameters params)
  {
    if (!params.items.length)
      return write("()");
    write("(");
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

  void writeTemplateParams()
  {
    if (!tparams)
      return;
    write(escape(textSpan(tparams.begin, tparams.end)));
    tparams = null;
  }

  void writeInheritanceList(BaseClassType[] bases)
  {
    if (bases.length == 0)
      return;
    auto basesBegin = bases[0].begin.prevNWS;
    if (basesBegin.kind == TOK.Colon)
      basesBegin = bases[0].begin;
    text ~= " : " ~ escape(textSpan(basesBegin, bases[$-1].end));
  }

  void write(char[][] strings...)
  {
    foreach (s; strings)
      text ~= s;
  }

  void SYMBOL(char[] name, Declaration d)
  {
    auto loc = d.begin.getRealLocation();
    auto str = Format("$(SYMBOL {}, {}, {}.d, {})", name, modul.getFQN(), modul.getFQNPath(), loc.lineNum);
    write(str);
    // write("$(DDOC_PSYMBOL ", name, ")");
  }

  uint prevDeclOffset;

  void DECL(void delegate() dg, bool writeSemicolon = true)
  {
    if (cmntIsDitto)
    { alias prevDeclOffset offs;
      assert(offs != 0);
      auto savedText = text;
      text = "";
      write("\n$(DDOC_DECL ");
      dg();
      write(";)");
      // Insert text at offset.
      auto len = text.length;
      text = savedText[0..offs] ~ text ~ savedText[offs..$];
      offs += len; // Add length of the inserted text to the offset.
      return;
    }
    write("\n$(DDOC_DECL ");
    dg();
    write(writeSemicolon ? ";)" : ")");
    prevDeclOffset = text.length;
  }

  void DESC(void delegate() dg)
  {
    if (cmntIsDitto)
      return;
    write("\n$(DDOC_DECL_DD ");
    dg();
    write(")");
  }

  void MEMBERS(char[] kind, void delegate() dg)
  {
    write("\n$(DDOC_"~kind~"_MEMBERS ");
    dg();
    write(")");
  }

  void writeClassOrInterface(T)(T d)
  {
    if (!ddoc(d))
      return d;
    DECL({
      write(d.begin.srcText, " ");
      SYMBOL(d.name.str, d);
      writeTemplateParams();
      writeInheritanceList(d.bases);
    });
    DESC({
      writeComment();
      MEMBERS(is(T == ClassDeclaration) ? "CLASS" : "INTERFACE", {
        scope s = new Scope();
        d.decls && super.visit(d.decls);
      });
    });
  }

  void writeStructOrUnion(T)(T d)
  {
    if (!ddoc(d))
      return d;
    DECL({
      write(d.begin.srcText, d.name ? " " : "");
      if (d.name)
        SYMBOL(d.name.str, d);
      writeTemplateParams();
    });
    DESC({
      writeComment();
      MEMBERS(is(T == StructDeclaration) ? "STRUCT" : "UNION", {
        scope s = new Scope();
        d.decls && super.visit(d.decls);
      });
    });
  }

  alias Declaration D;

override:
//   D visit(ModuleDeclaration d)
//   { return d; }

  D visit(AliasDeclaration d)
  {
    if (!ddoc(d))
      return d;
    if (auto vd = d.decl.Is!(VariablesDeclaration))
      foreach (name; vd.names)
        DECL({ write("alias "); SYMBOL(name.str, d); });
    else if (auto fd = d.decl.Is!(FunctionDeclaration))
    {}
    // DECL({ write(textSpan(d.begin, d.end)); }, false);
    DESC({ writeComment(); });
    return d;
  }

  D visit(TypedefDeclaration d)
  {
    if (!ddoc(d))
      return d;
    if (auto vd = d.decl.Is!(VariablesDeclaration))
      foreach (name; vd.names)
        DECL({ write("typedef "); SYMBOL(name.str, d); });
    else if (auto fd = d.decl.Is!(FunctionDeclaration))
    {}
    // DECL({ write(textSpan(d.begin, d.end)); }, false);
    DESC({ writeComment(); });
    return d;
  }

  D visit(EnumDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({
      write("enum", d.name ? " " : "");
      d.name && SYMBOL(d.name.str, d);
    });
    DESC({
      writeComment();
      MEMBERS("ENUM", { scope s = new Scope(); super.visit(d); });
    });
    return d;
  }

  D visit(EnumMemberDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL(d.name.str, d); }, false);
    DESC({ writeComment(); });
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
    });
    DESC({
      writeComment();
      MEMBERS("TEMPLATE", {
        scope s = new Scope();
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
    DECL({ SYMBOL("this", d); writeParams(d.params); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(StaticConstructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("static "); SYMBOL("this", d); write("()"); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(DestructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("~"); SYMBOL("this", d); write("()"); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(StaticDestructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("static ~"); SYMBOL("this", d); write("()"); });
    DESC({ writeComment(); });
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
    });
    DESC({ writeComment(); });
    return d;
  }

  D visit(NewDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL("new", d); writeParams(d.params); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(DeleteDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL("delete", d); writeParams(d.params); });
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
      DECL({ write(escape(type), " "); SYMBOL(name.str, d); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(InvariantDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("invariant"); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(UnittestDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("unittest"); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(DebugDeclaration d)
  { return d; }

  D visit(VersionDeclaration d)
  { return d; }
}
