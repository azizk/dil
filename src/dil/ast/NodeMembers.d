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
  t[N.IllegalExpression] =
  t[N.SpecialTokenExpression] = t[N.ThisExpression] =
  t[N.SuperExpression] = t[N.NullExpression] =
  t[N.DollarExpression] = t[N.BoolExpression] =
  t[N.IntExpression] = t[N.FloatExpression] = t[N.ComplexExpression] =
  t[N.CharExpression] = t[N.StringExpression] = t[N.VoidInitExpression] =
  t[N.ModuleScopeExpression] = t[N.AsmLocalSizeExpression] = [];
  t[N.AsmRegisterExpression] = ["number?"];
  t[N.IdentifierExpression] = ["next?"];
  t[N.TemplateInstanceExpression] = ["targs?", "next?"];
  // BinaryExpressions:
  t[N.CondExpression] = ["condition", "lhs", "rhs"];
  t[N.CommaExpression] = t[N.OrOrExpression] = t[N.AndAndExpression] =
  t[N.OrExpression] = t[N.XorExpression] = t[N.AndExpression] =
  t[N.EqualExpression] = t[N.IdentityExpression] = t[N.RelExpression] =
  t[N.InExpression] = t[N.LShiftExpression] = t[N.RShiftExpression] =
  t[N.URShiftExpression] = t[N.PlusExpression] = t[N.MinusExpression] =
  t[N.CatExpression] = t[N.MulExpression] = t[N.DivExpression] =
  t[N.PowExpression] = // D2
  t[N.ModExpression] = t[N.AssignExpression] = t[N.LShiftAssignExpression] =
  t[N.RShiftAssignExpression] = t[N.URShiftAssignExpression] =
  t[N.OrAssignExpression] = t[N.AndAssignExpression] =
  t[N.PlusAssignExpression] = t[N.MinusAssignExpression] =
  t[N.DivAssignExpression] = t[N.MulAssignExpression] =
  t[N.ModAssignExpression] = t[N.XorAssignExpression] =
  t[N.PowAssignExpression] = // D2
  t[N.CatAssignExpression] = ["lhs", "rhs"];
  // UnaryExpressions:
  t[N.AddressExpression] = t[N.PreIncrExpression] = t[N.PreDecrExpression] =
  t[N.PostIncrExpression] = t[N.PostDecrExpression] = t[N.DerefExpression] =
  t[N.SignExpression] = t[N.NotExpression] = t[N.CompExpression] =
  t[N.CallExpression] = t[N.DeleteExpression] =
  t[N.AsmTypeExpression] = t[N.AsmOffsetExpression] =
  t[N.AsmSegExpression] = ["una"];
  version(D2)
  t[N.CastExpression] = ["type?", "una"];
  else
  t[N.CastExpression] = ["type", "una"];
  t[N.IndexExpression] = ["una", "args[]"];
  t[N.SliceExpression] = ["una", "left?", "right?"];
  t[N.AsmPostBracketExpression] = ["una", "index"];
  t[N.NewExpression] = ["frame?", "newArgs[]", "type", "ctorArgs[]"];
  t[N.NewClassExpression] = ["frame?", "newArgs[]", "bases[]",
    "ctorArgs[]", "decls"];
  t[N.AsmBracketExpression] = ["expr"];
  t[N.ArrayLiteralExpression] = ["values[]"];
  t[N.AArrayLiteralExpression] = ["keys[]", "values[]"];
  t[N.AssertExpression] = ["expr", "msg?"];
  t[N.MixinExpression] = t[N.ImportExpression] = ["expr"];
  t[N.TypeofExpression] = t[N.TypeDotIdExpression] =
  t[N.TypeidExpression] = ["type"];
  t[N.IsExpression] = ["type", "specType?", "tparams?"];
  t[N.FunctionLiteralExpression] = ["returnType?", "params?", "funcBody"];
  t[N.ParenExpression] = ["next"];
  t[N.TraitsExpression] = ["targs"];
  t[N.ArrayInitExpression] = ["keys[?]", "values[]"];
  t[N.StructInitExpression] = ["values[]"];
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
