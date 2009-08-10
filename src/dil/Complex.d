/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.Complex;

import dil.Float;
import common;

import tango.stdc.stdio;

alias dil.Float.Float Float;

/// A class for working with imaginary numbers.
class Complex
{
  Float re; /// The real part.
  Float im; /// The imaginary part.
  /// The length or magnitude of the vector.
  alias re mag;
  /// The angle of the vector.
  alias im phi;

  /// Constructs an initialized Float.
  this()
  {
    re = new Float();
    im = new Float();
  }

  /// Constructs from a Complex.
  this(Complex c)
  {
    re = c.re.dup();
    im = c.im.dup();
  }

  /// Constructs from two Floats.
  this(Float r, Float i=null)
  {
    re = r;
    im = i ? i : new Float();
  }

  /// Constructs from two mpfr_t.
  this(mpfr_t* r, mpfr_t* i=null)
  {
    re = new Float(r);
    im = i ? new Float(i) : new Float();
  }

  /// Constructs from two longs.
  this(long r, long i=0)
  {
    re = new Float(r);
    im = new Float(i);
  }

  /// Constructs from two ulongs.
  this(ulong r, ulong i=0)
  {
    re = new Float(r);
    im = new Float(i);
  }

  /// Constructs from two longs.
  this(double r, double i=0)
  {
    re = new Float(r);
    im = new Float(i);
  }

  /// Constructs from two strings.
  this(string r, string i)
  {
    re = new Float(r);
    im = new Float(i);
  }

  /// Constructs from a string.
  /// Params:
  ///   x = can be "a", "aj", "-ai", "a + bj", "a - bi" etc.
  this(string x)
  {
    if (!x.length)
      this();
    else
    {
      if (x[$-1] != '\0')
        x = x ~ '\0'; // Terminate with zero
      this(x.ptr);
    }
  }

  /// Constructs a Complex from a zero-terminated string.
  this(char* x)
  {
    if (!x || !*x)
      (re = new Float()),
      im = new Float();
    else
      set(x);
  }

  Complex set(char* x)
  {
    x = x || *x ? x : "0";

    char[] r_str, i_str;
    bool i_neg;
    auto p = x;
    while (*p == ' ')
      p++;
    x = p; // Let x point to the beginning of the number.
    if (*p == '-' || *p == '+')
      p++; // Skip for look-behind expression below (p[-1]).
    while (*p != 0 && *p != ' ' &&
           (*p != '-' && *p != '+' || p[-1] == 'e'))
      p++;
    if (p[-1] == 'i' || p[-1] == 'j')
      i_str = x[0..p-x]; // Only an imaginary component.
    else
    {
      r_str = x[0..p-x]; // Real component.
      while (*p == ' ') // Skip whitespace.
        p++;
      i_neg = *p == '-';
      if (i_neg || *p == '+') // ±bi
      {
        while (*++p == ' '){} // Skip whitespace.
        x = p; // Update beginning of the imaginary component.
        while (*p != 0 && *p != 'i' && *p != 'j')
          p++;
        if (*p != 0)
          i_str = x[0..p-x];
      }
    }

    re = new Float(r_str);
    im = new Float(i_str);
    if (i_neg)
      im.neg();
    return this;
  }

  /// For convenient construction of Complex numbers.
  static Complex opCall(Params...)(Params P)
  {
    return new Complex(P);
  }

  /// Clears this number and deallocates its data.
  void clear()
  {
    re.clear();
    im.clear();
  }

  /// Returns a deep copy of this number.
  Complex dup()
  {
    return new Complex(this);
  }

  /// Calculates z += x.
  Complex opAddAssign(Complex x)
  {
    re += x.re;
    im += x.im;
    return this;
  }

  /// Calculates z+x.
  Complex opAdd(Complex x)
  {
    return new Complex() += x;
  }

  /// Calculates z+x.
  Complex opAdd(uint x)
  {
    auto z = new Complex();
    z.re += x;
    return z;
  }

  /// Calculates x-z.
//   Complex opAdd_r(T)(T x)
//   {
//     static if (is(T == Complex))
//       return x.dup() + this;
//     else
//       return new Complex(x) + this;
//   }

