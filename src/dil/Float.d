/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.Float;

import tango.stdc.stdio;
import common;

/// A wrapper class for the GMP library functions.
/// See: $(LINK http://gmplib.org/)
class Float
{
  mpf_t f = void; /// The multiprecission float variable.

  /// Constructs a Float initialized to 0.
  this()
  {
    mpf_init(&f);
  }

  /// Constructs from a Float. Copies x.
  this(Float x)
  {
    mpf_init_set(&f, &x.f);
    assert(f.limbs != x.f.limbs);
  }

  /// Constructs from a mpf_t. Does not duplicate x.
  this(mpf_t* x)
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
    if (x >> 32)
      mpf_init_set_ui(&f, x >> 32), // Initialize with higher dword.
      mpf_mul_2exp(&f, &f, 32), // Shift to the left 32 bits.
      mpf_add_ui(&f, &f, x); // Add lower dword.
    else
      mpf_init_set_ui(&f, x);
  }

  /// Constructs from a double.
  this(double x)
  {
    mpf_init_set_d(&f, x);
  }

  /// Constructs from a string.
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

  /// Constructs from a zero-terminated char*.
  this(char* x)
  {
    if (!x || !*x)
      mpf_init(&f);
    else
    { // TODO: skip whitespace.
      if (*x == '+')
        x++;
      mpf_init_set_str(&f, x, 10); // Returns 0 for success, -1 on failure.
    }
  }

  ~this()
  {
    mpf_clear(&f);
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
    mpf_clear(&this.f);
    f.limbs = null;
  }

  /// Returns a deep copy of this number.
  Float dup()
  {
    return new Float(this);
  }

  // TODO: add set() methods.

  /// Calculates f += x.
  Float opAddAssign(Float x)
  {
    mpf_add(&f, &f, &x.f);
    return this;
  }

  /// Calculates f += x.
  Float opAddAssign(uint x)
  {
    mpf_add_ui(&f, &f, x);
    return this;
  }

  /// Calculates f+x.
  Float opAdd(T)(T x)
  {
    static if (is(T == Float) || is(T == uint))
      return dup() += x;
    else
      return dup() += new Float(x);
  }

  /// Calculates f -= x.
  Float opSubAssign(Float x)
  {
    mpf_sub(&f, &f, &x.f);
    return this;
  }

  /// Calculates f -= x.
  Float opSubAssign(uint x)
  {
    mpf_sub_ui(&f, &f, x);
    return this;
  }

  /// Calculates f-x.
  Float opSub(T)(T x)
  {
    static if (is(T == Float) || is(T == uint))
      return dup() -= x;
    else
      return dup() -= new Float(x);
  }

  /// Calculates x-f.
  Float opSub_r(uint x)
  {
    auto result = new Float();
    mpf_ui_sub(&result.f, x, &f);
    return result;
  }

  /// Calculates f /= x.
  Float opDivAssign(Float x)
  {
    mpf_div(&f, &f, &x.f);
    return this;
  }

  /// Calculates f /= x.
  Float opDivAssign(uint x)
  {
    mpf_div_ui(&f, &f, x);
    return this;
  }

  /// Calculates f/x.
  Float opDiv(T)(T x)
  {
    static if (is(T == Float) || is(T == uint))
      return dup() /= x;
    else
      return dup() /= new Float(x);
  }

  /// Calculates x/f.
  Float opDiv_r(uint x)
  {
    auto result = new Float();
    mpf_ui_div(&result.f, x, &f);
    return result;
  }

  /// Calculates f *= x.
  Float opMulAssign(Float x)
  {
    mpf_mul(&f, &f, &x.f);
    return this;
  }

  /// Calculates f *= x.
  Float opMulAssign(uint x)
  {
    mpf_mul_ui(&f, &f, x);
    return this;
  }

  /// Calculates f*x.
  Float opMul(T)(T x)
  {
    static if (is(T == Float) || is(T == uint))
      return dup() *= x;
    else
      return dup() *= new Float(x);
  }

  /// Calculates f*2^x. Returns itself.
  Float mul_2exp(uint x)
  {
    mpf_mul_2exp(&f, &f, x);
    return this;
  }

  /// Calculates f/2^x. Returns itself.
  Float div_2exp(uint x)
  {
    mpf_div_2exp(&f, &f, x);
    return this;
  }

  /// Compares this to x.
  int opEquals(Float x)
  {
    return mpf_cmp(&f, &x.f) == 0;
  }

  /// ditto
  int opEquals(double x)
  {
    return mpf_cmp_d(&f, x) == 0;
  }

  /// ditto
  int opEquals(int x)
  {
    return mpf_cmp_si(&f, x) == 0;
  }

  /// ditto
  int opEquals(uint x)
  {
    return mpf_cmp_ui(&f, x) == 0;
  }

  /// Compares this to x.
  int opCmp(Float x)
  {
    return mpf_cmp(&f, &x.f);
  }

  /// ditto
  int opCmp(double x)
  {
    return mpf_cmp_d(&f, x);
  }

  /// ditto
  int opCmp(int x)
  {
    return mpf_cmp_si(&f, x);
  }

  /// ditto
  int opCmp(uint x)
  {
    return mpf_cmp_ui(&f, x);
  }

  /// Returns true if the first bits of f and x are equal.
  bool equals(Float x, uint bits)
  {
    return mpf_eq(&f, &x.f, bits) != 0;
  }

  /// Sets the exponent. Returns itself.
  Float exp(mp_exp_t x)
  {
    f.exp = x;
    return this;
  }

  /// Returns the exponent.
  mp_exp_t exp()
  {
    return f.exp;
  }

  /// Sets the mantissa. Returns itself.
  Float mant(long x)
  {
    // TODO:
    return this;
  }

  /// Sets the mantissa. Returns itself.
  Float mant(/+mpz_t+/int x)
  {
    // TODO:
    return this;
  }

  /// Returns the mantissa.
  /+mpz_t+/ int mant()
  {
    // TODO:
    return 0;
  }

  /// Sets the precision. Returns itself.
  Float prec(int prec)
  {
    f.prec = prec;
    return this;
  }

  /// Returns the precision.
  int prec()
  {
    return f.prec;
  }

  /// Negates the number. Returns itself.
  Float opNeg()
  {
    f.size = -f.size;
    return this;
  }

  /// ditto
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

  /// Takes the square root of this number. Returns itself.
  Float sqrt()
  {
    mpf_sqrt(&f, &f);
    return this;
  }

  /// Takes the square root of x and returns a Float.
  static Float sqrt(uint x)
  {
    auto result = new Float();
    mpf_sqrt_ui(&result.f, x);
    return result;
  }

  /// Raises the number to the power x.
  Float pow(uint x)
  {
    mpf_pow_ui(&f, &f, x);
    return this;
  }

  /// Returns the limbs of the float data structure.
  mp_limb_t[] limbs()
  {
    return f.limbs[0..f.size & 0x7FFF_FFFF]; // Clear sign bit.
  }

  /// Returns this float as a string.
  string toString()
  {
    return toString(30);
  }

  /// Returns this float as a string.
  /// Formatted in the scientific representation.
  string toString(uint digits, int base=10)
  {
    auto result = new char[digits + 3]; // 3 = '-' + '.' + '\0'.
    result[0] = '-';
    mp_exp_t exponent;
    mpf_get_str(result.ptr+1, &exponent, base, digits, &this.f);
    foreach (i, c; result)
      if (!c) { // Find null-terminator and adjust the string length.
        result.length = i;
        break;
      }
    if (result.length == 1)
      return (result[0] = '0'), result ~= ".0"; // Return "0.0".

    auto p = result.ptr;
    if (p[1] == '-')
      p++;
    *p = p[1]; // Shift the first digit to the left, to make place for the dot.
    p[1] = '.'; // Set the radix point.
    if (result[$-1] == '.')
      result ~= '0';
    // if (exponent == mp_exp_t.min) // TODO: protect agains underflow.
      // ...
    exponent--; // Adjust the exponent, because of the radix point shift.
    if (exponent == 0)
      return result;

    // Convert the exponent to a string.
    if (exponent < 0)
      (exponent = -exponent), // Remove sign for conversion.
      result ~= "e-";
    else
      result ~= "e+";
    char[] exp_str;
    do
      exp_str = cast(char)('0' + exponent % 10) ~ exp_str;
    while (exponent /= 10)
    return result ~= exp_str;
  }

  /// Returns the internals of the data structure as a hex string.
  string toHex()
  {
    char[] mantissa;
    foreach (l; limbs())
      mantissa = Format("{:X}", l) ~ mantissa;
    return Format("0x{}e{}p{}", mantissa, f.exp, f.prec);
  }
}

