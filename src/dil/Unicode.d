/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.Unicode;

import common;

public import util.uni : isUniAlpha;

/// U+FFFD = �. Used to replace invalid Unicode characters.
enum cdchar REPLACEMENT_CHAR = '\uFFFD';
enum cchar[3] REPLACEMENT_STR = "\uFFFD"; /// Ditto
/// Invalid character, returned on errors.
enum dchar ERROR_CHAR = 0xD800;

/// Returns: true if this character is not a surrogate
/// code point and not higher than 0x10FFFF.
bool isValidChar(dchar d)
{
  return d < 0xD800 || (d > 0xDFFF && d <= 0x10FFFF);
}

/// There are a total of 66 noncharacters.
/// Returns: true if this is one of them.
/// See_also: Chapter 16.7 Noncharacters in Unicode 5.0
bool isNoncharacter(dchar d)
{
  return 0xFDD0 <= d && d <= 0xFDEF || // 32
         d <= 0x10FFFF && (d & 0xFFFF) >= 0xFFFE; // 34
}

/// Returns: true if this is a trail byte of a UTF-8 sequence.
bool isTrailByte(ubyte b)
{
  return (b & 0xC0) == 0x80; // 10xx_xxxx
}

/// Returns: true if this is a lead byte of a UTF-8 sequence.
bool isLeadByte(ubyte b)
{
  return (b & 0xC0) == 0xC0; // 11xx_xxxx
}

// FIXME: isValidLead() should return true for ASCII as well.
/// Returns: true if c is a valid lead character.
bool isValidLead(char c)
{ // NB: not all overlong sequences are checked.
  return (c & 0xC0) == 0xC0 && (c & 0xFE) != 0xC0;
}

/// ditto
bool isValidLead(wchar c)
{
  return c <= 0xDBFF || c > 0xDFFF;
}

/// ditto
bool isValidLead(dchar c)
{
  return isValidChar(c);
}

/// Enumeration of errors related to decoding UTF-8 sequences.
enum UTF8Error
{
  Invalid,    /// The correctly decoded character is invalid.
  Overlong,   /// Overlong sequence (must be encoded with fewer bytes.)
  TrailByte,  /// Missing trail byte.
  Over4Bytes, /// The sequence is longer than 4 bytes.
}
/// Enumeration of errors related to decoding UTF-16 sequences.
enum UTF16Error
{
  Invalid,     /// The correctly decoded character is invalid.
  LoSurrogate, /// Missing low surrogate wchar.
  HiSurrogate, /// Missing high surrogate wchar.
}

/// Returns the precise error in a UTF-8 sequence.
UTF8Error utf8Error(cstring s, ref size_t i)
{
  auto p = s.ptr + i;
  auto e = utf8Error(p, s.ptr + s.length);
  i = p - s.ptr;
  return e;
}
/// ditto
UTF8Error utf8Error(ref cchar* p, cchar* end)
in { auto p_ = p; assert(decode(p_, end) == ERROR_CHAR); }
body
{
  UTF8Error error = UTF8Error.Invalid;
  dchar c = *p;
  assert(c >= 0x80);
  if (!(++p < end && isTrailByte(*p)))
    return UTF8Error.TrailByte;
  if (c.In(0xE0, 0xF0, 0xF8, 0xFC) && (c & *p) == 0x80 ||
      (c & 0xFE) == 0xC0) // 1100000x
    return UTF8Error.Overlong;
  if ((c & 0b1110_0000) == 0b1100_0000)
  {}
  else if ((c & 0b1111_0000) == 0b1110_0000)
  {
    if (!(p + 1 < end && isTrailByte(*++p)))
      error = UTF8Error.TrailByte;
  }
  else if ((c & 0b1111_1000) == 0b1111_0000)
  {
    if (!(p + 2 < end && isTrailByte(*++p) && isTrailByte(*++p)))
      error = UTF8Error.TrailByte;
  }
  else
    error = UTF8Error.Over4Bytes;
  return error;
}
/// Returns the precise error in a UTF-16 sequence.
UTF16Error utf16Error(cwstring s, ref size_t i)
{
  auto p = s.ptr + i;
  auto e = utf16Error(p, s.ptr + s.length);
  i = p - s.ptr;
  return e;
}
/// ditto
UTF16Error utf16Error(ref cwchar* p, cwchar* end)
in { auto p_ = p; assert(decode(p_, end) == ERROR_CHAR); }
body
{
  dchar c = *p;
  UTF16Error error = UTF16Error.LoSurrogate;
  if (c > 0xDBFF)
    error = UTF16Error.HiSurrogate;
  else if (p+1 < end && 0xDC00 <= (c = p[1]) && c <= 0xDFFF)
    (error = UTF16Error.Invalid), p++;
  p++;
  return error;
}

