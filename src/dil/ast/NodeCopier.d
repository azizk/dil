/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.NodeCopier;

import common;

/// Mixed into the body of a class that inherits from Node.
const string copyMethod = `
  override typeof(this) copy()
  {
    mixin copyNode!(typeof(this));
    return copyNode(this);
  }`;

/// A helper function that generates code for copying subnodes.
string doCopy_(string obj, string[] members)
{
  char[] result;
  foreach (member; members)
  {
    if (member.length > 2 && member[$-2..$] == "[]") // Array copy.
    {
      member = member[0..$-2];
      // obj.member = obj.member.dup;
      // foreach (ref m_; obj.member)
      //   m_ = m_.copy();
      result ~= obj~"."~member~" = "~obj~"."~member~".dup;"
      "foreach (ref m_; "~obj~"."~member~")"
        "m_ = m_.copy();";
    }
    else if (member[$-1] == '?') // Optional member copy.
    {
      member = member[0..$-1];
      // obj.member && (obj.member = obj.member.copy());
      result ~= obj~"."~member~" && ("~obj~"."~member~" = "~obj~"."~member~".copy());";
    }
    else // Non-optional member copy.
      // obj.member = obj.member.copy();
      result ~= obj~"."~member~" = "~obj~"."~member~".copy();";
  }
  return result;
}

string doCopy(string[] members)
{
  return doCopy_("x", members);
}

string doCopy(string member)
{
  return doCopy_("x", [member]);
}

// pragma(msg, doCopy("decls?"));

