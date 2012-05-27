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
import dil.semantic.Module;
import dil.Enums,
       dil.String;
import common;

/// Serializes a complete parse tree.
class ASTSerializer : Visitor2
{
  ubyte[] data; /// The binary text.
  size_t[Token*] tokenIndex; /// Maps tokens to index numbers.

  immutable HEADER = "DIL1.0AST\x1A\x04\n";

  /// Enumeration of array types.
  enum ArrayTID : ubyte
  {
    Declaration,
    Expression,
    Token,
    Tokens,
    EnumMemberDecl,
    BaseClassType,
  }

  /// Array of TypeInfos.
  static TypeInfo[ArrayTID.max+1] arrayTIs = [
    typeid(Declaration),
    typeid(Expression),
    typeid(Token*),
    typeid(Token*[]),
    typeid(EnumMemberDecl),
    typeid(BaseClassType),
  ];

  this()
  {
    data ~= HEADER;
  }

  /// Starts serialization.
  ubyte[] serialize(Module mod)
  {
    visitN(mod.root);
    return data;
  }

  Module deserialize()
  {
    // TODO: implement
    // When node is constructed:
    // * Set stcs/prot/lnkg; * Set begin/end Nodes
    return null;
  }

  /// Returns the index number of a token.
  /// If token is null, 0 is returned.
  size_t indexOf(Token* token)
  {
    return tokenIndex[token];
  }

  /// Writes a string array.
  void write(cstring str)
  {
    data ~= str;
  }

  /// Writes a String.
  void write(const(String) str)
  {
    data ~= str.array;
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
    write1B(cast(ubyte)k);
  }

  /// Writes the protection attribute.
  void write(Protection prot)
  {
    static assert(Protection.max <= ubyte.max);
    write1B(cast(ubyte)prot);
  }

  /// Writes the StorageClass attribute.
  void write(StorageClass stcs)
  {
    static assert(StorageClass.max <= uint.max);
    write4B(cast(uint)stcs);
  }

  /// Writes the LinkageType attribute.
  void write(LinkageType lnkg)
  {
    static assert(LinkageType.max <= ubyte.max);
    write1B(cast(ubyte)lnkg);
  }

  /// Writes a node.
  void write(Node n)
  {
    visitN(n);
  }

  /// Writes the mangled array type and then visits each node.
  void visitNodes(N)(N[] nodes, ArrayTID tid)
  {
    write("A");
    write1B(tid);
    write("L");
    writeSB(nodes.length);
    foreach (n; nodes)
      visitN(n);
  }

  void write(Declaration[] nodes)
  {
    visitNodes(nodes, ArrayTID.Declaration);
  }

  void write(Expression[] nodes)
  {
    visitNodes(nodes, ArrayTID.Expression);
  }

  void write(EnumMemberDecl[] nodes)
  {
    visitNodes(nodes, ArrayTID.EnumMemberDecl);
  }

  void write(BaseClassType[] nodes)
  {
    visitNodes(nodes, ArrayTID.BaseClassType);
  }

  /// Writes a boolean.
  void write(bool b)
  {
    write("B");
    write1B(b);
  }

  /// Writes a Token.
  void write(Token* t)
  {
    write("T");
    writeSB(indexOf(t));
  }

  /// Writes an array of Tokens.
  void write(Token*[] tokens)
  {
    write("A");
    write1B(ArrayTID.Token);
    write("L");
    writeSB(tokens.length);
    foreach (t; tokens)
      writeSB(indexOf(t));
  }

  /// Writes an array of arrays of Tokens.
  void write(Token*[][] tokenLists)
  {
    write("A");
    write1B(ArrayTID.Tokens);
    write("L");
    writeSB(tokenLists.length);
    foreach (tokens; tokenLists)
      write(tokenLists);
  }

  /// Calls write() on each member.
  void writeMembers(N, Members...)(N n)
  {
    write("N");
    write(n.kind);
    foreach (m; Members)
      write(mixin("n."~m));
  }

  // Visitor methods:

  mixin template visitX(N, Members...)
  {
    void visit(N n)
    {
      writeMembers!(N, Members)(n);
    }
  }

  void visit(IllegalDecl n)
  {
    assert(0);
  }

  // TODO: what if we could pass a delegate to avoid string mixins?
  //mixin visitX!(XYZ, n => Tuple!(n.name, n.decls));

  mixin visitX!(CompoundDecl, "decls");
  mixin visitX!(EmptyDecl);
  mixin visitX!(ModuleDecl, "typeIdent"/+, n.packages ~ n.moduleName+/);
  mixin visitX!(ImportDecl, "moduleFQNs", "moduleAliases", "bindNames",
    "bindAliases", "isStatic");
  mixin visitX!(AliasDecl, "decl");
  mixin visitX!(AliasThisDecl, "ident");
  mixin visitX!(TypedefDecl, "decl");
  mixin visitX!(EnumDecl, "name", "baseType", "members", "hasBody");
  mixin visitX!(EnumMemberDecl, "type", "name", "value");
  mixin visitX!(ClassDecl, "name", "bases", "decls");
  mixin visitX!(StructDecl, /+alignSize, +/"name", "decls");
  mixin visitX!(UnionDecl, "name", "decls");
  mixin visitX!(ConstructorDecl, "params", "funcBody");
  mixin visitX!(StaticCtorDecl, "funcBody");
  mixin visitX!(DestructorDecl, "funcBody");
  mixin visitX!(StaticDtorDecl, "funcBody");
  mixin visitX!(FunctionDecl, "returnType", "name", "params", "funcBody");
  mixin visitX!(VariablesDecl, "typeNode", "names", "inits");
  mixin visitX!(InvariantDecl, "funcBody");
  mixin visitX!(UnittestDecl, "funcBody");
  mixin visitX!(DebugDecl, "spec", "cond", "decls", "elseDecls");
  mixin visitX!(VersionDecl, "spec", "cond", "decls", "elseDecls");
  mixin visitX!(StaticIfDecl, "condition", "ifDecls", "elseDecls");
  mixin visitX!(StaticAssertDecl, "condition", "message");
  mixin visitX!(TemplateDecl, "name", "tparams", "constraint", "decls");
  mixin visitX!(NewDecl, "params", "funcBody");
  mixin visitX!(DeleteDecl, "params", "funcBody");
  mixin visitX!(ProtectionDecl, "prot", "decls");
  mixin visitX!(StorageClassDecl, "stcs", "decls");
  mixin visitX!(LinkageDecl, "linkageType", "decls");

  mixin visitX!(AlignDecl, "sizetok", "decls");
  mixin visitX!(PragmaDecl, "ident", "args", "decls");
  mixin visitX!(MixinDecl, "templateExpr", "mixinIdent", "argument");

  alias super.visit visit;

  // Statements:
  // TODO:

  // Expressions:
  // TODO:

  // Types:
  // TODO:

  // Parameters:
  // TODO:
}
