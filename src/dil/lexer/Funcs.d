/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.lexer.Funcs;

import dil.Unicode : isUnicodeAlpha;
import common;

/// Converts an unsigned integer to a string (CTF version.)
char[] StringCTF(uint x)
{
  char[] str;
  do
    str = cast(char)('0' + (x % 10)) ~ str;
  while (x /= 10)
  return str;
}

/// Converts an unsigned integer to a string.
char[] String(uint x)
{
  char[10] buffer; // "4294967295".len = 10
  auto end = buffer.ptr + 10;
  auto p = end;
  do
    *--p = '0' + x % 10;
  while (x /= 10)
  return String(p, end).dup;
}

/// Returns a string slice ranging from begin to end.
char[] String(char* begin, char* end)
{
  assert(begin && end && begin <= end);
  return begin[0..end-begin];
}

/// Calculates a hash value for str.
/// Note: The value will differ between 32bit and 64bit systems.
/// It will also differ between little and big endian systems.
hash_t hashOf(string str)
{
  hash_t hash;
  char* pstr = str.ptr;
  size_t len = str.length;

  ubyte rem_len = len % hash_t.sizeof; // Remainder.
  if (len == rem_len)
    goto Lonly_remainder;

  auto hptr = cast(hash_t*)pstr;
  // Divide the length by 4 or 8 (x86 vs. x86_64).
  auto hlen = len / hash_t.sizeof;
  assert(hlen, "can't be zero");

  while (hlen--) // Main loop.
    hash = hash * 11 + *hptr++;

  if (rem_len)
  { // Calculate the hash of the remaining characters.
    pstr = cast(char*)hptr; // hptr points exactly to the remainder.
  Lonly_remainder:
    size_t chunk;
    while (rem_len--) // Remainder loop.
      chunk = (chunk << 8) | *pstr++;
    hash = hash * 11 + chunk;
  }

  return hash;
}

const char[3] LS = "\u2028"; /// Unicode line separator.
const dchar LSd = 0x2028;  /// ditto
const char[3] PS = "\u2029"; /// Unicode paragraph separator.
const dchar PSd = 0x2029;  /// ditto
static assert(LS[0] == PS[0] && LS[1] == PS[1]);

const dchar _Z_ = 26; /// Control+Z.

/// Returns: true if d is a Unicode line or paragraph separator.
bool isUnicodeNewlineChar(dchar d)
{
  return d == LSd || d == PSd;
}

/// Returns: true if p points to a line or paragraph separator.
bool isUnicodeNewline(char* p)
{
  return *p == LS[0] && p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]);
}

/// Returns: true if p points to the start of a Newline.
/// $(BNF
////Newline := "\n" | "\r" | "\r\n" | LS | PS
////LS := "\u2028"
////PS := "\u2029"
////)
bool isNewline(char* p)
{
  return *p == '\n' || *p == '\r' || isUnicodeNewline(p);
}

/// Returns: true if c is a Newline character.
bool isNewline(dchar c)
{
  return c == '\n' || c == '\r' || isUnicodeNewlineChar(c);
}

/// Returns: true if p points to an EOF character.
/// $(BNF
////EOF := "\0" | _Z_
////_Z_ := "\x1A"
////)
bool isEOF(dchar c)
{
  return c == 0 || c == _Z_;
}

/// Returns: true if p points to the first character of an EndOfLine.
/// $(BNF EndOfLine := Newline | EOF)
bool isEndOfLine(char* p)
{
  return isNewline(p) || isEOF(*p);
}

/// Scans a Newline and sets p one character past it.
/// Returns: true if found or false otherwise.
bool scanNewline(ref char* p)
in { assert(p); }
body
{
  switch (*p)
  {
  case '\r':
    if (p[1] == '\n')
      ++p;
  case '\n':
    ++p;
    break;
  default:
    if (isUnicodeNewline(p))
      p += 3;
    else
      return false;
  }
  return true;
}

/// Scans a Newline and sets p one character past it.
/// Returns: true if found or false otherwise.
bool scanNewline(ref char* p, char* end)
in { assert(p && p < end); }
body
{
  switch (*p)
  {
  case '\r':
    if (p+1 < end && p[1] == '\n')
      ++p;
  case '\n':
    ++p;
    break;
  default:
    if (p+2 < end && isUnicodeNewline(p))
      p += 3;
    else
      return false;
  }
  return true;
}

/// Scans a Newline in reverse direction and sets end
/// on the first character of the newline.
/// Returns: true if found or false otherwise.
bool scanNewlineReverse(char* begin, ref char* end)
{
  switch (*end)
  {
  case '\n':
    if (begin <= end-1 && end[-1] == '\r')
      end--;
  case '\r':
    break;
  case LS[2], PS[2]:
    if (begin <= end-2 && end[-1] == LS[1] && end[-2] == LS[0]) {
      end -= 2;
      break;
    }
  // fall through
  default:
    return false;
  }
  return true;
}