/// Returns a deep copy of node.
T copyNode(T)(T node)
{
  assert(node !is null);

  // Firstly do a shallow copy.
  T x = cast(T)cast(void*)node.dup;

  // Now copy the subnodes.
  static if (is(Declaration) && is(T : Declaration))
  {
    alias T D;
    static if (is(D == CompoundDeclaration))
      mixin(doCopy("decls[]"));
    //EmptyDeclaration,
    //IllegalDeclaration,
    //ModuleDeclaration have no subnodes.
    static if (is(D == AliasDeclaration) ||
               is(D == TypedefDeclaration))
      mixin(doCopy("decl"));
    static if (is(D == EnumDeclaration))
      mixin(doCopy(["baseType?", "members[]"]));
    static if (is(D == EnumMemberDeclaration))
      mixin(doCopy(["type?", "value?"]));
    static if (is(D == ClassDeclaration) || is( D == InterfaceDeclaration))
      mixin(doCopy(["bases[]", "decls"]));
    static if (is(D == StructDeclaration) || is(D == UnionDeclaration))
      mixin(doCopy("decls"));
    static if (is(D == ConstructorDeclaration))
      mixin(doCopy(["params", "funcBody"]));
    static if (is(D == StaticConstructorDeclaration) ||
               is(D == DestructorDeclaration) ||
               is(D == StaticDestructorDeclaration) ||
               is(D == InvariantDeclaration) ||
               is(D == UnittestDeclaration))
      mixin(doCopy("funcBody"));
    static if (is(D == FunctionDeclaration))
      mixin(doCopy(["returnType?", "params", "funcBody"]));
    static if (is(D == VariablesDeclaration))
    {
      mixin(doCopy("typeNode?"));
      x.inits = x.inits.dup;
      foreach(ref init; x.inits)
        init && (init = init.copy());
    }
    static if (is(D == DebugDeclaration) || is(D == VersionDeclaration))
      mixin(doCopy(["decls?","elseDecls?"]));
    static if (is(D == StaticIfDeclaration))
      mixin(doCopy(["condition","ifDecls", "elseDecls?"]));
    static if (is(D == StaticAssertDeclaration))
      mixin(doCopy(["condition","message?"]));
    static if (is(D == TemplateDeclaration))
      mixin(doCopy(["tparams","decls"]));
    static if (is(D == NewDeclaration) || is(D == DeleteDeclaration))
      mixin(doCopy(["params","funcBody"]));
    static if (is(D == ProtectionDeclaration) ||
               is(D == StorageClassDeclaration) ||
               is(D == LinkageDeclaration) ||
               is(D == AlignDeclaration))
      mixin(doCopy("decls"));
    static if (is(D == PragmaDeclaration))
      mixin(doCopy(["args[]","decls"]));
    static if (is(D == MixinDeclaration))
      mixin(doCopy(["templateExpr?","argument?"]));
  }
  else
  static if (is(Expression) && is(T : Expression))
  {
    alias T E;
    static if (is(E == IllegalExpression))
    {}
    else
    static if (is(E == CondExpression))
      mixin(doCopy(["condition", "lhs", "rhs"]));
    else
    static if (is(E : BinaryExpression))
      mixin(doCopy(["lhs", "rhs"]));
    else
    static if (is(E : UnaryExpression))
    {
      static if (is(E == CastExpression))
        mixin(doCopy("type"));
      mixin(doCopy("e")); // Copy member in base class UnaryExpression.
      static if (is(E == IndexExpression))
        mixin(doCopy("args[]"));
      static if (is(E == SliceExpression))
        mixin(doCopy(["left?", "right?"]));
      static if (is(E == AsmPostBracketExpression))
        mixin(doCopy("e2"));
    }
    else
    {
      static if (is(E == NewExpression))
        mixin(doCopy(["newArgs[]", "type", "ctorArgs[]"]));
      static if (is(E == NewAnonClassExpression))
        mixin(doCopy(["newArgs[]", "bases[]", "ctorArgs[]", "decls"]));
      static if (is(E == AsmBracketExpression))
        mixin(doCopy("e"));
      static if (is(E == TemplateInstanceExpression))
        mixin(doCopy("targs?"));
      static if (is(E == ArrayLiteralExpression))
        mixin(doCopy("values[]"));
      static if (is(E == AArrayLiteralExpression))
        mixin(doCopy(["keys[]", "values[]"]));
      static if (is(E == AssertExpression))
        mixin(doCopy(["expr", "msg?"]));
      static if (is(E == MixinExpression) ||
                 is(E == ImportExpression))
        mixin(doCopy("expr"));
      static if (is(E == TypeofExpression) ||
                 is(E == TypeDotIdExpression) ||
                 is(E == TypeidExpression))
        mixin(doCopy("type"));
      static if (is(E == IsExpression))
        mixin(doCopy(["type", "specType?", "tparams?"]));
      static if (is(E == FunctionLiteralExpression))
        mixin(doCopy(["returnType?", "params?", "funcBody"]));
      static if (is(E == ParenExpression))
        mixin(doCopy("next"));
      static if (is(E == TraitsExpression))
        mixin(doCopy("targs"));
      // VoidInitializer has no subnodes.
      static if (is(E == ArrayInitExpression))
      {
        mixin(doCopy("values[]"));
        x.keys = x.keys.dup;
        foreach(ref key; x.keys)
          key && (key = key.copy());
      }
      static if (is(E == StructInitExpression))
        mixin(doCopy("values[]"));
      static if (is(E == StringExpression))
        x.str = x.str.dup;
    }
  }
  else
  static if (is(Statement) && is(T : Statement))
  {
    alias T S;
    static if (is(S == CompoundStatement))
      mixin(doCopy("stmnts[]"));
    //IllegalStatement,
    //EmptyStatement have no subnodes.
    static if (is(S == FuncBodyStatement))
      mixin(doCopy(["funcBody?", "inBody?", "outBody?"]));
    static if (is(S == ScopeStatement) || is(S == LabeledStatement))
      mixin(doCopy("s"));
    static if (is(S == ExpressionStatement))
      mixin(doCopy("e"));
    static if (is(S == DeclarationStatement))
      mixin(doCopy("decl"));
    static if (is(S == IfStatement))
    {
      if (x.variable)
        mixin(doCopy("variable"));
      else
        mixin(doCopy("condition"));
      mixin(doCopy(["ifBody", "elseBody?"]));
    }
    static if (is(S == WhileStatement))
      mixin(doCopy(["condition", "whileBody"]));
    static if (is(S == DoWhileStatement))
      mixin(doCopy(["doBody", "condition"]));
    static if (is(S == ForStatement))
      mixin(doCopy(["init?", "condition?", "increment?", "forBody"]));
    static if (is(S == ForeachStatement))
      mixin(doCopy(["params", "aggregate", "forBody"]));
    static if (is(S == ForeachRangeStatement))
      mixin(doCopy(["params", "lower", "upper", "forBody"]));
    static if (is(S == SwitchStatement))
      mixin(doCopy(["condition", "switchBody"]));
    static if (is(S == CaseStatement))
      mixin(doCopy(["values[]", "caseBody"]));
    static if (is(S == DefaultStatement))
      mixin(doCopy("defaultBody"));
    //ContinueStatement,
    //BreakStatement have no subnodes.
    static if (is(S == ReturnStatement))
      mixin(doCopy("e?"));
    static if (is(S == GotoStatement))
      mixin(doCopy("caseExpr?"));
    static if (is(S == WithStatement))
      mixin(doCopy(["e", "withBody"]));
    static if (is(S == SynchronizedStatement))
      mixin(doCopy(["e?", "syncBody"]));
    static if (is(S == TryStatement))
      mixin(doCopy(["tryBody", "catchBodies[]", "finallyBody?"]));
    static if (is(S == CatchStatement))
      mixin(doCopy(["param?", "catchBody"]));
    static if (is(S == FinallyStatement))
      mixin(doCopy("finallyBody"));
    static if (is(S == ScopeGuardStatement))
      mixin(doCopy("scopeBody"));
    static if (is(S == ThrowStatement))
      mixin(doCopy("e"));
    static if (is(S == VolatileStatement))
      mixin(doCopy("volatileBody?"));
    static if (is(S == AsmBlockStatement))
      mixin(doCopy("statements"));
    static if (is(S == AsmStatement))
      mixin(doCopy("operands[]"));
    //AsmAlignStatement,
    //IllegalAsmStatement have no subnodes.
    static if (is(S == PragmaStatement))
      mixin(doCopy(["args[]", "pragmaBody"]));
    static if (is(S == MixinStatement))
      mixin(doCopy("templateExpr"));
    static if (is(S == StaticIfStatement))
      mixin(doCopy(["condition", "ifBody", "elseBody?"]));
    static if (is(S == StaticAssertStatement))
      mixin(doCopy(["condition", "message?"]));
    static if (is(S == DebugStatement) || is(S == VersionStatement))
      mixin(doCopy(["mainBody", "elseBody?"]));
  }
  else
  static if (is(TypeNode) && is(T : TypeNode))
  {
    //IllegalType,
    //IntegralType,
    //ModuleScopeType,
    //IdentifierType have no subnodes.
    static if (is(T == QualifiedType))
      mixin(doCopy(["lhs", "rhs"]));
    static if (is(T == TypeofType))
      mixin(doCopy("e"));
    static if (is(T == TemplateInstanceType))
      mixin(doCopy("targs?"));
    static if (is(T == PointerType))
      mixin(doCopy("next"));
    static if (is(T == ArrayType))
      mixin(doCopy(["next", "assocType?", "e1?", "e2?"]));
    static if (is(T == FunctionType) || is(T == DelegateType))
      mixin(doCopy(["returnType", "params"]));
    static if (is(T == CFuncPointerType))
      mixin(doCopy(["next", "params?"]));
    static if (is(T == BaseClassType) ||
               is(T == ConstType) ||
               is(T == InvariantType))
      mixin(doCopy("next"));
  }
  else
  static if (is(Parameter) && is(T == Parameter))
  {
    mixin(doCopy(["type?", "defValue?"]));
  }
  else
  static if (is(Parameter) && is(T == Parameters) ||
             is(TemplateParameter) && is(T == TemplateParameters) ||
             is(TemplateArguments) && is(T == TemplateArguments))
  {
    mixin(doCopy("children[]"));
  }
  else
  static if (is(TemplateParameter) && is(T : TemplateParameter))
  {
    static if (is(N == TemplateAliasParameter) ||
               is(N == TemplateTypeParameter) ||
               is(N == TemplateThisParameter))
      mixin(doCopy(["specType", "defType"]));
    static if (is(N == TemplateValueParameter))
      mixin(doCopy(["valueType", "specValue?", "defValue?"]));
    //TemplateTupleParameter has no subnodes.
  }
  else
    static assert(0, "copying of "~typeof(x).stringof~" is not handled");
  return x;
}
