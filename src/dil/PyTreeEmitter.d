/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.PyTreeEmitter;

import dil.ast.Visitor,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Statements,
       dil.ast.Expressions,
       dil.ast.Parameters,
       dil.ast.Types;
import dil.semantic.Module;
import dil.lexer.Funcs;
import dil.Time;
import common;

import tango.core.Array : sort;

char[] escape_quotes(char[] text)
{
  char[] result;
  foreach (c; text)
    result ~= (c == '"') ? `\"`[] : (c == '\\' ? `\\` : c~"");
  return result;
}

char[] toString(uint x)
{
  char[] str;
  do
    str = cast(char)('0' + (x % 10)) ~ str;
  while (x /= 10)
  return str;
}

char[] countWhitespace(char[] ws)
{
  foreach (c; ws)
    if (c != ' ') return ws;
  return toString(ws.length);
}

enum Flags
{
  None = 0,
  Backslash = 1,
  DblQuote = 2,
  SglQuote = 4,
  Newline = 8
}

/// Searches for backslashes, quotes and newlines in a string.
/// Returns: a
Flags analyzeString(char[] str/*, out uint newlines*/)
{
  Flags flags;
  foreach (c; str)
    if (c == '\\') flags |= Flags.Backslash;
    else if (c == '"') flags |= Flags.DblQuote;
    else if (c == '\'') flags |= Flags.SglQuote;
    else if (c == '\n' || c == '\r' || c == '\u2028' || c == '\u2029')
      flags |= Flags.Newline;
  return flags;
}

char[] writeTokenList(Token* first_token, ref uint[Token*] indexMap)
{
  char[] result = "token_list = (\n";
  char[] line;
  class Tuple
  {
    uint count;
    char[] str;
    TOK kind;
    alias count pos;
    this(uint count, char[] str, TOK kind)
    {
      this.count = count;
      this.str = str;
      this.kind = kind;
    }
    static bool compare(Tuple a, Tuple b)
    {
      return a.count > b.count;
    }
  }
  // Gather all identifiers, comments, strings and numbers in this map.
  Tuple[char[]] map;
  for (auto token = first_token; token; token = token.next)
    switch(token.kind)
    {
    case TOK.Identifier, TOK.Comment, TOK.String, TOK.CharLiteral,
         TOK.Int32, TOK.Int64, TOK.Uint32, TOK.Uint64,
         TOK.Float32, TOK.Float64, TOK.Float80,
         TOK.Imaginary32, TOK.Imaginary64, TOK.Imaginary80:
      auto p = token.text in map;
      if (p) p.count += 1;
      else map[token.text] =  new Tuple(1, token.text, token.kind);
      break;
    default:
    }
  // Create a sorted list. We want the strings that appear the most
  // in the source text to be at the beginning of the list.
  // That way less space is taken up by index numbers in the emitted text.
  // NB.: First tests showed, that this only saves about 3% of characters.
  auto list = map.values;
  list.sort(&Tuple.compare);
  result ~= "(";
  // Print the sorted string list.
  foreach (i, item; list)
  { // By analyzing the string we can determine the optimal
    // way to represent strings in the Python source code.
    uint flags = analyzeString(item.str);
    char[] sgl_quot = "'", dbl_quot = `"`;
    if (flags & Flags.Newline) // Use triple quotes for multiline strings.
      (sgl_quot = "'''"), (dbl_quot = `"""`);

    if (flags & Flags.Backslash ||
        flags == (Flags.SglQuote | Flags.DblQuote))
      line ~= dbl_quot ~ escape_quotes(item.str) ~ dbl_quot;
    else if (flags & Flags.SglQuote)
      line ~= dbl_quot ~ item.str ~ dbl_quot;
    else
      line ~= sgl_quot ~ item.str ~ sgl_quot;

    line ~= ',';
    if (line.length > 100)
      (result ~= line ~ "\n"), line = null;
    item.pos = i; /// Update position.
  }
  if (line.length)
    result ~= line;
  if (result[$-1] == '\n')
    result = result[0..$-1];
  result ~= "),\n[\n";
  line = "";

  // Print the list of all tokens, encoded with IDs and indices.
  uint index;
  for (auto token = first_token; token; ++index, token = token.next)
  {
    indexMap[token] = index;
    line ~= '(' ~ toString(token.kind) ~ ',';
    line ~= (token.ws) ? countWhitespace(token.wsChars) : `0`;
    line ~= ',';
    switch(token.kind)
    {
    case TOK.Identifier, TOK.Comment, TOK.String, TOK.CharLiteral:
    case TOK.Int32, TOK.Int64, TOK.Uint32, TOK.Uint64,
         TOK.Float32, TOK.Float64, TOK.Float80,
         TOK.Imaginary32, TOK.Imaginary64, TOK.Imaginary80:
      line ~= toString(map[token.text].pos);
      break;
    case TOK.Shebang:
      line ~= '"' ~ escape_quotes(token.text) ~ '"';
      break;
    case TOK.HashLine:
      // The text to be inserted into formatStr.
      void printWS(char* start, char* end) {
        line ~= '"' ~ start[0 .. end - start] ~ `",`;
      }
      auto num = token.tokLineNum;
      line ~= `"#line"`;
      if (num)
      { // Print whitespace between #line and number.
        printWS(token.start, num.start); // Prints "#line" as well.
        line ~= '"' ~ num.text ~ '"'; // Print the number.
        if (auto filespec = token.tokLineFilespec)
        { // Print whitespace between number and filespec.
          printWS(num.end, filespec.start);
          line ~= '"' ~ escape_quotes(filespec.text) ~ '"';
        }
      }
      break;
    case TOK.Illegal:
      line ~= '"' ~ escape_quotes(token.text) ~ '"';
      break;
    default:
      line = line[0..$-1];
    }
    line ~= "),";
    if (line.length > 100)
      (result ~= line ~ "\n"), line = null;
  }
  if (line.length)
    result ~= line;
  return result ~ "\n])\n";
}

