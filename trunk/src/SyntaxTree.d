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
  Expression,
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
}

/// This string is mixed in into the constructor of a class that inherits from Node.
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