// NB: All functions below advance the pointer/index only
//     when the decoded Unicode sequence was valid.

/// Advances ref_p only if this is a valid Unicode alpha character.
/// Params:
///   ref_p = Set to the last trail byte of the valid UTF-8 sequence.
/// Returns: The valid alpha character or 0.
dchar decodeUnicodeAlpha(ref cchar* ref_p, cchar* end)
in { assert(ref_p && ref_p < end); }
out(c) { assert(c == 0 || isUniAlpha(c)); }
body
{
  dchar c = 0;
  if (*ref_p >= 0x80)
  {
    auto p = ref_p;
    c = decode(p, end);
    if (isUniAlpha(c))
      ref_p = p-1; // Subtract 1 because of decode().
    else
      c = 0;
  }
  return c;
}

/// Returns true when p points to a valid Unicode alpha character
/// (also advances p.)
bool scanUnicodeAlpha(ref cchar* p, cchar* end)
{
  return !!decodeUnicodeAlpha(p, end);
}

/// Returns true when p points to a valid Unicode alpha character.
bool isUnicodeAlpha(cchar* p, cchar* end)
{
  return !!decodeUnicodeAlpha(p, end);
}

/// Decodes a character from str at index.
/// Params:
///   index = Set to one past the ASCII char or one past the last trail byte
///           of the valid UTF-8 sequence.
dchar decode(cstring str, ref size_t index)
in { assert(str.length && index < str.length); }
out { assert(index <= str.length); }
body
{
  auto p = str.ptr + index;
  auto end = str.ptr + str.length;
  dchar c = decode(p, end);
  if (c != ERROR_CHAR)
    index = p - str.ptr;
  return c;
}

/// Decodes a character starting at ref_p.
/// Params:
///   ref_p = Set to one past the ASCII char or one past the last trail byte
///           of the valid UTF-8 sequence.
dchar decode(ref cchar* ref_p, cchar* end)
in { assert(ref_p && ref_p < end); }
out(c) { assert(ref_p <= end && (isValidChar(c) || c == ERROR_CHAR)); }
body
{
  auto p = ref_p;
  dchar c = *p;
  char c2 = void;

  if (c < 0x80)
    goto Lreturn; // ASCII character.

  // Error if: end of string or second byte is not a trail byte.
  if (!(++p < end && isTrailByte(c2 = *p)))
    goto Lerror;

  // Check for overlong sequences.
  // 0xE0: c=11100000 c2=100xxxxx
  // 0xF0: c=11110000 c2=1000xxxx
  // 0xF8: c=11111000 c2=10000xxx
  // 0xFC: c=11111100 c2=100000xx
  if (c.In(0xE0, 0xF0, 0xF8, 0xFC) && (c & c2) == 0x80 ||
      (c & 0xFE) == 0xC0) // 1100000x
    goto Lerror;

  enum checkNextByte = "if (!isTrailByte(c2 = *++p))"
                               "  goto Lerror;";
  enum appendSixBits = "c = (c << 6) | c2 & 0b0011_1111;";

  // See how many bytes need to be decoded.
  assert(p == ref_p+1, "p doesn't point to the second byte");
  if ((c & 0b1110_0000) == 0b1100_0000)
  { // 110xxxxx 10xxxxxx
    c &= 0b0001_1111;
    goto L2Bytes;
  }
  else if ((c & 0b1111_0000) == 0b1110_0000)
  { // 1110xxxx 10xxxxxx 10xxxxxx
    c &= 0b0000_1111;
    if (p + 1 < end)
      goto L3Bytes;
  }
  else if ((c & 0b1111_1000) == 0b1111_0000)
  { // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
    c &= 0b0000_0111;
    if (p + 2 < end)
      goto L4Bytes;
  }
  else
  { // 5 and 6 byte UTF-8 sequences are not allowed yet.
    // 111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
    // 1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
  }
  goto Lerror;

  // Decode the bytes now.
L4Bytes:
  mixin(appendSixBits);
  mixin(checkNextByte);
L3Bytes:
  mixin(appendSixBits);
  mixin(checkNextByte);
L2Bytes:
  mixin(appendSixBits);

  assert(isTrailByte(c2));
  if (!isValidChar(c)) // Final check for validity.
    goto Lerror;
Lreturn:
  ref_p = p+1; // Character is valid. Advance the pointer.
  return c;
Lerror:
  return ERROR_CHAR;
}

