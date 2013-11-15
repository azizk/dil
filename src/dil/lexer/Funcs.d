/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.lexer.Funcs;

import dil.Unicode : scanUnicodeAlpha, isUnicodeAlpha, encode, isValidChar;
import dil.String : slice;
import common;

const char[3] LS = "\u2028"; /// Unicode line separator.
const dchar LSd = 0x2028;  /// ditto
const char[3] PS = "\u2029"; /// Unicode paragraph separator.
const dchar PSd = 0x2029;  /// ditto
static assert(LS[0] == PS[0] && LS[1] == PS[1]);

const dchar _Z_ = 26; /// Control+Z.

/// Casts a string to an integer at compile-time.
/// Allows for fast string comparison using integers:
/// *cast(uint*)"\xAA\xBB\xCC\xDD".ptr == castInt("\xAA\xBB\xCC\xDD")
static size_t castInt(cstring s)
{
  assert(s.length <= size_t.sizeof);
  size_t x;
  foreach (i, c; s)
    version(BigEndian)
      x = (x << 8) | c; // Add c as LSByte.
    else
      x |= (c << i*8); // Add c as MSByte.
  return x;
}
version(LittleEndian)
static assert(castInt("\xAA\xBB\xCC\xDD") == 0xDDCCBBAA &&
  castInt("\xAB\xCD\xEF") == 0xEFCDAB && castInt("\xAB\xCD") == 0xCDAB);
else
static assert(castInt("\xAA\xBB\xCC\xDD") == 0xAABBCCDD &&
  castInt("\xAB\xCD\xEF") == 0xABCDEF && castInt("\xAB\xCD") == 0xABCD);

/// Returns: true if d is a Unicode line or paragraph separator.
bool isUnicodeNewlineChar(dchar d)
{
  return d == LSd || d == PSd;
}

/// Returns: true if p points to a line or paragraph separator.
bool isUnicodeNewline(cchar* p)
{
  return *p == LS[0] && p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]);
}

/// Returns: true if p points to the start of a Newline.
/// $(BNF
////Newline := "\n" | "\r" | "\r\n" | LS | PS
////LS := "\u2028"
////PS := "\u2029"
////)
bool isNewline(cchar* p)
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
bool isEndOfLine(cchar* p)
{
  return isNewline(p) || isEOF(*p);
}

/// Scans a Newline and sets p one character past it.
/// Returns: true if found or false otherwise.
bool scanNewline(ref cchar* p)
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
bool scanNewline(ref cchar* p, cchar* end)
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
bool scanNewlineReverse(cchar* begin, ref cchar* end)
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
///   ref_p = Where to start.
///   end = Where it ends.
/// Returns: the identifier if valid (sets ref_p one past the id,) or
///          null if invalid (leaves ref_p unchanged.)
cstring scanIdentifier(ref cchar* ref_p, cchar* end)
in { assert(ref_p && ref_p < end); }
body
{
  auto p = ref_p;
  if (isidbeg(*p) || scanUnicodeAlpha(p, end)) // IdStart
  {
    do // IdChar*
      p++;
    while (p < end && (isident(*p) || scanUnicodeAlpha(p, end)));
    auto identifier = slice(ref_p, p);
    ref_p = p;
    return identifier;
  }
  return null;
}

/// Returns true if p points to the start of a D identifier.
bool isIdentifierStart(cchar* p, cchar* end)
{
  return isidbeg(*p) || isUnicodeAlpha(p, end);
}

