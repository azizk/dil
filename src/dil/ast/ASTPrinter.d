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
  void write(Token* b, Token* e)
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

  void visit(IllegalDecl n)
  {
    if (n.begin && n.end)
      w(n.begin, n.end);
  }

  void visit(CompoundDecl n)
  {
    w([T.LBrace, Newline]);
    // TODO: inc indent
    foreach (x; n.decls)
      v(x);
    w([Newline, T.RBrace]);
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
    w([T.Semicolon, Newline]);
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
    w([Newline, T.LBrace]);
    // TODO: increase indentation
    foreach (m; n.members) {
      v(m);
      w([T.Comma, Newline]);
    }
    w([T.RBrace, Newline]);
  }

  void visit(EnumMemberDecl n)
  {
    if (n.type) {
      v(n.type);
      w(ws);
    }
    w(n.name);
    if (n.value) {
      w([ws, T.Equal, ws]);
      v(n.value);
    }
    w([T.Comma, Newline]);
  }


  void visit(TemplateDecl n)
  {
    if (n.isMixin)
      w([T.Mixin, ws]);
    w([T.Template, ws, n.name]);
    v(n.tparams);
    if (n.constraint)
    {
      w([ws, T.If, T.LParen]);
      v(n.constraint);
      w([T.RParen]);
    }
    w(Newline);
    // TODO: inc indent
    v(n.decls);
    w(Newline);
  }

  void visit(ClassDecl n)
  {
    w([T.Class, ws, n.name]);
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
    if (n.decls) {
      w(Newline);
      v(n.decls);
    }
    else
      w(T.Semicolon);
    w(Newline);
  }

  void visit(InterfaceDecl n)
  {
    w([T.Interface, ws, n.name]);
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
    if (n.decls) {
      w(Newline);
      v(n.decls);
    }
    else
      w(T.Semicolon);
    w(Newline);
  }

  void visit(StructDecl n)
  {
    w(T.Struct);
    if (n.name)
      w([ws, n.name]);
    if (n.decls) {
      w(Newline);
      v(n.decls);
    }
    else
      w(T.Semicolon);
    w(Newline);
  }

  void visit(UnionDecl n)
  {
    w(T.Union);
    if (n.name)
      w([ws, n.name]);
    if (n.decls) {
      w(Newline);
      v(n.decls);
    }
    else
      w(T.Semicolon);
    w(Newline);
  }

  void visit(ConstructorDecl n)
  {
    w(T.This);
    v(n.params);
    w(Newline);
    v(n.funcBody);
  }

  void visit(StaticCtorDecl n)
  {
    w([T.Static, ws, T.This, T.LParen, T.RParen, Newline]);
    v(n.funcBody);
  }

  void visit(DestructorDecl n)
  {
    w([T.Tilde, T.This, T.LParen, T.RParen, Newline]);
    v(n.funcBody);
  }

  void visit(StaticDtorDecl n)
  {
    w([T.Static, ws, T.Tilde, T.This, T.LParen, T.RParen, Newline]);
    v(n.funcBody);
  }

  void visit(FunctionDecl n)
  {
  }

  void visit(VariablesDecl n)
  {
  }

  void visit(InvariantDecl n)
  {
  }

  void visit(UnittestDecl n)
  {
  }

  void visit(DebugDecl n)
  {
  }

  void visit(VersionDecl n)
  {
  }

  void visit(StaticIfDecl n)
  {
  }

  void visit(StaticAssertDecl n)
  {
  }

  void visit(NewDecl n)
  {
  }

  void visit(DeleteDecl n)
  {
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
 // D2.0
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
 // D2
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
 // D2
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
 // D2.0
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
  }

  void visit(IntegralType n)
  {
  }

  void visit(ModuleScopeType n)
  {
  }

  void visit(IdentifierType n)
  {
  }

  void visit(TypeofType n)
  {
  }

  void visit(TemplateInstanceType n)
  {
  }

  void visit(PointerType n)
  {
  }

  void visit(ArrayType n)
  {
  }

  void visit(FunctionType n)
  {
  }

  void visit(DelegateType n)
  {
  }

  void visit(CFuncType n)
  {
  }

  void visit(BaseClassType n)
  {
  }

  void visit(ConstType n)
  {
  }
 // D2.0
  void visit(ImmutableType n)
  {
  }
 // D2.0
  void visit(InoutType n)
  {
  }
 // D2.0
  void visit(SharedType n)
  {
  }
 // D2.0

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
 // D2.0
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