  /// Calculates z -= x.
  Complex opSubAssign(Complex x)
  {
    re -= x.re;
    im -= x.im;
    return this;
  }

  /// Calculates z -= x.
  Complex opSubAssign(uint x)
  {
    re -= x;
    return this;
  }

  /// Calculates z-x.
  Complex opSub(T)(T x)
  {
    static if (is(T == Complex) || is(T == uint))
      return dup() -= x;
    else
      return dup() -= new Complex(x);
  }

  /// Calculates x-z.
//   Complex opSub_r(T)(T x)
//   {
//     static if (is(T == Complex))
//       return x.dup() - this;
//     else
//       return new Complex(x) - this;
//   }

  /// Calculates z /= x.
  Complex opDivAssign(T:Complex)(T x)
  {
    if (x.im == 0)
      (re /= x.re),
      (im /= x.re);
    else
    {
      // auto n = x.re / x.im;
      // auto d = x.re * n + x.im;
      // auto r_ = re.dup();
      // re *= n; re += im; re /= d;
      // im *= n; im -= r_; im /= d;
      auto d = x.re*x.re + x.im*x.im;
      auto r_ = re.dup();
      re *= x.re; re += im*x.im; re /= d;
      im *= x.re; im -= r_*x.im; im /= d;
    }
    return this;
  }

  /// Calculates z /= x.
  Complex opDivAssign(T)(T x)
  {
    static if (is(T == Float) || is(T == uint))
      alias x z;
    else
      auto z = new Float(x);
    re /= z;
    im /= z;
    return this;
  }

  /// Calculates z/x.
  Complex opDiv(T)(T x)
  {
    static if (is(T == Complex) || is(T == uint))
      alias x z;
    else
      auto z = new Complex(x);
    return dup() /= z;
  }

  // Cannot do the following because it conflicts with opDiv.
  // Complex opDiv_r(T)(T x)
  // { return new Complex(x) /= this; }

  /// Calculates x/z.
  Complex opDiv_r(uint x)
  {
    return new Complex(cast(ulong)x) /= this;
  }

  /// ditto
  Complex opDiv_r(double x)
  {
    return new Complex(x) /= this;
  }

  /// ditto
  Complex opDiv_r(string x)
  {
    return new Complex(x) /= this;
  }

  /// ditto
  Complex opDiv_r(char* x)
  {
    return new Complex(x) /= this;
  }

  /// Calculates z *= x.
  Complex opMulAssign(T:Complex)(T x)
  {
    if (x.im == 0)
      (re *= x.re),
      (im *= x.re);
    else
    {
      auto r_ = re.dup();
      re *= x.re; re -= im*x.im;
      im *= x.re; im += r_*=x.im;
    }
    return this;
  }

  /// Calculates z *= x.
  Complex opMulAssign(T)(T x)
  {
    static if (is(T == Float) || is(T == uint))
      alias x z;
    else
      auto z = new Float(x);
    re *= z;
    im *= z;
    return this;
  }

  /// Calculates z*x.
  Complex opMul(T)(T x)
  {
    static if (is(T == Complex) || is(T == uint))
      alias x z;
    else
      auto z = new Complex(x);
    return dup() *= z;
  }

  /// Calculates x*z.
//   Complex opMul_r(T)(T x)
//   {
//     static if (is(T == Complex))
//       return x.dup() *= this;
//     else
//       return new Complex(x) *= this;
//   }

  /// Calculates z *= 2^x. Returns itself.
  Complex mul_2exp(uint x)
  {
    re.mul_2exp(x);
    im.mul_2exp(x);
    return this;
  }

  /// Calculates z /= 2^x. Returns itself.
  Complex div_2exp(uint x)
  {
    re.div_2exp(x);
    im.div_2exp(x);
    return this;
  }

  /// Compares this to x.
  int opEquals(T)(T x)
  {
    static if (!is(T == Complex))
      auto z = new Complex(x);
    else
      alias x z;
    return re == z.re && im == z.im;
  }

  /// Returns a negated copy of this number.
  Complex opNeg()
  {
    auto n = dup();
    n.re.neg();
    n.im.neg();
    return n;
  }

