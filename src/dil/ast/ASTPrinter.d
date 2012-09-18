/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.ast.ASTPrinter;


import dil.ast.Visitor,
       dil.ast.NodeMembers,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;
import dil.lexer.IdTable;
import dil.Compilation;
import dil.String;
import dil.Enums;
import common;

/// Converts expressions like "TokenList.XYZ" to "toToken(TOK.XYZ)".
static struct TokenList
{
  static Token* opDispatch(string kind)()
  {
    return mixin("toToken(TOK."~kind~")");
  }
}

enum PREC
{
  None,
  Expression,
  Assignment,
  Conditional,
  LogicalOr,
  LogicalAnd,
  BinaryOr,
  BinaryXor,
  BinaryAnd,
  Relational,
  Shifting,
  Addition,
  Multiplication,
  Exponentiation,
  Unary,
  Primary,
}

/// Traverses a Node tree and constructs a string representation.
class ASTPrinter : Visitor2
{
  char[] text;      /// The printed text.
  Token*[] tokens;  /// The pre-built tokens of the text (Lexer not required.)
  bool buildTokens; /// True if the tokens should be built.
  Token* Newline;   /// Provides a newline token (depends on the platform).
  Token* wsToken;   /// Integer token with the current number of whitespaces.
  cstring spaces;   /// The current whitespace string.
  cstring indent;   /// The current indendation string.
  cstring indentStep; /// The string used to increase the indentation level.

  CompilationContext cc;
  alias TokenList T;

  /// Constructs an ASTPrinter.
  this(bool buildTokens, CompilationContext cc)
  {
    this.buildTokens = buildTokens;
    this.cc = cc;
    this.Newline = makeNewlineToken();
    this.indentStep = "  ";
  }

  /// Creates a newline token with a platform dependent string as its text.
  Token* makeNewlineToken()
  {
    auto t = new Token;
    t.kind = TOK.Newline;
    version(Windows)
    const nl = "\r\n";
    else version(OSX)
    const nl = "\r";
    else
    const nl = "\n";
    t.start = nl.ptr;
    t.end   = nl.ptr + nl.length;
    return t;
  }

  /// Starts the printer.
  char[] print(Node n)
  {
    visitN(n);
    fixTokens();
    return text;
  }

  /// Constructs a new Token with the given parameters and pushes to an array.
  void pushToken(TOK k, size_t start, size_t end, void* value)
  { // Create new token and set its members.
    cchar* prevEnd;
    auto t = new Token;
    if (tokens.length)
    { // Link in, if not the first element.
      Token* prev = tokens[$-1];
      prev.next = t;
      t.prev = prev;
      prevEnd = prev.end;
    }
    t.kind = k;
    t.ws = start ? prevEnd : null;
    t.start = prevEnd + start;
    t.end = prevEnd + end;
    t.pvoid = value;
    // Push to array.
    tokens ~= t;
  }

  /// When the emitted text is complete, the pointers in the tokens
  /// are updated to point to the correct text fragments.
  /// (Considering the text buffer might get relocated when appending to it.)
  void fixTokens()
  {
    if (!buildTokens || !tokens.length)
      return;
    const offset = cast(ssize_t)text.ptr;
    for (auto t = tokens[0]; t !is null; t = t.next)
    {
      if (t.ws)
        t.ws += offset;
      t.start += offset;
      t.end += offset;
    }
  }

  /// Returns the token kind for p.
  TOK protToTOK(PROT p)
  {
    TOK tk;
    final switch (p)
    {
    case Protection.Private:   tk = TOK.Private;   break;
    case Protection.Protected: tk = TOK.Protected; break;
    case Protection.Package:   tk = TOK.Package;   break;
    case Protection.Public:    tk = TOK.Public;    break;
    case Protection.Export:    tk = TOK.Export;    break;
    case Protection.None:
    }
    return tk;
  }

  /// Writes str to the text buffer.
  void writeS(cstring str)
  {
    text ~= str;
  }

  /// Writes a list of tokens.
  void write(Token*[] ts...)
  {
    foreach (t; ts)
      writeToken(t);
  }

  /// Writes the contents of a token to the text.
  void writeToken(Token* t)
  {
    if (t.kind == TOK.Invalid)
    { // Special whitespace token?
      spaces ~= t.text();
      return;
    }
    auto tokenText = t.text();
    if (buildTokens)
    {
      auto start = spaces.length;
      auto end = start + tokenText.length;
      pushToken(t.kind, start, end, t.pvoid);
    }
    writeS(spaces);
    writeS(tokenText);
    spaces = null; // Clear whitespace.
  }

  /// Writes the tokens between b and e (inclusive.)
  void writeSpan(Token* b, Token* e)
  {
    for (auto t = b; b !is e; t = t.next)
      if (!t.isWhitespace())
        writeToken(t);
  }

  /// Shortcuts.
  alias write w;
  /// ditto
  alias visitN v;

  /// Returns a new token containing 'n' number of whitespace characters.
  Token* ws(uint n) @property
  {
    auto s = String(" ") * n;
    auto t = new Token;
    t.start = s.ptr;
    t.end = s.end;
    return t;
  }

