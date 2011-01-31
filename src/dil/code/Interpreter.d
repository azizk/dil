/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very low)
module dil.code.Interpreter;

import dil.code.NotAResult;
import dil.code.Methods;
import dil.ast.Visitor,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;
import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Types;
import dil.Diagnostics;

/// Used for compile-time evaluation of D code.
class Interpreter : Visitor
{
  Diagnostics diag;
  EMethods EM;

  alias dil.code.NotAResult.NAR NAR;

  /// Evaluates the expression e.
  /// Returns: NAR or a value.
  static Expression interpret(Expression e, Diagnostics diag)
  {
    return (new Interpreter(diag)).eval(e);
  }

  /// Executes the function at compile-time with the given arguments.
  /// Returns: NAR or a value.
  static Expression interpret(FunctionDeclaration fd, Expression[] args,
                              Diagnostics diag)
  {
    return (new Interpreter(diag)).eval(fd, args);
  }

  /// Constructs an Interpreter object.
  this(Diagnostics diag)
  {
    this.diag = diag;
    this.EM = new EMethods(diag);
  }

  /// Start evaluation.
  Expression eval(Expression e)
  {
    return e;
  }
  // TODO: are eval() methods needed for other Nodes?

  /// Start evaluation of a function.
  Expression eval(FunctionDeclaration fd, Expression[] args)
  {
    // We cache this result so that we don't blindly try to reevaluate
    // functions that can't be evaluated at compile time
    if (fd.cantInterpret)
      return NAR;

    // TODO: check for nested/method

    // Check for invalid parameter types
    if (fd.params.hasVariadic() || fd.params.hasLazy())
    {
      fd.cantInterpret = true;
      return NAR;
    }

    // remove me plx
    assert(false);
    return NAR;
  }

  /// Some handy aliases.
  private alias Declaration D;
  private alias Expression E; /// ditto
  private alias Statement S; /// ditto
  private alias TypeNode T; /// ditto
  private alias Parameter P; /// ditto
  private alias Node N; /// ditto
  private alias NodeKind NK; /// ditto

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                Declarations                               |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  D visit(CompoundDeclaration d)
  {
    return d;
  }

  D visit(IllegalDeclaration)
  { assert(0, "interpreting invalid AST"); return null; }

  // D visit(EmptyDeclaration ed)
  // { return ed; }

  // D visit(ModuleDeclaration)
  // { return null; }

  D visit(ImportDeclaration d)
  {
    return d;
  }

  D visit(AliasDeclaration ad)
  {
    return ad;
  }

  D visit(TypedefDeclaration td)
  {
    return td;
  }

  D visit(EnumDeclaration d)
  {
    return d;
  }

  D visit(EnumMemberDeclaration d)
  {
    return d;
  }

  D visit(ClassDeclaration d)
  {
    return d;
  }

  D visit(InterfaceDeclaration d)
  {
    return d;
  }

  D visit(StructDeclaration d)
  {
    return d;
  }

  D visit(UnionDeclaration d)
  {
    return d;
  }

  D visit(ConstructorDeclaration d)
  {
    return d;
  }

  D visit(StaticConstructorDeclaration d)
  {
    return d;
  }

  D visit(DestructorDeclaration d)
  {
    return d;
  }

  D visit(StaticDestructorDeclaration d)
  {
    return d;
  }

  D visit(FunctionDeclaration d)
  {
    return d;
  }

  D visit(VariablesDeclaration vd)
  {
    return vd;
  }

  D visit(InvariantDeclaration d)
  {
    return d;
  }

  D visit(UnittestDeclaration d)
  {
    return d;
  }

  D visit(DebugDeclaration d)
  {
    return d;
  }

  D visit(VersionDeclaration d)
  {
    return d;
  }

  D visit(TemplateDeclaration d)
  {
    return d;
  }

  D visit(NewDeclaration d)
  {
    return d;
  }

  D visit(DeleteDeclaration d)
  {
    return d;
  }

  // Attributes:

  D visit(ProtectionDeclaration d)
  {
    return d;
  }

  D visit(StorageClassDeclaration d)
  {
    return d;
  }

  D visit(LinkageDeclaration d)
  {
    return d;
  }

  D visit(AlignDeclaration d)
  {
    return d;
  }

  D visit(StaticAssertDeclaration d)
  {
    return d;
  }

  D visit(StaticIfDeclaration d)
  {
    return d;
  }

  D visit(MixinDeclaration d)
  {
    return d;
  }