  /// Negates this number.
  Complex neg()
  {
    re.neg();
    im.neg();
    return this;
  }

  /// Converts this number to polar representation.
  Complex polar()
  {
    auto phi_ = im.dup.atan2(re);
    re.hypot(im); // r = √(re^2 + im^2)
    phi = phi_;   // φ = arctan(im/re)
    return this;
  }

  /// Converts this number to cartesian representation.
  Complex cart()
  { // Looks weird but saves temporary variables.
    auto mag_ = mag.dup();
    mag *= phi.dup().cos(); // re = r*cos(φ)
    phi.sin() *= mag_;      // im = r*sin(φ)
    return this;
  }

  /// Calculates the square root of this number. Returns itself.
  Complex sqrt()
  { // √z = √(r.e^iφ) = √(r).e^(iφ/2)
    polar();
    mag.sqrt();
    phi /= 2;
    return cart();
  }

  /// Calculates z^x. Returns itself.
  Complex pow(T)(T x)
  { // z^2 = (r.e^iφ)^2 = r^2.e^2φi
    polar();
    mag.pow(x);
    phi *= x;
    return cart();
  }

  /// Calculates z^w. Returns itself.
  Complex pow(T:Complex)(T w)
  { // z^w = e^(w*ln(z))
    ln() *= w; // z = ln(z); z *= w
    return exp(); // e^z
  }

  /// Calculates e^z. Returns itself.
  Complex exp()
  { // e^z = e^(a+bi) = e^a * e^bi = e^a (cos(b) + i.sin(b))
    re.exp(); // r = e^Re(z)  φ = Im(z)
    return cart();
  }

  /// Calculates ln(z). Returns itself.
  Complex ln()
  { // ln(z) = ln(r.e^iφ) = ln(r) + ln(e^iφ) = ln(r) + iφ
    polar();
    mag.ln();
    return this;
  }

  /// Calculates log_a+bi(z) = ln(z)/ln(a+bi). Returns a new number.
  Complex logz(Complex z)
  {
    return z.dup().ln() /= dup().ln();
  }

  /// Conjugates this number, conj(z) = Re(z) - Im(z). Returns itself.
  Complex conjugate()
  {
    im = -im;
    return this;
  }

  /// Returns a conjugated copy of this number.
  Complex conjugated()
  {
    return dup().conjugate();
  }

  /// Inverses this number. z = z^-1
  Complex inverse()
  { // re/(a*a+b*b) - im/(a*a+b*b)
    auto d = (re*re) += im*im;
    re /= d;
    im /= d.neg();
    return this;
  }

  /// Returns an inversed copy of this number. z^-1
  Complex inversed()
  {
    return dup().inverse();
  }

  /// Returns the polar angle. φ = arctan(b/a)
  Float arg()
  {
    return im.dup().atan2(re);
  }

  /// Returns the absolute value. |z| = √(re^2 + im^2)
  Float abs()
  {
    return re.dup().hypot(im);
  }

  /// Returns this float as a string.
  string toString()
  {
    return toString(30);
  }

  /// Returns this float as a string.
  string toString(uint precision)
  {
    auto im_sign = im.isNeg() ? "" : "+";
    return re.toString(precision) ~ im_sign ~ im.toString(precision) ~ "i";
  }
}

unittest
{
  Stdout("Testing class Complex.\n");

  alias Float F;
  alias Complex C;

  assert(-C(F(10), F(9)) == C(F(-10), F(-9)));
  assert(C(5., 20.) / 5. == C(1., 4.));
  assert(1. / C(5., 20.) == C(5., 20.).inverse());
  assert(C(3L, 2L) / C(4L,-6L) == C(0., 0.5));
  assert(C(3L, 4L).abs() == F(5));
  assert(C(3L, 4L).conjugate() == C(3L, -4L));
//   assert(C(3L, 4L).pow(2) == C(-7, 24));
//   assert(C(3L, 4L).sqrt() == C(2L, 1L));
  assert(C("3+4j") == C(3L, 4L));
  assert(C("-4e+2j") == C(0L, -400L));
}
