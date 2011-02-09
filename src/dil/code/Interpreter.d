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
       dil.semantic.Types,
       dil.semantic.TypesEnum;
import dil.Float,
       dil.Complex,
       dil.Diagnostics;
import common;

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

  void error(Node n, string msg, ...)
  {
    auto location = n.begin.getErrorLocation(/+filePath+/""); // FIXME
    msg = Format(_arguments, _argptr, msg);
    auto error = new SemanticError(location, msg);
    if (diag !is null)
      diag ~= error;
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
    error(s, "cannot interpret assembler statements at compile time");
    return s;
  }

  S visit(AsmStatement s)
  {
    assert(0);
    return s;
  }

  S visit(AsmAlignStatement s)
  {
    assert(0);
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

  /// Calculates z1 + z2 or z1 - z2.
  /// Returns a new ComplexExpression.
  ComplexExpression complexPlusOrMinus(BinaryExpression e, bool minusOp)
  {
    int comb = void; // Indicates which case needs to be calculated.
    Complex z = void; // Temp variable.
    Float re, im, r2, i2;
    Expression lhs = e.lhs, rhs = e.rhs; // Left and right operand.
    auto lt = lhs.type.flagsOf(), rt = rhs.type.flagsOf(); // Type flags.
    // Initialize left-hand side.
    if (lt.isReal())
      (re = EM.toReal(lhs)), (comb = 0);
    else if (lt.isImaginary())
      (im = EM.toImag(lhs)), (comb = 3);
    else if (lt.isComplex())
      (z = EM.toComplex(lhs)), (re = z.re), (im = z.im), (comb = 6);
    // Initialize right-hand side.
    if (rt.isReal())
      (r2 = EM.toReal(rhs)), (comb += 0);
    else if (rt.isImaginary())
      (i2 = EM.toImag(rhs)), (comb += 1);
    else if (rt.isComplex())
      (z = EM.toComplex(rhs)), (r2 = z.re), (i2 = z.im), (comb += 2);
    assert(comb != 0 && comb != 4, "must be handled elsewhere");
    if (minusOp)
    { // Negate the second operand if we have a minus operation.
      if (r2) r2.neg();
      if (i2) i2.neg();
    }
    // Do the calculation.
    switch (comb)
    {
    //case 0: re = re + r2; break;             // re + r2
    case 1: im = i2; break;                    // re + i2
    case 2: im = i2; goto case 6;              // re + (r2+i2)
    case 3: re = r2; break;                    // im + r2
    //case 4: im = im + i2; break;             // im + i2
    case 5: re = r2; goto case 7;              // im + (r2+i2)
    case 6: re = re + r2; break;               // (re+im) + r2
    case 7: im = im + i2; break;               // (re+im) + i2
    case 8: re = re + r2; im = im + i2; break; // (re+im) + (r2+i2)
    default: assert(0);
    }
    return new ComplexExpression(Complex(re, im), e.type);
  }

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
    auto r = new IntExpression(EM.toInt(e.lhs) | EM.toInt(e.rhs), e.type);
    r.setLoc(e);
    return r;
  }

  E visit(XorExpression e)
  {
    auto r = new IntExpression(EM.toInt(e.lhs) ^ EM.toInt(e.rhs), e.type);
    r.setLoc(e);
    return r;
  }

  E visit(AndExpression e)
  {
    auto r = new IntExpression(EM.toInt(e.lhs) & EM.toInt(e.rhs), e.type);
    r.setLoc(e);
    return r;
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
    auto r = new IntExpression(EM.toInt(e.lhs) << EM.toInt(e.rhs), e.type);
    r.setLoc(e);
    return r;
  }

  E visit(RShiftExpression e)
  {
    Expression r;
    ulong val = EM.toInt(e.lhs), bits = EM.toInt(e.rhs);
    switch (e.lhs.type.baseType().tid)
    {
    case TYP.Int8:    val =   cast(byte)val >> bits; break;
    case TYP.UInt8:   val =  cast(ubyte)val >> bits; break;
    case TYP.Int16:   val =  cast(short)val >> bits; break;
    case TYP.UInt16:  val = cast(ushort)val >> bits; break;
    case TYP.Int32:   val =    cast(int)val >> bits; break;
    case TYP.UInt32:  val =   cast(uint)val >> bits; break;
    case TYP.Int64:   val =   cast(long)val >> bits; break;
    case TYP.UInt64:  val =  cast(ulong)val >> bits; break;
    //case TYP.Int128:  val =   cast(cent)val >> bits; break;
    //case TYP.UInt128: val =  cast(ucent)val >> bits; break;
    case TYP.Error:  r = e; return r;
    default: assert(0);
    }
    r = new IntExpression(val, e.type);
    r.setLoc(e);
    return r;
  }

  E visit(URShiftExpression e)
  {
    Expression r;
    ulong val = EM.toInt(e.lhs), bits = EM.toInt(e.rhs);
    switch (e.lhs.type.baseType().tid)
    {
    case TYP.Int8, TYP.UInt8:     val =  cast(ubyte)val; break;
    case TYP.Int16, TYP.UInt16:   val = cast(ushort)val; break;
    case TYP.Int32, TYP.UInt32:   val =   cast(uint)val; break;
    case TYP.Int64, TYP.UInt64:   val =  cast(ulong)val; break;
    //case TYP.Int128, TYP.UInt128: val =  cast(ucent)val; break;
    case TYP.Error:  r = e; return r;
    default: assert(0);
    }
    r = new IntExpression(val >> bits, e.type);
    r.setLoc(e);
    return r;
  }

  E visit(PlusExpression e)
  {
    Expression r, lhs = e.lhs, rhs = e.rhs;
    auto et = e.type.flagsOf();
    if (et.isReal() || et.isImaginary()) // Boths operands are real or imag.
      r = new FloatExpression(
        EM.toRealOrImag(lhs) + EM.toRealOrImag(rhs), e.type);
    else if (et.isComplex())
      r = complexPlusOrMinus(e, false);
    else
      r = new IntExpression(EM.toInt(lhs) + EM.toInt(rhs), e.type);
    r.setLoc(e);
    return r;
  }

  E visit(MinusExpression e)
  {
    Expression r, lhs = e.lhs, rhs = e.rhs;
    auto et = e.type.flagsOf();
    if (et.isReal() || et.isImaginary()) // Boths operands are real or imag.
      r = new FloatExpression(
        EM.toRealOrImag(lhs) - EM.toRealOrImag(rhs), e.type);
    else if (et.isComplex())
      r = complexPlusOrMinus(e, true);
    else
      r = new IntExpression(EM.toInt(lhs) - EM.toInt(rhs), e.type);
    r.setLoc(e);
    return r;
  }

  E visit(CatExpression e)
  {
    return e;
  }

  E visit(MulExpression e)
  {
    Expression r, lhs = e.lhs, rhs = e.rhs;
    auto et = e.type.flagsOf();
    if (et.isFloating())
    {
      Complex z = EM.toComplex(lhs) * EM.toComplex(rhs);
      if (et.isReal() || et.isImaginary())
        r = new FloatExpression(et.isReal() ? z.re : z.im, e.type);
      else
        assert(et.isComplex()), r = new ComplexExpression(z, e.type);
    }
    else
      r = new IntExpression(EM.toInt(lhs) * EM.toInt(rhs), e.type);
    return r;
  }

  E visit(DivExpression e)
  {
    Expression r, lhs = e.lhs, rhs = e.rhs;
    auto et = e.type.flagsOf();
    if (et.isFloating())
    {
      Complex z = EM.toComplex(lhs) / EM.toComplex(rhs);
      if (et.isReal() || et.isImaginary())
        r = new FloatExpression(et.isReal() ? z.re : z.im, e.type);
      else
        assert(et.isComplex()), r = new ComplexExpression(z, e.type);
    }
    else
    {
      ulong x, x1 = EM.toInt(lhs), x2 = EM.toInt(rhs);
      if (x2 == 0)
        error(rhs, "division by 0");
      else if (lhs.type.isSigned() && rhs.type.isSigned())
        x = cast(long)x1 / cast(long)x2;
      else
        x = x1 / x2;
      r = new IntExpression(x, e.type);
    }
    return r;
  }

  E visit(ModExpression e)
  {
    Expression r, lhs = e.lhs, rhs = e.rhs;
    auto et = e.type.flagsOf();
    if (et.isFloating())
    {
      Complex z = EM.toComplex(lhs) % EM.toComplex(rhs);
      if (et.isReal() || et.isImaginary())
        r = new FloatExpression(et.isReal() ? z.re : z.im, e.type);
      else
        assert(et.isComplex()), r = new ComplexExpression(z, e.type);
    }
    else
    {
      ulong x, x1 = EM.toInt(lhs), x2 = EM.toInt(rhs);
      if (x2 == 0)
        error(rhs, "modulo by 0");
      else if (lhs.type.isSigned() && rhs.type.isSigned())
        x = cast(long)x1 % cast(long)x2;
      else
        x = x1 % x2;
      r = new IntExpression(x, e.type);
    }
    return r;
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
    auto r = new IntExpression(EM.isBool(e) == 0, e.type);
    r.setLoc(e);
    return r;
  }

  E visit(CompExpression e)
  {
    auto r = new IntExpression(~EM.toInt(e), e.type);
    r.setLoc(e);
    return r;
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
  { // Just return e.
    return e;
  }

  E visit(DollarExpression e)
  {
    return e;
  }

  E visit(BoolExpression e)
  { // Just return the value of e.
    return e.value;
  }

  E visit(IntExpression e)
  { // Just return e.
    return e;
  }

  E visit(FloatExpression e)
  { // Just return e.
    return e;
  }

  E visit(ComplexExpression e)
  { // Just return e.
    return e;
  }

  E visit(CharExpression e)
  { // Just return e.
    return e;
  }

  E visit(StringExpression e)
  { // Just return e.
    return e;
  }

  E visit(ArrayLiteralExpression e)
  {
    if (!e.values)
      goto Lerr;
    Expression[] elems_dup; // Duplicate if the elements changed.
    foreach (i, elem; e.values)
    {
      auto newelem = visitE(elem);
      if (newelem is NAR)
        goto Lerr;
      if (newelem !is elem)
      {
        if (!elems_dup)
          elems_dup = e.values.dup;
        elems_dup[i] = newelem; // Overwrite if the element changed.
      }
    }
    Expression r = e;
    if (elems_dup)
    { // Make a new array literal.
      r = new ArrayLiteralExpression(elems_dup);
      r.setLoc(e);
      r.type = e.type;
    }
    return r;
  Lerr:
    error(e, "cannot interpret array literal");
    return NAR;
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
    assert(0);
    return e;
  }

  E visit(AsmOffsetExpression e)
  {
    assert(0);
    return e;
  }

  E visit(AsmSegExpression e)
  {
    assert(0);
    return e;
  }

  E visit(AsmPostBracketExpression e)
  {
    assert(0);
    return e;
  }

  E visit(AsmBracketExpression e)
  {
    assert(0);
    return e;
  }

  E visit(AsmLocalSizeExpression e)
  {
    assert(0);
    return e;
  }

  E visit(AsmRegisterExpression e)
  {
    assert(0);
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
