/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.NodeMembers;

import dil.ast.NodesEnum;

/// CTF: Returns a table of Node class members as a string.
char[] genMembersTable()
{
  alias NodeKind N;
  string[][NodeClassNames.length] t;

  t[N.CompoundDecl] = ["decls[]"];
  t[N.EmptyDecl] = t[N.IllegalDecl] =
  t[N.ModuleDecl] = t[N.ImportDecl] =
  t[N.AliasThisDecl] = [];
  t[N.AliasDecl] = t[N.TypedefDecl] = ["decl"];
  t[N.EnumDecl] = ["baseType?", "members[]"];
  t[N.EnumMemberDecl] = ["type?", "value?"];
  t[N.ClassDecl] = t[N.InterfaceDecl] = ["bases[]", "decls?"];
  t[N.StructDecl] = t[N.UnionDecl] = ["decls?"];
  t[N.ConstructorDecl] = ["params", "funcBody"];
  t[N.StaticCtorDecl] = t[N.DestructorDecl] =
  t[N.StaticDtorDecl] = t[N.InvariantDecl] =
  t[N.UnittestDecl] = ["funcBody"];
  t[N.FunctionDecl] = ["returnType?", "params", "funcBody"];
  t[N.VariablesDecl] = ["type?", "inits[?]"];
  t[N.DebugDecl] = t[N.VersionDecl] = ["decls?", "elseDecls?"];
  t[N.StaticIfDecl] = ["condition", "ifDecls", "elseDecls?"];
  t[N.StaticAssertDecl] = ["condition", "message?"];
  t[N.TemplateDecl] = ["tparams", "constraint?", "decls"];
  t[N.NewDecl] = t[N.DeleteDecl] = ["params", "funcBody"];
  t[N.ProtectionDecl] = t[N.StorageClassDecl] =
  t[N.LinkageDecl] = t[N.AlignDecl] = t[N.ColonBlockDecl] = ["decls"];
  t[N.PragmaDecl] = ["args[]", "decls"];
  t[N.MixinDecl] = ["templateExpr?", "argument?"];
  // Expressions:
  t[N.IllegalExpr] =
  t[N.SpecialTokenExpr] = t[N.ThisExpr] =
  t[N.SuperExpr] = t[N.NullExpr] =
  t[N.DollarExpr] = t[N.BoolExpr] =
  t[N.IntExpr] = t[N.FloatExpr] = t[N.ComplexExpr] =
  t[N.CharExpr] = t[N.StringExpr] = t[N.VoidInitExpr] =
  t[N.ModuleScopeExpr] = t[N.AsmLocalSizeExpr] = [];
  t[N.AsmRegisterExpr] = ["number?"];
  t[N.IdentifierExpr] = ["next?"];
  t[N.TmplInstanceExpr] = ["targs?", "next?"];
  // BinaryExpressions:
  t[N.CondExpr] = ["condition", "lhs", "rhs"];
  t[N.CommaExpr] = t[N.OrOrExpr] = t[N.AndAndExpr] =
  t[N.OrExpr] = t[N.XorExpr] = t[N.AndExpr] =
  t[N.EqualExpr] = t[N.IdentityExpr] = t[N.RelExpr] =
  t[N.InExpr] = t[N.LShiftExpr] = t[N.RShiftExpr] =
  t[N.URShiftExpr] = t[N.PlusExpr] = t[N.MinusExpr] =
  t[N.CatExpr] = t[N.MulExpr] = t[N.DivExpr] =
  t[N.PowExpr] = // D2
  t[N.ModExpr] = t[N.AssignExpr] = t[N.LShiftAssignExpr] =
  t[N.RShiftAssignExpr] = t[N.URShiftAssignExpr] =
  t[N.OrAssignExpr] = t[N.AndAssignExpr] =
  t[N.PlusAssignExpr] = t[N.MinusAssignExpr] =
  t[N.DivAssignExpr] = t[N.MulAssignExpr] =
  t[N.ModAssignExpr] = t[N.XorAssignExpr] =
  t[N.PowAssignExpr] = // D2
  t[N.CatAssignExpr] = ["lhs", "rhs"];
  // UnaryExpressions:
  t[N.AddressExpr] = t[N.PreIncrExpr] = t[N.PreDecrExpr] =
  t[N.PostIncrExpr] = t[N.PostDecrExpr] = t[N.DerefExpr] =
  t[N.SignExpr] = t[N.NotExpr] = t[N.CompExpr] =
  t[N.CallExpr] = t[N.DeleteExpr] =
  t[N.AsmTypeExpr] = t[N.AsmOffsetExpr] =
  t[N.AsmSegExpr] = ["una"];
  version(D2)
  t[N.CastExpr] = ["type?", "una"];
  else
  t[N.CastExpr] = ["type", "una"];
  t[N.IndexExpr] = ["una", "args[]"];
  t[N.SliceExpr] = ["una", "left?", "right?"];
  t[N.AsmPostBracketExpr] = ["una", "index"];
  t[N.NewExpr] = ["frame?", "newArgs[]", "type", "ctorArgs[]"];
  t[N.NewClassExpr] = ["frame?", "newArgs[]", "bases[]",
    "ctorArgs[]", "decls"];
  t[N.AsmBracketExpr] = ["expr"];
  t[N.ArrayLiteralExpr] = ["values[]"];
  t[N.AArrayLiteralExpr] = ["keys[]", "values[]"];
  t[N.AssertExpr] = ["expr", "msg?"];
  t[N.MixinExpr] = t[N.ImportExpr] = ["expr"];
  t[N.TypeofExpr] = t[N.TypeDotIdExpr] =
  t[N.TypeidExpr] = ["type"];
  t[N.IsExpr] = ["type", "specType?", "tparams?"];
  t[N.FuncLiteralExpr] = ["returnType?", "params?", "funcBody"];
  t[N.LambdaExpr] = ["params", "expr"];
  t[N.ParenExpr] = ["next"];
  t[N.TraitsExpr] = ["targs"];
  t[N.ArrayInitExpr] = ["keys[?]", "values[]"];
  t[N.StructInitExpr] = ["values[]"];
  // Statements:
  t[N.IllegalStmt] = t[N.EmptyStmt] =
  t[N.ContinueStmt] = t[N.BreakStmt] =
  t[N.AsmAlignStmt] = t[N.IllegalAsmStmt] = [];
  t[N.CompoundStmt] = ["stmnts[]"];
  t[N.FuncBodyStmt] = ["funcBody?", "inBody?", "outBody?"];
  t[N.ScopeStmt] = t[N.LabeledStmt] = ["stmnt"];
  t[N.ExpressionStmt] = ["expr"];
  t[N.DeclarationStmt] = ["decl"];
  t[N.IfStmt] = ["variable?", "condition?", "ifBody", "elseBody?"];
  t[N.WhileStmt] = ["condition", "whileBody"];
  t[N.DoWhileStmt] = ["doBody", "condition"];
  t[N.ForStmt] = ["init?", "condition?", "increment?", "forBody"];
  t[N.ForeachStmt] = ["params", "aggregate", "forBody"];
  t[N.ForeachRangeStmt] = ["params", "lower", "upper", "forBody"];
  t[N.SwitchStmt] = ["condition", "switchBody"];
  t[N.CaseStmt] = ["values[]", "caseBody"];
  t[N.CaseRangeStmt] = ["left", "right", "caseBody"];
  t[N.DefaultStmt] = ["defaultBody"];
  t[N.ReturnStmt] = t[N.GotoStmt] = ["expr?"];
  t[N.WithStmt] = ["expr", "withBody"];
  t[N.SynchronizedStmt] = ["expr?", "syncBody"];
  t[N.TryStmt] = ["tryBody", "catchBodies[]", "finallyBody?"];
  t[N.CatchStmt] = ["param?", "catchBody"];
  t[N.FinallyStmt] = ["finallyBody"];
  t[N.ScopeGuardStmt] = ["scopeBody"];
  t[N.ThrowStmt] = ["expr"];
  t[N.VolatileStmt] = ["volatileBody?"];
  t[N.AsmBlockStmt] = ["statements"];
  t[N.AsmStmt] = ["operands[]"];
  t[N.PragmaStmt] = ["args[]", "pragmaBody"];
  t[N.MixinStmt] = ["templateExpr"];
  t[N.StaticIfStmt] = ["condition", "ifBody", "elseBody?"];
  t[N.StaticAssertStmt] = ["condition", "message?"];
  t[N.DebugStmt] = t[N.VersionStmt] = ["mainBody", "elseBody?"];
  // TypeNodes:
  t[N.IllegalType] = t[N.IntegralType] =
  t[N.ModuleScopeType] = [];
  t[N.IdentifierType] = ["next?"];
version(D2)
  t[N.TypeofType] = ["expr?"];
else
  t[N.TypeofType] = ["expr"];
  t[N.TmplInstanceType] = ["next?", "targs"];
  t[N.ArrayType] = ["next", "assocType?", "index1?", "index2?"];
  t[N.FunctionType] = t[N.DelegateType] = ["next", "params"];
  t[N.PointerType] = t[N.BaseClassType] = ["next"];
  t[N.ConstType] = t[N.ImmutableType] =
  t[N.InoutType] = t[N.SharedType] = ["next?"];
  // Parameters:
  t[N.Parameter] = ["type?", "defValue?"];
  t[N.Parameters] = t[N.TemplateParameters] =
  t[N.TemplateArguments] = ["children[]"];
  t[N.TemplateAliasParam] = ["spec?", "def?"];
  t[N.TemplateTypeParam] =
  t[N.TemplateThisParam] = ["specType?", "defType?"];
  t[N.TemplateValueParam] = ["valueType", "specValue?", "defValue?"];
  t[N.TemplateTupleParam] = [];

  char[] code = "[ ".dup;
  // Iterate over the elements in the table and create an array.
  foreach (members; t)
  {
    code ~= "[ ".dup;
    foreach (member; members)
      code ~= `"` ~ member ~ `",`;
    code[$-1] = ']'; // Overwrite last comma or space.
    code ~= ',';
  }
  code[$-1] = ']'; // Overwrite last comma.
  return code;
}

