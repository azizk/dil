/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.SyntaxTree;
import dil.Token;
import common;

enum NodeCategory
{
  Declaration,
  Statement,
  Expression,
  Type,
  Other
}

enum NodeKind
{
  // Declarations:
  Declarations,
  EmptyDeclaration,
  IllegalDeclaration,
  ModuleDeclaration,
  ImportDeclaration,
  AliasDeclaration,
  TypedefDeclaration,
  EnumDeclaration,
  ClassDeclaration,
  InterfaceDeclaration,
  StructDeclaration,
  UnionDeclaration,
  ConstructorDeclaration,
  StaticConstructorDeclaration,
  DestructorDeclaration,
  StaticDestructorDeclaration,
  FunctionDeclaration,
  VariableDeclaration,
  InvariantDeclaration,
  UnittestDeclaration,
  DebugDeclaration,
  VersionDeclaration,
  StaticIfDeclaration,
  StaticAssertDeclaration,
  TemplateDeclaration,
  NewDeclaration,
  DeleteDeclaration,
  AttributeDeclaration,
  ProtectionDeclaration,
  StorageClassDeclaration,
  LinkageDeclaration,
  AlignDeclaration,
  PragmaDeclaration,
  MixinDeclaration,

  // Statements:
  Statements,
  IllegalStatement,
  EmptyStatement,
  ScopeStatement,
  LabeledStatement,
  ExpressionStatement,
  DeclarationStatement,
  IfStatement,
  ConditionalStatement,
  WhileStatement,
  DoWhileStatement,
  ForStatement,
  ForeachStatement,
  ForeachRangeStatement, // D2.0
  SwitchStatement,
  CaseStatement,
  DefaultStatement,
  ContinueStatement,
  BreakStatement,
  ReturnStatement,
  GotoStatement,
  WithStatement,
  SynchronizedStatement,
  TryStatement,
  CatchBody,
  FinallyBody,
  ScopeGuardStatement,
  ThrowStatement,
  VolatileStatement,
  AsmStatement,
  AsmInstruction,
  AsmAlignStatement,
  IllegalAsmInstruction,
  PragmaStatement,
  MixinStatement,
  StaticIfStatement,
  StaticAssertStatement,
  DebugStatement,
  VersionStatement,

  // Expressions:
  EmptyExpression,
  BinaryExpression,
  CondExpression,
  CommaExpression,
  OrOrExpression,
  AndAndExpression,
  OrExpression,
  XorExpression,
  AndExpression,
  CmpExpression,
  EqualExpression,
  IdentityExpression,
  RelExpression,
  InExpression,
  LShiftExpression,
  RShiftExpression,
  URShiftExpression,
  PlusExpression,
  MinusExpression,
  CatExpression,
  MulExpression,
  DivExpression,
  ModExpression,
  AssignExpression,
  LShiftAssignExpression,
  RShiftAssignExpression,
  URShiftAssignExpression,
  OrAssignExpression,
  AndAssignExpression,
  PlusAssignExpression,
  MinusAssignExpression,
  DivAssignExpression,
  MulAssignExpression,
  ModAssignExpression,
  XorAssignExpression,
  CatAssignExpression,
  UnaryExpression,
  AddressExpression,
  PreIncrExpression,
  PreDecrExpression,
  PostIncrExpression,
  PostDecrExpression,
  DerefExpression,
  SignExpression,
  NotExpression,
  CompExpression,
  PostDotListExpression,
  CallExpression,
  NewExpression,
  NewAnonClassExpression,
  DeleteExpression,
  CastExpression,
  IndexExpression,
  SliceExpression,
  PrimaryExpressio,
  IdentifierExpression,
  SpecialTokenExpression,
  DotExpression,
  DotListExpression,
  TemplateInstanceExpression,
  ThisExpression,
  SuperExpression,
  NullExpression,
  DollarExpression,
  BoolExpression,
  IntExpression,
  RealExpression,
  ComplexExpression,
  CharExpression,
  StringExpression,
  ArrayLiteralExpression,
  AArrayLiteralExpression,
  AssertExpression,
  MixinExpression,
  ImportExpression,
  TypeofExpression,
  TypeDotIdExpression,
  TypeidExpression,
  IsExpression,
  FunctionLiteralExpression,
  TraitsExpression, // D2.0
  VoidInitializer,
  ArrayInitializer,
  StructInitializer,
  AsmTypeExpression,
  AsmOffsetExpression,
  AsmSegExpression,
  AsmPostBracketExpression,
  AsmBracketExpression,
  AsmLocalSizeExpression,
  AsmRegisterExpression,

  // Types:
  IntegralType,
  UndefinedType,
  DotType,
  DotListType,
  IdentifierType,
  TypeofType,
  TemplateInstanceType,
  PointerType,
  ArrayType,
  FunctionType,
  DelegateType,
  CFuncPointerType,
  ConstType, // D2.0
  InvariantType, // D2.0

  // Other:
  FunctionBody,
  Parameter,
  Parameters,
  BaseClass,
  TemplateAliasParameter,
  TemplateTypeParameter,
  TemplateThisParameter, // D2.0
  TemplateValueParameter,
  TemplateTupleParameter,
  TemplateParameters,
  TemplateArguments,
  EnumMember,
}

/// This string is mixed into the constructor of a class that inherits from Node.
const string set_kind = `this.kind = mixin("NodeKind." ~ typeof(this).stringof);`;

Class TryCast(Class)(Node n)
{
  assert(n !is null);
  if (n.kind == mixin("NodeKind." ~ typeof(Class).stringof))
    return cast(Class)cast(void*)n;
  return null;
}

Class CastTo(Class)(Node n)
{
  assert(n !is null && n.kind == mixin("NodeKind." ~ typeof(Class).stringof));
  return cast(Class)cast(void*)n;
}

class Node
{
  NodeCategory category;
  NodeKind kind;
  Node[] children;
  Token* begin, end;

  this(NodeCategory category)
  {
    this.category = category;
  }

  void setTokens(Token* begin, Token* end)
  {
    this.begin = begin;
    this.end = end;
  }

  Class setToks(Class)(Class node)
  {
    node.setTokens(this.begin, this.end);
    return node;
  }

  void addChild(Node child)
  {
    assert(child !is null, "failed in " ~ this.classinfo.name);
    this.children ~= child;
  }

  void addOptChild(Node child)
  {
    child is null || addChild(child);
  }

  void addChildren(Node[] children)
  {
    assert(children !is null && delegate{
      foreach (child; children)
        if (child is null)
          return false;
      return true; }(),
      "failed in " ~ this.classinfo.name
    );
    this.children ~= children;
  }

  void addOptChildren(Node[] children)
  {
    children is null || addChildren(children);
  }
}