  /// Returns a new token containing a single whitespace character.
  Token* ws() @property
  {
    auto s = String(" ");
    auto t = new Token;
    t.start = s.ptr;
    t.end = s.end;
    return t;
  }

  /// Returns the current indentation as a token.
  Token* ind() @property
  {
    auto t = new Token;
    t.start = indent.ptr;
    t.end = indent.ptr + indent.length;
    return t;
  }

  /// Returns a Token for an Identifier.
  Token* id(Identifier* id)
  {
    auto t = new Token;
    t.text = id.str;
    t.ident = id;
    return t;
  }

  /// Increases/decreases indentation on construction/destruction.
  scope class IndentLevel
  {
    this()
    {
      indent ~= indentStep;
    }
    ~this()
    {
      indent = indent[0 .. $-indentStep.length];
    }
  }

  /// Decreases/increases indentation on construction/destruction.
  scope class UnindentLevel
  {
    this()
    {
      assert(indent.length >= indentStep.length);
      indent = indent[0 .. $-indentStep.length];
    }
    ~this()
    {
      indent ~= indentStep;
    }
  }

  /// Sets/restores indentation on construction/destruction.
  scope class SetIndentLevel
  {
    cstring old;
    this(cstring i)
    {
      old = indent;
      indent = i;
    }
    ~this()
    {
      indent = old;
    }
  }

  void write(Expression n, PREC prec)
  {
    // TODO:
    PREC nextP; // = n.kind.getPrecedence();
    if (prec < nextP)
    {
      w(T.LParen);
      v(n);
      w(T.RParen);
    }
    else
      v(n);
  }

  /// Writes a comma-separated list of Expressions.
  void write(Expression[] es)
  {
    foreach (i, e; es)
    {
      if (i)
        w(T.Comma, ws);
      w(e, PREC.Assignment);
    }
  }

  /// Writes a binary expression.
  void write(BinaryExpr n)
  {
    // TODO:
    w(n.lhs, PREC.None);
    w(ws, n.optok, ws);
    w(n.rhs, PREC.None);
  }

  /// Writes a unary expression.
  void write(UnaryExpr n)
  {
    w(n.una, PREC.Unary);
  }

  void writeBlock(Node n)
  {
    w(Newline, ind, T.LBrace, Newline);
    {
      scope il = new IndentLevel();
      v(n);
    }
    w(Newline, ind, T.RBrace, Newline);
  }

  void writeAggregateBody(Node n)
  {
    if (n is null)
      w(T.Semicolon, Newline);
    else
      writeBlock(n);
  }

  void visit(IllegalDecl n)
  {
    if (n.begin && n.end)
      writeSpan(n.begin, n.end);
  }

  void visit(CompoundDecl n)
  {
    foreach (x; n.decls)
      v(x);
  }

  void visit(ColonBlockDecl n)
  {
    w(T.Colon, Newline);
    v(n.decls);
  }

  void visit(EmptyDecl n)
  {
    w(ind, T.Semicolon, Newline);
  }

  void visit(ModuleDecl n)
  {
    w(T.Module);
    if (n.type)
      w(ws, T.LParen, n.type, T.RParen);
    w(ws, n.fqn[0]);
    foreach (id; n.fqn[1..$])
      w(T.Dot, id);
    w(T.Semicolon, Newline, Newline);
  }

  void visit(ImportDecl n)
  {
    w(ind);
    if (n.isStatic)
      w(T.Static, ws);
    w(T.Import, ws);
    foreach (i, fqn; n.moduleFQNs)
    {
      if (i)
        w(T.Comma, ws);
      if (auto aliasId = n.moduleAliases[i])
        w(aliasId, ws, T.Equal, ws);
      foreach (j, id; fqn)
      {
        if (j)
          w(T.Dot);
        w(id);
      }
    }
    foreach (i, bindName; n.bindNames)
    {
      if (i == 0)
        w(ws, T.Colon, ws);
      else
        w(T.Comma, ws);
      if (auto bindAlias = n.bindAliases[i])
        w(bindAlias, ws, T.Equal, ws);
      w(bindName);
    }
    w(T.Semicolon, Newline);
  }

  void visit(AliasDecl n)
  {
    w(ind, T.Alias);
    scope il = new SetIndentLevel(" ");
    v(n.decl);
  }

  void visit(AliasThisDecl n)
  {
    w(ind, T.Alias, ws, T.This, ws, n.ident, T.Semicolon, Newline);
  }

  void visit(TypedefDecl n)
  {
    w(ind, T.Typedef);
    scope il = new SetIndentLevel(" ");
    v(n.decl);
  }

  void visit(EnumDecl n)
  {
    w(ind, T.Enum);
    if (n.name)
      w(ws, n.name);
    if (n.baseType) {
      w(ws, T.Colon, ws);
      v(n.baseType);
    }
    if (!n.members)
      w(T.Semicolon, Newline);
    else
    {
      w(Newline, ind, T.LBrace, Newline);
      {
        scope il = new IndentLevel();
        foreach (i, m; n.members)
        {
          if (i)
            w(T.Comma, Newline);
          v(m);
        }
      }
      w(Newline, ind, T.RBrace, Newline);
    }
    w(Newline);
  }