/// Scans a D identifier.
/// Params:
///   ref_p = where to start.
///   end = where it ends.
/// Returns: the identifier if valid (sets ref_p one past the id,) or
///          null if invalid (leaves ref_p unchanged.)
char[] scanIdentifier(ref char* ref_p, char* end)
in { assert(ref_p && ref_p < end); }
body
{
  auto p = ref_p;
  if (isidbeg(*p) || isUnicodeAlpha(p, end)) // IdStart
  {
    do // IdChar*
      p++;
    while (p < end && (isident(*p) || isUnicodeAlpha(p, end)))
    auto identifier = ref_p[0 .. p-ref_p];
    ref_p = p;
    return identifier;
  }
  return null;
}

/// ASCII character properties table.
static const int ptable[256] = [
 0, 0, 0, 0, 0, 0, 0, 0, 0,32, 0,32,32, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
32, 0, 0x2200, 0, 0, 0, 0, 0x2700, 0, 0, 0, 0, 0, 0, 0, 0,
 7, 7, 7, 7, 7, 7, 7, 7, 6, 6, 0, 0, 0, 0, 0, 0x3f00,
 0,12,12,12,12,12,12, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0x5c00, 0, 0,16,
 0, 0x70c, 0x80c,12,12,12, 0xc0c, 8, 8, 8, 8, 8, 8, 8, 0xa08, 8,
 8, 8, 0xd08, 8, 0x908, 8, 0xb08, 8, 8, 8, 8, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
];

/// Enumeration of character property flags.
enum CProperty
{
       Octal = 1,    /// [0-7]
       Digit = 1<<1, /// [0-9]
         Hex = 1<<2, /// [0-9a-fA-F]
       Alpha = 1<<3, /// [a-zA-Z]
  Underscore = 1<<4, /// [_]
  Whitespace = 1<<5  /// [ \t\v\f]
}

const uint EVMask = 0xFF00; // Bit mask for escape value.

private alias CProperty CP;
/// Returns: true if c is an octal digit.
int isoctal(char c) { return ptable[c] & CP.Octal; }
/// Returns: true if c is a decimal digit.
int isdigit(char c) { return ptable[c] & CP.Digit; }
/// Returns: true if c is a hexadecimal digit.
int ishexad(char c) { return ptable[c] & CP.Hex; }
/// Returns: true if c is a letter.
int isalpha(char c) { return ptable[c] & CP.Alpha; }
/// Returns: true if c is an alphanumeric.
int isalnum(char c) { return ptable[c] & (CP.Alpha | CP.Digit); }
/// Returns: true if c is the beginning of a D identifier (only ASCII.)
int isidbeg(char c) { return ptable[c] & (CP.Alpha | CP.Underscore); }
/// Returns: true if c is a D identifier character (only ASCII.)
int isident(char c) { return ptable[c] & (CP.Alpha | CP.Underscore | CP.Digit); }
/// Returns: true if c is a whitespace character.
int isspace(char c) { return ptable[c] & CP.Whitespace; }
/// Returns: the escape value for c.
int char2ev(char c) { return ptable[c] >> 8; /*(ptable[c] & EVMask) >> 8;*/ }
/// Returns: true if c is an ASCII character.
int isascii(uint c) { return c < 128; }

version(gen_ptable)
static this()
{
  alias ptable p;
  assert(p.length == 256);
  // Initialize character properties table.
  for (int i; i < p.length; ++i)
  {
    p[i] = 0; // Reset
    if ('0' <= i && i <= '7')
      p[i] |= CP.Octal;
    if ('0' <= i && i <= '9')
      p[i] |= CP.Digit | CP.Hex;
    if ('a' <= i && i <= 'f' || 'A' <= i && i <= 'F')
      p[i] |= CP.Hex;
    if ('a' <= i && i <= 'z' || 'A' <= i && i <= 'Z')
      p[i] |= CP.Alpha;
    if (i == '_')
      p[i] |= CP.Underscore;
    if (i == ' ' || i == '\t' || i == '\v' || i == '\f')
      p[i] |= CP.Whitespace;
  }
  // Store escape sequence values in second byte.
  assert(CProperty.max <= ubyte.max, "character property flags and escape value byte overlap.");
  p['\''] |= 39 << 8;
  p['"'] |= 34 << 8;
  p['?'] |= 63 << 8;
  p['\\'] |= 92 << 8;
  p['a'] |= 7 << 8;
  p['b'] |= 8 << 8;
  p['f'] |= 12 << 8;
  p['n'] |= 10 << 8;
  p['r'] |= 13 << 8;
  p['t'] |= 9 << 8;
  p['v'] |= 11 << 8;
  // Print a formatted array literal.
  char[] array = "[\n";
  foreach (i, c; ptable)
  {
    array ~= Format((c>255?" 0x{0:x},":"{0,2},"), c) ~ (((i+1) % 16) ? "":"\n");
  }
  array[$-2..$] = "\n]";
  Stdout(array).newline;
}
