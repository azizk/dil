/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Unicode;
public import util.uni : isUniAlpha;

/// U+FFFD = �. Used to replace invalid Unicode characters.
const dchar REPLACEMENT_CHAR = '\uFFFD';
const char[3] REPLACEMENT_STR = \uFFFD; /// Ditto
/// Invalid character, returned on errors.
const dchar ERROR_CHAR = 0xD800;

/// Returns: true if this character is not a surrogate
/// code point and not higher than 0x10FFFF.
bool isValidChar(dchar d)
{
  return d < 0xD800 || d > 0xDFFF && d <= 0x10FFFF;
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

/// Advances ref_p only if this is a valid Unicode alpha character.
bool isUnicodeAlpha(ref char* ref_p, char* end)
in { assert(ref_p && ref_p < end); }
body
{
  if (*ref_p < 0x80)
    return false;
  auto p = ref_p;
  auto c = decode(p, end);
  if (!isUniAlpha(c))
    return false;
  ref_p = p;
  return true;
}

/// Decodes a character from str at index.
/// Params:
///   index = set to one past the ASCII char or one past the last trail byte
///           of the valid UTF-8 sequence.
dchar decode(char[] str, ref size_t index)
in { assert(str.length && index < str.length); }
out { assert(index <= str.length); }
body
{
  char* p = str.ptr + index;
  char* end = str.ptr + str.length;
  dchar c = decode(p, end);
  if (c != ERROR_CHAR)
    index = p - str.ptr;
  return c;
}

/// Decodes a character starting at ref_p.
/// Params:
///   ref_p = set to one past the ASCII char or one past the last trail byte
///           of the valid UTF-8 sequence.
dchar decode(ref char* ref_p, char* end)
in { assert(ref_p && ref_p < end); }
out(c) { assert(ref_p <= end && (isValidChar(c) || c == ERROR_CHAR)); }
body
{
  char* p = ref_p;
  dchar c = *p;

  if (c < 0x80)
    return ref_p++, c;

  p++; // Move to second byte.
  if (!(p < end))
    return ERROR_CHAR;

  // Error if second byte is not a trail byte.
  if (!isTrailByte(*p))
    return ERROR_CHAR;

  // Check for overlong sequences.
  switch (c)
  {
  case 0xE0, // 11100000 100xxxxx
       0xF0, // 11110000 1000xxxx
       0xF8, // 11111000 10000xxx
       0xFC: // 11111100 100000xx
    if ((*p & c) == 0x80)
      return ERROR_CHAR;
  default:
    if ((c & 0xFE) == 0xC0) // 1100000x
      return ERROR_CHAR;
  }

  const char[] checkNextByte = "if (!(++p < end && isTrailByte(*p)))"
                                "  return ERROR_CHAR;";
  const char[] appendSixBits = "c = (c << 6) | *p & 0b0011_1111;";

  // Decode
  if ((c & 0b1110_0000) == 0b1100_0000)
  {
    // 110xxxxx 10xxxxxx
    c &= 0b0001_1111;
    mixin(appendSixBits);
  }
  else if ((c & 0b1111_0000) == 0b1110_0000)
  {
    // 1110xxxx 10xxxxxx 10xxxxxx
    c &= 0b0000_1111;
    mixin(appendSixBits ~
          checkNextByte ~ appendSixBits);
  }
  else if ((c & 0b1111_1000) == 0b1111_0000)
  {
    // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
    c &= 0b0000_0111;
    mixin(appendSixBits ~
          checkNextByte ~ appendSixBits ~
          checkNextByte ~ appendSixBits);
  }
  else
    // 5 and 6 byte UTF-8 sequences are not allowed yet.
    // 111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
    // 1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
    return ERROR_CHAR;

  assert(isTrailByte(*p));

  if (!isValidChar(c))
    return ERROR_CHAR;
  ref_p = p+1;
  return c;
}

/// Encodes c and appends it to str.
void encode(ref char[] str, dchar c)
{
  assert(isValidChar(c), "check if character is valid before calling encode().");

  char[6] b = void;
  if (c < 0x80)
    str ~= c;
  else if (c < 0x800)
  {
    b[0] = 0xC0 | (c >> 6);
    b[1] = 0x80 | (c & 0x3F);
    str ~= b[0..2];
  }
  else if (c < 0x10000)
  {
    b[0] = 0xE0 | (c >> 12);
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
///   str = the UTF-16 sequence.
///   index = where to start from.
/// Returns: ERROR_CHAR in case of an error in the sequence.
dchar decode(wchar[] str, ref size_t index)
{
  assert(str.length && index < str.length);
  dchar c = str[index];
  if (0xD800 > c || c > 0xDFFF)
  {
    ++index;
    return c;
  }
  if (c <= 0xDBFF && index+1 != str.length)
  {
    wchar c2 = str[index+1];
    if (0xDC00 <= c2 && c2 <= 0xDFFF)
    { // Decode surrogate pair.
      // (c - 0xD800) << 10 + 0x10000 ->
      // (c - 0xD800 + 0x40) << 10 ->
      c = (c - 0xD7C0) << 10;
      c |= (c2 & 0x3FF);
      index += 2;
      return c;
    }
  }
  return ERROR_CHAR;
}

/// Decodes a character from a UTF-16 sequence.
/// Params:
///   p = start of the UTF-16 sequence.
///   end = one past the end of the sequence.
/// Returns: ERROR_CHAR in case of an error in the sequence.
dchar decode(ref wchar* p, wchar* end)
{
  assert(p && p < end);
  dchar c = *p;
  if (0xD800 > c || c > 0xDFFF)
  {
    ++p;
    return c;
  }
  if (c <= 0xDBFF && p+1 != end)
  {
    wchar c2 = p[1];
    if (0xDC00 <= c2 && c2 <= 0xDFFF)
    {
      c = (c - 0xD7C0) << 10;
      c |= (c2 & 0x3FF);
      p += 2;
      return c;
    }
  }
  return ERROR_CHAR;
}

/// Decodes a character from a zero-terminated UTF-16 string.
/// Params:
///   p = start of the UTF-16 sequence.
/// Returns: ERROR_CHAR in case of an error in the sequence.
dchar decode(ref wchar* p)
{
  assert(p);
  dchar c = *p;
  if (0xD800 > c || c > 0xDFFF)
  {
    ++p;
    return c;
  }
  if (c <= 0xDBFF)
  {
    wchar c2 = p[1];
    if (0xDC00 <= c2 && c2 <= 0xDFFF)
    {
      c = (c - 0xD7C0) << 10;
      c |= (c2 & 0x3FF);
      p += 2;
      return c;
    }
  }
  return ERROR_CHAR;
}

/// Converts a UTF-8 string to a UTF-16 string.
wchar[] toUTF16(char[] str)
{
  wchar[] result;
  size_t idx;
  while (idx < str.length)
  {
    auto c = decode(str, idx);
    if (c == ERROR_CHAR)
    { // Skip trail bytes.
      while (++idx < str.length && isTrailByte(str[idx]))
      {}
      c = REPLACEMENT_CHAR;
    }
    encode(result, c);
  }
  return result;
}

/// Converts a UTF-8 string to a UTF-32 string.
dchar[] toUTF32(char[] str)
{
  dchar[] result;
  size_t idx;
  while (idx < str.length)
  {
    auto c = decode(str, idx);
    if (c == ERROR_CHAR)
    { // Skip trail bytes.
      while (++idx < str.length && isTrailByte(str[idx]))
      {}
      c = REPLACEMENT_CHAR;
    }
    result ~= c;
  }
  return result;
}
