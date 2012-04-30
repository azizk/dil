/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.Float;

import util.mpfr;
import common;

/// A wrapper class for the MPFR library functions.
/// See: $(LINK http://www.mpfr.org/)
/// Macros:
/// f = <a href="#Float.f" style="text-decoration:none">f</a>
class Float
{
  /// The default rounding method.
  static const mpfr_rnd_t RND = mpfr_rnd_t.RNDZ;
  /// The multiprecission float variable.
  mpfr_t f = void;

  /// Constructs a Float initialized to 0.
  this()
  {
    mpfr_init(&f);
    mpfr_set_ui(&f, 0, RND);
  }

  /// Constructs from a Float. Copies x.
  this(Float x)
  {
    mpfr_init(&f);
    mpfr_set(&f, &x.f, RND);
    assert(f.limbs != x.f.limbs);
  }

  /// Constructs from a mpfr_t. Does not duplicate x.
  this(mpfr_t* x)
  {
    f = *x;
  }

  /// Constructs from an int.
  this(int x)
  {
    this(cast(long)x);
  }

  /// Constructs from a uint.
  this(uint x)
  {
    this(cast(ulong)x);
  }

  /// Constructs from a long.
  this(long x)
  {
    bool negative;
    if (x < 0)
      (negative = true),
      x = -x;
    this(cast(ulong)x);
    if (negative)
      f.size = -f.size;
  }

  /// Constructs from a ulong.
  this(ulong x)
  {
    mpfr_init(&f);
    if (x >> 32)
      mpfr_set_ui(&f, x >> 32, RND), // Initialize with higher dword.
      mpfr_mul_2ui(&f, &f, 32, RND), // Shift to the left 32 bits.
      mpfr_add_ui(&f, &f, cast(uint)x, RND); // Add lower dword.
    else
      mpfr_set_ui(&f, cast(uint)x, RND);
  }

  /// Constructs from a double.
  this(double x)
  {
    mpfr_init(&f);
    mpfr_set_d(&f, x, RND);
  }

  /// Constructs from a string.
  this(cstring x, int base=10)
  {
    if (!x.length)
      this();
    else
    {
      if (x[$-1] != '\0')
        x = x ~ '\0'; // Terminate with zero
      this(x.ptr, base);
    }
  }

  /// Constructs from a zero-terminated string.
  this(cchar* x, int base = 10)
  {
    mpfr_init(&f);
    if (x && *x)
      // Returns 0 for success, -1 on failure.
      mpfr_set_str(&f, cast(char*)x, base, RND);
    else
      mpfr_set_ui(&f, 0, RND);
  }

  ~this()
  {
    mpfr_clear(&f);
    f.limbs = null; // Must be set to null or the GC will try to free it again.
  }

  /// For convenient construction of Floats.
  static Float opCall(Params...)(Params P)
  {
    return new Float(P);
  }

  /// Clears this number and deallocates its data.
  void clear()
  {
    mpfr_clear(&f);
    f.limbs = null;
  }

  /// Returns a deep copy of this number.
  Float dup()
  {
    return new Float(this);
  }

  /// Returns true for an infinite number.
  bool isInf()
  {
    return f.exp == MPFR_EXP_INF;
  }

  /// Returns true for positive infinity.
  bool isPInf()
  {
    return f.exp == MPFR_EXP_INF && f.size >= 0;
  }

  /// Returns true for negative infinity.
  bool isNInf()
  {
    return f.exp == MPFR_EXP_INF && f.size < 0;
  }

  /// Returns true for a NaN.
  bool isNaN()
  {
    return f.exp == MPFR_EXP_NAN;
  }

  /// Returns true for zero.
  bool isZero()
  {
    return f.exp == MPFR_EXP_ZERO;
  }

  // TODO: add set() methods.

  /// Calculates $(f) += x.
  Float opAddAssign(Float x)
  {
    mpfr_add(&f, &f, &x.f, RND);
    return this;
  }

  /// Calculates $(f) += x.
  Float opAddAssign(uint x)
  {
    mpfr_add_ui(&f, &f, x, RND);
    return this;
  }

  /// Calculates $(f) + x.
  Float opAdd(T)(T x)
  {
    static if (is(T == Float) || is(T == uint))
      return dup() += x;
    else
      return dup() += new Float(x);
  }

