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
  static Expression interpret(FunctionDecl fd, Expression[] args,
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
  Expression eval(FunctionDecl fd, Expression[] args)
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
  D visit(CompoundDecl d)
  {
    return d;
  }

  D visit(IllegalDecl)
  { assert(0, "interpreting invalid AST"); return null; }

  // D visit(EmptyDecl ed)
  // { return ed; }

  // D visit(ModuleDecl)
  // { return null; }

  D visit(ImportDecl d)
  {
    return d;
  }

  D visit(AliasDecl ad)
  {
    return ad;
  }

  D visit(TypedefDecl td)
  {
    return td;
  }

  D visit(EnumDecl d)
  {
    return d;
  }

  D visit(EnumMemberDecl d)
  {
    return d;
  }

  D visit(ClassDecl d)
  {
    return d;
  }

  D visit(InterfaceDecl d)
  {
    return d;
  }

  D visit(StructDecl d)
  {
    return d;
  }

  D visit(UnionDecl d)
  {
    return d;
  }

  D visit(ConstructorDecl d)
  {
    return d;
  }

  D visit(StaticCtorDecl d)
  {
    return d;
  }

  D visit(DestructorDecl d)
  {
    return d;
  }

  D visit(StaticDtorDecl d)
  {
    return d;
  }

  D visit(FunctionDecl d)
  {
    return d;
  }

  D visit(VariablesDecl vd)
  {
    return vd;
  }

  D visit(InvariantDecl d)
  {
    return d;
  }

  D visit(UnittestDecl d)
  {
    return d;
  }

  D visit(DebugDecl d)
  {
    return d;
  }

  D visit(VersionDecl d)
  {
    return d;
  }

  D visit(TemplateDecl d)
  {
    return d;
  }

  D visit(NewDecl d)
  {
    return d;
  }

  D visit(DeleteDecl d)
  {
    return d;
  }

  // Attributes:

  D visit(ProtectionDecl d)
  {
    return d;
  }

  D visit(StorageClassDecl d)
  {
    return d;
  }

  D visit(LinkageDecl d)
  {
    return d;
  }

  D visit(AlignDecl d)
  {
    return d;
  }

  D visit(StaticAssertDecl d)
  {
    return d;
  }

  D visit(StaticIfDecl d)
  {
    return d;
  }

  D visit(MixinDecl d)
  {
    return d;
  }

  D visit(PragmaDecl d)
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
  /// Returns a new ComplexExpr.
  ComplexExpr complexPlusOrMinus(BinaryExpr e, bool minusOp)
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
    return new ComplexExpr(Complex(re, im), e.type);
  }

