/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.translator.PyTreeEmitter;

import dil.ast.Visitor,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Statements,
       dil.ast.Expressions,
       dil.ast.Parameters,
       dil.ast.Types;
import dil.semantic.Module;
import dil.lexer.Funcs;
import dil.Time,
       dil.String;
import common;

import tango.core.Array : sort;

/// Replaces \ with \\ and " with \".
cstring escapeDblQuotes(cstring text)
{
  char[] result;
  auto p = text.ptr;
  auto end = p + text.length;
  auto prev = p;
  string esc;
  for (; p < end; p++)
    switch (*p)
    {
    case '"':  esc = `\"`;  goto case_common;
    case '\\': esc = `\\`;  goto case_common;
    case_common:
      if (prev < p) // Copy previous piece.
        result ~= String(prev, p).array;
      result ~= esc;
      prev = p + 1;
    default:
    }
  if (prev == text.ptr)
    return text; // Nothing to escape.
  if (prev < end) // Copy last piece.
    result ~= String(prev, p).array;
  return result;
}

/// Returns the number of characters if ws contains only ' ' chars,
/// otherwise returns ws in single quotes.
cstring quoteOrCountWhitespace(cstring ws)
{
  foreach (c; ws)
    if (c != ' ') return "'"~ws~"'";
  return itoa(ws.length);
}

/// Enumeration of flags that indicate what's contained in a string.
enum Flags
{
  None = 0,      /// No special characters.
  Backslash = 1, /// \
  DblQuote = 2,  /// "
  SglQuote = 4,  /// '
  Newline = 8,   /// \n, \r, \u2028, \u2029
  SglAndDbl = DblQuote | SglQuote, /// " and '
}

/// Searches for backslashes, quotes and newlines in a string.
/// Returns: A set of flags.
Flags analyzeString(cstring str)
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
  char[] result = "token_list = (\n".dup;
  char[] line;
  class Tuple
  {
    size_t count;
    cstring str;
    TOK kind;
    alias count pos;
    this(uint count, cstring str, TOK kind)
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
  Tuple[hash_t] map;
  for (auto token = first_token; token; token = token.next)
    switch (token.kind)
    {
    case TOK.Identifier, TOK.Comment, TOK.String, TOK.Character,
         TOK.Int32, TOK.Int64, TOK.UInt32, TOK.UInt64,
         TOK.Float32, TOK.Float64, TOK.Float80,
         TOK.IFloat32, TOK.IFloat64, TOK.IFloat80:
      auto hash = hashOf(token.text);
      auto p = hash in map;
      if (p) p.count += 1;
      else map[hash] = new Tuple(1, token.text, token.kind);
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
    auto str = item.str;
    Flags flags = analyzeString(str);
    string quote = `"`; // Default to double quotemarks.

    if (flags & Flags.Backslash ||
        (flags & Flags.SglAndDbl) == Flags.SglAndDbl)
    { // Use triple quotes for multiline strings.
      quote = (flags & Flags.Newline) ? `"""` : `"`;
      str = escapeDblQuotes(str);
    }
    else if (flags & Flags.Newline)
      quote = (flags & Flags.DblQuote) ? "'''" : `"""`;
    else if (flags & Flags.DblQuote)
      quote = "'";
    //else if (flags & Flags.SglQuote)
    //  quote = `"`;

    line ~= quote;
    line ~= str;
    line ~= quote;
    line ~= ',';

    if (line.length > 100)
      (result ~= line ~ "\n"), line = null;
    item.pos = i; /// Update position.
  }
  if (line.length)
    result ~= line;
  if (result[$-1] == '\n')
    result.length--;
  result ~= "),\n[\n";
  line = null;

  // Print the list of all tokens, encoded with IDs and indices.
  uint index;
  for (auto token = first_token; token; ++index, token = token.next)
  {
    indexMap[token] = index;
    line ~= '(' ~ itoa(token.kind) ~ ',';
    line ~= (token.ws) ? quoteOrCountWhitespace(token.wsChars) : `0`;
    line ~= ',';
    switch (token.kind)
    {
    case TOK.Identifier, TOK.Comment, TOK.String, TOK.Character:
    case TOK.Int32, TOK.Int64, TOK.UInt32, TOK.UInt64,
         TOK.Float32, TOK.Float64, TOK.Float80,
         TOK.IFloat32, TOK.IFloat64, TOK.IFloat80:
      line ~= itoa(map[hashOf(token.text)].pos);
      break;
    case TOK.Shebang:
      line ~= '"' ~ escapeDblQuotes(token.text) ~ '"';
      break;
    case TOK.HashLine:
      // The text to be inserted into formatStr.
      void printWS(cchar* start, cchar* end) {
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
          line ~= '"' ~ escapeDblQuotes(filespec.text) ~ '"';
        }
      }
      break;
    case TOK.Illegal:
      line ~= '"' ~ escapeDblQuotes(token.text) ~ '"';
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
class PyTreeEmitter : Visitor2
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
    string d_version = "1.0";
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
                  d_version, Time.now());

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
    text ~= ")\n";
    return text;
  }


  /// Returns the index number of a token as a string.
  char[] indexOf(Token* token)
  {
    return "t["~itoa(index[token])~"]";
  }

  void write(cstring str)
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

  void writeNodes(T)(T nodes)
  {
    write(cast(Node[])nodes);
  }

  void begin(Node n)
  {
    write("N"~itoa(n.kind)~"(");
  }

  void end(Node n, bool writeComma = true)
  {
    assert(n !is null && n.begin !is null && n.end !is null);
    auto i1 = index[n.begin], i2 = index[n.end];
    assert(i1 <= i2,
      Format("ops, Parser or AST buggy? {}@{},i1={},i2={}",
        NodeClassNames[n.kind],
        n.begin.getRealLocation(modul.filePath()).str(), i1, i2));
    write((writeComma ? ",":"") ~ "p("~itoa(i1)~","~itoa(i2-i1)~"))");
  }

