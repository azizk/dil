/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.NodeCopier;

import common;

/// Mixed into the body of a class that inherits from Node.
const string copyMethod =
  "override typeof(this) copy()"
  "{"
  "  alias typeof(this) this_t;"
  "  static if (is(BinaryExpression) && is(this_t : BinaryExpression))"
  "    mixin(genCopyCode(\"BinaryExpression\"));"
  "  else"
  "  static if (is(UnaryExpression) && is(this_t : UnaryExpression))"
  "    mixin(genCopyCode(\"UnaryExpression\"));"
  "  else"
  "    mixin(genCopyCode(this_t.stringof));"
  "  return n;"
  "}";

/// A helper function that generates code for copying subnodes.
///
/// Basic syntax:
/// $(PRE
/// Member := Array | OptionalNode | Node | Code
/// Array := Identifier "[]"
/// OptionalNode := Identifier "?"
/// Node := Identifier
/// Code := "%" AnyChar*
/// )
/// Params:
///   members = the names of the members to be copied.
string writeCopyCode(string[] members)
{
  char[] result;
  foreach (member; members)
  {
    if (member.length > 2 && member[$-2..$] == "[]")
    { // Copy an array.
      member = member[0..$-2]; // Strip off trailing '[]'.
      // n.member = n.member.dup;
      // foreach (ref m_; n.member)
      //   m_ = m_.copy();
      result ~= "n."~member~" = n."~member~".dup;"\n
      "foreach (ref m_; n."~member~")"\n
      "  m_ = m_.copy();\n";
    }
    else if (member[$-1] == '?')
    { // Copy a member, may be null.
      member = member[0..$-1]; // Strip off trailing '?'.
      // n.member && (n.member = n.member.copy());
      result ~= "n."~member~" && (n."~member~" = n."~member~".copy());"\n;
    }
    else if (member[0] == '%')
      result ~= member[1..$] ~ \n; // Copy code verbatim.
    else // Copy a member, must not be null.
      // n.member = n.member.copy();
      result ~= "n."~member~" = n."~member~".copy();"\n;
  }
  result = result[0..$-1]; // Strip off last '\n'.
  return result;
}

// pragma(msg, writeCopyNode("decls?"));

