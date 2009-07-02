/// Binding module to the MPFR library.
/// Author: Aziz Köksal
/// License: Public Domain
module util.mpfr;

// import tango.stdc.stdio : FILE;

enum mp_rnd_t
{
  GMP_RNDN, GMP_RNDZ, GMP_RNDU, GMP_RNDD, GMP_RND_MAX,
  GMP_RNDNA = -1
}

alias int mp_size_t, mp_exp_t;
alias size_t mp_limb_t; // 8 bytes on 64bit systems, 4 bytes on 32bit.
alias uint mpfr_prec_t;
alias int mpfr_sign_t;
alias mpfr_struct mpfr_t;
alias mpfr_t* mpfr_ptr, mpfr_srcptr;

const MPFR_EXP_ZERO = mp_exp_t.min + 1;
const MPFR_EXP_NAN  = mp_exp_t.min + 2;
const MPFR_EXP_INF  = mp_exp_t.min + 3;

struct mpfr_struct
{
  mpfr_prec_t prec;
  mpfr_sign_t size;
  mp_exp_t exp;
  mp_limb_t* limbs;
}

extern(C)
{
void mpfr_abs(mpfr_ptr, mpfr_srcptr);
void mpfr_add(mpfr_ptr, mpfr_srcptr, mpfr_srcptr);
void mpfr_add_ui(mpfr_ptr, mpfr_srcptr, uint, mp_rnd_t);
void mpfr_clear(mpfr_ptr);
int mpfr_cmp(mpfr_srcptr, mpfr_srcptr);
int mpfr_cmp_d(mpfr_srcptr, double);
int mpfr_cmp_si(mpfr_srcptr, int);
int mpfr_cmp_ui(mpfr_srcptr, uint);
void mpfr_div(mpfr_ptr, mpfr_srcptr, mpfr_srcptr, mp_rnd_t);
void mpfr_div_2ui(mpfr_ptr, mpfr_srcptr, uint, mp_rnd_t);
void mpfr_div_ui(mpfr_ptr, mpfr_srcptr, uint, mp_rnd_t);
void mpfr_dump(mpfr_srcptr);
int mpfr_equal_p(mpfr_srcptr, mpfr_srcptr);
int mpfr_eq(mpfr_srcptr, mpfr_srcptr, uint);
uint mpfr_get_prec(mpfr_srcptr);
char* mpfr_get_str(char*, mp_exp_t*, int, size_t, mpfr_srcptr, mp_rnd_t);
void mpfr_init(mpfr_ptr);
void mpfr_init2(mpfr_ptr, uint);
// size_t mpfr_inp_str(mpfr_ptr, FILE*, int);
void mpfr_mul(mpfr_ptr, mpfr_srcptr, mpfr_srcptr, mp_rnd_t);
void mpfr_mul_2ui(mpfr_ptr, mpfr_srcptr, uint, mp_rnd_t);
void mpfr_mul_ui(mpfr_ptr, mpfr_srcptr, uint, mp_rnd_t);
void mpfr_neg(mpfr_ptr, mpfr_srcptr);
// size_t mpfr_out_str(FILE*, int, size_t, mpfr_srcptr);
void mpfr_pow_ui(mpfr_ptr, mpfr_srcptr, uint, mp_rnd_t);
void mpfr_random2(mpfr_ptr, mp_size_t, mp_exp_t);
void mpfr_reldiff(mpfr_ptr, mpfr_srcptr, mpfr_srcptr);
void mpfr_set(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
void mpfr_set_d(mpfr_ptr, double, mp_rnd_t);
void mpfr_set_default_prec(uint);
void mpfr_set_prec(mpfr_ptr, uint);
void mpfr_set_prec_raw(mpfr_ptr, uint);
void mpfr_set_si(mpfr_ptr, int, mp_rnd_t);
int mpfr_set_str(mpfr_ptr, char*, int, mp_rnd_t);
void mpfr_set_ui(mpfr_ptr, uint, mp_rnd_t);
size_t mpfr_size(mpfr_srcptr);
void mpfr_sqrt(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
void mpfr_sqrt_ui(mpfr_ptr, uint, mp_rnd_t);
void mpfr_sub(mpfr_ptr, mpfr_srcptr, mpfr_srcptr, mp_rnd_t);
void mpfr_sub_ui(mpfr_ptr, mpfr_srcptr, uint, mp_rnd_t);
void mpfr_ui_div(mpfr_ptr, uint, mpfr_srcptr, mp_rnd_t);
void mpfr_ui_sub(mpfr_ptr, uint, mpfr_srcptr, mp_rnd_t);

// Format functions:
int mpfr_strtofr(mpfr_ptr, char*, char**, int base, mp_rnd_t);
int mpfr_snprintf(char*, size_t, char*, ...);
// int mpfr_vsnprintf(char*, size_t, char*, va_list);
int mpfr_asprintf(char** str, char*, ...);
// int mpfr_vasprintf(char** str, char*, va_list);
void mpfr_free_str(char*);

// Logarithmic functions:
int mpfr_log(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_log2(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_log10(mpfr_ptr, mpfr_srcptr, mp_rnd_t);

int mpfr_exp(mpfr_ptr, mpfr_srcptr, mp_rnd_t);

// Trigonometric functions:
int mpfr_atanh(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_acosh(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_asinh(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_cosh(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_sinh(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_tanh(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_sinh_cosh(mpfr_ptr, mpfr_ptr, mpfr_srcptr, mp_rnd_t);

int mpfr_sech(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_csch(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_coth(mpfr_ptr, mpfr_srcptr, mp_rnd_t);

int mpfr_acos(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_asin(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_atan(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_sin(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_sin_cos(mpfr_ptr, mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_cos(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_tan(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_atan2(mpfr_ptr, mpfr_srcptr, mpfr_srcptr, mp_rnd_t);
int mpfr_sec(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_csc(mpfr_ptr, mpfr_srcptr, mp_rnd_t);
int mpfr_cot(mpfr_ptr, mpfr_srcptr, mp_rnd_t);

int mpfr_hypot(mpfr_ptr, mpfr_srcptr, mpfr_srcptr, mp_rnd_t);
}
