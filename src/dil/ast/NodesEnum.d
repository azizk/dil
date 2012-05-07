/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.NodesEnum;

/// Enumerates the categories of a node.
enum NodeCategory : ushort
{
  Undefined,
  Declaration,
  Statement,
  Expression,
  Type,
  Other // Parameter
}

/// A list of all class names that inherit from Node.
enum string[] NodeClassNames = [
  // Declarations:
  "CompoundDecl",
  "EmptyDecl",
  "IllegalDecl",
  "ModuleDecl",
  "ImportDecl",
  "AliasDecl",
  "AliasThisDecl",
  "TypedefDecl",
  "EnumDecl",
  "EnumMemberDecl",
  "ClassDecl",
  "InterfaceDecl",
  "StructDecl",
  "UnionDecl",
  "ConstructorDecl",
  "StaticCtorDecl",
  "DestructorDecl",
  "StaticDtorDecl",
  "FunctionDecl",
  "VariablesDecl",
  "InvariantDecl",
  "UnittestDecl",
  "DebugDecl",
  "VersionDecl",
  "StaticIfDecl",
  "StaticAssertDecl",
  "TemplateDecl",
  "NewDecl",
  "DeleteDecl",
  "ProtectionDecl",
  "StorageClassDecl",
  "LinkageDecl",
  "AlignDecl",
  "PragmaDecl",
  "MixinDecl",

  // Statements:
  "CompoundStmt",
  "IllegalStmt",
  "EmptyStmt",
  "FuncBodyStmt",
  "ScopeStmt",
  "LabeledStmt",
  "ExpressionStmt",
  "DeclarationStmt",
  "IfStmt",
  "WhileStmt",
  "DoWhileStmt",
  "ForStmt",
  "ForeachStmt",
  "ForeachRangeStmt", // D2.0
  "SwitchStmt",
  "CaseStmt",
  "CaseRangeStmt",
  "DefaultStmt",
  "ContinueStmt",
  "BreakStmt",
  "ReturnStmt",
  "GotoStmt",
  "WithStmt",
  "SynchronizedStmt",
  "TryStmt",
  "CatchStmt",
  "FinallyStmt",
  "ScopeGuardStmt",
  "ThrowStmt",
  "VolatileStmt",
  "AsmBlockStmt",
  "AsmStmt",
  "AsmAlignStmt",
  "IllegalAsmStmt",
  "PragmaStmt",
  "MixinStmt",
  "StaticIfStmt",
  "StaticAssertStmt",
  "DebugStmt",
  "VersionStmt",

  // Expressions:
  "IllegalExpr",
  "CondExpr",
  "CommaExpr",
  "OrOrExpr",
  "AndAndExpr",
  "OrExpr",
  "XorExpr",
  "AndExpr",
  "EqualExpr",
  "IdentityExpr",
  "RelExpr",
  "InExpr",
  "LShiftExpr",
  "RShiftExpr",
  "URShiftExpr",
  "PlusExpr",
  "MinusExpr",
  "CatExpr",
  "MulExpr",
  "DivExpr",
  "ModExpr",
  "PowExpr", // D2
  "AssignExpr",
  "LShiftAssignExpr",
  "RShiftAssignExpr",
  "URShiftAssignExpr",
  "OrAssignExpr",
  "AndAssignExpr",
  "PlusAssignExpr",
  "MinusAssignExpr",
  "DivAssignExpr",
  "MulAssignExpr",
  "ModAssignExpr",
  "XorAssignExpr",
  "CatAssignExpr",
  "PowAssignExpr", // D2
  "AddressExpr",
  "PreIncrExpr",
  "PreDecrExpr",
  "PostIncrExpr",
  "PostDecrExpr",
  "DerefExpr",
  "SignExpr",
  "NotExpr",
  "CompExpr",
  "CallExpr",
  "NewExpr",
  "NewClassExpr",
  "DeleteExpr",
  "CastExpr",
  "IndexExpr",
  "SliceExpr",
  "ModuleScopeExpr",
  "IdentifierExpr",
  "SpecialTokenExpr",
  "TmplInstanceExpr",
  "ThisExpr",
  "SuperExpr",
  "NullExpr",
  "DollarExpr",
  "BoolExpr",
  "IntExpr",
  "FloatExpr",
  "ComplexExpr",
  "CharExpr",
  "StringExpr",
  "ArrayLiteralExpr",
  "AArrayLiteralExpr",
  "AssertExpr",
  "MixinExpr",
  "ImportExpr",
  "TypeofExpr",
  "TypeDotIdExpr",
  "TypeidExpr",
  "IsExpr",
  "ParenExpr",
  "FuncLiteralExpr",
  "TraitsExpr", // D2.0
  "VoidInitExpr",
  "ArrayInitExpr",
  "StructInitExpr",
  "AsmTypeExpr",
  "AsmOffsetExpr",
  "AsmSegExpr",
  "AsmPostBracketExpr",
  "AsmBracketExpr",
  "AsmLocalSizeExpr",
  "AsmRegisterExpr",

  // Types:
  "IllegalType",
  "IntegralType",
  "ModuleScopeType",
  "IdentifierType",
  "TypeofType",
  "TemplateInstanceType",
  "PointerType",
  "ArrayType",
  "FunctionType",
  "DelegateType",
  "CFuncType",
  "BaseClassType",
  "ConstType", // D2.0
  "ImmutableType", // D2.0
  "InoutType", // D2.0
  "SharedType", // D2.0

  // Parameters:
  "Parameter",
  "Parameters",
  "TemplateAliasParam",
  "TemplateTypeParam",
  "TemplateThisParam", // D2.0
  "TemplateValueParam",
  "TemplateTupleParam",
  "TemplateParameters",
  "TemplateArguments",
];

/// Generates the members of enum NodeKind.
char[] generateNodeKindMembers()
{
  char[] text;
  foreach (className; NodeClassNames)
    text ~= className ~ ",";
  return text;
}
// pragma(msg, generateNodeKindMembers());

version(DDoc)
  /// The node kind identifies every class that inherits from Node.
  enum NodeKind : ushort;
else
mixin(
  "enum NodeKind : ushort"
  "{"
    ~ generateNodeKindMembers ~
  "}"
);