  /// Calculates $(f) -= x.
  Float opSubAssign(Float x)
  {
    mpfr_sub(&f, &f, &x.f, RND);
    return this;
  }

  /// Calculates $(f) -= x.
  Float opSubAssign(uint x)
  {
    mpfr_sub_ui(&f, &f, x, RND);
    return this;
  }

  /// Calculates $(f) - x.
  Float opSub(T)(T x)
  {
    static if (is(T == Float) || is(T == uint))
      return dup() -= x;
    else
      return dup() -= new Float(x);
  }

  /// Calculates x - $(f).
  Float opSub_r(uint x)
  {
    auto result = new Float();
    mpfr_ui_sub(&result.f, x, &f, RND);
    return result;
  }

  /// Calculates $(f) /= x.
  Float opDivAssign(Float x)
  {
    mpfr_div(&f, &f, &x.f, RND);
    return this;
  }

  /// Calculates $(f) /= x.
  Float opDivAssign(uint x)
  {
    mpfr_div_ui(&f, &f, x, RND);
    return this;
  }

  /// Calculates $(f) / x.
  Float opDiv(T)(T x)
  {
    static if (is(T == Float) || is(T == uint))
      return dup() /= x;
    else
      return dup() /= new Float(x);
  }

  /// Calculates x / $(f).
  Float opDiv_r(uint x)
  {
    auto result = new Float();
    mpfr_ui_div(&result.f, x, &f, RND);
    return result;
  }

  /// Calculates $(f) %= x.
  Float opModAssign(Float x)
  {
    mpfr_fmod(&f, &f, &x.f, RND);
    return this;
  }

  /// Calculates $(f) % x.
  Float opMod(Float x)
  {
    return dup() %= x;
  }

  /// Calculates $(f) *= x.
  Float opMulAssign(Float x)
  {
    mpfr_mul(&f, &f, &x.f, RND);
    return this;
  }

  /// Calculates $(f) *= x.
  Float opMulAssign(uint x)
  {
    mpfr_mul_ui(&f, &f, x, RND);
    return this;
  }

  /// Calculates $(f) * x.
  Float opMul(T)(T x)
  {
    static if (is(T == Float) || is(T == uint))
      return dup() *= x;
    else
      return dup() *= new Float(x);
  }

  /// Calculates $(f) * 2$(SUP x). Returns itself.
  Float mul_2exp(uint x)
  {
    mpfr_mul_2ui(&f, &f, x, RND);
    return this;
  }

  /// Calculates $(f) / 2$(SUP x). Returns itself.
  Float div_2exp(uint x)
  {
    mpfr_div_2ui(&f, &f, x, RND);
    return this;
  }

  /// Compares $(f) to x.
  bool opEquals(Object x)
  {
    if (auto y = cast(Float)x)
      return opEquals(y);
    return true;
  }

  /// Compares $(f) to x.
  bool opEquals(Float x)
  {
    return mpfr_equal_p(&f, &x.f) != 0;
  }

  /// ditto
  bool opEquals(double x)
  {
    return mpfr_cmp_d(&f, x) == 0;
  }

  /// ditto
  bool opEquals(int x)
  {
    return mpfr_cmp_si(&f, x) == 0;
  }

  /// ditto
  bool opEquals(uint x)
  {
    return mpfr_cmp_ui(&f, x) == 0;
  }

  alias opEquals equals;

  alias super.opCmp opCmp;

  /// Compares $(f) to x.
  int opCmp(Float x)
  {
    return mpfr_cmp(&f, &x.f);
  }

  /// ditto
  int opCmp(double x)
  {
    return mpfr_cmp_d(&f, x);
  }

  /// ditto
  int opCmp(int x)
  {
    return mpfr_cmp_si(&f, x);
  }

  /// ditto
  int opCmp(uint x)
  {
    return mpfr_cmp_ui(&f, x);
  }

  /// Returns true if the first bits of $(f) and x are equal.
  bool equals(Float x, uint bits)
  {
    return mpfr_eq(&f, &x.f, bits) != 0;
  }

  /// Sets $(f) to frac($(f)). Returns itself.
  Float fraction()
  {
    mpfr_frac(&f, &f, RND);
    return this;
  }