/// Emits a D parse tree as Python code.
class PyTreeEmitter : Visitor
{
  char[] text; /// Contains the code.
  char[] line; /// Line buffer.
  Module modul; /// The module to be processed.
  uint[Token*] index; /// Map tokens to index numbers.

  /// Constructs a PyTreeEmitter object.
  this(Module modul)
  {
    this.modul = modul;
  }

  /// Entry method.
  char[] emit()
  {
    char[] d_version = "1.0";
    version(D2)
      d_version = "2.0";
    text = Format("# -*- coding: utf-8 -*-\n"
                  "from __future__ import unicode_literals\n"
                  "import dil.token\n\n"
                  "generated_by = 'dil'\n"
                  "format_version = '1.0'\n"
                  "d_version= '{}'\n"
                  "date = '{}'\n\n",
                  d_version, Time.toString());

    text ~= writeTokenList(modul.firstToken(), index);
    text ~= "tokens = token.create_tokens(token_list)\n\n";
    text ~= "def t(beg,end):\n"
            "  return (tokens[beg], tokens[beg+end])\n"
            "def tl(*args):\n"
            "  return [tokens[i] for i in args]\n"
            "  #return map(tokens.__getitem__, args)\n"
            "def N(id, *args):\n"
            "  return NodeTable[id](*args)\n\n";
    text ~= `module = Module(tokens=tokens, fqn="` ~ modul.getFQN() ~
            `",ext="` ~ modul.fileExtension() ~ `",root=`\n;
    visitD(modul.root);
    if (line.length)
      text ~= line ~ "\n";
    text ~= ")";
    return text;
  }

  /// Some handy aliases.
  private alias Declaration D;
  private alias Expression E; /// ditto
  private alias Statement S; /// ditto
  private alias TypeNode T; /// ditto
  private alias Parameter P; /// ditto
  private alias Node N; /// ditto
  /// Alias to the outer toString. Avoids conflicts with Object.toString.
  private alias .toString toString;

  /// Returns the index number of a token as a string.
  char[] indexOf(Token* token)
  {
    return toString(index[token]);
  }

  void write(char[] str)
  {
    line ~= str;
    if (line.length > 100)
      (this.text ~= line ~ "\n"), line = null;
  }

  /// Writes the list of nodes separated by commas.
  void write(Node[] nodes)
  {
    write("(");
    if (nodes.length)
    {
      visitN(nodes[0]);
      foreach (n; nodes[1..$])
        write(","), visitN(n);
      if (nodes.length == 1)
        write(","); // Trailing comma for single element tuples.
    }
    write(")");
  }


  void begin(Node n)
  {
//     write(g_classNames[n.kind]~"(");
    write("N("~toString(n.kind)~",");
  }

