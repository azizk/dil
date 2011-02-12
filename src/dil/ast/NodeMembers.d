/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.NodeMembers;

import dil.ast.NodesEnum;

private alias NodeKind N;

/// CTF: Returns a table of Node class members as a string.
char[] genMembersTable()
{
  char[][][NodeClassNames.length] t;

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
  t[N.VariablesDecl] = ["typeNode?", "inits[?]"];
  t[N.DebugDecl] = t[N.VersionDecl] = ["decls?", "elseDecls?"];
  t[N.StaticIfDecl] = ["condition", "ifDecls", "elseDecls?"];
  t[N.StaticAssertDecl] = ["condition", "message?"];
  t[N.TemplateDecl] = ["tparams", "constraint?", "decls"];
  t[N.NewDecl] = t[N.DeleteDecl] = ["params", "funcBody"];
  t[N.ProtectionDecl] = t[N.StorageClassDecl] =
  t[N.LinkageDecl] = t[N.AlignDecl] = ["decls"];
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
  t[N.ParenExpr] = ["next"];
  t[N.TraitsExpr] = ["targs"];
  t[N.ArrayInitExpr] = ["keys[?]", "values[]"];
  t[N.StructInitExpr] = ["values[]"];
  // Statements:
  t[N.IllegalStatement] = t[N.EmptyStatement] =
  t[N.ContinueStatement] = t[N.BreakStatement] =
  t[N.AsmAlignStatement] = t[N.IllegalAsmStatement] = [];
  t[N.CompoundStatement] = ["stmnts[]"];
  t[N.FuncBodyStatement] = ["funcBody?", "inBody?", "outBody?"];
  t[N.ScopeStatement] = t[N.LabeledStatement] = ["stmnt"];
  t[N.ExpressionStatement] = ["expr"];
  t[N.DeclarationStatement] = ["decl"];
  t[N.IfStatement] = ["variable?", "condition?", "ifBody", "elseBody?"];
  t[N.WhileStatement] = ["condition", "whileBody"];
  t[N.DoWhileStatement] = ["doBody", "condition"];
  t[N.ForStatement] = ["init?", "condition?", "increment?", "forBody"];
  t[N.ForeachStatement] = ["params", "aggregate", "forBody"];
  t[N.ForeachRangeStatement] = ["params", "lower", "upper", "forBody"];
  t[N.SwitchStatement] = ["condition", "switchBody"];
  t[N.CaseStatement] = ["values[]", "caseBody"];
  t[N.CaseRangeStatement] = ["left", "right", "caseBody"];
  t[N.DefaultStatement] = ["defaultBody"];
  t[N.ReturnStatement] = t[N.GotoStatement] = ["expr?"];
  t[N.WithStatement] = ["expr", "withBody"];
  t[N.SynchronizedStatement] = ["expr?", "syncBody"];
  t[N.TryStatement] = ["tryBody", "catchBodies[]", "finallyBody?"];
  t[N.CatchStatement] = ["param?", "catchBody"];
  t[N.FinallyStatement] = ["finallyBody"];
  t[N.ScopeGuardStatement] = ["scopeBody"];
  t[N.ThrowStatement] = ["expr"];
  t[N.VolatileStatement] = ["volatileBody?"];
  t[N.AsmBlockStatement] = ["statements"];
  t[N.AsmStatement] = ["operands[]"];
  t[N.PragmaStatement] = ["args[]", "pragmaBody"];
  t[N.MixinStatement] = ["templateExpr"];
  t[N.StaticIfStatement] = ["condition", "ifBody", "elseBody?"];
  t[N.StaticAssertStatement] = ["condition", "message?"];
  t[N.DebugStatement] = t[N.VersionStatement] = ["mainBody", "elseBody?"];
  // TypeNodes:
  t[N.IllegalType] = t[N.IntegralType] =
  t[N.ModuleScopeType] = [];
  t[N.IdentifierType] = ["next?"];
version(D2)
  t[N.TypeofType] = ["expr?"];
else
  t[N.TypeofType] = ["expr"];
  t[N.TemplateInstanceType] = ["next?", "targs"];
  t[N.ArrayType] = ["next", "assocType?", "index1?", "index2?"];
  t[N.FunctionType] = t[N.DelegateType] = t[N.CFuncType] = ["next", "params"];
  t[N.PointerType] = t[N.BaseClassType] = ["next"];
  t[N.ConstType] = t[N.ImmutableType] = t[N.SharedType] = ["next?"];
  // Parameters:
  t[N.Parameter] = ["type?", "defValue?"];
  t[N.Parameters] = t[N.TemplateParameters] =
  t[N.TemplateArguments] = ["children[]"];
  t[N.TemplateAliasParameter] = ["spec?", "def?"];
  t[N.TemplateTypeParameter] =
  t[N.TemplateThisParameter] = ["specType?", "defType?"];
  t[N.TemplateValueParameter] = ["valueType", "specValue?", "defValue?"];
  t[N.TemplateTupleParameter] = [];

  char[] code = "[ ";
  // Iterate over the elements in the table and create an array.
  foreach (m; t)
  {
    code ~= "[ ";
    foreach (n; m)
      code ~= `"` ~ n ~ `",`;
    code[$-1] = ']'; // Overwrite last comma or space.
    code ~= ',';
  }
  code[$-1] = ']'; // Overwrite last comma.
  return code;
}

/// A table listing the subnodes of all classes inheriting from Node.
static const char[][][/+NodeKind.max+1+/] NodeMembersTable = mixin(genMembersTable());

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
///   members = the member strings to be parsed.
/// Returns:
///   an array of tuples (Name, Type) where Name is the exact name of the member
///   and Type may be one of these values: "[]", "[?]", "?", "" or "%".
char[][2][] parseMembers(char[][] members)
{
  char[][2][] result;
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
