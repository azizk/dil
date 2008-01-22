/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.NodesEnum;

enum NodeCategory : ushort
{
  Undefined,
  Declaration,
  Statement,
  Expression,
  Type,
  Other
}

/// Array of class names that inherit from Node.
static const char[][] classNames = [
  // Declarations:
  "CompoundDeclaration",
  "EmptyDeclaration",
  "IllegalDeclaration",
  "ModuleDeclaration",
  "ImportDeclaration",
  "AliasDeclaration",
  "TypedefDeclaration",
  "EnumDeclaration",
  "EnumMemberDeclaration",
  "ClassDeclaration",
  "InterfaceDeclaration",
  "StructDeclaration",
  "UnionDeclaration",
  "ConstructorDeclaration",
  "StaticConstructorDeclaration",
  "DestructorDeclaration",
  "StaticDestructorDeclaration",
  "FunctionDeclaration",
  "VariablesDeclaration",
  "InvariantDeclaration",
  "UnittestDeclaration",
  "DebugDeclaration",
  "VersionDeclaration",
  "StaticIfDeclaration",
  "StaticAssertDeclaration",
  "TemplateDeclaration",
  "NewDeclaration",
  "DeleteDeclaration",
  "ProtectionDeclaration",
  "StorageClassDeclaration",
  "LinkageDeclaration",
  "AlignDeclaration",
  "PragmaDeclaration",
  "MixinDeclaration",

  // Statements:
  "CompoundStatement",
  "IllegalStatement",
  "EmptyStatement",
  "FuncBodyStatement",
  "ScopeStatement",
  "LabeledStatement",
  "ExpressionStatement",
  "DeclarationStatement",
  "IfStatement",
  "WhileStatement",
  "DoWhileStatement",
  "ForStatement",
  "ForeachStatement",
  "ForeachRangeStatement", // D2.0
  "SwitchStatement",
  "CaseStatement",
  "DefaultStatement",
  "ContinueStatement",
  "BreakStatement",
  "ReturnStatement",
  "GotoStatement",
  "WithStatement",
  "SynchronizedStatement",
  "TryStatement",
  "CatchStatement",
  "FinallyStatement",
  "ScopeGuardStatement",
  "ThrowStatement",
  "VolatileStatement",
  "AsmBlockStatement",
  "AsmStatement",
  "AsmAlignStatement",
  "IllegalAsmStatement",
  "PragmaStatement",
  "MixinStatement",
  "StaticIfStatement",
  "StaticAssertStatement",
  "DebugStatement",
  "VersionStatement",

  // Expressions:
  "IllegalExpression",
  "CondExpression",
  "CommaExpression",
  "OrOrExpression",
  "AndAndExpression",
  "OrExpression",
  "XorExpression",
  "AndExpression",
  "EqualExpression",
  "IdentityExpression",
  "RelExpression",
  "InExpression",
  "LShiftExpression",
  "RShiftExpression",
  "URShiftExpression",
  "PlusExpression",
  "MinusExpression",
  "CatExpression",
  "MulExpression",
  "DivExpression",
  "ModExpression",
  "AssignExpression",
  "LShiftAssignExpression",
  "RShiftAssignExpression",
  "URShiftAssignExpression",
  "OrAssignExpression",
  "AndAssignExpression",
  "PlusAssignExpression",
  "MinusAssignExpression",
  "DivAssignExpression",
  "MulAssignExpression",
  "ModAssignExpression",
  "XorAssignExpression",
  "CatAssignExpression",
  "AddressExpression",
  "PreIncrExpression",
  "PreDecrExpression",
  "PostIncrExpression",
  "PostDecrExpression",
  "DerefExpression",
  "SignExpression",
  "NotExpression",
  "CompExpression",
  "CallExpression",
  "NewExpression",
  "NewAnonClassExpression",
  "DeleteExpression",
  "CastExpression",
  "IndexExpression",
  "SliceExpression",
  "ModuleScopeExpression",
  "IdentifierExpression",
  "SpecialTokenExpression",
  "DotExpression",
  "TemplateInstanceExpression",
  "ThisExpression",
  "SuperExpression",
  "NullExpression",
  "DollarExpression",
  "BoolExpression",
  "IntExpression",
  "RealExpression",
  "ComplexExpression",
  "CharExpression",
  "StringExpression",
  "ArrayLiteralExpression",
  "AArrayLiteralExpression",
  "AssertExpression",
  "MixinExpression",
  "ImportExpression",
  "TypeofExpression",
  "TypeDotIdExpression",
  "TypeidExpression",
  "IsExpression",
  "ParenExpression",
  "FunctionLiteralExpression",
  "TraitsExpression", // D2.0
  "VoidInitExpression",
  "ArrayInitExpression",
  "StructInitExpression",
  "AsmTypeExpression",
  "AsmOffsetExpression",
  "AsmSegExpression",
  "AsmPostBracketExpression",
  "AsmBracketExpression",
  "AsmLocalSizeExpression",
  "AsmRegisterExpression",

  // Types:
  "IllegalType",
  "IntegralType",
  "QualifiedType",
  "ModuleScopeType",
  "IdentifierType",
  "TypeofType",
  "TemplateInstanceType",
  "PointerType",
  "ArrayType",
  "FunctionType",
  "DelegateType",
  "CFuncPointerType",
  "BaseClassType",
  "ConstType", // D2.0
  "InvariantType", // D2.0

  // Other:
  "Parameter",
  "Parameters",
  "TemplateAliasParameter",
  "TemplateTypeParameter",
  "TemplateThisParameter", // D2.0
  "TemplateValueParameter",
  "TemplateTupleParameter",
  "TemplateParameters",
  "TemplateArguments",
];

char[] generateNodeKindMembers()
{
  char[] text;
  foreach (className; classNames)
    text ~= className ~ ",";
  return text;
}
// pragma(msg, generateNodeKindMembers());

// enum NodeKind;
mixin(
  "enum NodeKind : ushort"
  "{"
    ~ generateNodeKindMembers ~
  "}"
);