/// Returns an escape sequence if c is not printable.
cstring escapeNonPrintable(dchar c)
{
  const H = "0123456789ABCDEF"; // Hex numerals.
  char[] s;
  if (c < 128)
  { // ASCII
    switch (c)
    {
    case '\0': c = '0'; goto Lcommon;
    case '\a': c = 'a'; goto Lcommon;
    case '\b': c = 'b'; goto Lcommon;
    case '\f': c = 'f'; goto Lcommon;
    case '\n': c = 'n'; goto Lcommon;
    case '\r': c = 'r'; goto Lcommon;
    case '\t': c = 't'; goto Lcommon;
    case '\v': c = 'v'; goto Lcommon;
    Lcommon:
      s = ['\\', cast(char)c];
      break;
    default:
      if (c < 0x20 || c == 0x7F)
        // Special non-printable characters.
        s = ['\\', 'x', H[c>>4], H[c&0x0F]];
      else // The rest is printable.
        s ~= c;
    }
  }
  else
  { // UNICODE
    // TODO: write function isUniPrintable() similar to isUniAlpha().
    if (0x80 >= c && c <= 0x9F) // C1 control character set.
      s = ['\\', 'u', '0', '0', H[c>>4], H[c&0x0F]];
    else if (!isValidChar(c))
    {
      if (c <= 0xFF)
        s = ['\\', 'x', H[c>>4], H[c&0x0F]];
      else if (c <= 0xFFFF)
        s = ['\\', 'x', H[c>>12], H[c>>8&0x0F],
             '\\', 'x', H[c>>4&0x0F], H[c&0x0F]];
      else
        s = ['\\', 'x', H[c>>28], H[c>>24&0x0F],
             '\\', 'x', H[c>>20&0x0F], H[c>>16&0x0F],
             '\\', 'x', H[c>>12&0x0F], H[c>>8&0x0F],
             '\\', 'x', H[c>>4&0x0F], H[c&0x0F]];
    }
    else // Treat the rest as printable.
      encode(s, c);
  }
  return s;
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

private alias CP = CProperty;
/// Returns: true if c is an octal digit.
int isoctal(char c) { return ptable[c] & CP.Octal; }
/// Returns: true if c is a decimal digit.
int isdigit(char c) { return ptable[c] & CP.Digit; }
/// ditto
int isdigit(uint c) { return isdigit(cast(char)c); }
/// Returns: true if c is a decimal digit or '_'.
int isdigi_(char c) { return ptable[c] & (CP.Digit | CP.Underscore); }
/// Returns: true if c is a hexadecimal digit.
int ishexad(char c) { return ptable[c] & CP.Hex; }
/// ditto
int ishexad(uint c) { return ishexad(cast(char)c); }
/// Returns: true if c is a hexadecimal digit or '_'.
int ishexa_(char c) { return ptable[c] & (CP.Hex | CP.Underscore); }
/// Returns: true if c is a letter.
int isalpha(char c) { return ptable[c] & CP.Alpha; }
/// Returns: true if c is an alphanumeric.
int isalnum(char c) { return ptable[c] & (CP.Alpha | CP.Digit); }
/// Returns: true if c is the beginning of a D identifier (only ASCII.)
int isidbeg(char c) { return ptable[c] & (CP.Alpha | CP.Underscore); }
/// ditto
int isidbeg(dchar c) { return isidbeg(cast(char)c); }
/// ditto
int isidbeg(uint c) { return isidbeg(cast(char)c); }
/// Returns: true if c is a D identifier character (only ASCII.)
int isident(char c) { return ptable[c] & (CP.Alpha|CP.Underscore|CP.Digit); }
/// ditto
int isident(uint c) { return isident(cast(char)c); }
/// Returns: true if c is a whitespace character.
int isspace(char c) { return ptable[c] & CP.Whitespace; }
/// ditto
int isspace(uint c) { return isspace(cast(char)c); }
/// Returns: the escape value for c.
int char2ev(char c) { return ptable[c] >> 8; /*(ptable[c] & EVMask) >> 8;*/ }
/// Returns: true if c is an ASCII character.
int isascii(uint c) { return c < 128; }

/// Returns true if the string is empty or has only whitespace characters.
bool isAllSpace(cchar* start, cchar* end)
{
  for (; start < end; start++)
    if (!isspace(*start))
      return false;
  return true;
}

/// Converts c to its hexadecimal value. Returns false if c isn't a hex digit.
bool hex2val(Char)(ref Char c)
{
  if (c - '0' < 10)
    c -= '0';
  else if ((c|0x20) - 'a' < 6) // 'A'|0x20 == 'a'
    c = (c|0x20) - 'a' + 10;
  else
    return false;
  return true;
}

version(gen_ptable)
static this()
{
  alias p = ptable;
  assert(p.length == 256);
  // Initialize character properties table.
  for (size_t i; i < p.length; ++i)
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
  assert(CProperty.max <= ubyte.max,
    "character property flags and escape value byte overlap.");
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
  char[] array = "[\n".dup;
  foreach (i, c; ptable)
  {
    array ~= Format((c>255?" 0x{0:x},":"{0,2},"), c) ~ (((i+1) % 16) ? "":"\n");
  }
  array[$-2..$] = "\n]";
  Stdout(array).newline;
}
