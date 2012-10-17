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
       dil.Diagnostics,
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
    Types,
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
    typeid(TypeNode[]),
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

  void write(TypeNode[] nodes)
  {
    write(cast(Node[])nodes, TID.Types);
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

  /// Generates a list of mixin declarations for all Node classes.
  /// E.g.:
  /// ---
  /// mixin visitX!(CompoundDecl);
  /// mixin visitX!(CompoundStmt);
  /// mixin visitX!(CondExpr);
  /// ---
  static char[] mixinVisitMethods()
  {
    char[] code;
    foreach (name; NodeClassNames)
      code ~= "mixin visitX!(" ~ name ~ ");\n";
    return code;
  }

  mixin(mixinVisitMethods());
}



/// Deserializes a binary AST file.
class ASTDeserializer : Visitor
{
  Token*[] tokens; /// The list of Tokens.
  const(ubyte)* p; /// Current byte.
  const(ubyte)* end; /// One past the last byte.
  Diagnostics diag; /// For error messages.

  /// Constructs an object.
  this(Token*[] tokens, Diagnostics diag)
  {
    this.tokens = tokens;
    this.diag = diag;
  }

  alias ASTSerializer.TID TID;

  /// Reads T.sizeof bytes.
  bool readXB(T)(out T x)
  {
    if (p + T.sizeof > end)
      return false;
    x = *cast(const T*)p;
    p += T.sizeof;
    return true;
  }

  /// Reads 1 byte.
  alias readXB!(ubyte) read1B;

  /// Reads 2 bytes.
  alias readXB!(ushort) read2B;

  /// Reads 4 bytes.
  alias readXB!(uint) read4B;

  /// Reads size_t.sizeof bytes.
  alias readXB!(size_t) readSB;

  /// Creates an error message.
  bool error(cstring msg, ...)
  {
    // TODO:
    return false;
  }

  /// Reads a byte and checks if it equals tid.
  bool check(TID tid)
  {
    ubyte x;
    return read1B(x) && x == tid || error("expected ‘TID.{}’", tid);
  }

  /// Reads a type id.
  bool read(out TID tid)
  {
    return read1B(tid);
  }

  /// Reads the kind of a Node.
  bool read(out NodeKind k)
  {
    return check(TID.NodeKind) && read1B(*cast(ubyte*)&k) &&
           k <= NodeKind.max || error("NodeKind value out of range");
  }

  /// Reads the protection attribute.
  bool read(out Protection prot)
  {
    return check(TID.Protection) && read1B(*cast(ubyte*)&prot) &&
           prot <= Protection.max || error("Protection value out of range");
  }

  /// Reads the StorageClass attribute.
  bool read(out StorageClass stcs)
  {
    return check(TID.StorageClass) && read4B(*cast(uint*)&stcs);
  }

  /// Reads the LinkageType attribute.
  bool read(out LinkageType lnkg)
  {
    return check(TID.LinkageType) && read1B(*cast(ubyte*)&lnkg);
  }

  /// Reads the mangled array type and then each node.
  bool read(ref Node[] nodes, TID tid)
  {
    size_t len;
    if (!check(TID.Array) || !check(tid) || !readSB(len))
      return false;
    nodes = new Node[len];
    foreach (ref n; nodes)
      if (!read(n))
        return false;
    return true;
  }

  bool read(out Node[] nodes)
  {
    return read(nodes, TID.Nodes);
  }

  bool read(out Declaration[] nodes)
  {
    return read(*cast(Node[]*)&nodes, TID.Declarations);
  }

  bool read(out Statement[] nodes)
  {
    return read(*cast(Node[]*)&nodes, TID.Statements);
  }

  bool read(out Expression[] nodes)
  {
    return read(*cast(Node[]*)&nodes, TID.Expressions);
  }

  bool read(out TypeNode[] nodes)
  {
    return read(*cast(Node[]*)&nodes, TID.Types);
  }

  bool read(out Parameter[] nodes)
  {
    return read(*cast(Node[]*)&nodes, TID.Parameters);
  }

  bool read(out TemplateParam[] nodes)
  {
    return read(*cast(Node[]*)&nodes, TID.TemplateParams);
  }

  bool read(out EnumMemberDecl[] nodes)
  {
    return read(*cast(Node[]*)&nodes, TID.EnumMemberDecls);
  }

  bool read(out BaseClassType[] nodes)
  {
    return read(*cast(Node[]*)&nodes, TID.BaseClassTypes);
  }

  bool read(out CatchStmt[] nodes)
  {
    return read(*cast(Node[]*)&nodes, TID.CatchStmts);
  }

  /// Reads a char.
  bool read(out char c)
  {
    return check(TID.Char) && read1B(*cast(ubyte*)&c);
  }

