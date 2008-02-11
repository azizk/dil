/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.DDoc;

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
import dil.File;
import dil.Converter;
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
    auto macros = mparser.parse(loadMacroFile(macroPath));
    mtable = new MacroTable(mtable);
    mtable.insert(macros);
  }

//   foreach (k, v; mtable.table)
//     Stdout(k)("=")(v.text);

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
    writeDocFile(dest.toString(), mod, mtable, incUndoc, infoMan2);
    if (infoMan2)
      infoMan ~= infoMan2.info;
  }
}

void writeDocFile(string dest, Module mod, MacroTable mtable, bool incUndoc,
                  InfoManager infoMan)
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

  auto doc = new DDocEmitter(mtable, incUndoc);
  doc.emit(mod);
  // Set BODY macro to the text produced by the DDocEmitter.
  mtable.insert("BODY", doc.text);
  // Do the macro expansion pass.
  auto fileText = MacroExpander.expand(mtable, "$(DDOC)", mod.filePath, infoMan);
//   fileText ~= "\n<pre>\n" ~ doc.text ~ "\n</pre>";
  // Finally write the file out to the harddisk.
  auto file = new File(dest);
  file.write(fileText);
}

string loadMacroFile(string filePath)
{
  return sanitizeText(loadFile(filePath));
}

/// Traverses the syntax tree and writes DDoc macros to a string buffer.
class DDocEmitter : DefaultVisitor
{
  char[] text;
  bool includeUndocumented;
  MacroTable mtable;

  this(MacroTable mtable, bool includeUndocumented)
  {
    this.mtable = mtable;
    this.includeUndocumented = includeUndocumented;
  }

  /// Entry method.
  char[] emit(Module mod)
  {
    if (auto d = mod.moduleDecl)
    {
      if (ddoc(d))
      {
        if (auto copyright = cmnt.takeCopyright())
          mtable.insert(new Macro("COPYRIGHT", copyright.text));
        DESC({ writeComment(); });
      }
    }
    MEMBERS("MODULE", { visitD(mod.root); });
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

  bool isTemplatized; /// True if an aggregate declaration is templatized.
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
    DDocComment old_prevCmnt;
    this()
    { // Save the previous comment of the parent scope.
      old_prevCmnt = this.outer.prevCmnt;
      // Entering a new scope. Set to null.
      this.outer.prevCmnt = null;
    }

    ~this()
    { // Restore the previous comment of the parent scope.
      this.outer.prevCmnt = old_prevCmnt;
    }
  }