  void end(Node n)
  {
    assert(n !is null && n.begin !is null && n.end !is null);
    auto i1 = index[n.begin], i2 = index[n.end];
    assert(i1 <= i2, Format("ops, Parser or AST buggy? {}@{},i1={},i2={}", g_classNames[n.kind], n.begin.getRealLocation().str(), i1, i2));
    write(",t("~toString(i1)~","~toString(i2-i1)~"))");
  }

override
{
  D visit(CompoundDeclaration d)
  {
    begin(d);
    write(d.decls);
    end(d);
    return d;
  }

  D visit(IllegalDeclaration)
  { assert(0); return null; }

  D visit(EmptyDeclaration d)
  {
    begin(d);
    end(d);
    return d;
  }

  D visit(ModuleDeclaration d)
  {
    begin(d);
    d.typeIdent ? write(indexOf(d.typeIdent)) : write("None");
    write(",");
    write(indexOf(d.moduleName)~",");
    write("tl(");
    foreach (pckg; d.packages)
      write(toString(index[pckg])~",");
    write(")");
    end(d);
    return d;
  }

  D visit(ImportDeclaration d)
  {
    begin(d);
    write("(");
    foreach(moduleFQN; d.moduleFQNs)
    {
      write("tl(");
      foreach(tok; moduleFQN)
        write(indexOf(tok)~",");
      write("),");
    }
    write("),tl(");
    foreach(tok; d.moduleAliases)
      tok ? write(indexOf(tok)~",") : write("-1,");
    write("),(");
    foreach(tok; d.bindNames)
      write(indexOf(tok)~",");
    write("),tl(");
    foreach(tok; d.bindAliases)
      tok ? write(indexOf(tok)~",") : write("-1,");
    write(")");
    end(d);
    return d;
  }

  D visit(AliasThisDeclaration d)
  {
    begin(d);
    write(indexOf(d.ident));
    end(d);
    return d;
  }

  D visit(AliasDeclaration d)
  {
    begin(d);
    visitD(d.decl);
    end(d);
    return d;
  }

  D visit(TypedefDeclaration d)
  {
    begin(d);
    visitD(d.decl);
    end(d);
    return d;
  }

  D visit(EnumDeclaration d)
  {
    begin(d);
    d.baseType ? visitT(d.baseType) : write("None");
    write(",");
    write(d.members);
    end(d);
    return d;
  }

  D visit(EnumMemberDeclaration d)
  {
    begin(d);
    d.type ? visitT(d.type) : write("None");
    write(",");
    d.value ? visitE(d.value) : write("None");
    end(d);
    return d;
  }

  D visit(ClassDeclaration d)
  {
    begin(d);
    write(d.bases);
    write(",");
    d.decls ? visitD(d.decls) : write("None");
    end(d);
    return d;
  }

  D visit(InterfaceDeclaration d)
  {
    begin(d);
    write(d.bases);
    write(",");
    d.decls ? visitD(d.decls) : write("None");
    end(d);
    return d;
  }

  D visit(StructDeclaration d)
  {
    begin(d);
    d.decls ? visitD(d.decls) : write("None");
    end(d);
    return d;
  }

  D visit(UnionDeclaration d)
  {
    begin(d);
    d.decls ? visitD(d.decls) : write("None");
    end(d);
    return d;
  }

  D visit(ConstructorDeclaration d)
  {
    begin(d);
    visitN(d.params);
    write(",");
    visitS(d.funcBody);
    end(d);
    return d;
  }

  D visit(StaticConstructorDeclaration d)
  {
    begin(d);
    visitS(d.funcBody);
    end(d);
    return d;
  }

  D visit(DestructorDeclaration d)
  {
    begin(d);
    visitS(d.funcBody);
    end(d);
    return d;
  }

  D visit(StaticDestructorDeclaration d)
  {
    begin(d);
    visitS(d.funcBody);
    end(d);
    return d;
  }

  D visit(FunctionDeclaration d)
  {
    begin(d);
    d.returnType ? visitT(d.returnType) : write("None");
    write(",");
    write(indexOf(d.nametok));
    write(",");
    visitN(d.params);
    write(",");
    visitS(d.funcBody);
    end(d);
    return d;
  }

  D visit(VariablesDeclaration d)
  {
    begin(d);
    // Type
    if (d.typeNode !is null)
      visitT(d.typeNode);
    else
      write("-1");
    // Variable names.
    write(",(");
    foreach (name; d.nametoks)
      write(indexOf(name) ~ ",");
    write("),(");
    foreach (init; d.inits) {
      if (init) visitE(init);
      else write("-1");
      write(",");
    }
    write(")");
    end(d);
    return d;
  }

  D visit(InvariantDeclaration d)
  {
    begin(d);
    visitS(d.funcBody);
    end(d);
    return d;
  }

  D visit(UnittestDeclaration d)
  {
    begin(d);
    visitS(d.funcBody);
    end(d);
    return d;
  }

  D visit(DebugDeclaration d)
  {
    begin(d);
    d.decls ? visitD(d.decls) : write("None");
    write(",");
    d.elseDecls ? visitD(d.elseDecls) : write("None");
    end(d);
    return d;
  }

  D visit(VersionDeclaration d)
  {
    begin(d);
    d.decls ? visitD(d.decls) : write("None");
    write(",");
    d.elseDecls ? visitD(d.elseDecls) : write("None");
    end(d);
    return d;
  }

  D visit(TemplateDeclaration d)
  {
    begin(d);
    visitN(d.tparams);
    write(",");
    d.constraint ? visitE(d.constraint) : write("None");
    write(",");
    visitD(d.decls);
    end(d);
    return d;
  }

  D visit(NewDeclaration d)
  {
    begin(d);
    visitN(d.params);
    write(",");
    visitS(d.funcBody);
    end(d);
    return d;
  }

  D visit(DeleteDeclaration d)
  {
    begin(d);
    visitN(d.params);
    write(",");
    visitS(d.funcBody);
    end(d);
    return d;
  }

  // Attributes:

  D visit(ProtectionDeclaration d)
  {
    begin(d);
    visitD(d.decls);
    end(d);
    return d;
  }

  D visit(StorageClassDeclaration d)
  {
    begin(d);
    visitD(d.decls);
    end(d);
    return d;
  }

  D visit(LinkageDeclaration d)
  {
    begin(d);
    visitD(d.decls);
    end(d);
    return d;
  }

  D visit(AlignDeclaration d)
  {
    begin(d);
    visitD(d.decls);
    end(d);
    return d;
  }

  D visit(StaticAssertDeclaration d)
  {
    begin(d);
    visitE(d.condition);
    write(",");
    d.message ? visitE(d.message) : write("None");
    end(d);
    return d;
  }

  D visit(StaticIfDeclaration d)
  {
    begin(d);
    visitE(d.condition);
    write(",");
    visitD(d.ifDecls);
    write(",");
    d.elseDecls ? visitD(d.elseDecls) : write("None");
    end(d);
    return d;
  }

  D visit(MixinDeclaration d)
  {
    begin(d);
    d.mixinIdent ? write(indexOf(d.mixinIdent)) : write("None");
    write(",");
    d.templateExpr ? visitE(d.templateExpr) : write("None");
    write(",");
    d.argument ? visitE(d.argument) : write("None");
    end(d);
    return d;
  }

  D visit(PragmaDeclaration d)
  {
    begin(d);
    write(indexOf(d.idtok));
    write(",");
    write(d.args);
    write(",");
    visitD(d.decls);
    end(d);
    return d;
  }

} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                 Statements                                |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{

  S visit(CompoundStatement s)
  {
    begin(s);
    write(s.stmnts);
    end(s);
    return s;
  }

  S visit(IllegalStatement)
  { assert(0, "interpreting invalid AST"); return null; }

  S visit(EmptyStatement s)
  {
    begin(s);
    end(s);
    return s;
  }

  S visit(FuncBodyStatement s)
  {
    begin(s);
    s.funcBody ? visitS(s.funcBody) : write("None");
    write(",");
    s.inBody ? visitS(s.inBody) : write("None");
    write(",");
    s.outBody ? visitS(s.outBody) : write("None");
    write(",");
    s.outIdent ? write(indexOf(s.outIdent)) : write("None");
    end(s);
    return s;
  }

  S visit(ScopeStatement s)
  {
    begin(s);
    visitS(s.stmnt);
    end(s);
    return s;
  }

  S visit(LabeledStatement s)
  {
    begin(s);
    visitS(s.stmnt);
    end(s);
    return s;
  }

  S visit(ExpressionStatement s)
  {
    begin(s);
    visitE(s.expr);
    end(s);
    return s;
  }

  S visit(DeclarationStatement s)
  {
    begin(s);
    visitD(s.decl);
    end(s);
    return s;
  }

  S visit(IfStatement s)
  {
    begin(s);
    s.variable ? visitS(s.variable) : write("None");
    write(",");
    s.condition ? visitE(s.condition) : write("None");
    write(",");
    visitS(s.ifBody);
    write(",");
    s.elseBody ? visitS(s.elseBody) : write("None");
    end(s);
    return s;
  }

  S visit(WhileStatement s)
  {
    begin(s);
    visitE(s.condition);
    write(",");
    visitS(s.whileBody);
    end(s);
    return s;
  }

  S visit(DoWhileStatement s)
  {
    begin(s);
    visitS(s.doBody);
    write(",");
    visitE(s.condition);
    end(s);
    return s;
  }

  S visit(ForStatement s)
  {
    begin(s);
    s.init ? visitS(s.init) : write("None");
    write(",");
    s.condition ? visitE(s.condition) : write("None");
    write(",");
    s.increment ? visitE(s.increment) : write("None");
    write(",");
    s.forBody ? visitS(s.forBody) : write("None");
    end(s);
    return s;
  }

  S visit(ForeachStatement s)
  {
    begin(s);
    visitN(s.params);
    write(",");
    visitE(s.aggregate);
    write(",");
    visitS(s.forBody);
    end(s);
    return s;
  }

  // D2.0
  S visit(ForeachRangeStatement s)
  {
    begin(s);
    visitN(s.params);
    write(",");
    visitE(s.lower);
    write(",");
    visitE(s.upper);
    write(",");
    visitS(s.forBody);
    end(s);
    return s;
  }

  S visit(SwitchStatement s)
  {
    begin(s);
    visitE(s.condition);
    write(",");
    visitS(s.switchBody);
    end(s);
    return s;
  }

  S visit(CaseStatement s)
  {
    begin(s);
    write(s.values);
    write(",");
    visitS(s.caseBody);
    end(s);
    return s;
  }

  S visit(DefaultStatement s)
  {
    begin(s);
    visitS(s.defaultBody);
    end(s);
    return s;
  }

  S visit(ContinueStatement s)
  {
    begin(s);
    s.ident ? write(indexOf(s.ident)) : write("None");
    end(s);
    return s;
  }

  S visit(BreakStatement s)
  {
    begin(s);
    s.ident ? write(indexOf(s.ident)) : write("None");
    end(s);
    return s;
  }

  S visit(ReturnStatement s)
  {
    begin(s);
    s.expr ? visitE(s.expr) : write("None");
    end(s);
    return s;
  }

  S visit(GotoStatement s)
  {
    begin(s);
    s.ident ? write(indexOf(s.ident)) : write("None");
    write(",");
    s.expr ? visitE(s.expr) : write("None");
    end(s);
    return s;
  }

  S visit(WithStatement s)
  {
    begin(s);
    visitE(s.expr);
    write(",");
    visitS(s.withBody);
    end(s);
    return s;
  }

  S visit(SynchronizedStatement s)
  {
    begin(s);
    s.expr ? visitE(s.expr) : write("None");
    write(",");
    visitS(s.syncBody);
    end(s);
    return s;
  }

  S visit(TryStatement s)
  {
    begin(s);
    visitS(s.tryBody);
    write(",");
    write(s.catchBodies);
    write(",");
    s.finallyBody ? visitS(s.finallyBody) : write("None");
    end(s);
    return s;
  }

  S visit(CatchStatement s)
  {
    begin(s);
    s.param ? visitN(s.param) : write("None");
    write(",");
    visitS(s.catchBody);
    end(s);
    return s;
  }

  S visit(FinallyStatement s)
  {
    begin(s);
    visitS(s.finallyBody);
    end(s);
    return s;
  }

  S visit(ScopeGuardStatement s)
  {
    begin(s);
    write(indexOf(s.condition));
    write(",");
    visitS(s.scopeBody);
    end(s);
    return s;
  }

  S visit(ThrowStatement s)
  {
    begin(s);
    visitE(s.expr);
    end(s);
    return s;
  }

  S visit(VolatileStatement s)
  {
    begin(s);
    s.volatileBody ? visitS(s.volatileBody) : write("None");
    end(s);
    return s;
  }

  S visit(AsmBlockStatement s)
  {
    begin(s);
    visitS(s.statements);
    end(s);
    return s;
  }

  S visit(AsmStatement s)
  {
    begin(s);
    s.ident ? write(indexOf(s.begin)) : write("None");
    write(",");
    write(s.operands);
    end(s);
    return s;
  }

  S visit(AsmAlignStatement s)
  {
    begin(s);
    write(toString(s.number));
    end(s);
    return s;
  }

  S visit(IllegalAsmStatement)
  { assert(0, "invalid AST"); return null; }

  S visit(PragmaStatement s)
  {
    begin(s);
    s.ident ? write(indexOf(s.ident)) : write("None");
    write(",");
    write(s.args);
    write(",");
    visitS(s.pragmaBody);
    end(s);
    return s;
  }

  S visit(MixinStatement s)
  {
    begin(s);
    visitE(s.templateExpr);
    write(",");
    s.mixinIdent ? write(indexOf(s.mixinIdent)) : write("None");
    end(s);
    return s;
  }

  S visit(StaticIfStatement s)
  {
    begin(s);
    visitE(s.condition);
    write(",");
    visitS(s.ifBody);
    write(",");
    s.elseBody ? visitS(s.elseBody) : write("None");
    end(s);
    return s;
  }

  S visit(StaticAssertStatement s)
  {
    begin(s);
    visitE(s.condition);
    write(",");
    s.message ? visitE(s.message) : write("None");
    end(s);
    return s;
  }

  S visit(DebugStatement s)
  {
    begin(s);
    visitS(s.mainBody);
    write(",");
    s.elseBody ? visitS(s.elseBody) : write("None");
    end(s);
    return s;
  }

  S visit(VersionStatement s)
  {
    begin(s);
    visitS(s.mainBody);
    write(",");
    s.elseBody ? visitS(s.elseBody) : write("None");
    end(s);
    return s;
  }

} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                Expressions                                |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  E visit(IllegalExpression)
  { assert(0, "interpreting invalid AST"); return null; }

