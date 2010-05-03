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

char[] countWhitespace(char[] ws)
{
  foreach (c; ws)
    if (c != ' ') return "'"~ws~"'";
  return String(ws.length);
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
    line ~= '(' ~ String(token.kind) ~ ',';
    line ~= (token.ws) ? countWhitespace(token.wsChars) : `0`;
    line ~= ',';
    switch(token.kind)
    {
    case TOK.Identifier, TOK.Comment, TOK.String, TOK.CharLiteral:
    case TOK.Int32, TOK.Int64, TOK.Uint32, TOK.Uint64,
         TOK.Float32, TOK.Float64, TOK.Float80,
         TOK.Imaginary32, TOK.Imaginary64, TOK.Imaginary80:
      line ~= String(map[token.text].pos);
      break;
    case TOK.Shebang:
      line ~= '"' ~ escape_quotes(token.text) ~ '"';
      break;
    case TOK.HashLine:
      // The text to be inserted into formatStr.
      void printWS(char* start, char* end) {
        line ~= '"' ~ start[0 .. end - start] ~ `",`;
      }
      auto num = token.hlval.lineNum;
      line ~= `"#line"`;
      if (num)
      { // Print whitespace between #line and number.
        printWS(token.start, num.start); // Prints "#line" as well.
        line ~= '"' ~ num.text ~ '"'; // Print the number.
        if (auto filespec = token.hlval.filespec)
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
                  "import dil.token\n"
                  "from dil.module import Module\n"
                  "from dil.nodes import *\n\n"
                  "generated_by = 'dil'\n"
                  "format_version = '1.0'\n"
                  "d_version= '{}'\n"
                  "date = '{}'\n\n",
                  d_version, Time.toString());

    text ~= writeTokenList(modul.firstToken(), index);
    text ~= "t = tokens = dil.token.create_tokens(token_list)\n\n";
    text ~= "def p(beg,end):\n"
            "  return (tokens[beg], tokens[beg+end])\n"
            /+"def tl(*args):\n"
            "  return [tokens[i] for i in args]\n"
            "  #return map(tokens.__getitem__, args)\n"+/
            "n = None\n\n"
            /+"def N(id, *args):\n"+/
            /+"  return NodeTable[id](*args)\n\n"+/;
    text ~= `module = Module(tokens=tokens, fqn="` ~ modul.getFQN() ~
            `",ext="` ~ modul.fileExtension() ~ `",root=`"\n";

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

  /// Returns the index number of a token as a string.
  char[] indexOf(Token* token)
  {
    return "t["~String(index[token])~"]";
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
    write("N"~String(n.kind)~"(");
  }

  void end(Node n, bool writeComma = true)
  {
    assert(n !is null && n.begin !is null && n.end !is null);
    auto i1 = index[n.begin], i2 = index[n.end];
    assert(i1 <= i2,
      Format("ops, Parser or AST buggy? {}@{},i1={},i2={}",
        g_classNames[n.kind],
        n.begin.getRealLocation(modul.filePath()).str(), i1, i2));
    write((writeComma ? ",":"") ~ "p("~String(i1)~","~String(i2-i1)~"))");
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
    end(d, false);
    return d;
  }

  D visit(ModuleDeclaration d)
  {
    begin(d);
    d.typeIdent ? write(indexOf(d.typeIdent)) : write("n");
    write(",");
    write(indexOf(d.moduleName)~",");
    write("(");
    foreach (tok; d.packages)
      write(indexOf(tok)~",");
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
      write("(");
      foreach(tok; moduleFQN)
        write(indexOf(tok)~",");
      write("),");
    }
    write("),(");
    foreach(tok; d.moduleAliases)
      tok ? write(indexOf(tok)~",") : write("n,");
    write("),(");
    foreach(tok; d.bindNames)
      write(indexOf(tok)~",");
    write("),(");
    foreach(tok; d.bindAliases)
      tok ? write(indexOf(tok)~",") : write("n,");
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
    write(indexOf(d.name));
    write(",");
    d.baseType ? visitT(d.baseType) : write("n");
    write(",");
    write(d.members);
    end(d);
    return d;
  }

  D visit(EnumMemberDeclaration d)
  {
    begin(d);
    d.type ? visitT(d.type) : write("n");
    write(",");
    write(indexOf(d.name));
    write(",");
    d.value ? visitE(d.value) : write("n");
    end(d);
    return d;
  }

  D visit(ClassDeclaration d)
  {
    begin(d);
    write(indexOf(d.name));
    write(",");
    write(d.bases);
    write(",");
    d.decls ? visitD(d.decls) : write("n");
    end(d);
    return d;
  }

  D visit(InterfaceDeclaration d)
  {
    begin(d);
    write(indexOf(d.name));
    write(",");
    write(d.bases);
    write(",");
    d.decls ? visitD(d.decls) : write("n");
    end(d);
    return d;
  }

  D visit(StructDeclaration d)
  {
    begin(d);
    write(indexOf(d.name));
    write(",");
    d.decls ? visitD(d.decls) : write("n");
    end(d);
    return d;
  }

  D visit(UnionDeclaration d)
  {
    begin(d);
    write(indexOf(d.name));
    write(",");
    d.decls ? visitD(d.decls) : write("n");
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
    d.returnType ? visitT(d.returnType) : write("n");
    write(",");
    write(indexOf(d.name));
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
    foreach (name; d.names)
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
    d.spec ? write(indexOf(d.spec)) : write("n");
    write(",");
    d.cond ? write(indexOf(d.cond)) : write("n");
    write(",");
    d.decls ? visitD(d.decls) : write("n");
    write(",");
    d.elseDecls ? visitD(d.elseDecls) : write("n");
    end(d);
    return d;
  }

  D visit(VersionDeclaration d)
  {
    begin(d);
    d.spec ? write(indexOf(d.spec)) : write("n");
    write(",");
    d.cond ? write(indexOf(d.cond)) : write("n");
    write(",");
    d.decls ? visitD(d.decls) : write("n");
    write(",");
    d.elseDecls ? visitD(d.elseDecls) : write("n");
    end(d);
    return d;
  }

  D visit(TemplateDeclaration d)
  {
    begin(d);
    write(indexOf(d.name));
    write(",");
    visitN(d.tparams);
    write(",");
    d.constraint ? visitE(d.constraint) : write("n");
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
    d.sizetok ? write(indexOf(d.sizetok)) : write("n");
    write(",");
    visitD(d.decls);
    end(d);
    return d;
  }

  D visit(StaticAssertDeclaration d)
  {
    begin(d);
    visitE(d.condition);
    write(",");
    d.message ? visitE(d.message) : write("n");
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
    d.elseDecls ? visitD(d.elseDecls) : write("n");
    end(d);
    return d;
  }

  D visit(MixinDeclaration d)
  {
    begin(d);
    d.templateExpr ? visitE(d.templateExpr) : write("n");
    write(",");
    d.argument ? visitE(d.argument) : write("n");
    write(",");
    d.mixinIdent ? write(indexOf(d.mixinIdent)) : write("n");
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
    end(s, false);
    return s;
  }

  S visit(FuncBodyStatement s)
  {
    begin(s);
    s.funcBody ? visitS(s.funcBody) : write("n");
    write(",");
    s.inBody ? visitS(s.inBody) : write("n");
    write(",");
    s.outBody ? visitS(s.outBody) : write("n");
    write(",");
    s.outIdent ? write(indexOf(s.outIdent)) : write("n");
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
    write(indexOf(s.label));
    write(",");
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
    s.variable ? visitS(s.variable) : write("n");
    write(",");
    s.condition ? visitE(s.condition) : write("n");
    write(",");
    visitS(s.ifBody);
    write(",");
    s.elseBody ? visitS(s.elseBody) : write("n");
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
    s.init ? visitS(s.init) : write("n");
    write(",");
    s.condition ? visitE(s.condition) : write("n");
    write(",");
    s.increment ? visitE(s.increment) : write("n");
    write(",");
    s.forBody ? visitS(s.forBody) : write("n");
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
    s.ident ? write(indexOf(s.ident)) : write("n");
    end(s);
    return s;
  }

  S visit(BreakStatement s)
  {
    begin(s);
    s.ident ? write(indexOf(s.ident)) : write("n");
    end(s);
    return s;
  }

  S visit(ReturnStatement s)
  {
    begin(s);
    s.expr ? visitE(s.expr) : write("n");
    end(s);
    return s;
  }

  S visit(GotoStatement s)
  {
    begin(s);
    s.ident ? write(indexOf(s.ident)) : write("n");
    write(",");
    s.expr ? visitE(s.expr) : write("n");
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
    s.expr ? visitE(s.expr) : write("n");
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
    s.finallyBody ? visitS(s.finallyBody) : write("n");
    end(s);
    return s;
  }

  S visit(CatchStatement s)
  {
    begin(s);
    s.param ? visitN(s.param) : write("n");
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
    s.volatileBody ? visitS(s.volatileBody) : write("n");
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
    s.ident ? write(indexOf(s.begin)) : write("n");
    write(",");
    write(s.operands);
    end(s);
    return s;
  }

  S visit(AsmAlignStatement s)
  {
    begin(s);
    write(indexOf(s.numtok));
    end(s);
    return s;
  }

  S visit(IllegalAsmStatement)
  { assert(0, "invalid AST"); return null; }

  S visit(PragmaStatement s)
  {
    begin(s);
    s.ident ? write(indexOf(s.ident)) : write("n");
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
    s.mixinIdent ? write(indexOf(s.mixinIdent)) : write("n");
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
    s.elseBody ? visitS(s.elseBody) : write("n");
    end(s);
    return s;
  }

  S visit(StaticAssertStatement s)
  {
    begin(s);
    visitE(s.condition);
    write(",");
    s.message ? visitE(s.message) : write("n");
    end(s);
    return s;
  }

  S visit(DebugStatement s)
  {
    begin(s);
    visitS(s.mainBody);
    write(",");
    s.elseBody ? visitS(s.elseBody) : write("n");
    end(s);
    return s;
  }

  S visit(VersionStatement s)
  {
    begin(s);
    visitS(s.mainBody);
    write(",");
    s.elseBody ? visitS(s.elseBody) : write("n");
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
    write(",");
    write(indexOf(e.tok));
    write(",");
    write(indexOf(e.ctok));
    end(e);
    return e;
  }

  const binaryExpr = `
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    write(",");
    write(indexOf(e.tok));
    end(e);
    return e;`;

  const unaryExpr = `
    begin(e);
    visitE(e.una);
    end(e);
    return e;`;

  E visit(CommaExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(OrOrExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(AndAndExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(OrExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(XorExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(AndExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(EqualExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(IdentityExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(RelExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(InExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(LShiftExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(RShiftExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(URShiftExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(PlusExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(MinusExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(CatExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(MulExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(DivExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(ModExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(AssignExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(LShiftAssignExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(RShiftAssignExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(URShiftAssignExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(OrAssignExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(AndAssignExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(PlusAssignExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(MinusAssignExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(DivAssignExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(MulAssignExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(ModAssignExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(XorAssignExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(CatAssignExpression e)
  {
    mixin(binaryExpr);
  }

  E visit(AddressExpression e)
  {
    mixin(unaryExpr);
  }

  E visit(PreIncrExpression e)
  {
    mixin(unaryExpr);
  }

  E visit(PreDecrExpression e)
  {
    mixin(unaryExpr);
  }

  E visit(PostIncrExpression e)
  {
    mixin(unaryExpr);
  }

  E visit(PostDecrExpression e)
  {
    mixin(unaryExpr);
  }

  E visit(DerefExpression e)
  {
    mixin(unaryExpr);
  }

  E visit(SignExpression e)
  {
    mixin(unaryExpr);
  }

  E visit(NotExpression e)
  {
    mixin(unaryExpr);
  }

  E visit(CompExpression e)
  {
    mixin(unaryExpr);
  }

  E visit(CallExpression e)
  {
    mixin(unaryExpr);
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

  E visit(NewClassExpression e)
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
    mixin(unaryExpr);
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
    e.left ? visitE(e.left) : write("n");
    write(",");
    e.right ? visitE(e.right) : write("n");
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
    end(e, false);
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
    e.targs ? visitN(e.targs) : write("n");
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
    end(e, false);
    return e;
  }

  E visit(SuperExpression e)
  {
    begin(e);
    end(e, false);
    return e;
  }

  E visit(NullExpression e)
  {
    begin(e);
    end(e, false);
    return e;
  }

  E visit(DollarExpression e)
  {
    begin(e);
    end(e, false);
    return e;
  }

  E visit(BoolExpression e)
  {
    begin(e);
    end(e, false);
    return e.value;
  }

  E visit(IntExpression e)
  {
    begin(e);
    end(e, false);
    return e;
  }

  E visit(RealExpression e)
  {
    begin(e);
    end(e, false);
    return e;
  }

  E visit(ComplexExpression e)
  {
    begin(e);
    end(e, false);
    return e;
  }

  E visit(CharExpression e)
  {
    begin(e);
    end(e, false);
    return e;
  }

  E visit(StringExpression e)
  {
    begin(e);
    end(e, false);
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
    e.msg ? visitE(e.msg) : write("n");
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
    e.specType ? visitT(e.specType) : write("n");
    write(",");
    e.tparams ? visitN(e.tparams) : write("n");
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
    e.returnType ? visitT(e.returnType) : write("n");
    write(",");
    e.params ? visitN(e.params) : write("n");
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
    end(e, false);
    return e;
  }

  E visit(ArrayInitExpression e)
  {
    begin(e);
    write("(");
    foreach (k; e.keys)
      (k ? visitE(k) : write("n")), write(",");
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
      (i ? write(indexOf(i)) : write("n")), write(",");
    write("),");
    write(e.values);
    end(e);
    return e;
  }

  E visit(AsmTypeExpression e)
  {
    mixin(unaryExpr);
  }

  E visit(AsmOffsetExpression e)
  {
    mixin(unaryExpr);
  }

  E visit(AsmSegExpression e)
  {
    mixin(unaryExpr);
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
    end(e, false);
    return e;
  }

  E visit(AsmRegisterExpression e)
  {
    begin(e);
    e.number ? visitE(e.number) : write("n");
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

  T visit(ModuleScopeType t)
  {
    begin(t);
    end(t, false);
    return t;
  }

  T visit(IdentifierType t)
  {
    begin(t);
    t.next ? visitT(t.next) : write("n");
    write(",");
    write(indexOf(t.begin));
    end(t);
    return t;
  }

  T visit(TypeofType t)
  {
    begin(t);
    t.expr ? visitE(t.expr) : write("n");
    end(t);
    return t;
  }

  T visit(TemplateInstanceType t)
  {
    begin(t);
    t.next ? visitT(t.next) : write("n");
    write(",");
    write(indexOf(t.begin));
    write(",");
    t.targs ? visitN(t.targs) : write("n");
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
    write(",");
    t.assocType ? visitT(t.assocType) : write("n");
    write(",");
    t.index1 ? visitE(t.index1) : write("n");
    write(",");
    t.index2 ? visitE(t.index2) : write("n");
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

  T visit(CFuncType t)
  {
    begin(t);
    visitT(t.next);
    write(",");
    visitN(t.params);
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
    t.next && visitT(t.next);
    end(t);
    return t;
  }

  T visit(ImmutableType t) // D2.0
  {
    begin(t);
    t.next && visitT(t.next);
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
    p.type ? visitT(p.type) : write("n");
    write(",");
    p.defValue ? visitE(p.defValue) : write("n");
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
    p.spec ? visitN(p.spec) : write("n");
    write(",");
    p.def ? visitN(p.def) : write("n");
    end(p);
    return p;
  }

  N visit(TemplateTypeParameter p)
  {
    begin(p);
    p.specType ? visitT(p.specType) : write("n");
    write(",");
    p.defType ? visitT(p.defType) : write("n");
    end(p);
    return p;
  }

  N visit(TemplateThisParameter p) // D2.0
  {
    begin(p);
    p.specType ? visitT(p.specType) : write("n");
    write(",");
    p.defType ? visitT(p.defType) : write("n");
    end(p);
    return p;
  }

  N visit(TemplateValueParameter p)
  {
    begin(p);
    p.valueType ? visitT(p.valueType) : write("n");
    write(",");
    p.specValue ? visitE(p.specValue) : write("n");
    write(",");
    p.defValue ? visitE(p.defValue) : write("n");
    end(p);
    return p;
  }

  N visit(TemplateTupleParameter p)
  {
    begin(p);
    end(p, false);
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
