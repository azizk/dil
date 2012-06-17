/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very low)
module dil.ast.ASTSerializer;

import dil.ast.Visitor,
       dil.ast.NodeMembers,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;
import dil.lexer.IdTable;
import dil.semantic.Module;
import dil.Enums,
       dil.String;
import common;

/// Serializes a complete parse tree.
class ASTSerializer : Visitor2
{
  immutable HEADER = "DIL1.0AST\x1A\x04\n"; /// Appears at the start.
  ubyte[] data; /// The binary text.
  size_t[Token*] tokenIndex; /// Maps tokens to index numbers.

  /// An enumeration of types that may appear in the data.
  enum TID : ubyte
  {
    Array = 'A',
    Null,
    Char,
    Bool,
    Uint,
    TOK,
    Protection,
    LinkageType,
    StorageClass,
    NodeKind,
    Node,
    Declaration,
    Statement,
    Expression,
    TypeNode,
    Parameter,
    TemplateParam,
    Nodes,
    Declarations,
    Statements,
    Expressions,
    Parameters,
    TemplateParams,
    EnumMemberDecls,
    BaseClassTypes,
    CatchStmts,
    Token,
    Tokens,
    TokenArrays,
  }

  /// Array of TypeInfos.
  static TypeInfo[TID.max+1] arrayTIs = [
    typeid(void[]),
    typeid(typeof(null)),
    typeid(char),
    typeid(bool),
    typeid(uint),
    typeid(TOK),
    typeid(Protection),
    typeid(LinkageType),
    typeid(StorageClass),
    typeid(NodeKind),
    typeid(Node),
    typeid(Declaration),
    typeid(Statement),
    typeid(Expression),
    typeid(TypeNode),
    typeid(Parameter),
    typeid(TemplateParam),
    typeid(Node[]),
    typeid(Declaration[]),
    typeid(Statement[]),
    typeid(Expression[]),
    typeid(Parameter[]),
    typeid(TemplateParam[]),
    typeid(EnumMemberDecl[]),
    typeid(BaseClassType[]),
    typeid(CatchStmt[]),
    typeid(Token*),
    typeid(Token*[]),
    typeid(Token*[][]),
  ];

  static TypeInfo getTypeInfo(TID tid)
  {
    return arrayTIs[tid - TID.Array];
  }

  this()
  {
  }

  /// Starts serialization.
  ubyte[] serialize(Module mod)
  {
    data ~= HEADER;
    tokenIndex = buildTokenIndex(mod.firstToken());
    visitN(mod.root);
    return data;
  }

  /// Builds a token index from a linked list of Tokens.
  /// The address of a token is mapped to its position index in the list.
  static size_t[Token*] buildTokenIndex(Token* head)
  {
    size_t[Token*] map;
    map[null] = size_t.max;
    size_t index;
    for (auto t = head; t; index++, t = t.next)
      map[t] = index;
    return map;
  }

  /// Returns the index number of a token.
  /// If token is null, 0 is returned.
  size_t indexOf(Token* token)
  {
    return tokenIndex[token];
  }

  /// Writes 1 byte.
  void write1B(ubyte x)
  {
    data ~= x;
  }

  /// Writes T.sizeof bytes.
  void writeXB(T)(T x)
  {
    data ~= (cast(ubyte*)&x)[0..T.sizeof];
  }

  /// Writes 2 bytes.
  alias writeXB!(ushort) write2B;

  /// Writes 4 bytes.
  alias writeXB!(uint) write4B;

  /// Writes size_t.sizeof bytes.
  alias writeXB!(size_t) writeSB;


  /// Writes the kind of a Node.
  void write(NodeKind k)
  {
    static assert(NodeKind.max <= ubyte.max);
    write1B(TID.NodeKind);
    write1B(cast(ubyte)k);
  }

  /// Writes the protection attribute.
  void write(Protection prot)
  {
    static assert(Protection.max <= ubyte.max);
    write1B(TID.Protection);
    write1B(cast(ubyte)prot);
  }

  /// Writes the StorageClass attribute.
  void write(StorageClass stcs)
  {
    static assert(StorageClass.max <= uint.max);
    write1B(TID.StorageClass);
    write4B(cast(uint)stcs);
  }

