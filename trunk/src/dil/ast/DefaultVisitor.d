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

class DefaultVisitor : Visitor
{
override: // Override methods of the base class.
  Declaration visit(D : Declaration)(D d)
  {
    static if (is(D == Declarations))
      foreach (node; d.children)
        visitD(node.to!(Declaration));
    static if (is(D == EmptyDeclaration))
    static if (is(D == IllegalDeclaration))
    static if (is(D == ModuleDeclaration))
    static if (is(D == AliasDeclaration) ||
               is(D == AliasDeclaration) ||
               is(D == TypedefDeclaration))
      visitD(d.decl);
    static if (is(D == EnumDeclaration))
    {
      foreach (member; d.members)
        visitD(member);
      visitT(d.baseType);
    }
    static if (is(D == EnumMember))
      visitE(d.value);
    static if (is(D == ClassDeclaration) || is( D == InterfaceDeclaration))
    {
      d.tparams && visitN(d.tparams);
      foreach (base; d.bases)
        visitT(base);
      d.decls && visitD(d.decls);
    }
    static if (is(D == StructDeclaration) || is(D == UnionDeclaration))
      d.tparams && visitN(d.tparams),
      d.decls && visitD(d.decls);
    static if (is(D == ConstructorDeclaration))
      visitN(d.parameters),
      visitS(d.funcBody);
    static if (is(D == StaticConstructorDeclaration) ||
               is(D == DestructorDeclaration) ||
               is(D == StaticDestructorDeclaration) ||
               is(D == InvariantDeclaration) ||
               is(D == UnittestDeclaration))
      visitS(d.funcBody);
    static if (is(D == FunctionDeclaration))
      visitT(d.returnType),
      d.tparams && visitN(d.tparams),
      visitN(d.params),
      visitS(d.funcBody);
    static if (is(D == VariableDeclaration))
    {
      d.typeNode && visitT(d.typeNode);
      foreach(value; d.values)
        value && visitE(value);
    }
    static if (is(D == DebugDeclaration) || is(D == VersionDeclaration))
      visitD(d.decls),
      d.elseDecls && visitD(d.elseDecls);
    static if (is(D == StaticIfDeclaration))
      visitE(d.condition),
      visitD(d.ifDecls),
      d.elseDecls && visitD(d.elseDecls);
    static if (is(D == StaticAssertDeclaration))
      visitE(d.condition),
      d.message && visitE(d.message);
    static if (is(D == TemplateDeclaration))
      d.tparams && visitN(d.tparams),
      visitD(d.decls);
    static if (is(D == NewDeclaration) || is(D == DeleteDeclaration))
      visitN(d.parameters),
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
    return d;
  }

  mixin visit!(Declarations);
  mixin visit!(EmptyDeclaration);
  mixin visit!(IllegalDeclaration);
  mixin visit!(ModuleDeclaration);
  mixin visit!(ImportDeclaration);
  mixin visit!(AliasDeclaration);
  mixin visit!(TypedefDeclaration);
  mixin visit!(EnumDeclaration);
  mixin visit!(EnumMember);
  mixin visit!(ClassDeclaration);
  mixin visit!(InterfaceDeclaration);
  mixin visit!(StructDeclaration);
  mixin visit!(UnionDeclaration);
  mixin visit!(ConstructorDeclaration);
  mixin visit!(StaticConstructorDeclaration);
  mixin visit!(DestructorDeclaration);
  mixin visit!(StaticDestructorDeclaration);
  mixin visit!(FunctionDeclaration);
  mixin visit!(VariableDeclaration);
  mixin visit!(InvariantDeclaration);
  mixin visit!(UnittestDeclaration);
  mixin visit!(DebugDeclaration);
  mixin visit!(VersionDeclaration);
  mixin visit!(StaticIfDeclaration);
  mixin visit!(StaticAssertDeclaration);
  mixin visit!(TemplateDeclaration);
  mixin visit!(NewDeclaration);
  mixin visit!(DeleteDeclaration);
  mixin visit!(ProtectionDeclaration);
  mixin visit!(StorageClassDeclaration);
  mixin visit!(LinkageDeclaration);
  mixin visit!(AlignDeclaration);
  mixin visit!(PragmaDeclaration);
  mixin visit!(MixinDeclaration);

  Expression visit(E : Expression)(E e)
  {
    static if (is(E == IllegalExpression))
    {}
    else
    static if (is(E : CondExpression))
      visitE(e.condition), visitE(e.left), visitE(e.right);
    else
    static if (is(E : BinaryExpression))
      visitE(e.left), visitE(e.right);
    else
    static if (is(E : UnaryExpression))
    {
      static if (is(E == CastExpression))
        visitT(e.type);
      visitE(e.e); // member of UnaryExpression
      static if (is(E == IndexExpression))
        foreach (arg; e.args)
          visitE(arg);
      static if (is(E == SliceExpression))
        visitE(e.left), visitE(e.right);
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
        e.parameters && visitN(e.parameters),
        visitS(e.funcBody);
      static if (is(E == ParenExpression))
        visitE(e.next);
      static if (is(E == TraitsExpression))
        visitN(e.targs);
      static if (is(E == ArrayInitializer))
        foreach (i, key; e.keys)
          key && visitE(key), visitE(e.values[i]);
      static if (is(E == StructInitializer))
        foreach (value; e.values)
          visitE(value);

    }
    return e;
  }