  DDocComment ddoc(Node node)
  {
    auto c = getDDocComment(node);
    this.cmnt = null;
    if (c)
    {
      if (c.isDitto)
        this.cmnt = this.prevCmnt;
      else
      {
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
                    "$(DDOC_PARAM_ID ", paramName, ")",
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
          p != end && p++; // Skip '>'.
          result ~= makeString(begin, p);
        }
        else
          result ~= "&lt;";
        continue;
      case '(': result ~= "&#40;"; break;
      case ')': result ~= "&#41;"; break;
      case '\'': result ~= "&apos;"; break; // &#39;
      case '"': result ~= "&quot;"; break;
      case '>': result ~= "&gt;"; break;
      case '&':
        if (p+1 < end && (isalpha(p[1]) || p[1] == '#'))
          goto default;
        result ~= "&amp;";
        break;
      case '-':
        if (p+2 < end && p[1] == '-' && p[2] == '-')
        {
          p += 2; // Point to 3rd '-'.
          auto codeBegin = p + 1;
          while (++p < end)
            if (p+2 < end && *p == '-' && p[1] == '-' && p[2] == '-')
            {
              result ~= "$(D_CODE " ~ scanCodeSection(makeString(codeBegin, p)) ~ ")";
              p += 3;
              break;
            }
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

  char[] scanCodeSection(char[] text)
  {
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
        if (typeBegin !is param.begin)
          write(textSpan(param.begin, typeBegin.prevNWS), " ");
        write(textSpan(typeBegin, param.type.end));
        write(" $(DDOC_PARAM ", param.name.str, ")");
        if (param.isDVariadic)
          write("...");
      }
      if (param !is lastParam)
        write(", ");
    }
    write(")");
  }

  void writeTemplateParams()
  {
    if (!isTemplatized)
      return;
    write("(", (tparams ? textSpan(tparams.begin, tparams.end) : ""), ")");
    isTemplatized = false;
    tparams = null;
  }

  void writeInheritanceList(BaseClassType[] bases)
  {
    if (bases.length == 0)
      return;
    text ~= " : " ~ textSpan(bases[0].begin, bases[$-1].end);
  }

  void writeFuncHeader(Declaration d, FuncBodyStatement s)
  {
    auto begin = d.begin;
    auto end = d.end.prevNWS;
    if (!s.isEmpty)
      end = s.begin.prevNWS;
    text ~= textSpan(begin, end);
  }

  void write(char[][] strings...)
  {
    foreach (s; strings)
      text ~= s;
  }

  void SYMBOL(char[][] strings...)
  {
    write("$(DDOC_PSYMBOL ");
    write(strings);
    write(")");
  }

  void DECL(void delegate() dg)
  {
    write("\n$(DDOC_DECL ");
    dg();
    write(")");
  }

  void DESC(void delegate() dg)
  {
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
    scope s = new Scope();
    DECL({
      write(d.begin.srcText, " ");
      SYMBOL(d.name.str);
      writeTemplateParams();
      writeInheritanceList(d.bases);
    });
    DESC({
      writeComment();
      MEMBERS(is(T == ClassDeclaration) ? "CLASS" : "INTERFACE", {
        d.decls && super.visit(d.decls);
      });
    });
  }

  void writeStructOrUnion(T)(T d)
  {
    if (!ddoc(d))
      return d;
    scope s = new Scope();
    DECL({
      write(d.begin.srcText, d.name ? " " : "");
      if (d.name)
        SYMBOL(d.name.str);
      writeTemplateParams();
    });
    DESC({
      writeComment();
      MEMBERS(is(T == StructDeclaration) ? "STRUCT" : "UNION", {
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
    DECL({ write(textSpan(d.begin, d.end)); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(TypedefDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write(textSpan(d.begin, d.end)); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(EnumDeclaration d)
  {
    if (!ddoc(d))
      return d;
    scope s = new Scope();
    DECL({
      write("enum", d.name ? " " : "");
      d.name && SYMBOL(d.name.str);
    });
    DESC({
      writeComment();
      MEMBERS("ENUM", { super.visit(d); });
    });
    return d;
  }

  D visit(EnumMemberDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ SYMBOL(d.name.str); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(TemplateDeclaration d)
  {
    if (d.begin.kind != TOK.Template)
    { // This is a templatized class/interface/struct/union.
      this.isTemplatized = true;
      this.tparams = d.tparams;
      return super.visit(d.decls);
    }
    if (!ddoc(d))
      return d;
    scope s = new Scope();
    DECL({
      write("template ");
      SYMBOL(d.name.str);
      write(textSpan(d.begin.nextNWS.nextNWS, d.decls.begin.prevNWS));
    });
    DESC({
      writeComment();
      MEMBERS("TEMPLATE", {
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
    DECL({ write("this"); writeParams(d.params); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(StaticConstructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ writeFuncHeader(d, d.funcBody); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(DestructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ writeFuncHeader(d, d.funcBody); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(StaticDestructorDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ writeFuncHeader(d, d.funcBody); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(FunctionDeclaration d)
  {
    if (!ddoc(d))
      return d;
    auto type = textSpan(d.returnType.baseType.begin, d.returnType.end);
    DECL({ write(type, " "); SYMBOL(d.name.str); writeParams(d.params); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(NewDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ write("new"); writeParams(d.params); });
    DESC({ writeComment(); });
    return d;
  }

  D visit(DeleteDeclaration d)
  {
    if (!ddoc(d))
      return d;
    DECL({ writeFuncHeader(d, d.funcBody); });
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
    {
      DECL({ write(type, " "); SYMBOL(name.str); });
      DESC({ writeComment(); });
    }
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
