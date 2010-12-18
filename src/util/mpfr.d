/// Binding module to the $(LINK2 http://www.mpfr.org/, MPFR) library.
/// Author: Aziz Köksal
/// License: Public Domain
module util.mpfr;

/// Enumeration of rounding methods.
enum mpfr_rnd_t : int
{
  RNDN, /// Round to nearest with ties to even.
  RNDZ, /// Round toward zero.
  RNDU, /// Round toward +Inf.
  RNDD, /// Round toward -Inf.
  RNDA, /// Round away from zero.
  RNDF, /// Faithful rounding.
  RNDNA = -1, /// Round to nearest with ties away from zero.
}

alias int    mpfr_prec_t; /// Precision type.
alias int    mpfr_sign_t; /// Sign type.
alias int    mpfr_exp_t;  /// Exponent type.
alias size_t mpfr_limb_t; /// Limb type.
alias mpfr_struct mpfr_t; /// Float type.
alias mpfr_t*     mpfr_ptr, mpfr_srcptr; /// Pointer to float type.

const MPFR_EXP_ZERO = mpfr_exp_t.min + 1; /// Exponent is zero.
const MPFR_EXP_NAN  = mpfr_exp_t.min + 2; /// Exponent of a NAN.
const MPFR_EXP_INF  = mpfr_exp_t.min + 3; /// Exponent of an Inf number.


/// The multi-precision float number structure.
struct mpfr_struct
{
  mpfr_prec_t  prec;  /// The precision of this float.
  mpfr_sign_t  size;  /// The number of limbs. Highest bit determines the sign.
  mpfr_exp_t   exp;   /// The exponent.
  mpfr_limb_t* limbs; /// The mantissa or significand.

  /// Returns the number of limbs.
  size_t len()
  {
    return size < 0 ? -size : size;
  }

  /// Returns the limbs as an array.
  mpfr_limb_t[] limbs_array()
  {
    return limbs[0..len()];
  }
}

extern(C)
{
char* mpfr_get_version();

void mpfr_init(mpfr_ptr);
void mpfr_init2(mpfr_ptr, mpfr_prec_t);
void mpfr_clear(mpfr_ptr);

void mpfr_set(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
void mpfr_set_d(mpfr_ptr, double, mpfr_rnd_t);
void mpfr_set_si(mpfr_ptr, int, mpfr_rnd_t);
int  mpfr_set_str(mpfr_ptr, char*, int, mpfr_rnd_t);
void mpfr_set_ui(mpfr_ptr, uint, mpfr_rnd_t);

int  mpfr_set_exp(mpfr_ptr, mpfr_exp_t);
mpfr_exp_t mpfr_get_exp(mpfr_ptr);

mpfr_prec_t mpfr_get_prec(mpfr_srcptr);
mpfr_prec_t mpfr_get_default_prec();
void mpfr_set_default_prec(mpfr_prec_t);
void mpfr_set_prec(mpfr_ptr, mpfr_prec_t);
void mpfr_set_prec_raw(mpfr_ptr, mpfr_prec_t);
void mpfr_prec_round(mpfr_ptr, mpfr_prec_t, mpfr_rnd_t);

void mpfr_neg(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
void mpfr_abs(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);

void mpfr_add(mpfr_ptr, mpfr_srcptr, mpfr_srcptr, mpfr_rnd_t);
void mpfr_add_ui(mpfr_ptr, mpfr_srcptr, uint, mpfr_rnd_t);
void mpfr_sub(mpfr_ptr, mpfr_srcptr, mpfr_srcptr, mpfr_rnd_t);
void mpfr_sub_ui(mpfr_ptr, mpfr_srcptr, uint, mpfr_rnd_t);
void mpfr_ui_sub(mpfr_ptr, uint, mpfr_srcptr, mpfr_rnd_t);

void mpfr_div(mpfr_ptr, mpfr_srcptr, mpfr_srcptr, mpfr_rnd_t);
void mpfr_div_2ui(mpfr_ptr, mpfr_srcptr, uint, mpfr_rnd_t);
void mpfr_div_ui(mpfr_ptr, mpfr_srcptr, uint, mpfr_rnd_t);
void mpfr_ui_div(mpfr_ptr, uint, mpfr_srcptr, mpfr_rnd_t);
void mpfr_mul(mpfr_ptr, mpfr_srcptr, mpfr_srcptr, mpfr_rnd_t);
void mpfr_mul_2ui(mpfr_ptr, mpfr_srcptr, uint, mpfr_rnd_t);
void mpfr_mul_ui(mpfr_ptr, mpfr_srcptr, uint, mpfr_rnd_t);
void mpfr_ui_mul(mpfr_ptr, uint, mpfr_srcptr, mpfr_rnd_t);

void mpfr_sqrt(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
void mpfr_sqrt_ui(mpfr_ptr, uint, mpfr_rnd_t);
void mpfr_pow(mpfr_ptr, mpfr_srcptr, mpfr_srcptr, mpfr_rnd_t);
void mpfr_pow_ui(mpfr_ptr, mpfr_srcptr, uint, mpfr_rnd_t);

int  mpfr_cmp(mpfr_srcptr, mpfr_srcptr);
int  mpfr_cmp_d(mpfr_srcptr, double);
int  mpfr_cmp_si(mpfr_srcptr, int);
int  mpfr_cmp_ui(mpfr_srcptr, uint);
int  mpfr_equal_p(mpfr_srcptr, mpfr_srcptr);
int  mpfr_eq(mpfr_srcptr, mpfr_srcptr, uint);

// Format functions:
int mpfr_strtofr(mpfr_ptr, char*, char**, int base, mpfr_rnd_t);
int mpfr_snprintf(char*, size_t, char*, ...);
// int mpfr_vsnprintf(char*, size_t, char*, va_list);
int mpfr_asprintf(char** str, char*, ...);
// int mpfr_vasprintf(char** str, char*, va_list);
void mpfr_free_str(char*);
char* mpfr_get_str(char*, mpfr_exp_t*, int, size_t, mpfr_srcptr, mpfr_rnd_t);

// Logarithmic functions:
int mpfr_log(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_log2(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_log10(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);

int mpfr_exp(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_exp2(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_exp10(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);

// Trigonometric functions:
int mpfr_atanh(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_acosh(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_asinh(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_cosh(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_sinh(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_tanh(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_sinh_cosh(mpfr_ptr, mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);

int mpfr_sech(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_csch(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_coth(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);

int mpfr_acos(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_asin(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_atan(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_sin(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_sin_cos(mpfr_ptr, mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_cos(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_tan(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_atan2(mpfr_ptr, mpfr_srcptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_sec(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_csc(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);
int mpfr_cot(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);

int mpfr_hypot(mpfr_ptr, mpfr_srcptr, mpfr_srcptr, mpfr_rnd_t);
}