  mixin visit!(IllegalExpression);
  mixin visit!(CondExpression);
  mixin visit!(CommaExpression);
  mixin visit!(OrOrExpression);
  mixin visit!(AndAndExpression);
  mixin visit!(OrExpression);
  mixin visit!(XorExpression);
  mixin visit!(AndExpression);
  mixin visit!(EqualExpression);
  mixin visit!(IdentityExpression);
  mixin visit!(RelExpression);
  mixin visit!(InExpression);
  mixin visit!(LShiftExpression);
  mixin visit!(RShiftExpression);
  mixin visit!(URShiftExpression);
  mixin visit!(PlusExpression);
  mixin visit!(MinusExpression);
  mixin visit!(CatExpression);
  mixin visit!(MulExpression);
  mixin visit!(DivExpression);
  mixin visit!(ModExpression);
  mixin visit!(AssignExpression);
  mixin visit!(LShiftAssignExpression);
  mixin visit!(RShiftAssignExpression);
  mixin visit!(URShiftAssignExpression);
  mixin visit!(OrAssignExpression);
  mixin visit!(AndAssignExpression);
  mixin visit!(PlusAssignExpression);
  mixin visit!(MinusAssignExpression);
  mixin visit!(DivAssignExpression);
  mixin visit!(MulAssignExpression);
  mixin visit!(ModAssignExpression);
  mixin visit!(XorAssignExpression);
  mixin visit!(CatAssignExpression);
  mixin visit!(DotExpression);

  mixin visit!(AddressExpression);
  mixin visit!(PreIncrExpression);
  mixin visit!(PreDecrExpression);
  mixin visit!(PostIncrExpression);
  mixin visit!(PostDecrExpression);
  mixin visit!(DerefExpression);
  mixin visit!(SignExpression);
  mixin visit!(NotExpression);
  mixin visit!(CompExpression);
  mixin visit!(CallExpression);
  mixin visit!(NewExpression);
  mixin visit!(NewAnonClassExpression);
  mixin visit!(DeleteExpression);
  mixin visit!(CastExpression);
  mixin visit!(IndexExpression);
  mixin visit!(SliceExpression);
  mixin visit!(ModuleScopeExpression);

  mixin visit!(IdentifierExpression);
  mixin visit!(SpecialTokenExpression);
  mixin visit!(TemplateInstanceExpression);
  mixin visit!(ThisExpression);
  mixin visit!(SuperExpression);
  mixin visit!(NullExpression);
  mixin visit!(DollarExpression);
  mixin visit!(BoolExpression);
  mixin visit!(IntExpression);
  mixin visit!(RealExpression);
  mixin visit!(ComplexExpression);
  mixin visit!(CharExpression);
  mixin visit!(StringExpression);
  mixin visit!(ArrayLiteralExpression);
  mixin visit!(AArrayLiteralExpression);
  mixin visit!(AssertExpression);
  mixin visit!(MixinExpression);
  mixin visit!(ImportExpression);
  mixin visit!(TypeofExpression);
  mixin visit!(TypeDotIdExpression);
  mixin visit!(TypeidExpression);

  mixin visit!(IsExpression);
  mixin visit!(FunctionLiteralExpression);
  mixin visit!(ParenExpression);
  mixin visit!(TraitsExpression);
  mixin visit!(VoidInitializer);
  mixin visit!(ArrayInitializer);
  mixin visit!(StructInitializer);
  mixin visit!(AsmTypeExpression);

  mixin visit!(AsmOffsetExpression);
  mixin visit!(AsmSegExpression);
  mixin visit!(AsmPostBracketExpression);
  mixin visit!(AsmBracketExpression);
  mixin visit!(AsmLocalSizeExpression);
  mixin visit!(AsmRegisterExpression);