  void visit(EnumMemberDecl n)
  {
    if (n.type) {
      w(ind);
      v(n.type);
      w(ws, n.name);
    }
    else
      w(ind, n.name);
    if (n.value) {
      w(ws, T.Equal, ws);
      v(n.value);
    }
  }


  void visit(TemplateDecl n)
  {
    w(ind);
    if (n.isMixin)
      w(T.Mixin, ws);
    w(T.Template, ws, n.name);
    v(n.tparams);
    if (n.constraint)
    {
      w(ws, T.If, T.LParen);
      v(n.constraint);
      w(T.RParen);
    }
    writeBlock(n.decls);
    w(Newline);
  }

  void visit(ClassDecl n)
  {
    w(ind, T.Class, ws, n.name);
    if (n.bases)
    {
      w(ws, T.Colon, ws);
      foreach (i, b; n.bases)
      {
        if (i)
          w(T.Comma, ws);
        v(b);
      }
    }
    writeAggregateBody(n.decls);
    w(Newline);
  }

  void visit(InterfaceDecl n)
  {
    w(ind, T.Interface, ws, n.name);
    if (n.bases)
    {
      w(ws, T.Colon, ws);
      foreach (i, b; n.bases)
      {
        if (i)
          w(T.Comma, ws);
        v(b);
      }
    }
    writeAggregateBody(n.decls);
    w(Newline);
  }

  void visit(StructDecl n)
  {
    w(ind, T.Struct);
    if (n.name)
      w(ws, n.name);
    writeAggregateBody(n.decls);
    w(Newline);
  }

  void visit(UnionDecl n)
  {
    w(ind, T.Union);
    if (n.name)
      w(ws, n.name);
    writeAggregateBody(n.decls);
    w(Newline);
  }

  void visit(ConstructorDecl n)
  {
    w(ind, T.This);
    v(n.params);
    v(n.funcBody);
  }

  void visit(StaticCtorDecl n)
  {
    w(ind, T.Static, ws, T.This, T.LParen, T.RParen);
    v(n.funcBody);
  }

  void visit(DestructorDecl n)
  {
    w(ind, T.Tilde, T.This, T.LParen, T.RParen);
    v(n.funcBody);
  }

  void visit(StaticDtorDecl n)
  {
    w(ind, T.Static, ws, T.Tilde, T.This, T.LParen, T.RParen);
    v(n.funcBody);
  }

  void visit(FunctionDecl n)
  {
    w(ind);
    if (n.returnType)
      v(n.returnType);
    else
      w(T.Auto);
    w(ws);
    w(n.name);
    v(n.params);
    v(n.funcBody);
  }

  void visit(VariablesDecl n)
  {
    w(ind);
    if (n.type)
      v(n.type);
    else
      w(T.Auto);
    w(ws);
    foreach (i, name; n.names)
    {
      if (i)
        w(T.Comma, ws);
      w(name);
      if (auto init = n.inits[i]) {
        w(ws, T.Equal, ws);
        v(init);
      }
    }
    w(T.Semicolon, Newline, Newline);
  }

  void visit(InvariantDecl n)
  {
    w(ind, T.Invariant, T.LParen, T.RParen);
    v(n.funcBody);
  }

  void visit(UnittestDecl n)
  {
    w(ind, T.Unittest);
    v(n.funcBody);
  }

  void visit(DebugDecl n)
  {
    w(ind, T.Debug);
    if (n.isSpecification())
      w(ws, T.Equal, ws, n.spec, T.Semicolon, Newline);
    else
    {
      if (n.cond)
        w(T.LParen, n.cond, T.RParen);
      writeBlock(n.decls);
      if (n.elseDecls) {
        w(T.Else);
        writeBlock(n.elseDecls);
      }
    }
    w(Newline);
  }

  void visit(VersionDecl n)
  {
    w(ind, T.Version);
    if (n.isSpecification())
      w(ws, T.Equal, ws, n.spec, T.Semicolon, Newline);
    else
    {
      w(T.LParen, n.cond, T.RParen);
      writeBlock(n.decls);
      if (n.elseDecls) {
        w(T.Else);
        writeBlock(n.elseDecls);
      }
    }
    w(Newline);
  }

  void visit(StaticIfDecl n)
  {
    w(ind, T.Static, T.If, T.LParen);
    v(n.condition);
    w(T.RParen, Newline);
    v(n.ifDecls);
    if (n.elseDecls) {
      w(T.Else, Newline);
      v(n.elseDecls);
    }
    w(Newline, Newline);
  }

  void visit(StaticAssertDecl n)
  {
    w(ind, T.Static, ws, T.Assert, T.LParen);
    v(n.condition);
    if (n.message) {
      w(T.Comma, ws);
      v(n.message);
    }
    w(T.RParen, Newline, Newline);
  }

  void visit(NewDecl n)
  {
    w(ind, T.New);
    v(n.params);
    v(n.funcBody);
  }

  void visit(DeleteDecl n)
  {
    w(ind, T.Delete);
    v(n.params);
    v(n.funcBody);
  }

  void visit(ProtectionDecl n)
  {
  }

  void visit(StorageClassDecl n)
  {
  }

  void visit(LinkageDecl n)
  {
  }

  void visit(AlignDecl n)
  {
  }

  void visit(PragmaDecl n)
  {
  }