/// A table listing the subnodes of all classes inheriting from Node.
enum string[][/+NodeKind.max+1+/] NodeMembersTable = mixin(genMembersTable());

/// A helper function that parses the special strings in NodeMembersTable.
///
/// Basic syntax:
/// $(BNF
////Member := Array | Array2 | OptionalNode | Node | Code
////Array := Identifier "[]"
////Array2 := Identifier "[?]"
////OptionalNode := Identifier "?"
////Node := Identifier
////Code := "%" AnyChar*
////$(MODLINK2 dil.lexer.Identifier, Identifier)
////)
/// Params:
///   members = The member strings to be parsed.
/// Returns:
///   an array of tuples (Name, Type) where Name is the exact name of the member
///   and Type may be one of these values: "[]", "[?]", "?", "" or "%".
string[2][] parseMembers(string[] members)
{
  string[2][] result;
  foreach (member; members)
    if (member.length > 2 && member[$-2..$] == "[]")
      result ~= [member[0..$-2], "[]"]; // Strip off trailing '[]'.
    else if (member.length > 3 && member[$-3..$] == "[?]")
      result ~= [member[0..$-3], "[?]"]; // Strip off trailing '[?]'.
    else if (member[$-1] == '?')
      result ~= [member[0..$-1], "?"]; // Strip off trailing '?'.
    else if (member[0] == '%')
      result ~= [member[1..$], "%"]; // Strip off preceding '%'.
    else
      result ~= [member, ""]; // Nothing to strip off.
  return result;
}