  D visit(PragmaDeclaration d)
  {
    return d;
  }
} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                 Statements                                |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  S visit(CompoundStatement s)
  {
    return s;
  }

  S visit(IllegalStatement)
  { assert(0, "interpreting invalid AST"); return null; }

  S visit(EmptyStatement s)
  {
    return s;
  }

  S visit(FuncBodyStatement s)
  {
    return s;
  }

  S visit(ScopeStatement s)
  {
    return s;
  }

  S visit(LabeledStatement s)
  {
    return s;
  }

  S visit(ExpressionStatement s)
  {
    return s;
  }

  S visit(DeclarationStatement s)
  {
    return s;
  }

  S visit(IfStatement s)
  {
    return s;
  }

  S visit(WhileStatement s)
  {
    return s;
  }

  S visit(DoWhileStatement s)
  {
    return s;
  }

  S visit(ForStatement s)
  {
    return s;
  }

  S visit(ForeachStatement s)
  {
    return s;
  }

  // D2.0
  S visit(ForeachRangeStatement s)
  {
    return s;
  }

  S visit(SwitchStatement s)
  {
    return s;
  }

  S visit(CaseStatement s)
  {
    return s;
  }

  S visit(DefaultStatement s)
  {
    return s;
  }

  S visit(ContinueStatement s)
  {
    return s;
  }

  S visit(BreakStatement s)
  {
    return s;
  }

  S visit(ReturnStatement s)
  {
    return s;
  }

  S visit(GotoStatement s)
  {
    return s;
  }

  S visit(WithStatement s)
  {
    return s;
  }

  S visit(SynchronizedStatement s)
  {
    return s;
  }

  S visit(TryStatement s)
  {
    return s;
  }

  S visit(CatchStatement s)
  {
    return s;
  }

  S visit(FinallyStatement s)
  {
    return s;
  }

  S visit(ScopeGuardStatement s)
  {
    return s;
  }

  S visit(ThrowStatement s)
  {
    return s;
  }

  S visit(VolatileStatement s)
  {
    return s;
  }

  S visit(AsmBlockStatement s)
  {
    return s;
  }

  S visit(AsmStatement s)
  {
    return s;
  }

  S visit(AsmAlignStatement s)
  {
    return s;
  }

  S visit(IllegalAsmStatement)
  { assert(0, "interpreting invalid AST"); return null; }

  S visit(PragmaStatement s)
  {
    return s;
  }

  S visit(MixinStatement s)
  {
    return s;
  }

  S visit(StaticIfStatement s)
  {
    return s;
  }

  S visit(StaticAssertStatement s)
  {
    return s;
  }

  S visit(DebugStatement s)
  {
    return s;
  }

  S visit(VersionStatement s)
  {
    return s;
  }
} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                Expressions                                |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  E visit(IllegalExpression)
  { assert(0, "interpreting invalid AST"); return null; }

  E visit(CondExpression e)
  {
    auto r = visitE(e.condition);
    if (r !is NAR)
    {
      auto bval = EM.isBool(r);
      if (bval == 1)      r = visitE(e.lhs);
      else if (bval == 0) r = visitE(e.rhs);
      else                r = NAR;
    }
    return r;
  }

  E visit(CommaExpression e)
  {
    return visitE(e.lhs) is NAR ? NAR : visitE(e.rhs);
  }

  E visit(OrOrExpression e)
  {
    auto r = EM.toBool(visitE(e.lhs));
    if (r !is NAR && r.to!(IntExpression).number == 0)
      r = EM.toBool(visitE(e.rhs));
    return r;
  }

  E visit(AndAndExpression e)
  {
    auto r = EM.toBool(visitE(e.lhs));
    if (r !is NAR && r.to!(IntExpression).number == 1)
      r = EM.toBool(visitE(e.rhs));
    return r;
  }

  E visit(OrExpression e)
  {
    return e;
  }

  E visit(XorExpression e)
  {
    return e;
  }

  E visit(AndExpression e)
  {
    return e;
  }

  E visit(EqualExpression e)
  {
    return e;
  }

  E visit(IdentityExpression e)
  {
    return e;
  }

  E visit(RelExpression e)
  {
    return e;
  }

  E visit(InExpression e)
  {
    return e;
  }

  E visit(LShiftExpression e)
  {
    return e;
  }

  E visit(RShiftExpression e)
  {
    return e;
  }

  E visit(URShiftExpression e)
  {
    return e;
  }

  E visit(PlusExpression e)
  {
    return e;
  }

  E visit(MinusExpression e)
  {
    return e;
  }

  E visit(CatExpression e)
  {
    return e;
  }

  E visit(MulExpression e)
  {
    return e;
  }

  E visit(DivExpression e)
  {
    return e;
  }

  E visit(ModExpression e)
  {
    return e;
  }

  E visit(AssignExpression e)
  {
    return e;
  }

  E visit(LShiftAssignExpression e)
  {
    return e;
  }

  E visit(RShiftAssignExpression e)
  {
    return e;
  }

  E visit(URShiftAssignExpression e)
  {
    return e;
  }

  E visit(OrAssignExpression e)
  {
    return e;
  }

  E visit(AndAssignExpression e)
  {
    return e;
  }

  E visit(PlusAssignExpression e)
  {
    return e;
  }

  E visit(MinusAssignExpression e)
  {
    return e;
  }

  E visit(DivAssignExpression e)
  {
    return e;
  }

  E visit(MulAssignExpression e)
  {
    return e;
  }

  E visit(ModAssignExpression e)
  {
    return e;
  }

  E visit(XorAssignExpression e)
  {
    return e;
  }

  E visit(CatAssignExpression e)
  {
    return e;
  }

  E visit(AddressExpression e)
  {
    return e;
  }

  E visit(PreIncrExpression e)
  {
    return e;
  }

  E visit(PreDecrExpression e)
  {
    return e;
  }

  E visit(PostIncrExpression e)
  {
    return e;
  }

  E visit(PostDecrExpression e)
  {
    return e;
  }

  E visit(DerefExpression e)
  {
    return e;
  }

  E visit(SignExpression e)
  {
    return e;
  }

  E visit(NotExpression e)
  {
    return e;
  }

  E visit(CompExpression e)
  {
    return e;
  }

  E visit(CallExpression e)
  {
    return e;
  }

  E visit(NewExpression e)
  {
    return e;
  }

  E visit(NewClassExpression e)
  {
    return e;
  }

  E visit(DeleteExpression e)
  {
    return e;
  }

  E visit(CastExpression e)
  {
    return e;
  }

  E visit(IndexExpression e)
  {
    return e;
  }

  E visit(SliceExpression e)
  {
    return e;
  }

  E visit(ModuleScopeExpression e)
  {
    return e;
  }

  E visit(IdentifierExpression e)
  {
    return e;
  }

  E visit(TemplateInstanceExpression e)
  {
    return e;
  }

  E visit(SpecialTokenExpression e)
  {
    return e;
  }

  E visit(ThisExpression e)
  {
    return e;
  }

  E visit(SuperExpression e)
  {
    return e;
  }

  E visit(NullExpression e)
  {
    return e;
  }

  E visit(DollarExpression e)
  {
    return e;
  }

  E visit(BoolExpression e)
  {
    return e.value;
  }

  E visit(IntExpression e)
  {
    return e;
  }

  E visit(RealExpression e)
  {
    return e;
  }

  E visit(ComplexExpression e)
  {
    return e;
  }

  E visit(CharExpression e)
  {
    return e;
  }

  E visit(StringExpression e)
  {
    return e;
  }

  E visit(ArrayLiteralExpression e)
  {
    return e;
  }

  E visit(AArrayLiteralExpression e)
  {
    return e;
  }

  E visit(AssertExpression e)
  {
    return e;
  }

  E visit(MixinExpression e)
  {
    return e;
  }

  E visit(ImportExpression e)
  {
    return e;
  }

  E visit(TypeofExpression e)
  {
    return e;
  }

  E visit(TypeDotIdExpression e)
  {
    return e;
  }

  E visit(TypeidExpression e)
  {
    return e;
  }

  E visit(IsExpression e)
  {
    return e;
  }

  E visit(ParenExpression e)
  {
    return e;
  }

  E visit(FunctionLiteralExpression e)
  {
    return e;
  }

  E visit(TraitsExpression e) // D2.0
  {
    return e;
  }

  E visit(VoidInitExpression e)
  {
    return e;
  }

  E visit(ArrayInitExpression e)
  {
    return e;
  }

  E visit(StructInitExpression e)
  {
    return e;
  }

  E visit(AsmTypeExpression e)
  {
    return e;
  }

  E visit(AsmOffsetExpression e)
  {
    return e;
  }

  E visit(AsmSegExpression e)
  {
    return e;
  }

  E visit(AsmPostBracketExpression e)
  {
    return e;
  }

  E visit(AsmBracketExpression e)
  {
    return e;
  }

  E visit(AsmLocalSizeExpression e)
  {
    return e;
  }

  E visit(AsmRegisterExpression e)
  {
    return e;
  }
} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                   Types                                   |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  T visit(IllegalType)
  { assert(0, "interpreting invalid AST"); return null; }

  T visit(IntegralType t)
  {
    return t;
  }

  T visit(ModuleScopeType t)
  {
    return t;
  }

  T visit(IdentifierType t)
  {
    return t;
  }

  T visit(TypeofType t)
  {
    return t;
  }

  T visit(TemplateInstanceType t)
  {
    return t;
  }

  T visit(PointerType t)
  {
    return t;
  }

  T visit(ArrayType t)
  {
    return t;
  }

  T visit(FunctionType t)
  {
    return t;
  }

  T visit(DelegateType t)
  {
    return t;
  }

  T visit(BaseClassType t)
  {
    return t;
  }

  T visit(ConstType t) // D2.0
  {
    return t;
  }

  T visit(ImmutableType t) // D2.0
  {
    return t;
  }
} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                 Parameters                                |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  N visit(Parameter p)
  {
    return p;
  }

  N visit(Parameters p)
  {
    return p;
  }

  N visit(TemplateAliasParameter p)
  {
    return p;
  }

  N visit(TemplateTypeParameter p)
  {
    return p;
  }

  N visit(TemplateThisParameter p) // D2.0
  {
    return p;
  }

  N visit(TemplateValueParameter p)
  {
    return p;
  }

  N visit(TemplateTupleParameter p)
  {
    return p;
  }

  N visit(TemplateParameters p)
  {
    return p;
  }

  N visit(TemplateArguments p)
  {
    return p;
  }
} // override
}