/// Encodes c and appends it to str.
void encode(ref char[] str, dchar c)
{
  assert(isValidChar(c), "check for valid character before calling encode().");

  char[6] b = void;
  if (c < 0x80)
    str ~= c;
  else if (c < 0x800)
  {
    b[0] = 0xC0 | cast(char)(c >> 6);
    b[1] = 0x80 | (c & 0x3F);
    str ~= b[0..2];
  }
  else if (c < 0x10000)
  {
    b[0] = 0xE0 | cast(char)(c >> 12);
    b[1] = 0x80 | ((c >> 6) & 0x3F);
    b[2] = 0x80 | (c & 0x3F);
    str ~= b[0..3];
  }
  else if (c < 0x200000)
  {
    b[0] = 0xF0 | (c >> 18);
    b[1] = 0x80 | ((c >> 12) & 0x3F);
    b[2] = 0x80 | ((c >> 6) & 0x3F);
    b[3] = 0x80 | (c & 0x3F);
    str ~= b[0..4];
  }
  /+ // There are no 5 and 6 byte UTF-8 sequences yet.
  else if (c < 0x4000000)
  {
    b[0] = 0xF8 | (c >> 24);
    b[1] = 0x80 | ((c >> 18) & 0x3F);
    b[2] = 0x80 | ((c >> 12) & 0x3F);
    b[3] = 0x80 | ((c >> 6) & 0x3F);
    b[4] = 0x80 | (c & 0x3F);
    str ~= b[0..5];
  }
  else if (c < 0x80000000)
  {
    b[0] = 0xFC | (c >> 30);
    b[1] = 0x80 | ((c >> 24) & 0x3F);
    b[2] = 0x80 | ((c >> 18) & 0x3F);
    b[3] = 0x80 | ((c >> 12) & 0x3F);
    b[4] = 0x80 | ((c >> 6) & 0x3F);
    b[5] = 0x80 | (c & 0x3F);
    str ~= b[0..6];
  }
  +/
  else
    assert(0);
}

/// Writes the encoded character to a buffer that must be of sufficient length.
char[] encode(char* p, dchar c)
{
  assert(isValidChar(c), "check for valid character before calling encode().");

  auto p0 = p;
  if (c < 0x80)
    *p++ = cast(char)c;
  else if (c < 0x800)
  {
    *p++ = 0xC0 | cast(char)(c >> 6);
    *p++ = 0x80 | (c & 0x3F);
  }
  else if (c < 0x10000)
  {
    *p++ = 0xE0 | cast(char)(c >> 12);
    *p++ = 0x80 | ((c >> 6) & 0x3F);
    *p++ = 0x80 | (c & 0x3F);
  }
  else if (c < 0x200000)
  {
    *p++ = 0xF0 | (c >> 18);
    *p++ = 0x80 | ((c >> 12) & 0x3F);
    *p++ = 0x80 | ((c >> 6) & 0x3F);
    *p++ = 0x80 | (c & 0x3F);
  }
  /+ // There are no 5 and 6 byte UTF-8 sequences yet.
  else if (c < 0x4000000)
  {
    *p++ = 0xF8 | (c >> 24);
    *p++ = 0x80 | ((c >> 18) & 0x3F);
    *p++ = 0x80 | ((c >> 12) & 0x3F);
    *p++ = 0x80 | ((c >> 6) & 0x3F);
    *p++ = 0x80 | (c & 0x3F);
  }
  else if (c < 0x80000000)
  {
    *p++ = 0xFC | (c >> 30);
    *p++ = 0x80 | ((c >> 24) & 0x3F);
    *p++ = 0x80 | ((c >> 18) & 0x3F);
    *p++ = 0x80 | ((c >> 12) & 0x3F);
    *p++ = 0x80 | ((c >> 6) & 0x3F);
    *p++ = 0x80 | (c & 0x3F);
  }
  +/
  else
    assert(0);
  return p0[0 .. p-p0];
}