override
{
  E visit(IllegalExpr)
  { assert(0, "interpreting invalid AST"); return null; }

  E visit(CondExpr e)
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

  E visit(CommaExpr e)
  {
    return visitE(e.lhs) is NAR ? NAR : visitE(e.rhs);
  }

  E visit(OrOrExpr e)
  {
    auto r = EM.toBool(visitE(e.lhs));
    if (r !is NAR && r.to!(IntExpr).number == 0)
      r = EM.toBool(visitE(e.rhs));
    return r;
  }

  E visit(AndAndExpr e)
  {
    auto r = EM.toBool(visitE(e.lhs));
    if (r !is NAR && r.to!(IntExpr).number == 1)
      r = EM.toBool(visitE(e.rhs));
    return r;
  }

  E visit(OrExpr e)
  {
    auto r = new IntExpr(EM.toInt(e.lhs) | EM.toInt(e.rhs), e.type);
    r.setLoc(e);
    return r;
  }

  E visit(XorExpr e)
  {
    auto r = new IntExpr(EM.toInt(e.lhs) ^ EM.toInt(e.rhs), e.type);
    r.setLoc(e);
    return r;
  }

  E visit(AndExpr e)
  {
    auto r = new IntExpr(EM.toInt(e.lhs) & EM.toInt(e.rhs), e.type);
    r.setLoc(e);
    return r;
  }

  E visit(EqualExpr e)
  {
    return e;
  }

  E visit(IdentityExpr e)
  {
    return e;
  }

  E visit(RelExpr e)
  {
    return e;
  }

  E visit(InExpr e)
  {
    return e;
  }

  E visit(LShiftExpr e)
  {
    auto r = new IntExpr(EM.toInt(e.lhs) << EM.toInt(e.rhs), e.type);
    r.setLoc(e);
    return r;
  }

  E visit(RShiftExpr e)
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
    r = new IntExpr(val, e.type);
    r.setLoc(e);
    return r;
  }

  E visit(URShiftExpr e)
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
    r = new IntExpr(val >> bits, e.type);
    r.setLoc(e);
    return r;
  }

  E visit(PlusExpr e)
  {
    Expression r, lhs = e.lhs, rhs = e.rhs;
    auto et = e.type.flagsOf();
    if (et.isReal() || et.isImaginary()) // Boths operands are real or imag.
      r = new FloatExpr(
        EM.toRealOrImag(lhs) + EM.toRealOrImag(rhs), e.type);
    else if (et.isComplex())
      r = complexPlusOrMinus(e, false);
    else
      r = new IntExpr(EM.toInt(lhs) + EM.toInt(rhs), e.type);
    r.setLoc(e);
    return r;
  }

  E visit(MinusExpr e)
  {
    Expression r, lhs = e.lhs, rhs = e.rhs;
    auto et = e.type.flagsOf();
    if (et.isReal() || et.isImaginary()) // Boths operands are real or imag.
      r = new FloatExpr(
        EM.toRealOrImag(lhs) - EM.toRealOrImag(rhs), e.type);
    else if (et.isComplex())
      r = complexPlusOrMinus(e, true);
    else
      r = new IntExpr(EM.toInt(lhs) - EM.toInt(rhs), e.type);
    r.setLoc(e);
    return r;
  }

  E visit(CatExpr e)
  {
    return e;
  }

  E visit(MulExpr e)
  {
    Expression r, lhs = e.lhs, rhs = e.rhs;
    auto et = e.type.flagsOf();
    if (et.isFloating())
    {
      Complex z = EM.toComplex(lhs) * EM.toComplex(rhs);
      if (et.isReal() || et.isImaginary())
        r = new FloatExpr(et.isReal() ? z.re : z.im, e.type);
      else
        assert(et.isComplex()), r = new ComplexExpr(z, e.type);
    }
    else
      r = new IntExpr(EM.toInt(lhs) * EM.toInt(rhs), e.type);
    return r;
  }

  E visit(DivExpr e)
  {
    Expression r, lhs = e.lhs, rhs = e.rhs;
    auto et = e.type.flagsOf();
    if (et.isFloating())
    {
      Complex z = EM.toComplex(lhs) / EM.toComplex(rhs);
      if (et.isReal() || et.isImaginary())
        r = new FloatExpr(et.isReal() ? z.re : z.im, e.type);
      else
        assert(et.isComplex()), r = new ComplexExpr(z, e.type);
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
      r = new IntExpr(x, e.type);
    }
    return r;
  }

  E visit(ModExpr e)
  {
    Expression r, lhs = e.lhs, rhs = e.rhs;
    auto et = e.type.flagsOf();
    if (et.isFloating())
    {
      Complex z = EM.toComplex(lhs) % EM.toComplex(rhs);
      if (et.isReal() || et.isImaginary())
        r = new FloatExpr(et.isReal() ? z.re : z.im, e.type);
      else
        assert(et.isComplex()), r = new ComplexExpr(z, e.type);
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
      r = new IntExpr(x, e.type);
    }
    return r;
  }

  E visit(AssignExpr e)
  {
    return e;
  }

  E visit(LShiftAssignExpr e)
  {
    return e;
  }

  E visit(RShiftAssignExpr e)
  {
    return e;
  }

  E visit(URShiftAssignExpr e)
  {
    return e;
  }

  E visit(OrAssignExpr e)
  {
    return e;
  }

  E visit(AndAssignExpr e)
  {
    return e;
  }

  E visit(PlusAssignExpr e)
  {
    return e;
  }

  E visit(MinusAssignExpr e)
  {
    return e;
  }

  E visit(DivAssignExpr e)
  {
    return e;
  }

  E visit(MulAssignExpr e)
  {
    return e;
  }

  E visit(ModAssignExpr e)
  {
    return e;
  }

  E visit(XorAssignExpr e)
  {
    return e;
  }

  E visit(CatAssignExpr e)
  {
    return e;
  }

  E visit(AddressExpr e)
  {
    return e;
  }

  E visit(PreIncrExpr e)
  {
    return e;
  }

  E visit(PreDecrExpr e)
  {
    return e;
  }

  E visit(PostIncrExpr e)
  {
    return e;
  }

  E visit(PostDecrExpr e)
  {
    return e;
  }

  E visit(DerefExpr e)
  {
    return e;
  }

  E visit(SignExpr e)
  {
    return e;
  }

  E visit(NotExpr e)
  {
    auto r = new IntExpr(EM.isBool(e) == 0, e.type);
    r.setLoc(e);
    return r;
  }

  E visit(CompExpr e)
  {
    auto r = new IntExpr(~EM.toInt(e), e.type);
    r.setLoc(e);
    return r;
  }

  E visit(CallExpr e)
  {
    return e;
  }

  E visit(NewExpr e)
  {
    return e;
  }

  E visit(NewClassExpr e)
  {
    return e;
  }

  E visit(DeleteExpr e)
  {
    return e;
  }

  E visit(CastExpr e)
  {
    return e;
  }

  E visit(IndexExpr e)
  {
    return e;
  }

  E visit(SliceExpr e)
  {
    return e;
  }

  E visit(ModuleScopeExpr e)
  {
    return e;
  }

  E visit(IdentifierExpr e)
  {
    return e;
  }

  E visit(TmplInstanceExpr e)
  {
    return e;
  }

  E visit(SpecialTokenExpr e)
  {
    return e;
  }

  E visit(ThisExpr e)
  {
    return e;
  }

  E visit(SuperExpr e)
  {
    return e;
  }

  E visit(NullExpr e)
  { // Just return e.
    return e;
  }

  E visit(DollarExpr e)
  {
    return e;
  }

  E visit(BoolExpr e)
  { // Just return the value of e.
    return e.value;
  }

  E visit(IntExpr e)
  { // Just return e.
    return e;
  }

  E visit(FloatExpr e)
  { // Just return e.
    return e;
  }

  E visit(ComplexExpr e)
  { // Just return e.
    return e;
  }

  E visit(CharExpr e)
  { // Just return e.
    return e;
  }

  E visit(StringExpr e)
  { // Just return e.
    return e;
  }

  E visit(ArrayLiteralExpr e)
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
      r = new ArrayLiteralExpr(elems_dup);
      r.setLoc(e);
      r.type = e.type;
    }
    return r;
  Lerr:
    error(e, "cannot interpret array literal");
    return NAR;
  }

  E visit(AArrayLiteralExpr e)
  {
    return e;
  }

  E visit(AssertExpr e)
  {
    return e;
  }

  E visit(MixinExpr e)
  {
    return e;
  }

  E visit(ImportExpr e)
  {
    return e;
  }

  E visit(TypeofExpr e)
  {
    return e;
  }

  E visit(TypeDotIdExpr e)
  {
    return e;
  }

  E visit(TypeidExpr e)
  {
    return e;
  }

  E visit(IsExpr e)
  {
    return e;
  }

  E visit(ParenExpr e)
  {
    return e;
  }

  E visit(FuncLiteralExpr e)
  {
    return e;
  }

  E visit(TraitsExpr e) // D2.0
  {
    return e;
  }

  E visit(VoidInitExpr e)
  {
    return e;
  }

  E visit(ArrayInitExpr e)
  {
    return e;
  }

  E visit(StructInitExpr e)
  {
    return e;
  }

  E visit(AsmTypeExpr e)
  {
    assert(0);
    return e;
  }

  E visit(AsmOffsetExpr e)
  {
    assert(0);
    return e;
  }

  E visit(AsmSegExpr e)
  {
    assert(0);
    return e;
  }

  E visit(AsmPostBracketExpr e)
  {
    assert(0);
    return e;
  }

  E visit(AsmBracketExpr e)
  {
    assert(0);
    return e;
  }

  E visit(AsmLocalSizeExpr e)
  {
    assert(0);
    return e;
  }

  E visit(AsmRegisterExpr e)
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