  /// Sets the exponent. Returns itself.
  Float exponent(mpfr_exp_t x)
  {
    f.exp = x;
    return this;
  }

  /// Returns the exponent.
  mpfr_exp_t exponent()
  {
    return f.exp;
  }

  /// Sets the mantissa. Returns itself.
  Float mantissa(long x)
  {
    // TODO:
    assert(0);
    return this;
  }

  /// Sets the mantissa. Returns itself.
  Float mantissa(/+mpz_t+/int x)
  {
    // TODO:
    assert(0);
    return this;
  }

  /// Returns the mantissa.
  /+mpz_t+/ int mant()
  {
    // TODO:
    assert(0);
    return 0;
  }

  /// Sets the precision. Returns itself.
  Float prec(mpfr_prec_t prec)
  {
    mpfr_prec_round(&f, prec, RND);
    return this;
  }

  /// Returns the precision.
  mpfr_prec_t prec()
  {
    return f.prec;
  }

  /// Returns a negated copy of this number.
  Float opNeg()
  {
    auto n = dup();
    n.f.size = -n.f.size;
    return n;
  }

  /// Negates this number.
  Float neg()
  {
    f.size = -f.size;
    return this;
  }

  /// Returns true if negative.
  bool isNeg()
  {
    return f.size < 0;
  }

  /// Sets the number to its absolute value. Returns itself.
  Float abs()
  {
    if (f.size < 0)
      f.size = -f.size;
    return this;
  }

  /// Returns the limbs of the float data structure.
  mpfr_limb_t[] limbs()
  {
    return f.limbs_array();
  }

  /// Returns this float as a string.
  string toString()
  {
    return toString(30).idup;
  }

  /// Returns this float as a string.
  /// Formatted in the scientific representation.
  char[] toString(uint precision)
  {
    char* str;
    int len = mpfr_asprintf(str, "%.*R*g".ptr, precision, RND, &f);
    if (len < 0)
      return null;
    auto res = str[0..len].dup;
    mpfr_free_str(str);
    return res;
  }

  /// Returns the internals of the data structure as a hex string.
  char[] toHex()
  {
    char[] mantissa;
    foreach (l; limbs())
      mantissa = Format("{:X}", l) ~ mantissa;
    return Format("0x{}e{}p{}", mantissa, f.exp, f.prec);
  }

  // Exponentiation and logarithmic functions.

  /// Calculates √$(f). Returns itself.
  Float sqrt()
  {
    mpfr_sqrt(&f, &f, RND);
    return this;
  }

  /// Calculates √x. Returns a new Float.
  static Float sqrt(uint x)
  {
    auto result = new Float();
    mpfr_sqrt_ui(&result.f, x, RND);
    return result;
  }

  /// Calculates $(f)$(SUP x). Returns itself.
  Float pow(uint x)
  {
    mpfr_pow_ui(&f, &f, x, RND);
    return this;
  }

  /// Calculates $(f)². Returns itself.
  Float square()
  {
    mpfr_sqr(&f, &f, RND);
    return this;
  }

  /// Calculates ln(x). Returns itself.
  Float ln()
  {
    mpfr_log(&f, &f, RND);
    return this;
  }
  /// Calculates log$(SUB 2)(x). Returns itself.
  Float log2()
  {
    mpfr_log2(&f, &f, RND);
    return this;
  }
  /// Calculates log$(SUB 10)(x). Returns itself.
  Float log10()
  {
    mpfr_log10(&f, &f, RND);
    return this;
  }
  /// Calculates e$(SUP x). Returns itself.
  Float exp()
  {
    mpfr_exp(&f, &f, RND);
    return this;
  }

  // Trigonometric functions:

  // mpfr_atanh(&f, &f, RND);
  // mpfr_acosh(&f, &f, RND);
  // mpfr_asinh(&f, &f, RND);
  // mpfr_cosh(&f, &f, RND);
  // mpfr_sinh(&f, &f, RND);
  // mpfr_tanh(&f, &f, RND);
  // mpfr_sinh_cosh(&f, &f2, &f, RND);
  //
  // mpfr_sech(&f, &f, RND);
  // mpfr_csch(&f, &f, RND);
  // mpfr_coth(&f, &f, RND);