  Statement visit(S : Statement)(S s)
  {
    static if (is(S == Statements))
      foreach (node; s.children)
        visitS(node.to!(Statement));
    //static if (is(S == IllegalStatement))
    static if (is(S == FunctionBody))
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
    //static if (is(S == ContinueStatement))
    //static if (is(S == BreakStatement))
    static if (is(S == ReturnStatement))
      visitE(s.e);
    static if (is(S == GotoStatement))
      s.caseExpr && visitE(s.caseExpr);
    static if (is(S == WithStatement))
      visitE(s.e), visitS(s.withBody);
    static if (is(S == SynchronizedStatement))
      s.e && visitE(s.e), visitS(s.syncBody);
    static if (is(S == TryStatement))
    {
      visitS(s.tryBody);
      foreach (body_; s.catchBodies)
        visitS(body_);
      s.finallyBody && visitS(s.finallyBody);
    }
    static if (is(S == CatchBody))
      s.param && visitN(s.param), visitS(s.catchBody);
    static if (is(S == FinallyBody))
      visitS(s.finallyBody);
    static if (is(S == ScopeGuardStatement))
      visitS(s.scopeBody);
    static if (is(S == ThrowStatement))
      visitE(s.e);
    static if (is(S == VolatileStatement))
      s.volatileBody && visitS(s.volatileBody);
    static if (is(S == AsmStatement))
      visitS(s.statements);
    static if (is(S == AsmInstruction))
      foreach (e; s.operands)
        visitE(e);
    //static if (is(S == AsmAlignStatement))
    static if (is(S == PragmaStatement))
    {
      foreach (e; s.args)
        visitE(e);
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
    return s;
  }

  mixin visit!(Statements);
  mixin visit!(IllegalStatement);
  mixin visit!(EmptyStatement);
  mixin visit!(FunctionBody);
  mixin visit!(ScopeStatement);
  mixin visit!(LabeledStatement);
  mixin visit!(ExpressionStatement);
  mixin visit!(DeclarationStatement);
  mixin visit!(IfStatement);
  mixin visit!(WhileStatement);
  mixin visit!(DoWhileStatement);
  mixin visit!(ForStatement);
  mixin visit!(ForeachStatement);
  mixin visit!(ForeachRangeStatement);
  mixin visit!(SwitchStatement);
  mixin visit!(CaseStatement);
  mixin visit!(DefaultStatement);
  mixin visit!(ContinueStatement);
  mixin visit!(BreakStatement);
  mixin visit!(ReturnStatement);
  mixin visit!(GotoStatement);
  mixin visit!(WithStatement);
  mixin visit!(SynchronizedStatement);
  mixin visit!(TryStatement);
  mixin visit!(CatchBody);
  mixin visit!(FinallyBody);
  mixin visit!(ScopeGuardStatement);
  mixin visit!(ThrowStatement);
  mixin visit!(VolatileStatement);
  mixin visit!(AsmStatement);
  mixin visit!(AsmInstruction);
  mixin visit!(AsmAlignStatement);
  mixin visit!(IllegalAsmInstruction);
  mixin visit!(PragmaStatement);
  mixin visit!(MixinStatement);
  mixin visit!(StaticIfStatement);
  mixin visit!(StaticAssertStatement);
  mixin visit!(DebugStatement);
  mixin visit!(VersionStatement);

  TypeNode visit(T : TypeNode)(T t)
  {
    //static if (is(T == UndefinedType))
    //static if (is(T == IntegralType))
    //static if (is(T == IdentifierType))
    static if (is(T == QualifiedType))
      visitT(t.left), visitT(t.right);
    static if (is(T == ModuleScopeType))
      visitT(t.next);
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
      else
        visitE(t.e), t.e2 && visitE(t.e2);
    }
    static if (is(T == FunctionType) || is(T == DelegateType))
      visitT(t.returnType), visitN(t.parameters);
    static if (is(T == CFuncPointerType))
      visitT(t.next), t.params && visitN(t.params);
    static if (is(T == BaseClass))
      visitT(t.next);
    static if (is(T == ConstType) || is(T == InvariantType))
      visitT(t.next);
    return t;
  }

  mixin visit!(UndefinedType);
  mixin visit!(IntegralType);
  mixin visit!(IdentifierType);
  mixin visit!(QualifiedType);
  mixin visit!(ModuleScopeType);
  mixin visit!(TypeofType);
  mixin visit!(TemplateInstanceType);
  mixin visit!(PointerType);
  mixin visit!(ArrayType);
  mixin visit!(FunctionType);
  mixin visit!(DelegateType);
  mixin visit!(CFuncPointerType);
  mixin visit!(BaseClass);
  mixin visit!(ConstType);
  mixin visit!(InvariantType);

  Node visit(N : Parameter)(N n)
  {
    visitT(n.type);
    n.defValue && visitE(n.defValue);
    return n;
  }

  Node visit(N : Parameters)(N n)
  {
    foreach (node; n.children)
      visitN(node.to!(Parameters));
    return n;
  }

  Node visit(N : TemplateParameters)(N n)
  {
    foreach (node; n.children)
      visitN(node.to!(TemplateParameters));
    return n;
  }

  Node visit(N : TemplateArguments)(N n)
  {
    foreach (node; n.children)
      visitN(node.to!(TemplateArguments));
    return n;
  }

  Node visit(N : TemplateParameter)(N n)
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
    //static if (is(N == TemplateTupleParameter))
    return n;
  }

  mixin visit!(Parameter);
  mixin visit!(Parameters);
  mixin visit!(TemplateAliasParameter);
  mixin visit!(TemplateTypeParameter);
  mixin visit!(TemplateThisParameter);
  mixin visit!(TemplateValueParameter);
  mixin visit!(TemplateTupleParameter);
  mixin visit!(TemplateParameters);
  mixin visit!(TemplateArguments);
}