  void visit(MixinDecl n)
  {
    w(ind, T.Mixin);
    if (n.isMixinExpr)
    {
      w(T.LParen);
      v(n.argument);
      w(T.RParen);
    }
    else
    {
      w(ws);
      v(n.templateExpr);
      if (n.mixinIdent)
        w(ws, n.mixinIdent);
    }
  }


  // Statements:
  void visit(IllegalStmt n)
  {
  }

  void visit(CompoundStmt n)
  {
    foreach (x; n.stmnts)
      v(x);
  }

  void visit(EmptyStmt n)
  {
    w(ind, T.Semicolon, Newline);
  }

  void visit(FuncBodyStmt n)
  {
    if (n.isEmpty())
      w(T.Semicolon, Newline);
    else
    {
      if (n.inBody) {
        w(Newline);
        w(ind, T.In);
        writeBlock(n.inBody);
      }
      if (n.outBody) {
        if (!n.inBody)
          w(Newline);
        w(ind, T.Out);
        if (n.outIdent)
          w(T.LParen, n.outIdent, T.RParen);
        writeBlock(n.outBody);
      }
      if (n.inBody || n.outBody)
        w(ind, T.Body);
      writeBlock(n.funcBody);
    }
    w(Newline);
  }

  void visit(ScopeStmt n)
  {
    v(n.stmnt);
  }

  void visit(LabeledStmt n)
  {
    {
      scope ul = new UnindentLevel;
      w(ind, n.label, T.Colon, Newline);
    }
    v(n.stmnt);
  }

  void visit(ExpressionStmt n)
  {
    w(ind);
    v(n.expr);
    w(T.Semicolon, Newline);
  }

  void visit(DeclarationStmt n)
  {
    v(n.decl);
  }

  void visit(IfStmt n)
  {
    w(ind, T.If, T.LParen);
    if (auto var = n.variable.to!VariablesDecl)
    {
      if (var.type)
        v(var.type);
      else
        w(T.Auto);
      w(ws, var.names[0], ws, T.Equal, ws);
      v(var.inits[0]);
    }
    else
      v(n.condition);
    w(T.RParen);
    writeBlock(n.ifBody);
    if (n.elseBody)
    {
      w(ind, T.Else);
      writeBlock(n.elseBody);
    }
  }

  void visit(WhileStmt n)
  {
    w(ind, T.While, T.LParen);
    v(n.condition);
    w(T.RParen);
    writeBlock(n.whileBody);
  }

  void visit(DoWhileStmt n)
  {
    w(ind, T.Do);
    writeBlock(n.doBody);
    w(ind, T.While, T.LParen);
    v(n.condition);
  version(D1)
    w(T.RParen, Newline);
  else
    w(T.RParen, T.Semicolon, Newline);
  }

  void visit(ForStmt n)
  {
    w(ind, T.For, T.LParen);
    if (n.init)
      v(n.init);
    else
      w(T.Semicolon);
    if (n.condition) {
      w(ws);
      v(n.condition);
    }
    w(T.Semicolon);
    if (n.increment) {
      w(ws);
      v(n.increment);
    }
    w(T.RParen);
    writeBlock(n.forBody);
  }

  void visit(ForeachStmt n)
  {
    w(ind, n.tok.toToken(), T.LParen);
    foreach (i, param; n.params.items())
    {
      if (i)
        w(T.Comma, ws);
      v(param);
    }
    w(T.Semicolon, ws);
    v(n.aggregate);
    w(T.RParen);
    writeBlock(n.forBody);
  }

  void visit(ForeachRangeStmt n)
  {
    w(ind, n.tok.toToken(), T.LParen);
    foreach (i, param; n.params.items())
    {
      if (i)
        w(T.Comma, ws);
      v(param);
    }
    w(T.Semicolon, ws);
    v(n.lower);
    w(T.Dot2);
    v(n.upper);
    w(T.RParen);
    writeBlock(n.forBody);
  }

  void visit(SwitchStmt n)
  {
    w(ind);
    if (n.isFinal)
      w(T.Final, ws);
    w(T.Switch, T.LParen);
    v(n.condition);
    w(T.RParen,);
    writeBlock(n.switchBody);
  }

  void visit(CaseStmt n)
  {
    scope ul = new UnindentLevel;
    w(ind, T.Case, ws);
    foreach (i, value; n.values)
    {
      if (i)
        w(T.Comma, ws);
      v(value);
    }
    w(T.Colon, Newline);
    scope il = new IndentLevel;
    v(n.caseBody);
  }

  void visit(CaseRangeStmt n)
  {
    scope ul = new UnindentLevel;
    w(ind, T.Case, ws);
    v(n.left);
    w(T.Dot2);
    v(n.right);
    w(T.Colon, Newline);
    scope il = new IndentLevel;
    v(n.caseBody);
  }

  void visit(DefaultStmt n)
  {
    scope ul = new UnindentLevel;
    w(ind, T.Default, ws);
    w(T.Colon, Newline);
    scope il = new IndentLevel;
    v(n.defaultBody);
  }

  void visit(ContinueStmt n)
  {
    w(ind, T.Continue);
    if (n.ident)
      w(ws, n.ident);
    w(T.Semicolon, Newline);
  }

  void visit(BreakStmt n)
  {
    w(ind, T.Break);
    if (n.ident)
      w(ws, n.ident);
    w(T.Semicolon, Newline);
  }

