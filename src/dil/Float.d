/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.Float;

import common;

// Used to be a wrapper class for the MPFR library functions.
// However, it was changed because the dependency has been a huge annoyance:
// * No up-to-date pre-compiled lib for Windows (let alone other platforms);
// * Can't be sure if the D mpfr struct has the correct size

/// A multiprecision float. TODO: needs to be implemented using BigInt.
/// Macros:
/// f = <a href="#Float.f" style="text-decoration:none">f</a>
class Float
{
  real f; /// Implemented using a 'real' for now.

  /// Constructs a Float initialized to NaN.
  this()
  {
  }

  /// Constructs from a Float. Copies x.
  this(Float x)
  {
    f = x.f;
  }

  /// Constructs from a real.
  this(real x)
  {
    f = x;
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
    f = x;
  }

  /// Constructs from a ulong.
  this(ulong x)
  {
    f = x;
  }

  /// Constructs from a double.
  this(double x)
  {
    f = x;
  }

  /// Constructs from a string.
  this(cstring x, int base = 10)
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
    // TODO:
  }

  /// Constructs from a string and outputs a precision return code.
  this(out int retcode, cstring str)
  {
    // TODO:
  }

  /// For convenient construction of Floats.
  static Float opCall(Params...)(Params P)
  {
    return new Float(P);
  }

  /// Returns a deep copy of this number.
  Float dup()
  {
    return new Float(this);
  }

  /// Returns true for an infinite number.
  bool isInf()
  {
    // TODO:
    return false;
  }

  /// Returns true for positive infinity.
  bool isPInf()
  {
    // TODO:
    return false;
  }

  /// Returns true for negative infinity.
  bool isNInf()
  {
    // TODO:
    return false;
  }

  /// Returns true for a NaN.
  bool isNaN()
  {
    // TODO:
    return false;
  }

  /// Returns true for zero.
  bool isZero()
  {
    // TODO:
    return false;
  }

  // TODO: add set() methods.

  /// Calculates $(f) += x.
  Float opAddAssign(Float x)
  {
    f += x.f;
    return this;
  }

  /// Calculates $(f) += x.
  Float opAddAssign(uint x)
  {
    f += x;
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
    f -= x.f;
    return this;
  }

  /// Calculates $(f) -= x.
  Float opSubAssign(uint x)
  {
    f -= x;
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
    return new Float(x - f);
  }

  /// Calculates $(f) /= x.
  Float opDivAssign(Float x)
  {
    f /= x.f;
    return this;
  }

  /// Calculates $(f) /= x.
  Float opDivAssign(uint x)
  {
    f /= x;
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
    return new Float(x / f);
  }

  /// Calculates $(f) %= x.
  Float opModAssign(Float x)
  {
    f %= x.f;
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
    f *= x.f;
    return this;
  }

  /// Calculates $(f) *= x.
  Float opMulAssign(uint x)
  {
    f *= x;
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
    // TODO:
    return false;
  }

  /// ditto
  bool opEquals(double x)
  {
    // TODO:
    return false;
  }

  /// ditto
  bool opEquals(int x)
  {
    // TODO:
    return false;
  }

  /// ditto
  bool opEquals(uint x)
  {
    // TODO:
    return false;
  }

  alias opEquals equals;

  alias super.opCmp opCmp;

  /// Compares $(f) to x.
  int opCmp(Float x)
  {
    // TODO:
    return false;
  }

  /// ditto
  int opCmp(double x)
  {
    // TODO:
    return false;
  }

  /// ditto
  int opCmp(int x)
  {
    // TODO:
    return false;
  }

  /// ditto
  int opCmp(uint x)
  {
    // TODO:
    return false;
  }

  /// Returns true if the first bits of $(f) and x are equal.
  bool equals(Float x, uint bits)
  {
    // TODO:
    return false;
  }

  /// Sets $(f) to frac($(f)). Returns itself.
  Float fraction()
  {
    // TODO:
    return this;
  }

  /// Returns a negated copy of this number.
  Float opNeg()
  {
    auto x = dup();
    x.f = -f;
    return x;
  }

  /// Negates this number.
  Float neg()
  {
    f = -f;
    return this;
  }

  /// Returns true if negative.
  bool isNeg()
  {
    return f < 0;
  }

  /// Sets the number to its absolute value. Returns itself.
  Float abs()
  {
    if (f < 0)
      f = -f;
    return this;
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
    // FIXME:
    return Format("{}", f);
  }

  /// Returns the internals of the data structure as a hex string.
  char[] toHex()
  {
    // FIXME:
    return Format("{:X}", f);
  }

  // Exponentiation and logarithmic functions.

  /// Calculates √$(f). Returns itself.
  Float sqrt()
  {
    // TOOD:
    return this;
  }

  /// Calculates √x. Returns a new Float.
  static Float sqrt(uint x)
  {
    // TODO:
    return new Float();
  }

  /// Calculates $(f)$(SUP x). Returns itself.
  Float pow(uint x)
  {
    // TODO:
    return this;
  }

  /// Calculates $(f)². Returns itself.
  Float square()
  {
    // TODO:
    return this;
  }

  /// Calculates ln(x). Returns itself.
  Float ln()
  {
    // TODO:
    return this;
  }
  /// Calculates log$(SUB 2)(x). Returns itself.
  Float log2()
  {
    // TODO:
    return this;
  }
  /// Calculates log$(SUB 10)(x). Returns itself.
  Float log10()
  {
    // TODO:
    return this;
  }
  /// Calculates e$(SUP x). Returns itself.
  Float exp()
  {
    // TODO:
    return this;
  }

  /// Calculates acos(x). Returns itself.
  Float acos()
  {
    // TODO:
    return this;
  }

  /// Calculates asin(x). Returns itself.
  Float asin()
  {
    // TODO:
    return this;
  }

  /// Calculates atan(x). Returns itself.
  Float atan()
  {
    // TODO:
    return this;
  }

  /// Calculates sin(x). Returns itself.
  Float sin()
  {
    // TODO:
    return this;
  }

  /// Calculates cos(x). Returns itself.
  Float cos()
  {
    // TODO:
    return this;
  }

  /// Calculates tan(x). Returns itself.
  Float tan()
  {
    // TODO:
    return this;
  }

  /// Calculates atan(y/x). Returns itself.
  Float atan2(Float x)
  {
    // TODO:
    return this;
  }

  /// Calculates hypot(x, y) = √(x² + y²). Returns itself.
  Float hypot(Float y)
  {
    // TODO:
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


void testFloat()
{
  return; // Remove when Float is fixed.
  scope msg = new UnittestMsg("Testing class Float.");

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