unittest
{
  Stdout("Testing class Float.\n");

  alias Float F;
  assert(F("").toString() == "0.0");
  assert(F("123456789") == F(123456789));
  assert(F("12345678.9") == F(123456789) / 10);
  assert(F("123456.789") == F(123456789) / 1000);
  assert(F("123.456789") == F(123456789) / 1000000);
  assert(F("1.23456789") == F(123456789) / 100000000);
  // FIXME: Doesn't work for some reason.
//   assert(F(".123456789") == F(123456789) / 1000000000);
  assert(F("12345678.9") == F(123456789.0)/10);
  assert(F("12345678.9") == F(Format("{}", 12345678.9)));
  // FIXME: The same as the line above, but the mpf_set_d() routine is
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
}

extern(C)
{
alias int mp_size_t;
alias int mp_exp_t;
alias uint mp_limb_t;
alias mpf_struct mpf_t;
alias mpf_t* mpf_ptr, mpf_srcptr;

struct mpf_struct
{
  int prec;
  int size;
  mp_exp_t exp;
  mp_limb_t* limbs;
}

void __gmpf_abs(mpf_ptr, mpf_srcptr);
void __gmpf_add(mpf_ptr, mpf_srcptr, mpf_srcptr);
void __gmpf_add_ui(mpf_ptr, mpf_srcptr, uint);
void __gmpf_clear(mpf_ptr);
int __gmpf_cmp(mpf_srcptr, mpf_srcptr);
int __gmpf_cmp_d(mpf_srcptr, double);
int __gmpf_cmp_si(mpf_srcptr, int);
int __gmpf_cmp_ui(mpf_srcptr, uint);
void __gmpf_div(mpf_ptr, mpf_srcptr, mpf_srcptr);
void __gmpf_div_2exp(mpf_ptr, mpf_srcptr, uint);
void __gmpf_div_ui(mpf_ptr, mpf_srcptr, uint);
void __gmpf_dump(mpf_srcptr);
int __gmpf_eq(mpf_srcptr, mpf_srcptr, uint);
uint __gmpf_get_prec(mpf_srcptr);
char* __gmpf_get_str(char*, mp_exp_t*, int, size_t, mpf_srcptr);
void __gmpf_init(mpf_ptr);
void __gmpf_init2(mpf_ptr, uint);
size_t __gmpf_inp_str(mpf_ptr, FILE*, int);
void __gmpf_init_set(mpf_ptr, mpf_srcptr);
void __gmpf_init_set_d(mpf_ptr, double);
void __gmpf_init_set_si(mpf_ptr, int);
int __gmpf_init_set_str(mpf_ptr, char*, int);
void __gmpf_init_set_ui(mpf_ptr, uint);
void __gmpf_mul(mpf_ptr, mpf_srcptr, mpf_srcptr);
void __gmpf_mul_2exp(mpf_ptr, mpf_srcptr, uint);
void __gmpf_mul_ui(mpf_ptr, mpf_srcptr, uint);
void __gmpf_neg(mpf_ptr, mpf_srcptr);
size_t __gmpf_out_str(FILE*, int, size_t, mpf_srcptr);
void __gmpf_pow_ui(mpf_ptr, mpf_srcptr, uint);
void __gmpf_random2(mpf_ptr, mp_size_t, mp_exp_t);
void __gmpf_reldiff(mpf_ptr, mpf_srcptr, mpf_srcptr);
void __gmpf_set(mpf_ptr, mpf_srcptr);
void __gmpf_set_d(mpf_ptr, double);
void __gmpf_set_default_prec(uint);
void __gmpf_set_prec(mpf_ptr, uint);
void __gmpf_set_prec_raw(mpf_ptr, uint);
void __gmpf_set_si(mpf_ptr, int);
int __gmpf_set_str(mpf_ptr, char*, int);
void __gmpf_set_ui(mpf_ptr, uint);
size_t __gmpf_size(mpf_srcptr);
void __gmpf_sqrt(mpf_ptr, mpf_srcptr);
void __gmpf_sqrt_ui(mpf_ptr, uint);
void __gmpf_sub(mpf_ptr, mpf_srcptr, mpf_srcptr);
void __gmpf_sub_ui(mpf_ptr, mpf_srcptr, uint);
void __gmpf_ui_div(mpf_ptr, uint, mpf_srcptr);
void __gmpf_ui_sub(mpf_ptr, uint, mpf_srcptr);
alias __gmpf_abs mpf_abs;
alias __gmpf_add mpf_add;
alias __gmpf_add_ui mpf_add_ui;
alias __gmpf_clear mpf_clear;
alias __gmpf_cmp mpf_cmp;
alias __gmpf_cmp_d mpf_cmp_d;
alias __gmpf_cmp_si mpf_cmp_si;
alias __gmpf_cmp_ui mpf_cmp_ui;
alias __gmpf_div mpf_div;
alias __gmpf_div_2exp mpf_div_2exp;
alias __gmpf_div_ui mpf_div_ui;
alias __gmpf_dump mpf_dump;
alias __gmpf_eq mpf_eq;
alias __gmpf_get_prec mpf_get_prec;
alias __gmpf_get_str mpf_get_str;
alias __gmpf_init mpf_init;
alias __gmpf_init2 mpf_init2;
alias __gmpf_inp_str mpf_inp_str;
alias __gmpf_init_set mpf_init_set;
alias __gmpf_init_set_d mpf_init_set_d;
alias __gmpf_init_set_si mpf_init_set_si;
alias __gmpf_init_set_str mpf_init_set_str;
alias __gmpf_init_set_ui mpf_init_set_ui;
alias __gmpf_mul mpf_mul;
alias __gmpf_mul_2exp mpf_mul_2exp;
alias __gmpf_mul_ui mpf_mul_ui;
alias __gmpf_neg mpf_neg;
alias __gmpf_out_str mpf_out_str;
alias __gmpf_pow_ui mpf_pow_ui;
alias __gmpf_random2 mpf_random2;
alias __gmpf_reldiff mpf_reldiff;
alias __gmpf_set mpf_set;
alias __gmpf_set_d mpf_set_d;
alias __gmpf_set_default_prec mpf_set_default_prec;
alias __gmpf_set_prec mpf_set_prec;
alias __gmpf_set_prec_raw mpf_set_prec_raw;
alias __gmpf_set_si mpf_set_si;
alias __gmpf_set_str mpf_set_str;
alias __gmpf_set_ui mpf_set_ui;
alias __gmpf_size mpf_size;
alias __gmpf_sqrt mpf_sqrt;
alias __gmpf_sqrt_ui mpf_sqrt_ui;
alias __gmpf_sub mpf_sub;
alias __gmpf_sub_ui mpf_sub_ui;
alias __gmpf_ui_div mpf_ui_div;
alias __gmpf_ui_sub mpf_ui_sub;

}
