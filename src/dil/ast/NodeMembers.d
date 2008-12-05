/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.NodeMembers;

import dil.ast.NodesEnum;

private alias NodeKind N;

char[] genMembersTable()
{ //pragma(msg, "genMembersTable()");
  char[][][] t = [];
  // t.length = g_classNames.length;
  // Setting the length doesn't work in CTFs. This is a workaround:
  // FIXME: remove this when dmd issue #2337 has been resolved.
  for (uint i; i < g_classNames.length; i++)
    t ~= [[]];
  assert(t.length == g_classNames.length);

  t[N.CompoundDeclaration] = ["decls[]"];
  t[N.EmptyDeclaration] = t[N.IllegalDeclaration] =
  t[N.ModuleDeclaration] = t[N.ImportDeclaration] = [];
  t[N.AliasDeclaration] = t[N.TypedefDeclaration] = ["decl"];
  t[N.EnumDeclaration] = ["baseType?", "members[]"];
  t[N.EnumMemberDeclaration] = ["type?", "value?"];
  t[N.ClassDeclaration] = t[N.InterfaceDeclaration] = ["bases[]", "decls?"];
  t[N.StructDeclaration] = t[N.UnionDeclaration] = ["decls?"];
  t[N.ConstructorDeclaration] = ["params", "funcBody"];
  t[N.StaticConstructorDeclaration] = t[N.DestructorDeclaration] =
  t[N.StaticDestructorDeclaration] = t[N.InvariantDeclaration] =
  t[N.UnittestDeclaration] = ["funcBody"];
  t[N.FunctionDeclaration] = ["returnType?", "params", "funcBody"];
  t[N.VariablesDeclaration] = ["typeNode?", "inits[?]"];
  t[N.DebugDeclaration] = t[N.VersionDeclaration] = ["decls?", "elseDecls?"];
  t[N.StaticIfDeclaration] = ["condition", "ifDecls", "elseDecls?"];
  t[N.StaticAssertDeclaration] = ["condition", "message?"];
  t[N.TemplateDeclaration] = ["tparams", "constraint?", "decls"];
  t[N.NewDeclaration] = t[N.DeleteDeclaration] = ["params", "funcBody"];
  t[N.ProtectionDeclaration] = t[N.StorageClassDeclaration] =
  t[N.LinkageDeclaration] = t[N.AlignDeclaration] = ["decls"];
  t[N.PragmaDeclaration] = ["args[]", "decls"];
  t[N.MixinDeclaration] = ["templateExpr?", "argument?"];
  // Expressions:
  t[N.IllegalExpression] = t[N.IdentifierExpression] =
  t[N.SpecialTokenExpression] = t[N.ThisExpression] =
  t[N.SuperExpression] = t[N.NullExpression] =
  t[N.DollarExpression] = t[N.BoolExpression] =
  t[N.IntExpression] = t[N.RealExpression] = t[N.ComplexExpression] =
  t[N.CharExpression] = t[N.VoidInitExpression] =
  t[N.AsmLocalSizeExpression] = t[N.AsmRegisterExpression] = [];
  // BinaryExpressions:
  t[N.CondExpression] = ["condition", "lhs", "rhs"];
  t[N.CommaExpression] = t[N.OrOrExpression] = t[N.AndAndExpression] =
  t[N.OrExpression] = t[N.XorExpression] = t[N.AndExpression] =
  t[N.EqualExpression] = t[N.IdentityExpression] = t[N.RelExpression] =
  t[N.InExpression] = t[N.LShiftExpression] = t[N.RShiftExpression] =
  t[N.URShiftExpression] = t[N.PlusExpression] = t[N.MinusExpression] =
  t[N.CatExpression] = t[N.MulExpression] = t[N.DivExpression] =
  t[N.ModExpression] = t[N.AssignExpression] = t[N.LShiftAssignExpression] =
  t[N.RShiftAssignExpression] = t[N.URShiftAssignExpression] =
  t[N.OrAssignExpression] = t[N.AndAssignExpression] =
  t[N.PlusAssignExpression] = t[N.MinusAssignExpression] =
  t[N.DivAssignExpression] = t[N.MulAssignExpression] =
  t[N.ModAssignExpression] = t[N.XorAssignExpression] =
  t[N.CatAssignExpression] = t[N.DotExpression] = ["lhs", "rhs"];
  // UnaryExpressions:
  t[N.AddressExpression] = t[N.PreIncrExpression] = t[N.PreDecrExpression] =
  t[N.PostIncrExpression] = t[N.PostDecrExpression] = t[N.DerefExpression] =
  t[N.SignExpression] = t[N.NotExpression] = t[N.CompExpression] =
  t[N.CallExpression] = t[N.DeleteExpression] = t[N.ModuleScopeExpression] =
  t[N.AsmTypeExpression] = t[N.AsmOffsetExpression] =
  t[N.AsmSegExpression] = ["e"];
  t[N.CastExpression] = ["type", "e"];
  t[N.IndexExpression] = ["e", "args[]"];
  t[N.SliceExpression] = ["e", "left?", "right?"];
  t[N.AsmPostBracketExpression] = ["e", "e2"];
  t[N.NewExpression] = ["newArgs[]", "type", "ctorArgs[]"];
  t[N.NewAnonClassExpression] = ["newArgs[]", "bases[]", "ctorArgs[]", "decls"];
  t[N.AsmBracketExpression] = ["e"];
  t[N.TemplateInstanceExpression] = ["targs?"];
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
  t[N.StringExpression] = [],
  // Statements:
  t[N.IllegalStatement] = t[N.EmptyStatement] =
  t[N.ContinueStatement] = t[N.BreakStatement] =
  t[N.AsmAlignStatement] = t[N.IllegalAsmStatement] = [];
  t[N.CompoundStatement] = ["stmnts[]"];
  t[N.FuncBodyStatement] = ["funcBody?", "inBody?", "outBody?"];
  t[N.ScopeStatement] = t[N.LabeledStatement] = ["s"];
  t[N.ExpressionStatement] = ["e"];
  t[N.DeclarationStatement] = ["decl"];
  t[N.IfStatement] = ["variable?", "condition?", "ifBody", "elseBody?"];
  t[N.WhileStatement] = ["condition", "whileBody"];
  t[N.DoWhileStatement] = ["doBody", "condition"];
  t[N.ForStatement] = ["init?", "condition?", "increment?", "forBody"];
  t[N.ForeachStatement] = ["params", "aggregate", "forBody"];
  t[N.ForeachRangeStatement] = ["params", "lower", "upper", "forBody"];
  t[N.SwitchStatement] = ["condition", "switchBody"];
  t[N.CaseStatement] = ["values[]", "caseBody"];
  t[N.DefaultStatement] = ["defaultBody"];
  t[N.ReturnStatement] = ["e?"];
  t[N.GotoStatement] = ["caseExpr?"];
  t[N.WithStatement] = ["e", "withBody"];
  t[N.SynchronizedStatement] = ["e?", "syncBody"];
  t[N.TryStatement] = ["tryBody", "catchBodies[]", "finallyBody?"];
  t[N.CatchStatement] = ["param?", "catchBody"];
  t[N.FinallyStatement] = ["finallyBody"];
  t[N.ScopeGuardStatement] = ["scopeBody"];
  t[N.ThrowStatement] = ["e"];
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
  t[N.ModuleScopeType] = t[N.IdentifierType] = [];
  t[N.QualifiedType] = ["lhs", "rhs"];
  t[N.TypeofType] = ["e"];
  t[N.TemplateInstanceType] = ["targs?"];
  t[N.ArrayType] = ["next", "assocType?", "e1?", "e2?"];
  t[N.FunctionType] = t[N.DelegateType] = ["returnType", "params"];
  t[N.CFuncPointerType] = ["next", "params?"];
  t[N.PointerType] = t[N.BaseClassType] =
  t[N.ConstType] = t[N.InvariantType] = ["next"];
  // Parameters:
  t[N.Parameter] = ["type?", "defValue?"];
  t[N.Parameters] = t[N.TemplateParameters] =
  t[N.TemplateArguments] = ["children[]"];
  t[N.TemplateAliasParameter] = t[N.TemplateTypeParameter] =
  t[N.TemplateThisParameter] = ["specType?", "defType?"];
  t[N.TemplateValueParameter] = ["valueType", "specValue?", "defValue?"];
  t[N.TemplateTupleParameter] = [];

  char[] code = "[";
  // Iterate over the elements in the table and create an array.
  foreach (m; t)
  {
    if (!m.length) {
      code ~= "[],";
      continue; // No members, append "[]," and continue.
    }
    code ~= '[';
    foreach (n; m)
      code ~= `"` ~ n ~ `",`;
    code[code.length-1] = ']'; // Overwrite last comma.
    code ~= ',';
  }
  code[code.length-1] = ']'; // Overwrite last comma.
  return code;
}

/// A table listing the subnodes of all classes inheriting from Node.
static const char[][][/+NodeKind.max+1+/] g_membersTable = mixin(genMembersTable());

/// A helper function that parses the special strings in g_membersTable.
///
/// Basic syntax:
/// $(PRE
/// Member := Array | Array2 | OptionalNode | Node | Code
/// Array := Identifier "[]"
/// Array2 := Identifier "[?]"
/// OptionalNode := Identifier "?"
/// Node := Identifier
/// Code := "%" AnyChar*
/// $(MODLINK2 dil.lexer.Identifier, Identifier)
/// )
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
