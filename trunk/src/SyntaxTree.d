/++
  Author: Aziz Köksal
  License: GPL3
+/
module SyntaxTree;
import Token;

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
  ExternDeclaration,
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
  IllegalAsmInstruction,
  PragmaStatement,
  MixinStatement,
  StaticIfStatement,
  StaticAssertStatement,
  DebugStatement,
  VersionStatement,
  AttributeStatement,
  ExternStatement,

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
  DotListExpression,
  TemplateInstanceExpression,
  ThisExpression,
  SuperExpression,
  NullExpression,
  DollarExpression,
  BoolExpression,
  IntNumberExpression,
  RealNumberExpression,
  CharLiteralExpression,
  StringLiteralsExpression,
  ArrayLiteralExpression,
  AssocArrayLiteralExpression,
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

  // Types:
  IntegralType,
  UndefinedType,
  DotListType,
  IdentifierType,
  TypeofType,
  TemplateInstanceType,
  PointerType,
  ArrayType,
  FunctionType,
  DelegateType,
  ConstType, // D2.0
  InvariantType, // D2.0

  // Other:
  FunctionBody,
  Parameter,
  Parameters,
  BaseClass,
  TemplateParameter,
  TemplateParameters,
  TemplateArguments,
}

/// This string is mixed into the constructor of a class that inherits from Node.
const string set_kind = `this.kind = mixin("NodeKind." ~ typeof(this).stringof);`;

class Node
{
  NodeCategory category;
  NodeKind kind;
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
}