override
{
  void visit(CompoundDecl d)
  {
    begin(d);
    writeNodes(d.decls);
    end(d);
  }

  void visit(IllegalDecl)
  { assert(0); }

  void visit(EmptyDecl d)
  {
    begin(d);
    end(d, false);
  }

  void visit(ModuleDecl d)
  {
    begin(d);
    d.type ? write(indexOf(d.type)) : write("n");
    write(",");
    write(indexOf(d.name)~",");
    write("(");
    foreach (tok; d.packages)
      write(indexOf(tok)~",");
    write(")");
    end(d);
  }

  void visit(ImportDecl d)
  {
    begin(d);
    write("(");
    foreach (moduleFQN; d.moduleFQNs)
    {
      write("(");
      foreach (tok; moduleFQN)
        write(indexOf(tok)~",");
      write("),");
    }
    write("),(");
    foreach (tok; d.moduleAliases)
      tok ? write(indexOf(tok)~",") : write("n,");
    write("),(");
    foreach (tok; d.bindNames)
      write(indexOf(tok)~",");
    write("),(");
    foreach (tok; d.bindAliases)
      tok ? write(indexOf(tok)~",") : write("n,");
    write(")");
    end(d);
  }

  void visit(AliasThisDecl d)
  {
    begin(d);
    write(indexOf(d.ident));
    end(d);
  }

  void visit(AliasDecl d)
  {
    begin(d);
    visitD(d.decl);
    end(d);
  }

  void visit(TypedefDecl d)
  {
    begin(d);
    visitD(d.decl);
    end(d);
  }

  void visit(EnumDecl d)
  {
    begin(d);
    write(indexOf(d.name));
    write(",");
    d.baseType ? visitT(d.baseType) : write("n");
    write(",");
    writeNodes(d.members);
    end(d);
  }

  void visit(EnumMemberDecl d)
  {
    begin(d);
    d.type ? visitT(d.type) : write("n");
    write(",");
    write(indexOf(d.name));
    write(",");
    d.value ? visitE(d.value) : write("n");
    end(d);
  }

  void visit(ClassDecl d)
  {
    begin(d);
    write(indexOf(d.name));
    write(",");
    writeNodes(d.bases);
    write(",");
    d.decls ? visitD(d.decls) : write("n");
    end(d);
  }

  void visit(InterfaceDecl d)
  {
    begin(d);
    write(indexOf(d.name));
    write(",");
    writeNodes(d.bases);
    write(",");
    d.decls ? visitD(d.decls) : write("n");
    end(d);
  }

  void visit(StructDecl d)
  {
    begin(d);
    write(indexOf(d.name));
    write(",");
    d.decls ? visitD(d.decls) : write("n");
    end(d);
  }

  void visit(UnionDecl d)
  {
    begin(d);
    write(indexOf(d.name));
    write(",");
    d.decls ? visitD(d.decls) : write("n");
    end(d);
  }

  void visit(ConstructorDecl d)
  {
    begin(d);
    visitN(d.params);
    write(",");
    visitS(d.funcBody);
    end(d);
  }

  void visit(StaticCtorDecl d)
  {
    begin(d);
    visitS(d.funcBody);
    end(d);
  }

  void visit(DestructorDecl d)
  {
    begin(d);
    visitS(d.funcBody);
    end(d);
  }

  void visit(StaticDtorDecl d)
  {
    begin(d);
    visitS(d.funcBody);
    end(d);
  }

  void visit(FunctionDecl d)
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
  }

  void visit(VariablesDecl d)
  {
    begin(d);
    // Type
    if (d.type !is null)
      visitT(d.type);
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
  }

  void visit(InvariantDecl d)
  {
    begin(d);
    visitS(d.funcBody);
    end(d);
  }

  void visit(UnittestDecl d)
  {
    begin(d);
    visitS(d.funcBody);
    end(d);
  }

  void visit(DebugDecl d)
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
  }

  void visit(VersionDecl d)
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
  }

  void visit(TemplateDecl d)
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
  }

  void visit(NewDecl d)
  {
    begin(d);
    visitN(d.params);
    write(",");
    visitS(d.funcBody);
    end(d);
  }

  void visit(DeleteDecl d)
  {
    begin(d);
    visitN(d.params);
    write(",");
    visitS(d.funcBody);
    end(d);
  }

  // Attributes:

  void visit(ProtectionDecl d)
  {
    begin(d);
    visitD(d.decls);
    end(d);
  }

  void visit(StorageClassDecl d)
  {
    begin(d);
    visitD(d.decls);
    end(d);
  }

  void visit(LinkageDecl d)
  {
    begin(d);
    visitD(d.decls);
    end(d);
  }

  void visit(AlignDecl d)
  {
    begin(d);
    d.sizetok ? write(indexOf(d.sizetok)) : write("n");
    write(",");
    visitD(d.decls);
    end(d);
  }

  void visit(StaticAssertDecl d)
  {
    begin(d);
    visitE(d.condition);
    write(",");
    d.message ? visitE(d.message) : write("n");
    end(d);
  }

  void visit(StaticIfDecl d)
  {
    begin(d);
    visitE(d.condition);
    write(",");
    visitD(d.ifDecls);
    write(",");
    d.elseDecls ? visitD(d.elseDecls) : write("n");
    end(d);
  }

  void visit(MixinDecl d)
  {
    begin(d);
    d.templateExpr ? visitE(d.templateExpr) : write("n");
    write(",");
    d.argument ? visitE(d.argument) : write("n");
    write(",");
    d.mixinIdent ? write(indexOf(d.mixinIdent)) : write("n");
    end(d);
  }

  void visit(PragmaDecl d)
  {
    begin(d);
    write(indexOf(d.ident));
    write(",");
    writeNodes(d.args);
    write(",");
    visitD(d.decls);
    end(d);
  }

} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                 Statements                                |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{

  void visit(CompoundStmt s)
  {
    begin(s);
    writeNodes(s.stmnts);
    end(s);
  }

  void visit(IllegalStmt)
  { assert(0, "interpreting invalid AST"); }

  void visit(EmptyStmt s)
  {
    begin(s);
    end(s, false);
  }

  void visit(FuncBodyStmt s)
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
  }

  void visit(ScopeStmt s)
  {
    begin(s);
    visitS(s.stmnt);
    end(s);
  }

  void visit(LabeledStmt s)
  {
    begin(s);
    write(indexOf(s.label));
    write(",");
    visitS(s.stmnt);
    end(s);
  }

  void visit(ExpressionStmt s)
  {
    begin(s);
    visitE(s.expr);
    end(s);
  }

  void visit(DeclarationStmt s)
  {
    begin(s);
    visitD(s.decl);
    end(s);
  }

  void visit(IfStmt s)
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
  }

  void visit(WhileStmt s)
  {
    begin(s);
    visitE(s.condition);
    write(",");
    visitS(s.whileBody);
    end(s);
  }

  void visit(DoWhileStmt s)
  {
    begin(s);
    visitS(s.doBody);
    write(",");
    visitE(s.condition);
    end(s);
  }

  void visit(ForStmt s)
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
  }

  void visit(ForeachStmt s)
  {
    begin(s);
    visitN(s.params);
    write(",");
    visitE(s.aggregate);
    write(",");
    visitS(s.forBody);
    end(s);
  }

  // D2.0
  void visit(ForeachRangeStmt s)
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
  }

  void visit(SwitchStmt s)
  {
    begin(s);
    visitE(s.condition);
    write(",");
    visitS(s.switchBody);
    end(s);
  }

  void visit(CaseStmt s)
  {
    begin(s);
    writeNodes(s.values);
    write(",");
    visitS(s.caseBody);
    end(s);
  }

  void visit(DefaultStmt s)
  {
    begin(s);
    visitS(s.defaultBody);
    end(s);
  }

  void visit(ContinueStmt s)
  {
    begin(s);
    s.ident ? write(indexOf(s.ident)) : write("n");
    end(s);
  }

  void visit(BreakStmt s)
  {
    begin(s);
    s.ident ? write(indexOf(s.ident)) : write("n");
    end(s);
  }

  void visit(ReturnStmt s)
  {
    begin(s);
    s.expr ? visitE(s.expr) : write("n");
    end(s);
  }

  void visit(GotoStmt s)
  {
    begin(s);
    s.ident ? write(indexOf(s.ident)) : write("n");
    write(",");
    s.expr ? visitE(s.expr) : write("n");
    end(s);
  }

  void visit(WithStmt s)
  {
    begin(s);
    visitE(s.expr);
    write(",");
    visitS(s.withBody);
    end(s);
  }

  void visit(SynchronizedStmt s)
  {
    begin(s);
    s.expr ? visitE(s.expr) : write("n");
    write(",");
    visitS(s.syncBody);
    end(s);
  }

  void visit(TryStmt s)
  {
    begin(s);
    visitS(s.tryBody);
    write(",");
    writeNodes(s.catchBodies);
    write(",");
    s.finallyBody ? visitS(s.finallyBody) : write("n");
    end(s);
  }

  void visit(CatchStmt s)
  {
    begin(s);
    s.param ? visitN(s.param) : write("n");
    write(",");
    visitS(s.catchBody);
    end(s);
  }

  void visit(FinallyStmt s)
  {
    begin(s);
    visitS(s.finallyBody);
    end(s);
  }

  void visit(ScopeGuardStmt s)
  {
    begin(s);
    write(indexOf(s.condition));
    write(",");
    visitS(s.scopeBody);
    end(s);
  }

  void visit(ThrowStmt s)
  {
    begin(s);
    visitE(s.expr);
    end(s);
  }

  void visit(VolatileStmt s)
  {
    begin(s);
    s.volatileBody ? visitS(s.volatileBody) : write("n");
    end(s);
  }

  void visit(AsmBlockStmt s)
  {
    begin(s);
    visitS(s.statements);
    end(s);
  }

  void visit(AsmStmt s)
  {
    begin(s);
    s.ident ? write(indexOf(s.begin)) : write("n");
    write(",");
    writeNodes(s.operands);
    end(s);
  }

  void visit(AsmAlignStmt s)
  {
    begin(s);
    write(indexOf(s.numtok));
    end(s);
  }

  void visit(IllegalAsmStmt)
  { assert(0, "invalid AST"); }

  void visit(PragmaStmt s)
  {
    begin(s);
    s.ident ? write(indexOf(s.ident)) : write("n");
    write(",");
    writeNodes(s.args);
    write(",");
    visitS(s.pragmaBody);
    end(s);
  }

  void visit(MixinStmt s)
  {
    begin(s);
    visitE(s.templateExpr);
    write(",");
    s.mixinIdent ? write(indexOf(s.mixinIdent)) : write("n");
    end(s);
  }

  void visit(StaticIfStmt s)
  {
    begin(s);
    visitE(s.condition);
    write(",");
    visitS(s.ifBody);
    write(",");
    s.elseBody ? visitS(s.elseBody) : write("n");
    end(s);
  }

  void visit(StaticAssertStmt s)
  {
    begin(s);
    visitE(s.condition);
    write(",");
    s.message ? visitE(s.message) : write("n");
    end(s);
  }

  void visit(DebugStmt s)
  {
    begin(s);
    visitS(s.mainBody);
    write(",");
    s.elseBody ? visitS(s.elseBody) : write("n");
    end(s);
  }

  void visit(VersionStmt s)
  {
    begin(s);
    visitS(s.mainBody);
    write(",");
    s.elseBody ? visitS(s.elseBody) : write("n");
    end(s);
  }

} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                Expressions                                |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  immutable binaryExpr = `
    begin(e);
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    write(",");
    write(indexOf(e.optok));
    end(e);`;

  immutable unaryExpr = `
    begin(e);
    visitE(e.una);
    end(e);`;

