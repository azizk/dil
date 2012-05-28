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
  ubyte[] data; /// The binary text.
  size_t[Token*] tokenIndex; /// Maps tokens to index numbers.

  immutable HEADER = "DIL1.0AST\x1A\x04\n";

  /// Enumeration of array types.
  enum ArrayTID : ubyte
  {
    Node,
    Declaration,
    Statement,
    Expression,
    Parameter,
    TemplateParam,
    Token,
    Tokens,
    EnumMemberDecl,
    BaseClassType,
    CatchStmt,
  }

  /// Array of TypeInfos.
  static TypeInfo[ArrayTID.max+1] arrayTIs = [
    typeid(Node),
    typeid(Declaration),
    typeid(Statement),
    typeid(Expression),
    typeid(Parameter),
    typeid(TemplateParam),
    typeid(Token*),
    typeid(Token*[]),
    typeid(EnumMemberDecl),
    typeid(BaseClassType),
    typeid(CatchStmt),
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

  void write(Node[] nodes)
  {
    visitNodes(nodes, ArrayTID.Node);
  }

  void write(Declaration[] nodes)
  {
    visitNodes(nodes, ArrayTID.Declaration);
  }

  void write(Statement[] nodes)
  {
    visitNodes(nodes, ArrayTID.Statement);
  }

  void write(Expression[] nodes)
  {
    visitNodes(nodes, ArrayTID.Expression);
  }

  void write(Parameter[] nodes)
  {
    visitNodes(nodes, ArrayTID.Parameter);
  }

  void write(TemplateParam[] nodes)
  {
    visitNodes(nodes, ArrayTID.TemplateParam);
  }

  void write(EnumMemberDecl[] nodes)
  {
    visitNodes(nodes, ArrayTID.EnumMemberDecl);
  }

  void write(BaseClassType[] nodes)
  {
    visitNodes(nodes, ArrayTID.BaseClassType);
  }

  void write(CatchStmt[] nodes)
  {
    visitNodes(nodes, ArrayTID.CatchStmt);
  }

  /// Writes a boolean.
  void write(bool b)
  {
    write("B");
    write1B(b);
  }

  /// Writes a TOK.
  void write(TOK tok)
  {
    assert(TOK.max <= ushort.max);
    write2B(cast(ushort)tok);
  }

  /// Writes a char.
  void write(char c)
  {
    write1B(c);
  }

  /// Writes an Identifier.
  void write(Identifier* id)
  {
    write("I");
    writeSB(id.str.length);
    write(id.str);
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
  mixin visitX!(CompoundStmt, "stmnts");
  mixin visitX!(EmptyStmt);
  mixin visitX!(FuncBodyStmt, "funcBody", "inBody", "outBody", "outIdent");
  mixin visitX!(ScopeStmt, "stmnt");
  mixin visitX!(LabeledStmt, "label", "stmnt");
  mixin visitX!(ExpressionStmt, "expr");
  mixin visitX!(DeclarationStmt, "decl");
  mixin visitX!(IfStmt, "variable", "condition", "ifBody", "elseBody");
  mixin visitX!(WhileStmt, "condition", "whileBody");
  mixin visitX!(DoWhileStmt, "condition", "doBody");
  mixin visitX!(ForStmt, "init", "condition", "increment", "forBody");
  mixin visitX!(ForeachStmt, "tok", "params", "aggregate", "forBody");
  mixin visitX!(ForeachRangeStmt, "tok", "params", "lower", "upper", "forBody");
  mixin visitX!(SwitchStmt, "condition", "switchBody", "isFinal");
  mixin visitX!(CaseStmt, "values", "caseBody");
  mixin visitX!(CaseRangeStmt, "left", "right", "caseBody");
  mixin visitX!(DefaultStmt, "defaultBody");
  mixin visitX!(ContinueStmt, "ident");
  mixin visitX!(BreakStmt, "ident");
  mixin visitX!(ReturnStmt, "expr");
  mixin visitX!(GotoStmt, "ident", "expr");
  mixin visitX!(WithStmt, "expr", "withBody");
  mixin visitX!(SynchronizedStmt, "expr", "syncBody");
  mixin visitX!(TryStmt, "tryBody", "catchBodies", "finallyBody");
  mixin visitX!(CatchStmt, "param", "catchBody");
  mixin visitX!(FinallyStmt, "finallyBody");
  mixin visitX!(ScopeGuardStmt, "condition", "scopeBody");
  mixin visitX!(ThrowStmt, "expr");
  mixin visitX!(VolatileStmt, "volatileBody");
  mixin visitX!(AsmBlockStmt, "statements");
  mixin visitX!(AsmStmt, "ident", "operands");
  mixin visitX!(AsmAlignStmt, "numtok");
  mixin visitX!(PragmaStmt, "ident", "args", "pragmaBody");
  mixin visitX!(MixinStmt, "templateExpr", "mixinIdent");
  mixin visitX!(StaticIfStmt, "condition", "ifBody", "elseBody");
  mixin visitX!(StaticAssertStmt, "condition", "message");
  mixin visitX!(DebugStmt, "cond", "mainBody", "elseBody");
  mixin visitX!(VersionStmt, "cond", "mainBody", "elseBody");

  // Expressions:
  mixin visitX!(CondExpr, "lhs", "rhs", "optok", "ctok");
  mixin visitX!(CommaExpr, "lhs", "rhs", "optok");
  mixin visitX!(OrOrExpr, "lhs", "rhs", "optok");
  mixin visitX!(AndAndExpr, "lhs", "rhs", "optok");
  mixin visitX!(OrExpr, "lhs", "rhs", "optok");
  mixin visitX!(XorExpr, "lhs", "rhs", "optok");
  mixin visitX!(AndExpr, "lhs", "rhs", "optok");
  mixin visitX!(EqualExpr, "lhs", "rhs", "optok");
  mixin visitX!(IdentityExpr, "lhs", "rhs", "optok");
  mixin visitX!(RelExpr, "lhs", "rhs", "optok");
  mixin visitX!(InExpr, "lhs", "rhs", "optok");
  mixin visitX!(LShiftExpr, "lhs", "rhs", "optok");
  mixin visitX!(RShiftExpr, "lhs", "rhs", "optok");
  mixin visitX!(URShiftExpr, "lhs", "rhs", "optok");
  mixin visitX!(PlusExpr, "lhs", "rhs", "optok");
  mixin visitX!(MinusExpr, "lhs", "rhs", "optok");
  mixin visitX!(CatExpr, "lhs", "rhs", "optok");
  mixin visitX!(MulExpr, "lhs", "rhs", "optok");
  mixin visitX!(DivExpr, "lhs", "rhs", "optok");
  mixin visitX!(ModExpr, "lhs", "rhs", "optok");
  mixin visitX!(PowExpr, "lhs", "rhs", "optok");
  mixin visitX!(AssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(LShiftAssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(RShiftAssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(URShiftAssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(OrAssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(AndAssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(PlusAssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(MinusAssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(DivAssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(MulAssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(ModAssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(XorAssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(CatAssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(PowAssignExpr, "lhs", "rhs", "optok");
  mixin visitX!(AddressExpr, "una");
  mixin visitX!(PreIncrExpr, "una");
  mixin visitX!(PreDecrExpr, "una");
  mixin visitX!(PostIncrExpr, "una");
  mixin visitX!(PostDecrExpr, "una");
  mixin visitX!(DerefExpr, "una");
  mixin visitX!(SignExpr, "una");
  mixin visitX!(NotExpr, "una");
  mixin visitX!(CompExpr, "una");
  mixin visitX!(CallExpr, "una", "args");
  mixin visitX!(NewExpr, "frame", "newArgs", "type", "ctorArgs");
  mixin visitX!(NewClassExpr, "frame", "newArgs", "bases", "ctorArgs", "decls");
  mixin visitX!(DeleteExpr, "una");
  mixin visitX!(CastExpr, "type", "una");
  mixin visitX!(IndexExpr, "una", "args");
  mixin visitX!(SliceExpr, "una", "left", "right");
  mixin visitX!(ModuleScopeExpr);
  mixin visitX!(IdentifierExpr, "next", "ident");
  mixin visitX!(SpecialTokenExpr, "specialToken");
  mixin visitX!(TmplInstanceExpr, "next", "ident", "targs");
  mixin visitX!(ThisExpr);
  mixin visitX!(SuperExpr);
  mixin visitX!(NullExpr);
  mixin visitX!(DollarExpr);
  mixin visitX!(BoolExpr, "toBool");
  mixin visitX!(IntExpr, "begin"); // TODO: add method that returns begin?
  mixin visitX!(FloatExpr, "begin");
  mixin visitX!(ComplexExpr, "begin");
  mixin visitX!(CharExpr, "begin");
  mixin visitX!(StringExpr, "tokens");
  mixin visitX!(ArrayLiteralExpr, "values");
  mixin visitX!(AArrayLiteralExpr, "keys", "values");
  mixin visitX!(AssertExpr, "expr", "msg");
  mixin visitX!(MixinExpr, "expr");
  mixin visitX!(ImportExpr, "expr");
  mixin visitX!(TypeofExpr, "type");
  mixin visitX!(TypeDotIdExpr, "type");
  mixin visitX!(TypeidExpr, "type");
  mixin visitX!(IsExpr, "type", "ident", "opTok", "specTok", "specType",
    "tparams");
  mixin visitX!(ParenExpr, "next");
  mixin visitX!(FuncLiteralExpr, "returnType", "params", "funcBody");
  mixin visitX!(TraitsExpr, "ident", "targs");
  mixin visitX!(VoidInitExpr);
  mixin visitX!(ArrayInitExpr, "keys", "values");
  mixin visitX!(StructInitExpr, "idents", "values");
  mixin visitX!(AsmTypeExpr, "una");
  mixin visitX!(AsmOffsetExpr, "una");
  mixin visitX!(AsmSegExpr, "una");
  mixin visitX!(AsmPostBracketExpr, "una", "index");
  mixin visitX!(AsmBracketExpr, "expr");
  mixin visitX!(AsmLocalSizeExpr);
  mixin visitX!(AsmRegisterExpr, "register", "number");

  // Types:
  mixin visitX!(IntegralType, "tok");
  mixin visitX!(ModuleScopeType);
  mixin visitX!(IdentifierType, "next", "ident");
  mixin visitX!(TypeofType, "expr");
  mixin visitX!(TemplateInstanceType, "next", "ident", "targs");
  mixin visitX!(PointerType, "next");
  mixin visitX!(ArrayType, "next", "index1", "index2", "assocType");
  mixin visitX!(FunctionType, "returnType", "params");
  mixin visitX!(DelegateType, "returnType", "params");
  mixin visitX!(CFuncType, "next", "params");
  mixin visitX!(BaseClassType, "prot", "next");
  mixin visitX!(ConstType, "next");
  mixin visitX!(ImmutableType, "next");
  mixin visitX!(InoutType, "next");
  mixin visitX!(SharedType, "next");

  // Parameters:
  mixin visitX!(Parameter, "stcs", "stok", "type", "name", "defValue");
  mixin visitX!(Parameters, "items");
  mixin visitX!(TemplateAliasParam, "name", "spec", "def");
  mixin visitX!(TemplateTypeParam, "name", "specType", "defType");
  mixin visitX!(TemplateThisParam, "name", "specType", "defType");
  mixin visitX!(TemplateValueParam, "valueType", "name", "specValue", "defValue");
  mixin visitX!(TemplateTupleParam, "name");
  mixin visitX!(TemplateParameters, "items");
  mixin visitX!(TemplateArguments, "items");
}