/// Returns a deep copy of node.
string genCopyCode(string className = "")
{
  string[] m; // Array of member names to be copied.

  switch (className)
  {
  case "CompoundDeclaration":
    m = ["decls[]"]; break;
  case "EmptyDeclaration", "IllegalDeclaration", "ModuleDeclaration",
       "ImportDeclaration":
    break; // no subnodes.
  case "AliasDeclaration", "TypedefDeclaration":
    m = ["decl"]; break;
  case "EnumDeclaration":
    m = ["baseType?", "members[]"]; break;
  case "EnumMemberDeclaration":
    m = ["type?", "value?"]; break;
  case "ClassDeclaration", "InterfaceDeclaration":
    m = ["bases[]", "decls"]; break;
  case "StructDeclaration", "UnionDeclaration":
    m = ["decls"]; break;
  case "ConstructorDeclaration":
    m = ["params", "funcBody"]; break;
  case "StaticConstructorDeclaration", "DestructorDeclaration",
       "StaticDestructorDeclaration", "InvariantDeclaration",
       "UnittestDeclaration":
    m = ["funcBody"]; break;
  case "FunctionDeclaration":
    m = ["returnType?", "params", "funcBody"]; break;
  case "VariablesDeclaration":
    m = ["typeNode?",
         "%n.inits = n.inits.dup;"
         "foreach(ref init; n.inits)"
         "  init && (init = init.copy());"];
    break;
  case "DebugDeclaration", "VersionDeclaration":
    m = ["decls?", "elseDecls?"]; break;
  case "StaticIfDeclaration":
    m = ["condition", "ifDecls", "elseDecls?"]; break;
  case "StaticAssertDeclaration":
    m = ["condition", "message?"]; break;
  case "TemplateDeclaration":
    m = ["tparams", "constraint?", "decls"]; break;
  case "NewDeclaration", "DeleteDeclaration":
    m = ["params", "funcBody"]; break;
  case "ProtectionDeclaration", "StorageClassDeclaration",
       "LinkageDeclaration", "AlignDeclaration":
    m = ["decls"]; break;
  case "PragmaDeclaration":
    m = ["args[]", "decls"]; break;
  case "MixinDeclaration":
    m = ["templateExpr?", "argument?"]; break;
  // Expressions:
  case "IllegalExpression", "IdentifierExpression",
       "SpecialTokenExpression", "ThisExpression",
       "SuperExpression", "NullExpression",
       "DollarExpression", "BoolExpression",
       "IntExpression", "RealExpression", "ComplexExpression",
       "CharExpression", "VoidExpression", "VoidInitExpression",
       "AsmLocalSizeExpression", "AsmRegisterExpression":
    break; // no subnodes.
  case "CondExpression":
    m = ["condition", "lhs", "rhs"]; break;
  case "BinaryExpression": // Special case. Unites all BinaryExpressions.
    m = ["lhs", "rhs"]; break;
  case "CastExpression":
    m = ["type", "e"]; break;
  case "UnaryExpression": // Special case. Unites all UnaryExpressions.
    m = ["e"]; break;
  case "IndexExpression":
    m = ["e", "args[]"]; break;
  case "SliceExpression":
    m = ["e", "left?", "right?"]; break;
  case "AsmPostBracketExpression":
    m = ["e", "e2"]; break;
  case "NewExpression":
    m = ["newArgs[]", "type", "ctorArgs[]"]; break;
  case "NewAnonClassExpression":
    m = ["newArgs[]", "bases[]", "ctorArgs[]", "decls"]; break;
  case "AsmBracketExpression":
    m = ["e"]; break;
  case "TemplateInstanceExpression":
    m = ["targs?"]; break;
  case "ArrayLiteralExpression":
    m = ["values[]"]; break;
  case "AArrayLiteralExpression":
    m = ["keys[]", "values[]"]; break;
  case "AssertExpression":
    m = ["expr", "msg?"]; break;
  case "MixinExpression", "ImportExpression":
    m = ["expr"]; break;
  case "TypeofExpression", "TypeDotIdExpression", "TypeidExpression":
    m = ["type"]; break;
  case "IsExpression":
    m = ["type", "specType?", "tparams?"]; break;
  case "FunctionLiteralExpression":
    m = ["returnType?", "params?", "funcBody"]; break;
  case "ParenExpression":
    m = ["next"]; break;
  case "TraitsExpression":
    m = ["targs"]; break;
  case "VoidInitializer": break; // no subnodes.
  case "ArrayInitExpression":
    m = ["values[]",
         "%n.keys = n.keys.dup;"
         "foreach(ref key; n.keys)"
         "  key && (key = key.copy());"];
    break;
  case "StructInitExpression":
    m = ["values[]"]; break;
  case "StringExpression":
    m = ["%n.str = n.str.dup;"]; break;
  // Statements:
  case "CompoundStatement":
    m = ["stmnts[]"]; break;
  case "IllegalStatement", "EmptyStatement": break; // no subnodes.
  case "FuncBodyStatement":
    m = ["funcBody?", "inBody?", "outBody?"]; break;
  case "ScopeStatement", "LabeledStatement":
    m = ["s"]; break;
  case "ExpressionStatement":
    m = ["e"]; break;
  case "DeclarationStatement":
    m = ["decl"]; break;
  case "IfStatement":
    m = ["%if (n.variable)", "variable", "%else", "condition",
         "ifBody", "elseBody?"];
    break;
  case "WhileStatement":
    m = ["condition", "whileBody"]; break;
  case "DoWhileStatement":
    m = ["doBody", "condition"]; break;
  case "ForStatement":
    m = ["init?", "condition?", "increment?", "forBody"]; break;
  case "ForeachStatement":
    m = ["params", "aggregate", "forBody"]; break;
  case "ForeachRangeStatement":
    m = ["params", "lower", "upper", "forBody"]; break;
  case "SwitchStatement":
    m = ["condition", "switchBody"]; break;
  case "CaseStatement":
    m = ["values[]", "caseBody"]; break;
  case "DefaultStatement":
    m = ["defaultBody"]; break;
  case "ContinueStatement", "BreakStatement": break; //no subnodes.
  case "ReturnStatement":
    m = ["e?"]; break;
  case "GotoStatement":
    m = ["caseExpr?"]; break;
  case "WithStatement":
    m = ["e", "withBody"]; break;
  case "SynchronizedStatement":
    m = ["e?", "syncBody"]; break;
  case "TryStatement":
    m = ["tryBody", "catchBodies[]", "finallyBody?"]; break;
  case "CatchStatement":
    m = ["param?", "catchBody"]; break;
  case "FinallyStatement":
    m = ["finallyBody"]; break;
  case "ScopeGuardStatement":
    m = ["scopeBody"]; break;
  case "ThrowStatement":
    m = ["e"]; break;
  case "VolatileStatement":
    m = ["volatileBody?"]; break;
  case "AsmBlockStatement":
    m = ["statements"]; break;
  case "AsmStatement":
    m = ["operands[]"]; break;
  case "AsmAlignStatement", "IllegalAsmStatement": break; // no subnodes.
  case "PragmaStatement":
    m = ["args[]", "pragmaBody"]; break;
  case "MixinStatement":
    m = ["templateExpr"]; break;
  case "StaticIfStatement":
    m = ["condition", "ifBody", "elseBody?"]; break;
  case "StaticAssertStatement":
    m = ["condition", "message?"]; break;
  case "DebugStatement", "VersionStatement":
    m = ["mainBody", "elseBody?"]; break;
  // TypeNodes:
  case "IllegalType", "IntegralType",
       "ModuleScopeType", "IdentifierType": break; // no subnodes.
  case "QualifiedType":
    m = ["lhs", "rhs"]; break;
  case "TypeofType":
    m = ["e"]; break;
  case "TemplateInstanceType":
    m = ["targs?"]; break;
  case "PointerType":
    m = ["next"]; break;
  case "ArrayType":
    m = ["next", "assocType?", "e1?", "e2?"]; break;
  case "FunctionType", "DelegateType":
    m = ["returnType", "params"]; break;
  case "CFuncPointerType":
    m = ["next", "params?"]; break;
  case "BaseClassType", "ConstType", "InvariantType":
    m = ["next"]; break;
  // Parameters:
  case "Parameter":
    m = ["type?", "defValue?"]; break;
  case "Parameters", "TemplateParameters", "TemplateArguments":
    m = ["children[]"]; break;
  case "TemplateAliasParameter", "TemplateTypeParameter",
       "TemplateThisParameter":
    m = ["specType", "defType"]; break;
  case "TemplateValueParameter":
    m = ["valueType", "specValue?", "defValue?"]; break;
  case "TemplateTupleParameter": break; // no subnodes.
  default:
    assert(0, "copying of "~className~" is not handled");
  }

  char[] code =
  // First do a shallow copy.
  "auto n = cast(this_t)cast(void*)this.dup;\n";

  // Then copy the members.
  if (m.length)
    code ~= writeCopyCode(m);

  return code;
}

// pragma(msg, genCopyCode("ArrayType"));