  void visit(ReturnStmt n)
  {
    w(ind, T.Return);
    if (n.expr) {
      w(ws);
      v(n.expr);
    }
    w(T.Semicolon, Newline);
  }

  void visit(GotoStmt n)
  {
    w(ind, T.Goto, ws);
    if (n.isGotoLabel)
      w(n.ident);
    else if (n.isGotoCase)
      v(n.expr);
    else
      w(T.Default);
    w(T.Semicolon, Newline);
  }

  void visit(WithStmt n)
  {
    w(ind, T.With, T.LParen);
    v(n.expr);
    w(T.RParen);
    writeBlock(n.withBody);
  }

  void visit(SynchronizedStmt n)
  {
    w(ind, T.Synchronized);
    if (n.expr)
    {
      w(T.LParen);
      v(n.expr);
      w(T.RParen);
    }
    writeBlock(n.syncBody);
  }

  void visit(TryStmt n)
  {
    w(ind, T.Try);
    writeBlock(n.tryBody);
    foreach (b; n.catchBodies)
      v(b);
    if (n.finallyBody)
      v(n.finallyBody);
  }

  void visit(CatchStmt n)
  {
    w(ind, T.Catch);
    if (n.param)
    {
      w(T.LParen);
      v(n.param);
      w(T.RParen);
    }
    writeBlock(n.catchBody);
  }

  void visit(FinallyStmt n)
  {
    w(ind, T.Finally);
    writeBlock(n.finallyBody);
  }

  void visit(ScopeGuardStmt n)
  {
    w(ind, T.Scope, T.LParen, n.condition, T.RParen);
    writeBlock(n.scopeBody);
  }

  void visit(ThrowStmt n)
  {
    w(ind, T.Throw, ws);
    v(n.expr);
    w(T.Semicolon, Newline);
  }

  void visit(VolatileStmt n)
  {
    w(ind, T.Volatile);
    writeBlock(n.volatileBody);
  }

  void visit(AsmBlockStmt n)
  {
    w(ind, T.LBrace);
    scope il = new IndentLevel;
    v(n.statements);
    w(T.RBrace);
  }

  void visit(AsmStmt n)
  {
    w(ind, n.ident);
    foreach (i, o; n.operands)
    {
      if (i)
        w(T.Comma, ws);
      v(o);
    }
    w(T.Semicolon, Newline);
  }

  void visit(AsmAlignStmt n)
  {
    w(ind, T.Align, n.numtok, T.Semicolon, Newline);
  }

  void visit(IllegalAsmStmt n)
  {
    assert(0);
  }

  void visit(PragmaStmt n)
  {
    w(ind, T.Pragma, T.LParen, n.ident);
    foreach (arg; n.args) {
      w(T.Comma, ws);
      v(arg);
    }
    w(T.RParen);
    writeBlock(n.pragmaBody);
  }

  void visit(MixinStmt n)
  {
    w(ind, T.Mixin, ws);
    v(n.templateExpr);
    if (n.mixinIdent)
      w(ws, n.mixinIdent);
    w(T.Semicolon, Newline);
  }

  void visit(StaticIfStmt n)
  {
    w(ind, T.Static, ws, T.If, T.LParen);
    v(n.condition);
    w(T.RParen);
    writeBlock(n.ifBody);
    if (n.elseBody) {
      w(ind, T.Else);
      writeBlock(n.elseBody);
    }
  }

  void visit(StaticAssertStmt n)
  {
    w(ind, T.Static, ws, T.Assert, T.LParen);
    v(n.condition);
    if (n.message) {
      w(T.Comma, ws);
      v(n.message);
    }
    w(T.RParen, Newline);
  }

  void visit(DebugStmt n)
  {
    w(ind, T.Debug);
    if (n.cond)
      w(T.LParen, n.cond, T.RParen);
    writeBlock(n.mainBody);
    if (n.elseBody)
    {
      w(ind, T.Else);
      writeBlock(n.elseBody);
    }
  }

  void visit(VersionStmt n)
  {
    w(ind, T.Version, T.LParen, n.cond, T.RParen);
    writeBlock(n.mainBody);
    if (n.elseBody)
    {
      w(ind, T.Else);
      writeBlock(n.elseBody);
    }
  }


  // Expressions:
  void visit(IllegalExpr n)
  {
    assert(0);
  }

  void visit(CondExpr n)
  {
    w(n.condition, PREC.LogicalOr);
    w(ws, T.Question, ws);
    w(n.lhs, PREC.Expression);
    w(ws, T.Colon, ws);
    w(n.rhs, PREC.Conditional);
  }

  void visit(CommaExpr n)
  {
    w(n);
  }

  void visit(OrOrExpr n)
  {
    w(n);
  }

  void visit(AndAndExpr n)
  {
    w(n);
  }

  void visit(OrExpr n)
  {
    w(n);
  }

  void visit(XorExpr n)
  {
    w(n);
  }

  void visit(AndExpr n)
  {
    w(n);
  }

  void visit(EqualExpr n)
  {
    w(n);
  }

