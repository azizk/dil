/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.DefaultVisitor;

import dil.ast.Visitor;

import dil.ast.Node;
import dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;
import common;

/++
  This huge template function, when instantiated for a certain node class,
  generates a body of visit method calls on the subnodes.
+/
returnType!(T.stringof) visitDefault(T)(T t)
{
  assert(t !is null, "node passed to visitDefault() is null");
  //Stdout(t).newline;

  alias t d, s, e, n; // Variable aliases of t.

  static if (is(T : Declaration))
  {
    alias T D;
    static if (is(D == CompoundDeclaration))
      foreach (decl; d.decls)
        visitD(decl);
    //EmptyDeclaration,
    //IllegalDeclaration,
    //ModuleDeclaration have no subnodes.
    static if (is(D == AliasDeclaration) ||
               is(D == TypedefDeclaration))
      visitD(d.decl);
    static if (is(D == EnumDeclaration))
    {
      d.baseType && visitT(d.baseType);
      foreach (member; d.members)
        visitD(member);
    }
    static if (is(D == EnumMemberDeclaration))
      d.value && visitE(d.value);
    static if (is(D == ClassDeclaration) || is( D == InterfaceDeclaration))
    {
//       visitN(d.tparams);
      foreach (base; d.bases)
        visitT(base);
      d.decls && visitD(d.decls);
    }
    static if (is(D == StructDeclaration) || is(D == UnionDeclaration))
//       visitN(d.tparams),
      d.decls && visitD(d.decls);
    static if (is(D == ConstructorDeclaration))
      visitN(d.params), visitS(d.funcBody);
    static if (is(D == StaticConstructorDeclaration) ||
               is(D == DestructorDeclaration) ||
               is(D == StaticDestructorDeclaration) ||
               is(D == InvariantDeclaration) ||
               is(D == UnittestDeclaration))
      visitS(d.funcBody);
    static if (is(D == FunctionDeclaration))
      visitT(d.returnType),
//       visitN(d.tparams),
      visitN(d.params),
      visitS(d.funcBody);
    static if (is(D == VariablesDeclaration))
    {
      d.typeNode && visitT(d.typeNode);
      foreach(init; d.inits)
        init && visitE(init);
    }
    static if (is(D == DebugDeclaration) || is(D == VersionDeclaration))
      d.decls && visitD(d.decls),
      d.elseDecls && visitD(d.elseDecls);
    static if (is(D == StaticIfDeclaration))
      visitE(d.condition),
      visitD(d.ifDecls),
      d.elseDecls && visitD(d.elseDecls);
    static if (is(D == StaticAssertDeclaration))
      visitE(d.condition),
      d.message && visitE(d.message);
    static if (is(D == TemplateDeclaration))
      visitN(d.tparams),
      visitD(d.decls);
    static if (is(D == NewDeclaration) || is(D == DeleteDeclaration))
      visitN(d.params),
      visitS(d.funcBody);
    static if (is(D == ProtectionDeclaration) ||
               is(D == StorageClassDeclaration) ||
               is(D == LinkageDeclaration) ||
               is(D == AlignDeclaration))
      visitD(d.decls);
    static if (is(D == PragmaDeclaration))
    {
      foreach (arg; d.args)
        visitE(arg);
      visitD(d.decls);
    }
    static if (is(D == MixinDeclaration))
      d.templateExpr ? visitE(d.templateExpr) : visitE(d.argument);
  }
  else
  static if (is(T : Expression))
  {
    alias T E;
    static if (is(E == IllegalExpression))
    {}
    else
    static if (is(E : CondExpression))
      visitE(e.condition), visitE(e.lhs), visitE(e.rhs);
    else
    static if (is(E : BinaryExpression))
      visitE(e.lhs), visitE(e.rhs);
    else
    static if (is(E : UnaryExpression))
    {
      static if (is(E == CastExpression))
        visitT(e.type);
      visitE(e.e); // Visit member in base class UnaryExpression.
      static if (is(E == IndexExpression))
        foreach (arg; e.args)
          visitE(arg);
      static if (is(E == SliceExpression))
        e.left && (visitE(e.left), visitE(e.right));
      static if (is(E == AsmPostBracketExpression))
        visitE(e.e2);
    }
    else
    {
      static if (is(E == NewExpression))
      {
        foreach (arg; e.newArgs)
          visitE(arg);
        visitT(e.type);
        foreach (arg; e.ctorArgs)
          visitE(arg);
      }
      static if (is(E == NewAnonClassExpression))
      {
        foreach (arg; e.newArgs)
          visitE(arg);
        foreach (base; e.bases)
          visitT(base);
        foreach (arg; e.ctorArgs)
          visitE(arg);
        visitD(e.decls);
      }
      static if (is(E == AsmBracketExpression))
        visitE(e.e);
      static if (is(E == TemplateInstanceExpression))
        e.targs && visitN(e.targs);
      static if (is(E == ArrayLiteralExpression))
        foreach (value; e.values)
          visitE(value);
      static if (is(E == AArrayLiteralExpression))
        foreach (i, key; e.keys)
          visitE(key), visitE(e.values[i]);
      static if (is(E == AssertExpression))
        visitE(e.expr), e.msg && visitE(e.msg);
      static if (is(E == MixinExpression) ||
                 is(E == ImportExpression))
        visitE(e.expr);
      static if (is(E == TypeofExpression) ||
                 is(E == TypeDotIdExpression) ||
                 is(E == TypeidExpression))
        visitT(e.type);
      static if (is(E == IsExpression))
        visitT(e.type), e.specType && visitT(e.specType),
        e.tparams && visitN(e.tparams);
      static if (is(E == FunctionLiteralExpression))
        e.returnType && visitT(e.returnType),
        e.params && visitN(e.params),
        visitS(e.funcBody);
      static if (is(E == ParenExpression))
        visitE(e.next);
      static if (is(E == TraitsExpression))
        visitN(e.targs);
      // VoidInitializer has no subnodes.
      static if (is(E == ArrayInitExpression))
        foreach (i, key; e.keys)
          key && visitE(key), visitE(e.values[i]);
      static if (is(E == StructInitExpression))
        foreach (value; e.values)
          visitE(value);
    }
  }
  else
  static if (is(T : Statement))
  {
    alias T S;
    static if (is(S == CompoundStatement))
      foreach (node; s.children)
        visitS(cast(Statement)cast(void*)node);
    //IllegalStatement has no subnodes.
    static if (is(S == FuncBodyStatement))
      s.funcBody && visitS(s.funcBody),
      s.inBody && visitS(s.inBody),
      s.outBody && visitS(s.outBody);
    static if (is(S == ScopeStatement) || is(S == LabeledStatement))
      visitS(s.s);
    static if (is(S == ExpressionStatement))
      visitE(s.e);
    static if (is(S == DeclarationStatement))
      visitD(s.decl);
    static if (is(S == IfStatement))
    {
      s.variable ? cast(Node)visitS(s.variable) : visitE(s.condition);
      visitS(s.ifBody), s.elseBody && visitS(s.elseBody);
    }
    static if (is(S == WhileStatement))
      visitE(s.condition), visitS(s.whileBody);
    static if (is(S == DoWhileStatement))
      visitS(s.doBody), visitE(s.condition);
    static if (is(S == ForStatement))
      s.init && visitS(s.init),
      s.condition && visitE(s.condition),
      s.increment && visitE(s.increment),
      visitS(s.forBody);
    static if (is(S == ForeachStatement))
      visitN(s.params), visitE(s.aggregate), visitS(s.forBody);
    static if (is(S == ForeachRangeStatement))
      visitN(s.params), visitE(s.lower), visitE(s.upper), visitS(s.forBody);
    static if (is(S == SwitchStatement))
      visitE(s.condition), visitS(s.switchBody);
    static if (is(S == CaseStatement))
    {
      foreach (value; s.values)
        visitE(value);
      visitS(s.caseBody);
    }
    static if (is(S == DefaultStatement))
      visitS(s.defaultBody);
    //ContinueStatement,
    //BreakStatement have no subnodes.
    static if (is(S == ReturnStatement))
      s.e && visitE(s.e);
    static if (is(S == GotoStatement))
      s.caseExpr && visitE(s.caseExpr);
    static if (is(S == WithStatement))
      visitE(s.e), visitS(s.withBody);
    static if (is(S == SynchronizedStatement))
      s.e && visitE(s.e), visitS(s.syncBody);
    static if (is(S == TryStatement))
    {
      visitS(s.tryBody);
      foreach (catchBody; s.catchBodies)
        visitS(catchBody);
      s.finallyBody && visitS(s.finallyBody);
    }
    static if (is(S == CatchStatement))
      s.param && visitN(s.param), visitS(s.catchBody);
    static if (is(S == FinallyStatement))
      visitS(s.finallyBody);
    static if (is(S == ScopeGuardStatement))
      visitS(s.scopeBody);
    static if (is(S == ThrowStatement))
      visitE(s.e);
    static if (is(S == VolatileStatement))
      s.volatileBody && visitS(s.volatileBody);
    static if (is(S == AsmBlockStatement))
      visitS(s.statements);
    static if (is(S == AsmStatement))
      foreach (op; s.operands)
        visitE(op);
    //AsmAlignStatement has no subnodes.
    static if (is(S == PragmaStatement))
    {
      foreach (arg; s.args)
        visitE(arg);
      visitS(s.pragmaBody);
    }
    static if (is(S == MixinStatement))
      visitE(s.templateExpr);
    static if (is(S == StaticIfStatement))
      visitE(s.condition), visitS(s.ifBody), s.elseBody && visitS(s.elseBody);
    static if (is(S == StaticAssertStatement))
      visitE(s.condition), s.message && visitE(s.message);
    static if (is(S == DebugStatement) || is(S == VersionStatement))
      visitS(s.mainBody), s.elseBody && visitS(s.elseBody);
  }
  else
  static if (is(T : TypeNode))
  {
    //IllegalType,
    //IntegralType,
    //IdentifierType have no subnodes.
    static if (is(T == QualifiedType))
      visitT(t.lhs), visitT(t.rhs);
    static if (is(T == TypeofType))
      visitE(t.e);
    static if (is(T == TemplateInstanceType))
      t.targs && visitN(t.targs);
    static if (is(T == PointerType))
      visitT(t.next);
    static if (is(T == ArrayType))
    {
      visitT(t.next);
      if (t.assocType)
        visitT(t.assocType);
      else if (t.e1)
        visitE(t.e1), t.e2 && visitE(t.e2);
    }
    static if (is(T == FunctionType) || is(T == DelegateType))
      visitT(t.returnType), visitN(t.params);
    static if (is(T == CFuncPointerType))
      visitT(t.next), t.params && visitN(t.params);
    static if (is(T == ModuleScopeType) ||
               is(T == BaseClassType) ||
               is(T == ConstType) ||
               is(T == InvariantType))
      visitT(t.next);
  }
  else
  static if (is(T == Parameter))
  {
    n.type && visitT(n.type);
    n.defValue && visitE(n.defValue);
  }
  else
  static if (is(T == Parameters) ||
             is(T == TemplateParameters) ||
             is(T == TemplateArguments))
  {
    foreach (node; n.children)
      visitN(node);
  }
  else
  static if (is(T : TemplateParameter))
  {
    static if (is(N == TemplateAliasParameter) ||
               is(N == TemplateTypeParameter) ||
               is(N == TemplateThisParameter))
      n.specType && visitN(n.specType),
      n.defType && visitN(n.defType);
    static if (is(N == TemplateValueParameter))
      visitT(n.valueType),
      n.specValue && visitN(n.specValue),
      n.defValue && visitN(n.defValue);
    //TemplateTupleParameter has no subnodes.
  }
  else
    assert(0, "Missing default visit method for: "~t.classinfo.name);
  return t;
}

/++
  Generate default visit methods.
  E.g:
  private mixin .visitDefault!(ClassDeclaration) _ClassDeclaration;
  override returnType!("ClassDeclaration") visit(ClassDeclaration node)
  { return _ClassDeclaration.visitDefault(node); }
+/
char[] generateDefaultVisitMethods()
{
  char[] text;
  foreach (className; classNames)
    text ~= "private mixin .visitDefault!("~className~") _"~className~";\n"
            "override returnType!(\""~className~"\") visit("~className~" node){return _"~className~".visitDefault(node);}\n";
  return text;
}
// pragma(msg, generateDefaultVisitMethods());

/++
  This class provides default methods for traversing nodes in a syntax tree.
+/
class DefaultVisitor : Visitor
{
  // Comment out if too many errors are shown.
  mixin(generateDefaultVisitMethods());
}