  /// Reads a boolean.
  bool read(out bool b)
  {
    ubyte u;
    auto a = check(TID.Bool) && read1B(u) && u <= 1;
    if (a)
      b = !!u;
    return a;
  }

  /// Reads a uint.
  bool read(out uint u)
  {
    return check(TID.Uint) && read4B(u);
  }

  /// Reads a TOK.
  bool read(out TOK tok)
  {
    return check(TID.TOK) && read2B(tok) && tok <= TOK.max;
  }

  /// Reads a Token.
  bool read(out Token* t)
  {
    size_t index;
    bool b = check(TID.Token) && readSB(index);
    if (b)
      t = index < tokens.length ? tokens[index] : null;
    return b;
  }

  /// Reads an array of Tokens.
  bool read(out Token*[] tokens)
  {
    size_t len;
    if (!check(TID.Tokens) || !readSB(len))
      return false;
    tokens = new Token*[len];
    foreach (ref t; tokens)
      if (!read(t))
        return false;
    return true;
  }

  /// Reads an array of arrays of Tokens.
  bool read(out Token*[][] tokenLists)
  {
    size_t len;
    if (!check(TID.TokenArrays) || !readSB(len))
      return false;
    tokenLists = new Token*[][len];
    foreach (ref tokens; tokenLists)
      if (!read(tokens))
        return false;
    return true;
  }

  bool read(ref Node n)
  {
    TID tid;
    NodeKind kind;
    Token* begin, end;
    if (!read(tid) && tid == TID.Node ||
        !read(kind) ||
        !read(begin) ||
        !read(end))
      goto Lerr;
    n = dispatch(n, kind);
    if (n is null)
      goto Lerr;
    n.setTokens(begin, end);
    return true;
  Lerr:
    return false;
  }

  bool read(out CompoundDecl n)
  {
    return read(*cast(Node*)&n);
  }

  bool read(out CompoundStmt n)
  {
    return read(*cast(Node*)&n);
  }

  bool read(out Declaration n)
  {
    return read(*cast(Node*)&n);
  }

  bool read(out Statement n)
  {
    return read(*cast(Node*)&n);
  }

  bool read(out Expression n)
  {
    return read(*cast(Node*)&n);
  }

  bool read(out TypeNode n)
  {
    return read(*cast(Node*)&n);
  }

  bool read(out TemplateParameters n)
  {
    return read(*cast(Node*)&n);
  }

  bool read(out Parameters n)
  {
    return read(*cast(Node*)&n);
  }

  bool read(out Parameter n)
  {
    return read(*cast(Node*)&n);
  }

  bool read(out FuncBodyStmt n)
  {
    return read(*cast(Node*)&n);
  }

  bool read(out TemplateArguments n)
  {
    return read(*cast(Node*)&n);
  }

  bool read(out FinallyStmt n)
  {
    return read(*cast(Node*)&n);
  }

  Module deserialize(const ubyte[] data)
  {
    p = data.ptr;
    end = data.ptr + data.length;
    Node rootDecl;
    read(rootDecl);
    return null;
  }

  mixin template visitX(N)
  {
    returnType!(N) visit(N n)
    {
      mixin(generateReaders(N._mtypesArray));
      static if (is(N : Declaration))
      {
        StorageClass stcs;
        Protection prot;
        if (!read(stcs) || !read(prot))
          goto Lerr;
        n.setStorageClass(stcs);
        n.setProtection(prot);
      }
      return mixin(generateCtorCall(N._members.length));
    Lerr:
      return null;
    }
  }

  /// Generates e.g.:
  /// ---
  /// Token* _0;
  /// if (!read(_0)) goto Lerr;
  /// Token*[] _1;
  /// if (!read(_1)) goto Lerr;
  /// ---
  static char[] generateReaders(string[] types)
  {
    char[] code;
    foreach (i, t; types)
    {
      const arg = "_" ~ itoactf(i);
      code ~= t ~ " " ~ arg ~ ";\n" ~
        "if (!read(" ~ arg ~ ")) goto Lerr;\n";
    }
    return code;
  }

  /// Generates e.g.: _0, _1, _2
  static char[] generateCtorCall(size_t num)
  {
    char[] code = "new N( ".dup;
    for (size_t i; i < num; i++)
      code ~= "_" ~ itoactf(i) ~ ",";
    code[$-1] = ')';
    return code;
  }

  /// Generates e.g.: mixin visitX!(CompoundDecl);
  static char[] generateMixins()
  {
    char[] code;
    foreach (name; NodeClassNames)
      code ~= "mixin visitX!(" ~ name ~ ");\n";
    return code;
  }

  mixin(generateMixins());
}