  void visit(IdentityExpr n)
  {
    w(n.lhs, PREC.Relational);
    if (n.optok.kind == TOK.Exclaim)
      w(ws, T.Exclaim, T.Is, ws);
    else
      w(ws, T.Is, ws);
    w(n.rhs, PREC.Relational);
  }

  void visit(RelExpr n)
  {
    w(n);
  }

  void visit(InExpr n)
  {
    w(n.lhs, PREC.Relational);
    if (n.optok.kind == TOK.Exclaim)
      w(ws, T.Exclaim, T.In, ws);
    else
      w(ws, T.In, ws);
    w(n.rhs, PREC.Relational);
  }

  void visit(LShiftExpr n)
  {
    w(n);
  }

  void visit(RShiftExpr n)
  {
    w(n);
  }

  void visit(URShiftExpr n)
  {
    w(n);
  }

  void visit(PlusExpr n)
  {
    w(n);
  }

  void visit(MinusExpr n)
  {
    w(n);
  }

  void visit(CatExpr n)
  {
    w(n);
  }

  void visit(MulExpr n)
  {
    w(n);
  }

  void visit(DivExpr n)
  {
    w(n);
  }

  void visit(ModExpr n)
  {
    w(n);
  }

  void visit(PowExpr n)
  {
    w(n);
  }

  void visit(AssignExpr n)
  {
    w(n);
  }

  void visit(LShiftAssignExpr n)
  {
    w(n);
  }

  void visit(RShiftAssignExpr n)
  {
    w(n);
  }

  void visit(URShiftAssignExpr n)
  {
    w(n);
  }

  void visit(OrAssignExpr n)
  {
    w(n);
  }

  void visit(AndAssignExpr n)
  {
    w(n);
  }

  void visit(PlusAssignExpr n)
  {
    w(n);
  }

  void visit(MinusAssignExpr n)
  {
    w(n);
  }

  void visit(DivAssignExpr n)
  {
    w(n);
  }

  void visit(MulAssignExpr n)
  {
    w(n);
  }

  void visit(ModAssignExpr n)
  {
    w(n);
  }

  void visit(XorAssignExpr n)
  {
    w(n);
  }

  void visit(CatAssignExpr n)
  {
    w(n);
  }

  void visit(PowAssignExpr n)
  {
    w(n);
  }

  void visit(AddressExpr n)
  {
    w(T.Amp);
    w(n);
  }

  void visit(PreIncrExpr n)
  {
    w(T.Plus2);
    w(n);
  }

  void visit(PreDecrExpr n)
  {
    w(T.Minus2);
    w(n);
  }

  void visit(PostIncrExpr n)
  {
    w(n);
    w(T.Plus2);
  }

  void visit(PostDecrExpr n)
  {
    w(n);
    w(T.Minus2);
  }

  void visit(DerefExpr n)
  {
    w(T.Star);
    w(n);
  }

  void visit(SignExpr n)
  {
    if (n.isPos)
      w(T.Plus);
    else
      w(T.Minus);
    w(n);
  }

  void visit(NotExpr n)
  {
    w(T.Exclaim);
    w(n);
  }

  void visit(CompExpr n)
  {
    w(T.Tilde);
    w(n);
  }

  void visit(CallExpr n)
  {
    w(n);
    w(T.LParen);
    w(n.args);
    w(T.RParen);
  }

  void visit(NewExpr n)
  {
    if (n.frame) {
      v(n.frame);
      w(T.Dot);
    }
    w(T.New);
    if (n.newArgs)
    {
      w(T.LParen);
      w(n.newArgs);
      w(T.RParen);
    }
    w(ws);
    v(n.type);
    if (n.ctorArgs)
    {
      w(T.LParen);
      w(n.ctorArgs);
      w(T.RParen);
    }
  }

  void visit(NewClassExpr n)
  {
    if (n.frame) {
      v(n.frame);
      w(T.Dot);
    }
    w(T.New);
    if (n.newArgs)
    {
      w(T.LParen);
      w(n.newArgs);
      w(T.RParen);
    }
    w(ws);
    w(T.Class);
    if (n.ctorArgs)
    {
      w(T.LParen);
      w(n.ctorArgs);
      w(T.RParen);
    }
    if (n.bases)
    {
      w(ws);
      foreach (i, b; n.bases)
      {
        if (i)
          w(T.Comma, ws);
        v(b);
      }
    }
    writeAggregateBody(n.decls);
  }

  void visit(DeleteExpr n)
  {
    w(T.Delete);
    v(n.una);
  }

  void visit(CastExpr n)
  {
    w(T.Cast, T.LParen);
    if (n.type)
      v(n.type);
    w(T.RParen);
    w(n);
  }

  void visit(IndexExpr n)
  {
    w(n);
    w(n.args);
  }

  void visit(SliceExpr n)
  {
    w(n);
    w(T.LBracket);
    if (n.left)
    {
      w(n.left, PREC.Assignment);
      w(T.Dot2);
      w(n.right, PREC.Assignment);
    }
    w(T.RBracket);
  }

  void visit(ModuleScopeExpr n)
  {
    w(T.Dot);
  }

  void visit(IdentifierExpr n)
  {
    if (n.next) {
      w(n.next, PREC.Primary);
      w(T.Dot);
    }
    w(n.ident);
  }

  void visit(SpecialTokenExpr n)
  {
    w(n.specialToken);
  }