  E visit(CondExpression e)
  {
    begin(e);
    visitE(e.condition);
    write(",");
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(CommaExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(OrOrExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(AndAndExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(OrExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(XorExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(AndExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(EqualExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(IdentityExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(RelExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(InExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(LShiftExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(RShiftExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(URShiftExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(PlusExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(MinusExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(CatExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(MulExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(DivExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(ModExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(AssignExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(LShiftAssignExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(RShiftAssignExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(URShiftAssignExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(OrAssignExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(AndAssignExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(PlusAssignExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(MinusAssignExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(DivAssignExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(MulAssignExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(ModAssignExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(XorAssignExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(CatAssignExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(AddressExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(PreIncrExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(PreDecrExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(PostIncrExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(PostDecrExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(DerefExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(SignExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(NotExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(CompExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(CallExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(NewExpression e)
  {
    begin(e);
    write(e.newArgs);
    write(",");
    visitT(e.type);
    write(",");
    write(e.ctorArgs);
    end(e);
    return e;
  }

  E visit(NewAnonClassExpression e)
  {
    begin(e);
    write(e.newArgs);
    write(",");
    write(e.bases);
    write(",");
    write(e.ctorArgs);
    write(",");
    visitD(e.decls);
    end(e);
    return e;
  }

  E visit(DeleteExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(CastExpression e)
  {
    begin(e);
    visitT(e.type);
    write(",");
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(IndexExpression e)
  {
    begin(e);
    visitE(e.una);
    write(",");
    write(e.args);
    end(e);
    return e;
  }

  E visit(SliceExpression e)
  {
    begin(e);
    visitE(e.una);
    write(",");
    e.left ? visitE(e.left) : write("None");
    write(",");
    e.right ? visitE(e.right) : write("None");
    end(e);
    return e;
  }

  E visit(DotExpression e)
  {
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    end(e);
    return e;
  }

  E visit(ModuleScopeExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(IdentifierExpression e)
  {
    begin(e);
    write(indexOf(e.idToken));
    end(e);
    return e;
  }

  E visit(TemplateInstanceExpression e)
  {
    begin(e);
    write(indexOf(e.idToken));
    write(",");
    e.targs ? visitN(e.targs) : write("None");
    end(e);
    return e;
  }

  E visit(SpecialTokenExpression e)
  {
    begin(e);
    write(indexOf(e.specialToken));
    end(e);
    return e;
  }

  E visit(ThisExpression e)
  {
    begin(e);
    end(e);
    return e;
  }

  E visit(SuperExpression e)
  {
    begin(e);
    end(e);
    return e;
  }

  E visit(NullExpression e)
  {
    begin(e);
    end(e);
    return e;
  }

  E visit(DollarExpression e)
  {
    begin(e);
    end(e);
    return e;
  }

  E visit(BoolExpression e)
  {
    begin(e);
    end(e);
    return e.value;
  }

  E visit(IntExpression e)
  {
    begin(e);
    end(e);
    return e;
  }

  E visit(RealExpression e)
  {
    begin(e);
    end(e);
    return e;
  }

  E visit(ComplexExpression e)
  {
    begin(e);
    end(e);
    return e;
  }

  E visit(CharExpression e)
  {
    begin(e);
    end(e);
    return e;
  }

  E visit(StringExpression e)
  {
    begin(e);
    end(e);
    return e;
  }

  E visit(ArrayLiteralExpression e)
  {
    begin(e);
    write(e.values);
    end(e);
    return e;
  }

  E visit(AArrayLiteralExpression e)
  {
    begin(e);
    write(e.keys);
    write(",");
    write(e.values);
    end(e);
    return e;
  }

  E visit(AssertExpression e)
  {
    begin(e);
    visitE(e.expr);
    write(",");
    e.msg ? visitE(e.msg) : write("None");
    end(e);
    return e;
  }

  E visit(MixinExpression e)
  {
    begin(e);
    visitE(e.expr);
    end(e);
    return e;
  }

  E visit(ImportExpression e)
  {
    begin(e);
    visitE(e.expr);
    end(e);
    return e;
  }

  E visit(TypeofExpression e)
  {
    begin(e);
    visitT(e.type);
    end(e);
    return e;
  }

  E visit(TypeDotIdExpression e)
  {
    begin(e);
    visitT(e.type);
    end(e);
    return e;
  }

  E visit(TypeidExpression e)
  {
    begin(e);
    visitT(e.type);
    end(e);
    return e;
  }

  E visit(IsExpression e)
  {
    begin(e);
    visitT(e.type);
    write(",");
    e.specType ? visitT(e.specType) : write("None");
    write(",");
    e.tparams ? visitN(e.tparams) : write("None");
    end(e);
    return e;
  }

  E visit(ParenExpression e)
  {
    begin(e);
    visitE(e.next);
    end(e);
    return e;
  }

  E visit(FunctionLiteralExpression e)
  {
    begin(e);
    e.returnType ? visitT(e.returnType) : write("None");
    write(",");
    e.params ? visitN(e.params) : write("None");
    write(",");
    visitS(e.funcBody);
    end(e);
    return e;
  }

  E visit(TraitsExpression e) // D2.0
  {
    begin(e);
    write(indexOf(e.ident)~",");
    visitN(e.targs);
    end(e);
    return e;
  }

  E visit(VoidInitExpression e)
  {
    begin(e);
    end(e);
    return e;
  }

  E visit(ArrayInitExpression e)
  {
    begin(e);
    write("(");
    foreach (k; e.keys)
      (k ? visitE(k) : write("None")), write(",");
    write("),");
    write(e.values);
    end(e);
    return e;
  }

  E visit(StructInitExpression e)
  {
    begin(e);
    write("(");
    foreach (i; e.idents)
      (i ? write(indexOf(i)) : write("None")), write(",");
    write("),");
    write(e.values);
    end(e);
    return e;
  }

  E visit(AsmTypeExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(AsmOffsetExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(AsmSegExpression e)
  {
    begin(e);
    visitE(e.una);
    end(e);
    return e;
  }

  E visit(AsmPostBracketExpression e)
  {
    begin(e);
    visitE(e.una);
    write(",");
    visitE(e.index);
    end(e);
    return e;
  }

  E visit(AsmBracketExpression e)
  {
    begin(e);
    visitE(e.expr);
    end(e);
    return e;
  }

  E visit(AsmLocalSizeExpression e)
  {
    begin(e);
    end(e);
    return e;
  }

  E visit(AsmRegisterExpression e)
  {
    begin(e);
    e.number ? visitE(e.number) : write("None");
    end(e);
    return e;
  }
} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                   Types                                   |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  T visit(IllegalType)
  { assert(0, "interpreting invalid AST"); return null; }

  T visit(IntegralType t)
  {
    begin(t);
    write(indexOf(t.begin));
    end(t);
    return t;
  }

  T visit(QualifiedType t)
  {
    begin(t);
    visitT(t.lhs);
    write(",");
    visitT(t.rhs);
    end(t);
    return t;
  }

  T visit(ModuleScopeType t)
  {
    begin(t);
    end(t);
    return t;
  }

  T visit(IdentifierType t)
  {
    begin(t);
    write(indexOf(t.begin));
    end(t);
    return t;
  }

  T visit(TypeofType t)
  {
    begin(t);
    t.expr ? visitE(t.expr) : write("None");
    end(t);
    return t;
  }

  T visit(TemplateInstanceType t)
  {
    begin(t);
    write(indexOf(t.begin));
    write(",");
    t.targs ? visitN(t.targs) : write("None");
    end(t);
    return t;
  }

  T visit(PointerType t)
  {
    begin(t);
    visitT(t.next);
    end(t);
    return t;
  }

  T visit(ArrayType t)
  {
    begin(t);
    visitT(t.next);
    t.assocType ? visitT(t.assocType) : write("None");
    write(",");
    t.index1 ? visitE(t.index1) : write("None");
    write(",");
    t.index2 ? visitE(t.index2) : write("None");
    end(t);
    return t;
  }

  T visit(FunctionType t)
  {
    begin(t);
    visitT(t.returnType);
    write(",");
    visitN(t.params);
    end(t);
    return t;
  }

  T visit(DelegateType t)
  {
    begin(t);
    visitT(t.returnType);
    write(",");
    visitN(t.params);
    end(t);
    return t;
  }

  T visit(CFuncPointerType t)
  {
    begin(t);
    visitT(t.next);
    write(",");
    t.params ? visitN(t.params) : write("None");
    end(t);
    return t;
  }

  T visit(BaseClassType t)
  {
    begin(t);
    // TODO: emit t.prot?
    visitT(t.next);
    end(t);
    return t;
  }

  T visit(ConstType t) // D2.0
  {
    begin(t);
    visitT(t.next);
    end(t);
    return t;
  }

  T visit(InvariantType t) // D2.0
  {
    begin(t);
    visitT(t.next);
    end(t);
    return t;
  }
} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                 Parameters                                |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  N visit(Parameter p)
  {
    begin(p);
    p.type ? visitT(p.type) : write("None");
    write(",");
    p.defValue ? visitE(p.defValue) : write("None");
    end(p);
    return p;
  }

  N visit(Parameters p)
  {
    begin(p);
    write(p.children);
    end(p);
    return p;
  }

  N visit(TemplateAliasParameter p)
  {
    begin(p);
    p.specType ? visitT(p.specType) : write("None");
    write(",");
    p.defType ? visitT(p.defType) : write("None");
    end(p);
    return p;
  }

  N visit(TemplateTypeParameter p)
  {
    begin(p);
    p.specType ? visitT(p.specType) : write("None");
    write(",");
    p.defType ? visitT(p.defType) : write("None");
    end(p);
    return p;
  }

  N visit(TemplateThisParameter p) // D2.0
  {
    begin(p);
    p.specType ? visitT(p.specType) : write("None");
    write(",");
    p.defType ? visitT(p.defType) : write("None");
    end(p);
    return p;
  }

  N visit(TemplateValueParameter p)
  {
    begin(p);
    p.valueType ? visitT(p.valueType) : write("None");
    write(",");
    p.specValue ? visitE(p.specValue) : write("None");
    write(",");
    p.defValue ? visitE(p.defValue) : write("None");
    end(p);
    return p;
  }

  N visit(TemplateTupleParameter p)
  {
    begin(p);
    end(p);
    return p;
  }

  N visit(TemplateParameters p)
  {
    begin(p);
    write(p.children);
    end(p);
    return p;
  }

  N visit(TemplateArguments p)
  {
    begin(p);
    write(p.children);
    end(p);
    return p;
  }
} // override
}