  /// Writes the LinkageType attribute.
  void write(LinkageType lnkg)
  {
    static assert(LinkageType.max <= ubyte.max);
    write1B(TID.LinkageType);
    write1B(cast(ubyte)lnkg);
  }

  /// Writes a node.
  void write(Node n, TID tid)
  {
    if (n is null) {
      write1B(TID.Null);
      write1B(tid);
    }
    else
      visitN(n);
  }

  void write(Node n)
  {
    write(n, TID.Node);
  }

  void write(Declaration n)
  {
    write(n, TID.Declaration);
  }

  void write(Statement n)
  {
    write(n, TID.Statement);
  }

  void write(Expression n)
  {
    write(n, TID.Expression);
  }

  void write(TypeNode n)
  {
    write(n, TID.TypeNode);
  }

  void write(Parameter n)
  {
    write(n, TID.Parameter);
  }

  void write(TemplateParam n)
  {
    write(n, TID.TemplateParam);
  }

  /// Writes the mangled array type and then visits each node.
  void write(Node[] nodes, TID tid)
  {
    write1B(TID.Array);
    write1B(tid);
    writeSB(nodes.length);
    foreach (n; nodes)
      write(n, tid);
  }

  void write(Node[] nodes)
  {
    write(nodes, TID.Nodes);
  }

  void write(Declaration[] nodes)
  {
    write(cast(Node[])nodes, TID.Declarations);
  }

  void write(Statement[] nodes)
  {
    write(cast(Node[])nodes, TID.Statements);
  }

  void write(Expression[] nodes)
  {
    write(cast(Node[])nodes, TID.Expressions);
  }

  void write(Parameter[] nodes)
  {
    write(cast(Node[])nodes, TID.Parameters);
  }

  void write(TemplateParam[] nodes)
  {
    write(cast(Node[])nodes, TID.TemplateParams);
  }

  void write(EnumMemberDecl[] nodes)
  {
    write(cast(Node[])nodes, TID.EnumMemberDecls);
  }

  void write(BaseClassType[] nodes)
  {
    write(cast(Node[])nodes, TID.BaseClassTypes);
  }

  void write(CatchStmt[] nodes)
  {
    write(cast(Node[])nodes, TID.CatchStmts);
  }

  /// Writes a char.
  void write(char c)
  {
    write1B(TID.Char);
    write1B(c);
  }

  /// Writes a boolean.
  void write(bool b)
  {
    write1B(TID.Bool);
    write1B(b);
  }

  /// Writes a uint.
  void write(uint u)
  {
    write1B(TID.Uint);
    write4B(u);
  }

  /// Writes a TOK.
  void write(TOK tok)
  {
    assert(TOK.max <= ushort.max);
    write1B(TID.TOK);
    write2B(cast(ushort)tok);
  }

  /// Writes a Token.
  void write(Token* t)
  {
    write1B(TID.Token);
    writeSB(indexOf(t));
  }

  /// Writes an array of Tokens.
  void write(Token*[] tokens)
  {
    write1B(TID.Tokens);
    writeSB(tokens.length);
    foreach (t; tokens)
      writeSB(indexOf(t));
  }

  /// Writes an array of arrays of Tokens.
  void write(Token*[][] tokenLists)
  {
    write1B(TID.TokenArrays);
    writeSB(tokenLists.length);
    foreach (tokens; tokenLists)
      write(tokens);
  }

  // Visitor methods:

  /// Generates a visit method for a specific Node.
  mixin template visitX(N)
  {
    void visit(N n)
    {
      alias Array2Tuple!(N._members) Members;
      assert(n);
      write1B(TID.Node);
      write(n.kind);
      write(n.begin);
      write(n.end);
      static if (is(N : Declaration))
      { // Write the attributes of Declarations.
        write(n.stcs);
        write(n.prot);
      }
      assert(Members.length < ubyte.max);
      write1B(Members.length);
      foreach (m; Members)
        write(mixin("n."~m));
    }
  }

  void visit(IllegalDecl n)
  {
    assert(0);
  }

  void visit(IllegalStmt n)
  {
    assert(0);
  }

  void visit(IllegalAsmStmt n)
  {
    assert(0);
  }

  void visit(IllegalExpr n)
  {
    assert(0);
  }

  void visit(IllegalType n)
  {
    assert(0);
  }