  void visit(TmplInstanceExpr n)
  {
    if (n.next) {
      w(n.next, PREC.Primary);
      w(T.Dot);
    }
    w(n.ident, T.Exclaim, T.LParen);
    v(n.targs);
    w(T.RParen);
  }

  void visit(ThisExpr n)
  {
    w(T.This);
  }

  void visit(SuperExpr n)
  {
    w(T.Super);
  }

  void visit(NullExpr n)
  {
    w(T.Null);
  }

  void visit(DollarExpr n)
  {
    w(T.Dollar);
  }

  void visit(BoolExpr n)
  {
    w(n.toBool ? T.True : T.False);
  }

  void visit(IntExpr n)
  {
    // TODO:
  }

  void visit(FloatExpr n)
  {
    // TODO:
  }

  void visit(ComplexExpr n)
  {
    // TODO:
  }

  void visit(CharExpr n)
  {
    // TODO:
  }

  void visit(StringExpr n)
  {
    // TODO:
  }

  void visit(ArrayLiteralExpr n)
  {
    w(T.LBracket);
    w(n.values);
    w(T.RBracket);
  }

  void visit(AArrayLiteralExpr n)
  {
    w(T.LBracket);
    foreach (i, value; n.values)
    {
      if (i)
        w(T.Comma, ws);
      w(n.keys[i], PREC.Assignment);
      w(T.Colon, ws);
      w(value, PREC.Assignment);
    }
    w(T.RBracket);
  }

  void visit(AssertExpr n)
  {
    w(T.Assert, T.LParen);
    w(n.expr, PREC.Assignment);
    if (n.msg) {
      w(T.Comma, ws);
      w(n.expr, PREC.Assignment);
    }
    w(T.RParen);
  }

  void visit(MixinExpr n)
  {
    w(T.Mixin, T.LParen);
    v(n.expr);
    w(T.RParen);
  }

  void visit(ImportExpr n)
  {
    w(T.Import, T.LParen);
    v(n.expr);
    w(T.RParen);
  }

  void visit(TypeofExpr n)
  {
    w(T.Typeof, T.LParen);
    v(n.type);
    w(T.RParen);
  }

  void visit(TypeDotIdExpr n)
  {
    w(T.LParen);
    v(n.type);
    w(T.RParen, T.Dot, n.ident);
  }

  void visit(TypeidExpr n)
  {
    w(T.Typeid, T.LParen);
    v(n.type);
    w(T.RParen);
  }

  void visit(IsExpr n)
  {
    w(T.Is, T.LParen);
    v(n.type);
    if (n.ident)
      w(ws, n.ident);
    if (n.opTok)
    {
      w(ws, n.opTok, ws);
      if (n.specTok)
        w(n.specTok);
      else
        v(n.specType);
    }
    if (n.ident && n.specType && n.tparams)
    {
      w(T.Comma, ws);
      foreach (i, param; n.tparams.items())
      {
        if (i)
          w(T.Comma, ws);
        v(param);
      }
    }
    w(T.RParen);
  }

  void visit(ParenExpr n)
  {
    w(T.LParen);
    v(n.next);
    w(T.RParen);
  }

  void visit(FuncLiteralExpr n)
  {
    // TODO:
  }

  void visit(TraitsExpr n)
  {
    w(T.Traits, T.LParen, n.ident);
    if (n.targs) {
      w(T.Comma);
      v(n.targs);
    }
    w(T.RParen);
  }

  void visit(VoidInitExpr n)
  {
    w(T.Void);
  }

  void visit(ArrayInitExpr n)
  {
    w(T.LBracket);
    foreach (i, value; n.values)
    {
      if (i)
        w(T.Comma, ws);
      if (auto key = n.keys[i]) {
        w(key, PREC.Assignment);
        w(T.Colon, ws);
      }
      w(value, PREC.Assignment);
    }
    w(T.RBracket);
  }

  void visit(StructInitExpr n)
  {
    w(T.LBrace);
    foreach (i, value; n.values)
    {
      if (i)
        w(T.Comma, ws);
      if (auto ident = n.idents[i])
        w(ident, T.Colon, ws);
      w(value, PREC.Assignment);
    }
    w(T.RBrace);
  }

  void visit(AsmTypeExpr n)
  {
    w(n.prefix, ws, id(Ident.ptr), ws);
    w(n.una, PREC.Unary);
  }

  void visit(AsmOffsetExpr n)
  {
    w(id(Ident.offsetof));
    w(n.una, PREC.Unary);
  }

  void visit(AsmSegExpr n)
  {
    w(id(Ident.seg));
    w(n.una, PREC.Unary);
  }

  void visit(AsmPostBracketExpr n)
  {
    w(n.una, PREC.Unary);
    w(T.LBracket);
    w(n.index, PREC.Expression);
    w(T.RBracket);
  }

  void visit(AsmBracketExpr n)
  {
    w(T.LBracket);
    w(n.expr, PREC.Expression);
    w(T.RBracket);
  }

  void visit(AsmLocalSizeExpr n)
  {
    w(id(Ident.__LOCAL_SIZE));
  }

