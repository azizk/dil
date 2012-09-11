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
  void write(Token*[] ts)
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

  alias writeToken write;

  /// Writes the tokens between b and e (inclusive.)
  void writeSpan(Token* b, Token* e)
  {
    for (auto t = b; b !is e; t = t.next)
      if (!t.isWhitespace())
        writeToken(t);
  }

  /// Shortcut.
  alias write w;
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

  void writeBlock(Node n)
  {
    w([Newline, ind, T.LBrace, Newline]);
    {
      scope il = new IndentLevel();
      v(n);
    }
    w([Newline, ind, T.RBrace, Newline]);
  }

  void writeAggregateBody(Node n)
  {
    if (n is null)
      w([T.Semicolon, Newline]);
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

  void visit(EmptyDecl n)
  {
    w([T.Semicolon, Newline]);
  }

  void visit(ModuleDecl n)
  {
    w(T.Module);
    if (n.type)
      w([ws, T.LParen, n.type, T.RParen]);
    w([ws, n.fqn[0]]);
    foreach (id; n.fqn[1..$])
      w([T.Dot, id]);
    w([T.Semicolon, Newline, Newline]);
  }

  void visit(ImportDecl n)
  {
    if (n.isStatic)
      w([T.Static, ws]);
    w([T.Import, ws]);
    foreach (i, fqn; n.moduleFQNs)
    {
      if (i)
        w([T.Comma, ws]);
      if (auto aliasId = n.moduleAliases[i])
        w([aliasId, ws, T.Equal, ws]);
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
        w([ws, T.Colon, ws]);
      else
        w([T.Comma, ws]);
      if (auto bindAlias = n.bindAliases[i])
        w([bindAlias, ws, T.Equal, ws]);
      w(bindName);
    }
    w([T.Semicolon, Newline]);
  }

  void visit(AliasDecl n)
  {
    w(T.Alias);
    v(n.decl);
    w([T.Semicolon, Newline]);
  }

  void visit(AliasThisDecl n)
  {
    w([T.Alias, T.This, n.ident, T.Semicolon, Newline]);
  }

  void visit(TypedefDecl n)
  {
    w(T.Typedef);
    v(n.decl);
    w([T.Semicolon, Newline]);
  }

  void visit(EnumDecl n)
  {
    w(T.Enum);
    if (n.name)
      w([ws, n.name]);
    if (n.baseType) {
      w([ws, T.Colon, ws]);
      v(n.baseType);
    }
    if (!n.members)
      w([T.Semicolon, Newline]);
    else
    {
      w([Newline, ind, T.LBrace, Newline]);
      {
        scope il = new IndentLevel();
        foreach (i, m; n.members)
        {
          if (i)
            w([T.Comma, Newline]);
          v(m);
        }
      }
      w([Newline, ind, T.RBrace, Newline]);
    }
    w(Newline);
  }

  void visit(EnumMemberDecl n)
  {
    if (n.type) {
      w(ind);
      v(n.type);
      w([ws, n.name]);
    }
    else
      w([ind, n.name]);
    if (n.value) {
      w([ws, T.Equal, ws]);
      v(n.value);
    }
  }


  void visit(TemplateDecl n)
  {
    if (n.isMixin)
      w([ind, T.Mixin, ws]);
    else
      w(ind);
    w([T.Template, ws, n.name]);
    v(n.tparams);
    if (n.constraint)
    {
      w([ws, T.If, T.LParen]);
      v(n.constraint);
      w([T.RParen]);
    }
    writeBlock(n.decls);
    w(Newline);
  }

  void visit(ClassDecl n)
  {
    w([ind, T.Class, ws, n.name]);
    if (n.bases)
    {
      w([ws, T.Colon, ws]);
      foreach (i, b; n.bases)
      {
        if (i)
          w([T.Comma, ws]);
        v(b);
      }
    }
    writeAggregateBody(n.decls);
    w(Newline);
  }

  void visit(InterfaceDecl n)
  {
    w([ind, T.Interface, ws, n.name]);
    if (n.bases)
    {
      w([ws, T.Colon, ws]);
      foreach (i, b; n.bases)
      {
        if (i)
          w([T.Comma, ws]);
        v(b);
      }
    }
    writeAggregateBody(n.decls);
    w(Newline);
  }

  void visit(StructDecl n)
  {
    w([ind, T.Struct]);
    if (n.name)
      w([ws, n.name]);
    writeAggregateBody(n.decls);
    w(Newline);
  }

  void visit(UnionDecl n)
  {
    w([ind, T.Union]);
    if (n.name)
      w([ws, n.name]);
    writeAggregateBody(n.decls);
    w(Newline);
  }

  void visit(ConstructorDecl n)
  {
    w([ind, T.This]);
    v(n.params);
    v(n.funcBody);
  }

  void visit(StaticCtorDecl n)
  {
    w([ind, T.Static, ws, T.This, T.LParen, T.RParen]);
    v(n.funcBody);
  }

  void visit(DestructorDecl n)
  {
    w([ind, T.Tilde, T.This, T.LParen, T.RParen]);
    v(n.funcBody);
  }

  void visit(StaticDtorDecl n)
  {
    w([ind, T.Static, ws, T.Tilde, T.This, T.LParen, T.RParen]);
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
        w([T.Comma, ws]);
      w(name);
      if (auto init = n.inits[i]) {
        w([ws, T.Equal, ws]);
        v(init);
      }
    }
    w([T.Semicolon, Newline, Newline]);
  }

  void visit(InvariantDecl n)
  {
    w([ind, T.Invariant, T.LParen, T.RParen]);
    v(n.funcBody);
  }

  void visit(UnittestDecl n)
  {
    w([ind, T.Unittest]);
    v(n.funcBody);
  }

  void visit(DebugDecl n)
  {
    w([ind, T.Debug]);
    if (n.isSpecification())
      w([ws, T.Equal, ws, n.spec, T.Semicolon, Newline]);
    else
    {
      if (n.cond)
        w([T.LParen, n.cond, T.RParen]);
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
    w([ind, T.Version]);
    if (n.isSpecification())
      w([ws, T.Equal, ws, n.spec, T.Semicolon, Newline]);
    else
    {
      w([T.LParen, n.cond, T.RParen]);
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
    w([ind, T.Static, T.If, T.LParen]);
    v(n.condition);
    w([T.RParen, Newline]);
    v(n.ifDecls);
    if (n.elseDecls) {
      w([T.Else, Newline]);
      v(n.elseDecls);
    }
    w([Newline, Newline]);
  }

  void visit(StaticAssertDecl n)
  {
    w([ind, T.Static, ws, T.Assert, T.LParen]);
    v(n.condition);
    if (n.message) {
      w([T.Comma, ws]);
      v(n.message);
    }
    w([T.RParen, Newline, Newline]);
  }

  void visit(NewDecl n)
  {
    w([ind, T.New]);
    v(n.params);
    v(n.funcBody);
  }

  void visit(DeleteDecl n)
  {
    w([ind, T.Delete]);
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
    w([ind, T.Mixin]);
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
        w([ws, n.mixinIdent]);
    }
  }


  // Statements:
  void visit(IllegalStmt n)
  {
  }

  void visit(CompoundStmt n)
  {
  }

  void visit(EmptyStmt n)
  {
  }

  void visit(FuncBodyStmt n)
  {
    if (n.isEmpty())
      w([T.Semicolon, Newline]);
    else
    {
      if (n.inBody) {
        w([ind, T.In]);
        writeBlock(n.inBody);
      }
      if (n.outBody) {
        w([ind, T.Out]);
        if (n.outIdent)
          w([T.LParen, n.outIdent, T.RParen]);
        writeBlock(n.outBody);
      }
      if (n.inBody || n.outBody)
        w([ind, T.Body]);
      writeBlock(n.funcBody);
    }
    w(Newline);
  }

  void visit(ScopeStmt n)
  {
  }

  void visit(LabeledStmt n)
  {
  }

  void visit(ExpressionStmt n)
  {
  }

  void visit(DeclarationStmt n)
  {
  }

  void visit(IfStmt n)
  {
  }

  void visit(WhileStmt n)
  {
  }

  void visit(DoWhileStmt n)
  {
  }

  void visit(ForStmt n)
  {
  }

  void visit(ForeachStmt n)
  {
  }

  void visit(ForeachRangeStmt n)
  {
  }

  void visit(SwitchStmt n)
  {
  }

  void visit(CaseStmt n)
  {
  }

  void visit(CaseRangeStmt n)
  {
  }

  void visit(DefaultStmt n)
  {
  }

  void visit(ContinueStmt n)
  {
  }

  void visit(BreakStmt n)
  {
  }

  void visit(ReturnStmt n)
  {
  }

  void visit(GotoStmt n)
  {
  }

  void visit(WithStmt n)
  {
  }

  void visit(SynchronizedStmt n)
  {
  }

  void visit(TryStmt n)
  {
  }

  void visit(CatchStmt n)
  {
  }

  void visit(FinallyStmt n)
  {
  }

  void visit(ScopeGuardStmt n)
  {
  }

  void visit(ThrowStmt n)
  {
  }

  void visit(VolatileStmt n)
  {
  }

  void visit(AsmBlockStmt n)
  {
  }

  void visit(AsmStmt n)
  {
  }

  void visit(AsmAlignStmt n)
  {
  }

  void visit(IllegalAsmStmt n)
  {
  }

  void visit(PragmaStmt n)
  {
  }

  void visit(MixinStmt n)
  {
  }

  void visit(StaticIfStmt n)
  {
  }

  void visit(StaticAssertStmt n)
  {
  }

  void visit(DebugStmt n)
  {
  }

  void visit(VersionStmt n)
  {
  }


  // Expressions:
  void visit(IllegalExpr n)
  {
  }

  void visit(CondExpr n)
  {
  }

  void visit(CommaExpr n)
  {
  }

  void visit(OrOrExpr n)
  {
  }

  void visit(AndAndExpr n)
  {
  }

  void visit(OrExpr n)
  {
  }

  void visit(XorExpr n)
  {
  }

  void visit(AndExpr n)
  {
  }

  void visit(EqualExpr n)
  {
  }

  void visit(IdentityExpr n)
  {
  }

  void visit(RelExpr n)
  {
  }

  void visit(InExpr n)
  {
  }

  void visit(LShiftExpr n)
  {
  }

  void visit(RShiftExpr n)
  {
  }

  void visit(URShiftExpr n)
  {
  }

  void visit(PlusExpr n)
  {
  }

  void visit(MinusExpr n)
  {
  }

  void visit(CatExpr n)
  {
  }

  void visit(MulExpr n)
  {
  }

  void visit(DivExpr n)
  {
  }

  void visit(ModExpr n)
  {
  }

  void visit(PowExpr n)
  {
  }

  void visit(AssignExpr n)
  {
  }

  void visit(LShiftAssignExpr n)
  {
  }

  void visit(RShiftAssignExpr n)
  {
  }

  void visit(URShiftAssignExpr n)
  {
  }

  void visit(OrAssignExpr n)
  {
  }

  void visit(AndAssignExpr n)
  {
  }

  void visit(PlusAssignExpr n)
  {
  }

  void visit(MinusAssignExpr n)
  {
  }

  void visit(DivAssignExpr n)
  {
  }

  void visit(MulAssignExpr n)
  {
  }

  void visit(ModAssignExpr n)
  {
  }

  void visit(XorAssignExpr n)
  {
  }

  void visit(CatAssignExpr n)
  {
  }

  void visit(PowAssignExpr n)
  {
  }

  void visit(AddressExpr n)
  {
  }

  void visit(PreIncrExpr n)
  {
  }

  void visit(PreDecrExpr n)
  {
  }

  void visit(PostIncrExpr n)
  {
  }

  void visit(PostDecrExpr n)
  {
  }

  void visit(DerefExpr n)
  {
  }

  void visit(SignExpr n)
  {
  }

  void visit(NotExpr n)
  {
  }

  void visit(CompExpr n)
  {
  }

  void visit(CallExpr n)
  {
  }

  void visit(NewExpr n)
  {
  }

  void visit(NewClassExpr n)
  {
  }

  void visit(DeleteExpr n)
  {
  }

  void visit(CastExpr n)
  {
  }

  void visit(IndexExpr n)
  {
  }

  void visit(SliceExpr n)
  {
  }

  void visit(ModuleScopeExpr n)
  {
  }

  void visit(IdentifierExpr n)
  {
  }

  void visit(SpecialTokenExpr n)
  {
  }

  void visit(TmplInstanceExpr n)
  {
  }

  void visit(ThisExpr n)
  {
  }

  void visit(SuperExpr n)
  {
  }

  void visit(NullExpr n)
  {
  }

  void visit(DollarExpr n)
  {
  }

  void visit(BoolExpr n)
  {
  }

  void visit(IntExpr n)
  {
  }

  void visit(FloatExpr n)
  {
  }

  void visit(ComplexExpr n)
  {
  }

  void visit(CharExpr n)
  {
  }

  void visit(StringExpr n)
  {
  }

  void visit(ArrayLiteralExpr n)
  {
  }

  void visit(AArrayLiteralExpr n)
  {
  }

  void visit(AssertExpr n)
  {
  }

  void visit(MixinExpr n)
  {
  }

  void visit(ImportExpr n)
  {
  }

  void visit(TypeofExpr n)
  {
  }

  void visit(TypeDotIdExpr n)
  {
  }

  void visit(TypeidExpr n)
  {
  }

  void visit(IsExpr n)
  {
  }

  void visit(ParenExpr n)
  {
  }

  void visit(FuncLiteralExpr n)
  {
  }

  void visit(TraitsExpr n)
  {
  }

  void visit(VoidInitExpr n)
  {
  }

  void visit(ArrayInitExpr n)
  {
  }

  void visit(StructInitExpr n)
  {
  }

  void visit(AsmTypeExpr n)
  {
  }

  void visit(AsmOffsetExpr n)
  {
  }

  void visit(AsmSegExpr n)
  {
  }

  void visit(AsmPostBracketExpr n)
  {
  }

  void visit(AsmBracketExpr n)
  {
  }

  void visit(AsmLocalSizeExpr n)
  {
  }

  void visit(AsmRegisterExpr n)
  {
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
    w([T.Typeof, T.LParen]);
    if (n.isTypeofReturn)
      w(T.Return);
    else
      v(n.expr);
    w(T.RParen);
  }

  void visit(TemplateInstanceType n)
  {
    if (n.next) {
      v(n.next);
      w(T.Dot);
    }
    w([n.ident, T.Exclaim, T.LParen]);
    v(n.targs);
    w(T.RParen);
  }

  void visit(PointerType n)
  {
    v(n.next);
    if (!n.next.Is!(CFuncType))
      w(T.Star); // The pointer must be omitted if it's a CFuncType.
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
    w([ws, T.Function]);
    v(n.params);
  }

  void visit(DelegateType n)
  {
    v(n.next);
    w([ws, T.Delegate]);
    v(n.params);
  }

  void visit(CFuncType n)
  {
    v(n.next);
    w([ws, T.Function]);
    v(n.params);
  }

  void visit(BaseClassType n)
  {
    if (auto tok = protToTOK(n.prot))
      w([tok.toToken(), ws]);
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
  }

  void visit(Parameters n)
  {
    w(T.LParen);
    foreach (i, param; n.items())
    {
      if (i)
        w([T.Comma, ws]);
      v(param);
    }
    w(T.RParen);
  }

  void visit(TemplateAliasParam n)
  {
  }

  void visit(TemplateTypeParam n)
  {
  }

  void visit(TemplateThisParam n)
  {
  }

  void visit(TemplateValueParam n)
  {
  }

  void visit(TemplateTupleParam n)
  {
  }

  void visit(TemplateParameters n)
  {
    w(T.LParen);
    foreach (i, param; n.items())
    {
      if (i)
        w([T.Comma, ws]);
      v(param);
    }
    w(T.RParen);
  }

  void visit(TemplateArguments n)
  {
  }
}