  mixin visitX!(CompoundDecl);
  mixin visitX!(EmptyDecl);
  mixin visitX!(ModuleDecl);
  mixin visitX!(ImportDecl);
  mixin visitX!(AliasDecl);
  mixin visitX!(AliasThisDecl);
  mixin visitX!(TypedefDecl);
  mixin visitX!(EnumDecl);
  mixin visitX!(EnumMemberDecl);
  mixin visitX!(TemplateDecl);
  mixin visitX!(ClassDecl);
  mixin visitX!(InterfaceDecl);
  mixin visitX!(StructDecl);
  mixin visitX!(UnionDecl);
  mixin visitX!(ConstructorDecl);
  mixin visitX!(StaticCtorDecl);
  mixin visitX!(DestructorDecl);
  mixin visitX!(StaticDtorDecl);
  mixin visitX!(FunctionDecl);
  mixin visitX!(VariablesDecl);
  mixin visitX!(InvariantDecl);
  mixin visitX!(UnittestDecl);
  mixin visitX!(DebugDecl);
  mixin visitX!(VersionDecl);
  mixin visitX!(StaticIfDecl);
  mixin visitX!(StaticAssertDecl);
  mixin visitX!(NewDecl);
  mixin visitX!(DeleteDecl);
  mixin visitX!(ProtectionDecl);
  mixin visitX!(StorageClassDecl);
  mixin visitX!(LinkageDecl);
  mixin visitX!(AlignDecl);
  mixin visitX!(PragmaDecl);
  mixin visitX!(MixinDecl);

  // Statements:
  mixin visitX!(CompoundStmt);
  mixin visitX!(EmptyStmt);
  mixin visitX!(FuncBodyStmt);
  mixin visitX!(ScopeStmt);
  mixin visitX!(LabeledStmt);
  mixin visitX!(ExpressionStmt);
  mixin visitX!(DeclarationStmt);
  mixin visitX!(IfStmt);
  mixin visitX!(WhileStmt);
  mixin visitX!(DoWhileStmt);
  mixin visitX!(ForStmt);
  mixin visitX!(ForeachStmt);
  mixin visitX!(ForeachRangeStmt);
  mixin visitX!(SwitchStmt);
  mixin visitX!(CaseStmt);
  mixin visitX!(CaseRangeStmt);
  mixin visitX!(DefaultStmt);
  mixin visitX!(ContinueStmt);
  mixin visitX!(BreakStmt);
  mixin visitX!(ReturnStmt);
  mixin visitX!(GotoStmt);
  mixin visitX!(WithStmt);
  mixin visitX!(SynchronizedStmt);
  mixin visitX!(TryStmt);
  mixin visitX!(CatchStmt);
  mixin visitX!(FinallyStmt);
  mixin visitX!(ScopeGuardStmt);
  mixin visitX!(ThrowStmt);
  mixin visitX!(VolatileStmt);
  mixin visitX!(AsmBlockStmt);
  mixin visitX!(AsmStmt);
  mixin visitX!(AsmAlignStmt);
  mixin visitX!(PragmaStmt);
  mixin visitX!(MixinStmt);
  mixin visitX!(StaticIfStmt);
  mixin visitX!(StaticAssertStmt);
  mixin visitX!(DebugStmt);
  mixin visitX!(VersionStmt);

