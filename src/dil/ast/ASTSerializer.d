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