override
{
  void visit(IllegalExpr)
  { assert(0, "interpreting invalid AST"); }

  void visit(CondExpr e)
  {
    begin(e);
    visitE(e.condition);
    write(",");
    visitE(e.lhs);
    write(",");
    visitE(e.rhs);
    write(",");
    write(indexOf(e.optok));
    write(",");
    write(indexOf(e.ctok));
    end(e);
  }

  void visit(CommaExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(OrOrExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(AndAndExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(OrExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(XorExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(AndExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(EqualExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(IdentityExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(RelExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(InExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(LShiftExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(RShiftExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(URShiftExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(PlusExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(MinusExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(CatExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(MulExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(DivExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(ModExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(AssignExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(LShiftAssignExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(RShiftAssignExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(URShiftAssignExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(OrAssignExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(AndAssignExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(PlusAssignExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(MinusAssignExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(DivAssignExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(MulAssignExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(ModAssignExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(XorAssignExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(CatAssignExpr e)
  {
    mixin(binaryExpr);
  }

  void visit(AddressExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(PreIncrExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(PreDecrExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(PostIncrExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(PostDecrExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(DerefExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(SignExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(NotExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(CompExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(CallExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(NewExpr e)
  {
    begin(e);
    writeNodes(e.newArgs);
    write(",");
    visitT(e.type);
    write(",");
    writeNodes(e.ctorArgs);
    end(e);
  }

  void visit(NewClassExpr e)
  {
    begin(e);
    writeNodes(e.newArgs);
    write(",");
    writeNodes(e.bases);
    write(",");
    writeNodes(e.ctorArgs);
    write(",");
    visitD(e.decls);
    end(e);
  }

  void visit(DeleteExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(CastExpr e)
  {
    begin(e);
    version(D2)
    e.type ? visitT(e.type) : write("n");
    else
    visitT(e.type);
    write(",");
    visitE(e.una);
    end(e);
  }

  void visit(IndexExpr e)
  {
    begin(e);
    visitE(e.una);
    write(",");
    writeNodes(e.args);
    end(e);
  }

  void visit(SliceExpr e)
  {
    begin(e);
    visitE(e.una);
    write(",");
    e.left ? visitE(e.left) : write("n");
    write(",");
    e.right ? visitE(e.right) : write("n");
    end(e);
  }

  void visit(ModuleScopeExpr e)
  {
    begin(e);
    end(e, false);
  }

  void visit(IdentifierExpr e)
  {
    begin(e);
    write(indexOf(e.ident));
    end(e);
  }

  void visit(TmplInstanceExpr e)
  {
    begin(e);
    write(indexOf(e.ident));
    write(",");
    e.targs ? visitN(e.targs) : write("n");
    end(e);
  }

  void visit(SpecialTokenExpr e)
  {
    begin(e);
    write(indexOf(e.specialToken));
    end(e);
  }

  void visit(ThisExpr e)
  {
    begin(e);
    end(e, false);
  }

  void visit(SuperExpr e)
  {
    begin(e);
    end(e, false);
  }

  void visit(NullExpr e)
  {
    begin(e);
    end(e, false);
  }

  void visit(DollarExpr e)
  {
    begin(e);
    end(e, false);
  }

  void visit(BoolExpr e)
  {
    begin(e);
    end(e, false);
  }

  void visit(IntExpr e)
  {
    begin(e);
    end(e, false);
  }

  void visit(FloatExpr e)
  {
    begin(e);
    end(e, false);
  }

  void visit(ComplexExpr e)
  {
    begin(e);
    end(e, false);
  }

  void visit(CharExpr e)
  {
    begin(e);
    end(e, false);
  }

  void visit(StringExpr e)
  {
    begin(e);
    end(e, false);
  }

  void visit(ArrayLiteralExpr e)
  {
    begin(e);
    writeNodes(e.values);
    end(e);
  }

  void visit(AArrayLiteralExpr e)
  {
    begin(e);
    writeNodes(e.keys);
    write(",");
    writeNodes(e.values);
    end(e);
  }

  void visit(AssertExpr e)
  {
    begin(e);
    visitE(e.expr);
    write(",");
    e.msg ? visitE(e.msg) : write("n");
    end(e);
  }

  void visit(MixinExpr e)
  {
    begin(e);
    visitE(e.expr);
    end(e);
  }

  void visit(ImportExpr e)
  {
    begin(e);
    visitE(e.expr);
    end(e);
  }

  void visit(TypeofExpr e)
  {
    begin(e);
    visitT(e.type);
    end(e);
  }

  void visit(TypeDotIdExpr e)
  {
    begin(e);
    visitT(e.type);
    end(e);
  }

  void visit(TypeidExpr e)
  {
    begin(e);
    visitT(e.type);
    end(e);
  }

  void visit(IsExpr e)
  {
    begin(e);
    visitT(e.type);
    write(",");
    e.specType ? visitT(e.specType) : write("n");
    write(",");
    e.tparams ? visitN(e.tparams) : write("n");
    end(e);
  }

  void visit(ParenExpr e)
  {
    begin(e);
    visitE(e.next);
    end(e);
  }

  void visit(FuncLiteralExpr e)
  {
    begin(e);
    e.returnType ? visitT(e.returnType) : write("n");
    write(",");
    e.params ? visitN(e.params) : write("n");
    write(",");
    visitS(e.funcBody);
    end(e);
  }

  void visit(TraitsExpr e) // D2.0
  {
    begin(e);
    write(indexOf(e.ident)~",");
    visitN(e.targs);
    end(e);
  }

  void visit(VoidInitExpr e)
  {
    begin(e);
    end(e, false);
  }

  void visit(ArrayInitExpr e)
  {
    begin(e);
    write("(");
    foreach (k; e.keys)
      (k ? visitE(k) : write("n")), write(",");
    write("),");
    writeNodes(e.values);
    end(e);
  }

  void visit(StructInitExpr e)
  {
    begin(e);
    write("(");
    foreach (i; e.idents)
      (i ? write(indexOf(i)) : write("n")), write(",");
    write("),");
    writeNodes(e.values);
    end(e);
  }

  void visit(AsmTypeExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(AsmOffsetExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(AsmSegExpr e)
  {
    mixin(unaryExpr);
  }

  void visit(AsmPostBracketExpr e)
  {
    begin(e);
    visitE(e.una);
    write(",");
    visitE(e.index);
    end(e);
  }

  void visit(AsmBracketExpr e)
  {
    begin(e);
    visitE(e.expr);
    end(e);
  }

  void visit(AsmLocalSizeExpr e)
  {
    begin(e);
    end(e, false);
  }

  void visit(AsmRegisterExpr e)
  {
    begin(e);
    e.number ? visitE(e.number) : write("n");
    end(e);
  }
} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                   Types                                   |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  void visit(IllegalType)
  { assert(0, "interpreting invalid AST"); }

  void visit(IntegralType t)
  {
    begin(t);
    write(indexOf(t.begin));
    end(t);
  }

  void visit(ModuleScopeType t)
  {
    begin(t);
    end(t, false);
  }

  void visit(IdentifierType t)
  {
    begin(t);
    t.next ? visitT(t.next) : write("n");
    write(",");
    write(indexOf(t.begin));
    end(t);
  }

  void visit(TypeofType t)
  {
    begin(t);
    t.expr ? visitE(t.expr) : write("n");
    end(t);
  }

  void visit(TemplateInstanceType t)
  {
    begin(t);
    t.next ? visitT(t.next) : write("n");
    write(",");
    write(indexOf(t.begin));
    write(",");
    t.targs ? visitN(t.targs) : write("n");
    end(t);
  }

  void visit(PointerType t)
  {
    begin(t);
    visitT(t.next);
    end(t);
  }

  void visit(ArrayType t)
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
  }

  void visit(FunctionType t)
  {
    begin(t);
    visitT(t.returnType);
    write(",");
    visitN(t.params);
    end(t);
  }

  void visit(DelegateType t)
  {
    begin(t);
    visitT(t.returnType);
    write(",");
    visitN(t.params);
    end(t);
  }

  void visit(CFuncType t)
  {
    begin(t);
    visitT(t.next);
    write(",");
    visitN(t.params);
    end(t);
  }

  void visit(BaseClassType t)
  {
    begin(t);
    // TODO: emit t.prot?
    visitT(t.next);
    end(t);
  }

  void visit(ConstType t) // D2.0
  {
    begin(t);
    t.next && visitT(t.next);
    end(t);
  }

  void visit(ImmutableType t) // D2.0
  {
    begin(t);
    t.next && visitT(t.next);
    end(t);
  }

  void visit(InoutType t) // D2.0
  {
    begin(t);
    t.next && visitT(t.next);
    end(t);
  }

  void visit(SharedType t) // D2.0
  {
    begin(t);
    t.next && visitT(t.next);
    end(t);
  }
} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                 Parameters                                |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  void visit(Parameter p)
  {
    begin(p);
    p.type ? visitT(p.type) : write("n");
    write(",");
    p.defValue ? visitE(p.defValue) : write("n");
    end(p);
  }

  void visit(Parameters p)
  {
    begin(p);
    write(p.children);
    end(p);
  }

  void visit(TemplateAliasParam p)
  {
    begin(p);
    p.spec ? visitN(p.spec) : write("n");
    write(",");
    p.def ? visitN(p.def) : write("n");
    end(p);
  }

  void visit(TemplateTypeParam p)
  {
    begin(p);
    p.specType ? visitT(p.specType) : write("n");
    write(",");
    p.defType ? visitT(p.defType) : write("n");
    end(p);
  }

  void visit(TemplateThisParam p) // D2.0
  {
    begin(p);
    p.specType ? visitT(p.specType) : write("n");
    write(",");
    p.defType ? visitT(p.defType) : write("n");
    end(p);
  }

  void visit(TemplateValueParam p)
  {
    begin(p);
    p.valueType ? visitT(p.valueType) : write("n");
    write(",");
    p.specValue ? visitE(p.specValue) : write("n");
    write(",");
    p.defValue ? visitE(p.defValue) : write("n");
    end(p);
  }

  void visit(TemplateTupleParam p)
  {
    begin(p);
    end(p, false);
  }

  void visit(TemplateParameters p)
  {
    begin(p);
    write(p.children);
    end(p);
  }

  void visit(TemplateArguments p)
  {
    begin(p);
    write(p.children);
    end(p);
  }
} // override
}