  // Expressions:
  mixin visitX!(CondExpr);
  mixin visitX!(CommaExpr);
  mixin visitX!(OrOrExpr);
  mixin visitX!(AndAndExpr);
  mixin visitX!(OrExpr);
  mixin visitX!(XorExpr);
  mixin visitX!(AndExpr);
  mixin visitX!(EqualExpr);
  mixin visitX!(IdentityExpr);
  mixin visitX!(RelExpr);
  mixin visitX!(InExpr);
  mixin visitX!(LShiftExpr);
  mixin visitX!(RShiftExpr);
  mixin visitX!(URShiftExpr);
  mixin visitX!(PlusExpr);
  mixin visitX!(MinusExpr);
  mixin visitX!(CatExpr);
  mixin visitX!(MulExpr);
  mixin visitX!(DivExpr);
  mixin visitX!(ModExpr);
  mixin visitX!(PowExpr);
  mixin visitX!(AssignExpr);
  mixin visitX!(LShiftAssignExpr);
  mixin visitX!(RShiftAssignExpr);
  mixin visitX!(URShiftAssignExpr);
  mixin visitX!(OrAssignExpr);
  mixin visitX!(AndAssignExpr);
  mixin visitX!(PlusAssignExpr);
  mixin visitX!(MinusAssignExpr);
  mixin visitX!(DivAssignExpr);
  mixin visitX!(MulAssignExpr);
  mixin visitX!(ModAssignExpr);
  mixin visitX!(XorAssignExpr);
  mixin visitX!(CatAssignExpr);
  mixin visitX!(PowAssignExpr);
  mixin visitX!(AddressExpr);
  mixin visitX!(PreIncrExpr);
  mixin visitX!(PreDecrExpr);
  mixin visitX!(PostIncrExpr);
  mixin visitX!(PostDecrExpr);
  mixin visitX!(DerefExpr);
  mixin visitX!(SignExpr);
  mixin visitX!(NotExpr);
  mixin visitX!(CompExpr);
  mixin visitX!(CallExpr);
  mixin visitX!(NewExpr);
  mixin visitX!(NewClassExpr);
  mixin visitX!(DeleteExpr);
  mixin visitX!(CastExpr);
  mixin visitX!(IndexExpr);
  mixin visitX!(SliceExpr);
  mixin visitX!(ModuleScopeExpr);
  mixin visitX!(IdentifierExpr);
  mixin visitX!(SpecialTokenExpr);
  mixin visitX!(TmplInstanceExpr);
  mixin visitX!(ThisExpr);
  mixin visitX!(SuperExpr);
  mixin visitX!(NullExpr);
  mixin visitX!(DollarExpr);
  mixin visitX!(BoolExpr);
  mixin visitX!(IntExpr);
  mixin visitX!(FloatExpr);
  mixin visitX!(ComplexExpr);
  mixin visitX!(CharExpr);
  mixin visitX!(StringExpr);
  mixin visitX!(ArrayLiteralExpr);
  mixin visitX!(AArrayLiteralExpr);
  mixin visitX!(AssertExpr);
  mixin visitX!(MixinExpr);
  mixin visitX!(ImportExpr);
  mixin visitX!(TypeofExpr);
  mixin visitX!(TypeDotIdExpr);
  mixin visitX!(TypeidExpr);
  mixin visitX!(IsExpr);
  mixin visitX!(ParenExpr);
  mixin visitX!(FuncLiteralExpr);
  mixin visitX!(TraitsExpr);
  mixin visitX!(VoidInitExpr);
  mixin visitX!(ArrayInitExpr);
  mixin visitX!(StructInitExpr);
  mixin visitX!(AsmTypeExpr);
  mixin visitX!(AsmOffsetExpr);
  mixin visitX!(AsmSegExpr);
  mixin visitX!(AsmPostBracketExpr);
  mixin visitX!(AsmBracketExpr);
  mixin visitX!(AsmLocalSizeExpr);
  mixin visitX!(AsmRegisterExpr);

  // Types:
  mixin visitX!(IntegralType);
  mixin visitX!(ModuleScopeType);
  mixin visitX!(IdentifierType);
  mixin visitX!(TypeofType);
  mixin visitX!(TemplateInstanceType);
  mixin visitX!(PointerType);
  mixin visitX!(ArrayType);
  mixin visitX!(FunctionType);
  mixin visitX!(DelegateType);
  mixin visitX!(CFuncType);
  mixin visitX!(BaseClassType);
  mixin visitX!(ConstType);
  mixin visitX!(ImmutableType);
  mixin visitX!(InoutType);
  mixin visitX!(SharedType);

  // Parameters:
  mixin visitX!(Parameter);
  mixin visitX!(Parameters);
  mixin visitX!(TemplateAliasParam);
  mixin visitX!(TemplateTypeParam);
  mixin visitX!(TemplateThisParam);
  mixin visitX!(TemplateValueParam);
  mixin visitX!(TemplateTupleParam);
  mixin visitX!(TemplateParameters);
  mixin visitX!(TemplateArguments);
}


class ASTDeserializer
{
  this()
  {

  }

  Module deserialize(const ubyte[] data)
  {
    // TODO: implement
    // When node is constructed:
    // * Set stcs/prot/lnkg; * Set begin/end Nodes
    return null;
  }
}