/// Encodes c and appends it to str.
void encode(ref wchar[] str, dchar c)
in { assert(isValidChar(c)); }
body
{
  if (c < 0x10000)
    str ~= cast(wchar)c;
  else
  { // Encode with surrogate pair.
    wchar[2] pair = void;
    c -= 0x10000; // c'
    // higher10bits(c') | 0b1101_10xx_xxxx_xxxx
    pair[0] = (c >> 10) | 0xD800;
    // lower10bits(c') | 0b1101_11yy_yyyy_yyyy
    pair[1] = (c & 0x3FF) | 0xDC00;
    str ~= pair;
  }
}

/// Decodes a character from a UTF-16 sequence.
/// Params:
///   str = The UTF-16 sequence.
///   index = Where to start from.
/// Returns: ERROR_CHAR in case of an error in the sequence.
dchar decode(cwstring str, ref size_t index)
in { assert(str.length && index < str.length, "empty string or reached end"); }
out(c) { assert(index <= str.length && (isValidChar(c) || c == ERROR_CHAR)); }
body
{
  dchar c = str[index];
  if (0xD800 > c || c > 0xDFFF)
    return ++index, c;
  if (c <= 0xDBFF && index+1 < str.length)
  {
    wchar c2 = str[index+1];
    if (0xDC00 <= c2 && c2 <= 0xDFFF)
    { // Decode surrogate pair.
      // (c - 0xD800) << 10 + 0x10000 ->
      // (c - 0xD800 + 0x40) << 10 ->
      c = (c - 0xD7C0) << 10;
      c |= (c2 & 0x3FF);
      if (isValidChar(c))
        return (index += 2), c;
    }
  }
  return ERROR_CHAR;
}

/// Decodes a character from a UTF-16 sequence.
/// Params:
///   p = Start of the UTF-16 sequence.
///   end = One past the end of the sequence.
/// Returns: ERROR_CHAR in case of an error in the sequence.
dchar decode(ref cwchar* p, cwchar* end)
in { assert(p && p < end, "p is null or at the end of the string"); }
out(c) { assert(p <= end && (isValidChar(c) || c == ERROR_CHAR)); }
body
{
  dchar c = *p;
  if (0xD800 > c || c > 0xDFFF)
    return ++p, c;
  if (c <= 0xDBFF && p+1 < end)
  {
    wchar c2 = p[1];
    if (0xDC00 <= c2 && c2 <= 0xDFFF)
    {
      c = (c - 0xD7C0) << 10;
      c |= (c2 & 0x3FF);
      if (isValidChar(c))
        return (p += 2), c;
    }
  }
  return ERROR_CHAR;
}

/// Decodes a character from a zero-terminated UTF-16 string.
/// Params:
///   p = Start of the UTF-16 sequence.
/// Returns: ERROR_CHAR in case of an error in the sequence.
dchar decode(ref cwchar* p)
in { assert(p && *p, "p is null or at the end of the string"); }
out(c) { assert(isValidChar(c) || c == ERROR_CHAR); }
body
{
  assert(p);
  dchar c = *p;
  if (0xD800 > c || c > 0xDFFF)
    return ++p, c;
  if (c <= 0xDBFF)
  {
    wchar c2 = p[1];
    if (0xDC00 <= c2 && c2 <= 0xDFFF)
    {
      c = (c - 0xD7C0) << 10;
      c |= (c2 & 0x3FF);
      if (isValidChar(c))
        return (p += 2), c;
    }
  }
  return ERROR_CHAR;
}

/// Converts a string from type A to B.
B[] convertString(A, B)(const(A)[] str)
{
  B[] result;
  size_t idx, len = str.length;
  while (idx < len)
  {
    auto c = decode(str, idx);
    if (c == ERROR_CHAR)
    { // Skip to valid lead char.
      while (++idx < len && !isValidLead(str[idx]))
      {}
      c = REPLACEMENT_CHAR;
    }
    static if (is(B == dchar))
      result ~= c; // Just append. No need for an encoding function.
    else
      encode(result, c);
  }
  return result;
}

/// Converts a UTF-8 string to a UTF-16 string.
alias toUTF16 = convertString!(char, wchar);
/// Converts a UTF-8 string to a UTF-32 string.
alias toUTF32 = convertString!(char, dchar);
/// Converts a UTF-16 string to a UTF-8 string.
alias toUTF8 = convertString!(wchar, char);