  void visit(AsmRegisterExpr n)
  {
    w(n.register);
    if (n.number)
    {
      if (n.register.ident is Ident.ST && n.number)
      {
        w(T.LBracket);
        v(n.number);
        w(T.RBracket);
      }
      else
      {
        w(T.Colon);
        w(n.number, PREC.Expression);
      }
    }
  }


  // Types:
  void visit(IllegalType n)
  {
    assert(0);
  }

  void visit(IntegralType n)
  {
    w(n.tok.toToken());
  }

  void visit(ModuleScopeType n)
  {
    w(T.Dot);
  }

  void visit(IdentifierType n)
  {
    if (n.next) {
      v(n.next);
      w(T.Dot);
    }
    w(n.ident);
  }

  void visit(TypeofType n)
  {
    w(T.Typeof, T.LParen);
    if (n.isTypeofReturn)
      w(T.Return);
    else
      v(n.expr);
    w(T.RParen);
  }

  void visit(TmplInstanceType n)
  {
    if (n.next) {
      v(n.next);
      w(T.Dot);
    }
    w(n.ident, T.Exclaim, T.LParen);
    v(n.targs);
    w(T.RParen);
  }

  void visit(PointerType n)
  {
    v(n.next);
  }

  void visit(ArrayType n)
  {
    v(n.next);
    w(T.LBracket);
    if (n.assocType)
      v(n.assocType);
    else if (n.index1)
    {
      v(n.index1);
      if (n.index2) {
        w(T.Dot2);
        v(n.index2);
      }
    }
    w(T.RBracket);
  }

  void visit(FunctionType n)
  {
    v(n.next);
    w(ws, T.Function);
    v(n.params);
  }

  void visit(DelegateType n)
  {
    v(n.next);
    w(ws, T.Delegate);
    v(n.params);
  }

  void visit(BaseClassType n)
  {
    if (auto tok = protToTOK(n.prot))
      w(tok.toToken(), ws);
    v(n.next);
  }

  /// Writes "(" Type ")" if n is not null.
  void writeWithParen(TypeNode n)
  {
    if (n)
    {
      w(T.LParen);
      v(n);
      w(T.RParen);
    }
  }

  void visit(ConstType n)
  {
    w(T.Const);
    writeWithParen(n.next);
  }

  void visit(ImmutableType n)
  {
    w(T.Immutable);
    writeWithParen(n.next);
  }

  void visit(InoutType n)
  {
    w(T.Inout);
    writeWithParen(n.next);
  }

  void visit(SharedType n)
  {
    w(T.Shared);
    writeWithParen(n.next);
  }

  // Parameters:
  void visit(Parameter n)
  {
    if (n.isCVariadic)
      return w(T.Dot3);
    if (n.stcs)
    {
      for (auto i = STC.max; i; i >>= 1)
        if (n.stcs & i)
        {
          TOK t;
          switch (i)
          {
          case STC.Const:     t = TOK.Const;     break;
          case STC.Immutable: t = TOK.Immutable; break;
          case STC.Inout:     t = TOK.Inout;     break;
          case STC.Shared:    t = TOK.Shared;    break;
          case STC.Final:     t = TOK.Final;     break;
          case STC.Scope:     t = TOK.Scope;     break;
          case STC.Static:    t = TOK.Static;    break;
          case STC.Auto:      t = TOK.Auto;      break;
          case STC.In:        t = TOK.In;        break;
          case STC.Out:       t = TOK.Out;       break;
          case STC.Ref:       t = TOK.Ref;       break;
          default:
            assert(0);
          }
          w(t.toToken(), ws);
        }
    }
    if (n.type)
      v(n.type);
    if (n.hasName)
      w(ws, n.name);
    if (n.isDVariadic)
      w(T.Dot3);
    if (n.defValue) {
      w(ws, T.Equal, ws);
      v(n.defValue);
    }
  }

  void visit(Parameters n)
  {
    w(T.LParen);
    foreach (i, param; n.items())
    {
      if (i)
        w(T.Comma, ws);
      v(param);
    }
    w(T.RParen);
  }

  /// Writes specification and/or default values.
  void writeSpecDef(Node s, Node d)
  {
    if (s) {
      w(ws, T.Colon, ws);
      v(s);
    }
    if (d) {
      w(ws, T.Equal, ws);
      v(d);
    }
  }

  void visit(TemplateAliasParam n)
  {
    w(T.Alias, n.name);
    writeSpecDef(n.spec, n.def);
  }

  void visit(TemplateTypeParam n)
  {
    w(n.name);
    writeSpecDef(n.specType, n.defType);
  }

  void visit(TemplateThisParam n)
  {
    w(T.This, n.name);
    writeSpecDef(n.specType, n.defType);
  }

  void visit(TemplateValueParam n)
  {
    v(n.valueType);
    w(ws, n.name);
    writeSpecDef(n.specValue, n.defValue);
  }

  void visit(TemplateTupleParam n)
  {
    w(n.name, T.Dot3);
  }

  void visit(TemplateParameters n)
  {
    w(T.LParen);
    foreach (i, param; n.items())
    {
      if (i)
        w(T.Comma, ws);
      v(param);
    }
    w(T.RParen);
  }

  void visit(TemplateArguments n)
  {
    foreach (i, x; n.items)
    {
      if (i)
        w(T.Comma, ws);
      v(x);
    }
  }
}