  /// Calculates acos(x). Returns itself.
  Float acos()
  {
    mpfr_acos(&f, &f, RND);
    return this;
  }

  /// Calculates asin(x). Returns itself.
  Float asin()
  {
    mpfr_asin(&f, &f, RND);
    return this;
  }

  /// Calculates atan(x). Returns itself.
  Float atan()
  {
    mpfr_atan(&f, &f, RND);
    return this;
  }

  /// Calculates sin(x). Returns itself.
  Float sin()
  {
    mpfr_sin(&f, &f, RND);
    return this;
  }

  /// Calculates cos(x). Returns itself.
  Float cos()
  {
    mpfr_cos(&f, &f, RND);
    return this;
  }

  /// Calculates tan(x). Returns itself.
  Float tan()
  {
    mpfr_tan(&f, &f, RND);
    return this;
  }

  /// Calculates atan(y/x). Returns itself.
  Float atan2(Float x)
  {
    mpfr_atan2(&f, &f, &x.f, RND);
    return this;
  }

  // mpfr_sec(&f, &f, RND);
  // mpfr_csc(&f, &f, RND);
  // mpfr_cot(&f, &f, RND);

  /// Calculates hypot(x, y) = √(x² + y²). Returns itself.
  Float hypot(Float y)
  {
    mpfr_hypot(&f, &f, &y.f, RND);
    return this;
  }
}

/// Returns ln(x).
Float ln(Float x)
{
  return x.dup().ln();
}
/// Returns log$(SUB 2)(x).
Float log2(Float x)
{
  return x.dup().log2();
}
/// Returns log$(SUB 10)(x).
Float log10(Float x)
{
  return x.dup().log10();
}
/// Returns e$(SUP x).
Float exp(Float x)
{
  return x.dup().exp();
}

/// Returns acos(x).
Float acos(Float x)
{
  return x.dup().acos();
}
/// Returns asin(x).
Float asin(Float x)
{
  return x.dup().asin();
}
/// Returns atan(x).
Float atan(Float x)
{
  return x.dup().atan();
}
/// Returns sin(x).
Float sin(Float x)
{
  return x.dup().sin();
}
/// Returns cos(x).
Float cos(Float x)
{
  return x.dup().cos();
}
/// Returns tan(x).
Float tan(Float x)
{
  return x.dup().tan();
}
/// Returns atan2(x,y) = atan(y/x).
Float atan2(Float y, Float x)
{
  return y.dup().atan2(x);
}
/// Returns hypot(x) = √(x² + y²).
Float hypot(Float x, Float y)
{
  return x.dup().hypot(y);
}


unittest
{
  Stdout("Testing class Float.\n");

  alias Float F;

  assert(F() == 0);
  assert(F("").toString() == "0");
  assert(F("0").toString() == "0");
  assert(F("1.125").toString() == "1.125");

  size_t i = "123456789".length,
         n = 1;
  for (; i < i.max; (i--), (n *= 10))
    // E.g.: F("12345678.9") == F(123456789) / 10
    assert(F("123456789"[0..i] ~ "." ~ "123456789"[i..$]) == F(123456789) / n);

  assert(F("12345678.9") == F(123456789.0) / 10);
  assert(F("12345678.9") == F(Format("{}", 12345678.9)));
  // FIXME: The same as the line above, but the mpfr_set_d() routine is
  //        inaccurate apparently.
//   assert(F("12345678.9") == F(12345678.9));
  assert(2 / F(0.5) == 4);
  assert(F(0.5) / 2 == 0.25);
  assert(F(0.5) * 8 == 4);
  assert(F(1.2).dup() == F(1.2));
  assert(F(3.7) < F(3.8));
  assert(F(99.8) <= F(99.8));
  assert((F(39) += 61) == F(250e-1) * 4);
  assert((F(100) /= 5) == (F(50e-1) *= 4));
  assert((F(111) -= 11) == F(111) - 11);
  assert(10-F("3.5") == 6.5);
  assert(10/F("2.5") == 4);
  assert(F(2401).sqrt() == F(7).pow(2));
  assert(F(16).neg() == F(-16));
  assert(F(16).neg().abs() == F(-16).abs());
  assert(F(1).exp().ln() <= F(1));
  assert(F(32).square() == F(1024));
}

