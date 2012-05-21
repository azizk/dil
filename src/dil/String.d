/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.String;

import common;

/// A string implementation that uses two pointers,
/// as opposed to one pointer and a size variable.
struct StringT(C)
{
  alias StringT S; /// Shortcut to own type.
  C* ptr; /// Points to the beginning of the string.
  C* end; /// Points one past the end of the string.

  /// A dummy struct to simulate "tail const".
  ///
  /// When a local variable with the type inout(S) has to be defined,
  /// one cannot modify it or its members.
  /// This issue can be worked around with this struct.
  struct S2
  {
    const(C)* ptr;
    const(C)* end;
    void set(const(C)* p, const(C)* e)
    {
      ptr = p;
      end = e;
    }
    void set(const(S) s)
    {
      set(s.ptr, s.end);
    }
    void set(const(C)[] a)
    {
      set(a.ptr, a.ptr + a.length);
    }
    static S2 ctor(T)(T x)
    {
      S2 s = void;
      s.set(x);
      return s;
    }
  }

  /// Constructs from an array string.
  this(inout(C)[] str) inout
  {
    ptr = str.ptr;
    end = str.ptr + str.length;
  }

  /// Constructs from start and end pointers.
  this(inout(C)* p, inout(C)* e) inout
  {
    ptr = p;
    end = e;
  }

  /// Constructs from a character terminated string.
  this(inout(C)* p, const(C) terminator) inout
  {
    ptr = p;
    while (*p != terminator)
      p++;
    end = p;
  }

  /// Constructs from a single character.
  this(ref inout(C) c) inout
  {
    this(&c, &c + 1);
  }

  /// Constructs from an unsigned long.
  this(ulong x) inout
  {
    C[20] buffer; // ulong.max -> "18446744073709551616".len == 20
    auto end = buffer.ptr + buffer.length;
    auto p = end;
    do
      *--p = '0' + x % 10;
    while (x /= 10);
    this(S(p, end).array.dup);
  }

  /// Checks pointers.
  invariant()
  {
    assert(ptr <= end);
    if (ptr is null) assert(end is null);
  }

  /// Generates a constructor expression when arg is not of type StringT.
  static string ConvertToS(T)(string arg)
  {
    static if (is(T : const(S)))
      auto expr = arg;
    else
      auto expr = "S("~arg~")";
    return expr;
  }

  /// Returns itself.
  ref inout(S) opSlice() inout
  {
    return this;
  }

  /// Returns a pointer from an index number.
  /// When x is negative it is subtracted from the end pointer.
  inout(C)* indexPtr(ssize_t x) inout
  {
    auto p = x < 0 ? end + x : ptr + x;
    assert(ptr <= p && p < end);
    return p;
  }

  /// Returns a slice.
  /// Params:
  ///   x = Start index. Negative values are subtracted from the end.
  ///   y = End index. Negative values are subtracted from the end.
  inout(S) opSlice(ssize_t x, ssize_t y) inout
  {
    alias inout(StringT) S;
    return S(indexPtr(x), indexPtr(y));
  }

  /// Returns the character at position x.
  /// Params:
  ///   x = Character index. Negative values are subtracted from the end.
  inout(C) opIndex(ssize_t x) inout
  {
    return *indexPtr(x);
  }

  /// Assigns c at position x.
  ref S opIndexAssign(C c, ssize_t x)
  {
    *indexPtr(x) = c;
    return this;
  }

  /// Compares the bytes of two Strings for exact equality.
  int opEquals(const(S) s) const
  {
    if (len != s.len)
      return 0;
    const(C)* p = ptr, p2 = s.ptr;
    while (p < end)
      if (*p++ != *p2++)
        return 0;
    return 1;
  }

  /// Compares to a boolean value.
  int opEquals(bool b) const
  {
    return cast(bool)this == b;
  }

  /// Compares the chars of two Strings.
  /// Returns: 0 if borth are equal.
  int opCmp(const(S) s) const
  {
    auto n = (len <= s.len) ? len : s.len;
    const(C)* p = ptr, p2 = s.ptr;
    for (; n; n--, p++, p2++)
      if (*p != *p2)
        return *p - *p2;
    if (len != s.len)
      n = len - s.len;
    return n;
  }

  /// Compares two Strings ignoring case (only ASCII.)
  int icmp_(const(S) s) const
  {
    auto n = (len <= s.len) ? len : s.len;
    const(C)* p = ptr, p2 = s.ptr;
    for (; n; n--, p++, p2++)
      if (tolower(*p) != tolower(*p2))
        return *p - *p2;
    if (len != s.len)
      n = len - s.len;
    return n;
  }

  /// ditto
  int icmp(T)(T s) const
  {
    auto s_ = mixin(ConvertToS!(T)("s"));
    return icmp_(s_);
  }

  /// Compares two Strings ignoring case for equality (only ASCII.)
  bool ieql(T)(T s) const
  {
    auto s_ = mixin(ConvertToS!(T)("s"));
    return icmp_(s_) == 0;
  }

  /// Concatenates x copies of this string.
  S times(size_t x) const
  {
    auto str = array;
    auto slen = str.length;
    C[] result = new C[x * slen];
    for (size_t i, n; i < x; i++, (n += slen))
      result[n .. n+slen] = str;
    return S(result);
  }

  /// ditto
  S opBinary(string op : "*")(size_t rhs) const
  {
    return times(rhs);
  }

  /// ditto
  S opBinaryRight(string op : "*")(size_t lhs) const
  {
    return times(lhs);
  }

  /// Returns a list of Strings where each piece is of length n.
  /// The last piece may be shorter.
  inout(S)[] pieces(size_t n) inout
  {
    if (n == 0)
      return null; // TODO: throw Exception?
    if (n >= len)
      return [this];

    const roundlen = (len + len % n) / n;
    S2[] result = new S2[roundlen];
    const(C)* p = ptr;
    auto elem = result.ptr;

    for (; p + n <= end; (p += n), elem++)
      elem.set(p, p + n);
    if (p < end)
      elem.set(p, end);

    return cast(inout(S)[])result;
  }

  /// Divides the String into num parts.
  /// The remainder is appended to the last piece.
  inout(S)[] divide(size_t num) inout
  {
    if (num == 0)
      return null; // TODO: throw Exception?
    if (num == 1)
      return [this];

    const piecelen = len / num; // Length of one piece.
    S2[] result = new S2[num];
    const(C)* p = ptr;
    auto elem = result.ptr;

    for (; num--; (p += piecelen), elem++)
      elem.set(p, p + piecelen);
    if (p < end) // Update last element and include the rest of the String.
      (--elem).set(p-piecelen, end);

    return cast(inout(S)[])result;
  }

  /// ditto
  inout(S)[] opBinary(string op : "/")(size_t rhs) inout
  {
    return divide(rhs);
  }

  /// Concatenates another string array.
  S opBinary(string op : "~")(const(S) rhs) const
  {
    return S(array ~ rhs.array);
  }

  /// ditto
  S opBinary(string op : "~")(const(C)[] rhs) const
  {
    return S(array ~ rhs);
  }

  /// Appends another String.
  ref S opOpAssign(string op : "~=")(const(S) rhs)
  {
    this = this ~ rhs;
    return this;
  }

  /// Returns a pointer to the first character, if this String is in rhs.
  inout(C)* opBinary(string op : "in")(inout(C)[] rhs) const
  {
    auto s = S2.ctor(rhs);
    return (cast(inout(S))s).findp(this);
  }

  /// Returns a pointer to the first character, if lhs is in this String.
  inout(C)* opBinaryRight(string op : "in")(const(S) lhs) inout
  {
    return findp(lhs);
  }

  /// ditto
  inout(C)* opBinaryRight(string op : "in")(const(C)[] lhs) inout
  {
    return findp(S(lhs));
  }

  /// Converts to bool.
  bool opCast(T : bool)() const
  {
    return !isEmpty();
  }

  /// Converts to an array string.
  inout(C)[] opCast(T : inout(C)[])() inout
  {
    return ptr[0..len];
  }

  /// Returns the byte length.
  @property size_t len() const
  {
    return end - ptr;
  }

  /// Returns a copy.
  @property S dup() const
  {
    return S(ptr[0..len].dup);
  }

  /// Returns true if pointers are null.
  @property bool isNull() const
  {
    return ptr is null;
  }

  /// Returns true if the string is empty.
  @property bool isEmpty() const
  {
    return ptr is end;
  }

  /// Returns an array string.
  @property inout(C)[] array() inout
  {
    return ptr[0..len];
  }

  /// ditto
  immutable(C)[] toString()
  {
    return array.idup;
  }

  /// Return true if lower-case.
  static bool islower(inout(C) c)
  {
    return 'a' <= c && c <= 'z';
  }

  /// Return true if upper-case.
  static bool isupper(inout(C) c)
  {
    return 'A' <= c && c <= 'Z';
  }

  /// Returns the lower-case version of c.
  static inout(C) tolower(inout(C) c)
  {
    return isupper(c) ? cast(typeof(c))(c + 0x20) : c;
  }

  /// Returns the upper-case version of c.
  static inout(C) toupper(inout(C) c)
  {
    return islower(c) ? cast(typeof(c))(c - 0x20) : c;
  }

  /// Converts to lower-case (only ASCII.)
  ref S tolower()
  {
    auto p = ptr;
    for (; p < end; p++)
      *p = tolower(*p);
    return this;
  }

  /// ditto
  S tolower() const
  {
    return dup.tolower();
  }

  /// Converts to upper-case (only ASCII.)
  ref S toupper()
  {
    auto p = ptr;
    for (; p < end; p++)
      *p = toupper(*p);
    return this;
  }

  /// ditto
  S toupper() const
  {
    return dup.toupper();
  }

  /// Encodes the byte characters with hexadecimal digits.
  S toHex(bool lowercase = true) const
  {
    immutable hexdigits = lowercase ? "0123456789abcdef" : "0123456789ABCDEF";
    auto result = S(new C[len * 2]); // Reserve space.
    auto pr = result.ptr;
    for (const(C)* p = ptr; p < end; p++)
      (*pr++ = hexdigits[*p >> 4]), (*pr++ = hexdigits[*p & 0x0F]);
    return result;
  }

  /// Calculates a hash value.
  /// Note: The value will differ between 32bit and 64bit systems,
  /// and also between little and big endian systems.
  hash_t hashOf() const
  {
    hash_t hash;
    const(C)* sptr = ptr;
    auto slen = len;

    auto rem_len = slen % hash_t.sizeof; // Remainder.
    if (slen == rem_len)
      goto Lonly_remainder;

    auto hptr = cast(const(hash_t)*)sptr;
    // Divide the length by 4 or 8 (x86 vs. x86_64).
    auto hlen = slen / hash_t.sizeof;
    assert(hlen, "can't be zero");

    while (hlen--) // Main loop.
      hash = hash * 11 + *hptr++;

    if (rem_len)
    { // Calculate the hash of the remaining characters.
      sptr = cast(typeof(sptr))hptr; // hptr points exactly to the remainder.
    Lonly_remainder:
      hash_t chunk;
      while (rem_len--) // Remainder loop.
        chunk = (chunk << 8) | *sptr++;
      hash = hash * 11 + chunk;
    }

    return hash;
  }

  /// Returns true if this String starts with prefix.
  bool startsWith(const(S) prefix) const
  {
    return prefix.len <= len && S(ptr, ptr + prefix.len) == prefix;
  }

  /// ditto
  bool startsWith(const(C)[] prefix) const
  {
    return startsWith(S(prefix));
  }

  /// Returns true if this String starts with one of the specified prefixes.
  bool startsWith(const(S)[] prefixes) const
  {
    foreach (prefix; prefixes)
      if (startsWith(prefix))
        return true;
    return false;
  }

  /// ditto
  bool startsWith(const(C)[][] prefixes) const
  {
    foreach (prefix; prefixes)
      if (startsWith(S(prefix)))
        return true;
    return false;
  }

  /// Returns true if this String ends with suffix.
  bool endsWith(const(S) suffix) const
  {
    return suffix.len <= len && S(end - suffix.len, end) == suffix;
  }

  /// ditto
  bool endsWith(const(C)[] suffix) const
  {
    return endsWith(S(suffix));
  }

  /// Returns true if this String ends with one of the specified suffixes.
  bool endsWith(const(S)[] suffixes) const
  {
    foreach (suffix; suffixes)
      if (endsWith(suffix))
        return true;
    return false;
  }

  /// ditto
  bool endsWith(const(C)[][] suffixes) const
  {
    foreach (suffix; suffixes)
      if (endsWith(S(suffix)))
        return true;
    return false;
  }

  /// Searches for character c.
  ssize_t find(const(C) c) const
  {
    const(C)* p = ptr;
    for (; p < end; p++)
      if (*p == c)
        return p - ptr;
    return -1;
  }

  /// Searches for s.
  /// Returns: The position index, or -1 if not found.
  ssize_t find(const(S) s) const
  {
    if (s.len == 0)
      return 0;
    else
    if (s.len == 1)
      return find(s[0]);
    else
    if (s.len <= len) // Return when the argument string is longer.
    {
      const(C)* p = ptr;
      const firstChar = *s.ptr;

      for (; p < end; p++)
      {
        if (*p == firstChar) // Find first matching character.
        {
          const(C)* p2 = s.ptr, matchBegin = p;
          while (p < end)
          {
            if (*p++ != *p2++)
              break;
            if (p2 is s.end) // If at the end, we have a match.
              return matchBegin - ptr;
          }
        }
      }
    }
    return -1;
  }

  /// Searches for character c.
  /// Returns: A pointer to c, or null if not found.
  inout(C)* findp(const(C) c) inout
  {
    inout(C)* p = ptr;
    for (; p < end; p++)
      if (*p == c)
        return p;
    return null;
  }

  /// Searches for s.
  /// Returns: A pointer to the beginning of s, or null if not found.
  inout(C)* findp(const(S) s) inout
  {
    if (s.len == 0)
      return ptr;
    else
    if (s.len == 1)
      return findp(s[0]);
    else
    if (s.len <= len) // Return when the argument string is longer.
    {
      inout(C)* p = ptr;
      const firstChar = *s.ptr;

      for (; p < end; p++)
      {
        if (*p == firstChar) // Find first matching character.
        {
          const(C)* p2 = s.ptr;
          inout(C)* matchBegin = p;
          while (p < end)
          {
            if (*p++ != *p2++)
              break;
            if (p2 is s.end) // If at the end, we have a match.
              return matchBegin;
          }
        }
      }
    }
    return null;
  }

  /// Splits by String s and returns a list of slices.
  inout(S)[] split(const(S) s) inout
  {
    S2[] result;
    const(C)* p = ptr, prev = p;
    auto slen = s.len;
    if (slen == 0)
    {
      result = new S2[len + 2]; // +2 for first and last empty elements.
      auto elem = result.ptr;

      for (; p <= end; p++, elem++)
      {
        elem.set(prev, p);
        prev = p;
      }
      elem.set(p, p);
    }
    else
    if (slen == 1)
    {
      const c = *s.ptr;
      for (; p < end; p++)
        if (*p == c)
        {
          result ~= S2(prev, p);
          prev = p+1;
        }
      result ~= S2(prev, end);
    }
    else
    {
      const(C)* ps;
      while ((ps = S(p, end).findp(s)) !is null)
      {
        result ~= S2(p, ps);
        p = ps + slen;
        assert(p <= end);
      }
      result ~= S2(p, end);
    }
    return cast(inout(S)[])result;
  }

  /// ditto
  inout(S)[] split(const(C) c) inout
  {
    return split(S(c));
  }

  /// ditto
  inout(S)[] split(const(C)[] s) inout
  {
    return split(S(s));
  }

  /// Substitutes a with b.
  ref S sub_(C a, C b)
  {
    auto p = ptr;
    for (; p < end; p++)
      if (*p == a)
        *p = b;
    return this;
  }

  /// ditto
  S sub_(C a, C b) const
  {
    return dup.sub_(a, b);
  }

  /// ditto
  ref S sub_(const(S) a, const(S) b)
  {
    auto alen = a.len, blen = b.len;

    if (alen == 0 && blen == 0)
    {}
    else
    if (alen == 0)
    {
      C[] result;
      const bstr = b.array;
      const(C)* p = ptr;

      while (p < end)
        result ~= bstr ~ *p++;
      result ~= bstr;
      this = S(result);
    }
    else
    if (alen == 1 && blen == 1)
      sub_(a[0], b[0]);
    else
    if (blen == 0)
    {
      C* pwriter = ptr;
      const(C)* preader = pwriter, pa;

      while ((pa = S(preader, end).findp(a)) !is null)
      {
        while (preader < pa) // Copy till beginning of a.
          *pwriter++ = *preader++;
        preader += alen; // Skip a.
      }
      if (preader !is pwriter)
      { // Write the rest.
        while (preader < end)
          *pwriter++ = *preader++;
        end = pwriter;
      }
    }
    else
    {
      const(C)* pa = findp(a);
      if (pa)
      {
        C[] result;
        const bstr = b.array;
        const(C)* p = ptr;

        do
        {
          if (pa) // Append previous string?
            result ~= S(p, pa).array;
          result ~= bstr;
          p = pa + alen; // Skip a.
        } while ((pa = S(p, end).findp(a)) !is null);
        if (p < end)
          result ~= S(p, end).array;
        this = S(result);
      }
    }
    return this;
  }

  /// ditto
  S sub_(const(S) a, const(S) b) const
  {
    return dup.sub_(a, b);
  }

  /// ditto
  ref S sub(A, B)(A a, B b)
  {
    auto aS = mixin(ConvertToS!(A)("a"));
    auto bS = mixin(ConvertToS!(B)("b"));
    return sub_(aS, bS);
  }

  /// ditto
  S sub(A, B)(A a, B b) const
  {
    return dup.sub!(A, B)(a, b);
  }

  /// Returns itself reversed.
  ref S reverse()
  {
    auto lft = ptr;
    auto rgt = end - 1;
    for (auto n = len / 2; n != 0; n--, lft++, rgt--)
    { // Swap left and right characters.
      const c = *lft;
      *lft = *rgt;
      *rgt = c;
    }
    return this;
  }

  /// Returns a reversed String.
  S reverse() const
  {
    return dup.reverse();
  }
}

alias StringT!(char)  String;  /// Instantiation for char.
alias StringT!(wchar) WString; /// Instantiation for wchar.
alias StringT!(dchar) DString; /// Instantiation for dchar.


/// Returns a string array slice ranging from begin to end.
inout(char)[] slice(inout(char)* begin, inout(char)* end)
{
  alias inout(String) S;
  return S(begin, end).array;
}

/// Replaces a with b in str.
/// Returns: A copy.
cstring replace(cstring str, char a, char b)
{
  return String(str).sub_(a, b).array;
}

/// Converts x to a string array.
char[] itoa(ulong x)
{
  return String(x).array;
}

/// Converts x to a string array (CTF version.)
char[] itoactf(ulong x)
{
  char[] str;
  do
    str = cast(char)('0' + (x % 10)) ~ str;
  while (x /= 10);
  return str;
}

/// Calculates a hash value for str.
/// Note: The value will differ between 32bit and 64bit systems.
/// It will also differ between little and big endian systems.
hash_t hashOf(cstring str)
{
  return String(str).hashOf();
}

/// ditto
hash_t hashOfCTF(string str)
{ /// Nested func because DMD can't do: cast(hash_t[])str
  hash_t[] toHashArray(string s)
  { // See: $(DMDBUG 5497, reinterpret cast inside CTFs)
    hash_t swapBytesOnLE(hash_t c)
    { // Reverse bytes on little-endian machines.
      version(BigEndian)
      return c; // Return as is on big-endian machines.
      hash_t c_;
      for (size_t i; i < hash_t.sizeof; i++, c >>= 8)
        c_ = c_ << 8 | (c & 0xFF); // Pick 1byte from c and append to c_.
      return c_;
    }
    auto ha_len = s.length / hash_t.sizeof;
    hash_t[] ha;
    for (size_t i, j; i < ha_len; i++)
    {
      hash_t hc; // A hash char.
      for (size_t k = j + hash_t.sizeof; j < k; j++)
        hc = hc << 8 | s[j]; // Append as many bytes as possible.
      ha ~= swapBytesOnLE(hc); // Append to hash array.
    }
    return ha;
  }

  hash_t hash;
  auto rem_len = str.length % hash_t.sizeof; // Remainder.
  hash_t[] ha = toHashArray(str);
  if (rem_len)
  { // Append remainder hash character.
    hash_t hc;
    foreach (c; str[$-rem_len .. $]) // Remainder loop.
      hc = (hc << 8) | c;
    ha ~= hc;
  }
  foreach (hc; ha) // Main loop.
    hash = hash * 11 + hc;
  return hash;
}

unittest
{
  scope msg = new UnittestMsg("Testing struct String.");
  alias String S;

  // Constructing.
  assert(S("", 0) == S("")); // String literals are always zero terminated.
  assert(S("abcd", 0) == S("abcd"));
  assert(S("abcd", 'c') == S("ab"));
  assert(S(0) == S("0") && S(1999) == S("1999"));

  // Boolean conversion.
  if (S("is cool")) {}
  else assert(0);
  assert(S() == false && !S());
  assert(S("") == false && !S(""));
  assert(S("verdad") == true);

  // Substitution.
  assert(S("abce").sub('e', 'd') == S("abcd"));
  assert(S("abc ef").sub(' ', 'd') == S("abcdef"));
  assert(S("abc f").sub(' ', "de") == S("abcdef"));
  assert(S("abcd").sub("", " ") == S(" a b c d "));
  assert(S("").sub("", "a") == S("a"));
  assert(S(" a b c d ").sub(" ", "") == S("abcd"));
  assert(S("ab_cd").sub("_", "") == S("abcd"));
  assert(S("abcd").sub("abcd", "") == S(""));
  assert(S("aaaa").sub("a", "") == S(""));

  // Duplication.
  assert(S("chica").dup == S("chica"));

  // Comparison.
  assert(S("a") < S("b"));
  assert(S("b") > S("a"));
  assert(S("a") <= S("a"));
  assert(S("b") >= S("b"));
  assert(S("a") == S("a"));
  assert(S("a") != S("b"));
  assert(S("abcd") == S("abcd"));
  assert(S("") == S(""));
  assert(S() == S());
  assert(S() == S("") && "" == null);

  // Multiplication.
  assert(S("ha") * 6 == S("hahahahahaha"));
  assert(S("oi") * 3 == S("oioioi"));
  assert(S("palabra") * 0 == S());
  assert(1 * S("mundo") == S("mundo"));

  // Slicing.
  assert(S("rapido")[1..4] == S("api"));
  assert(S("rapido")[2..-3] == S("p"));
  assert(S("rapido")[-3..3] == S(""));
  assert(S("rapido")[-4..-1] == S("pid"));

  // Indexing.
  assert(S("abcd")[0] == 'a');
  assert(S("abcd")[2] == 'c');
  assert(S("abcd")[-1] == 'd');

  // Dividing.
  assert(S("abcd") / 1 == [S("abcd")]);
  assert(S("abcd") / 2 == [S("ab"), S("cd")]);
  assert(S("abcd") / 3 == [S("a"), S("b"), S("cd")]);
  assert(S("abcdefghi") / 2 == [S("abcd"), S("efghi")]);
  assert(S("abcdefghijk") / 4 == [S("ab"), S("cd"), S("ef"), S("ghijk")]);

  assert(S("abcdef").pieces(2) == [S("ab"), S("cd"), S("ef")]);
  assert(S("abcdef").pieces(4) == [S("abcd"), S("ef")]);

  // Splitting.
  assert(S("") == S(""));
  assert(S("").split("") == [S(""), S("")]);
  assert(S("abc").split("") == [S(""), S("a"), S("b"), S("c"), S("")]);
  assert(S("abc").split("b") == [S("a"), S("c")]);

  // Searching.
  assert("Mundo" in S("¡Hola Mundo!"));
  assert(S("") in "a");
  assert(S("abcd").find(S("cd")) == 2);
  assert(S("").find(S("")) == 0);
  {
  auto s = S("abcd");
  assert(s.findp(S("abcd")) is s.ptr);
  assert(s.findp(S("d")) is s.end - 1);
  }

  // Reversing.
  assert(S("").reverse() == S(""));
  assert(S("a").reverse() == S("a"));
  assert(S("abc").reverse() == S("cba"));
  assert(S("abcd").reverse() == S("dcba"));
  assert(S("abc").reverse() == S("cba"));
  assert(S("abc").reverse().reverse() == S("abc"));

  // Matching prefixes and suffixes.
  assert(S("abcdefg").startsWith("abc"));
  assert(S("abcdefg").startsWith([" ", "abc"]));
  assert(!S("ab").startsWith("abc"));
  assert(S("abcdefg").endsWith("efg"));
  assert(S("abcdefg").endsWith([" ", "efg"]));
  assert(!S("fg").endsWith("efg"));

  // Converting to hex string.
  assert(S("äöü").toHex() == S("c3a4c3b6c3bc"));
  assert(S("äöü").toHex(false) == S("C3A4C3B6C3BC"));

  // Case conversion.
  assert(S("^agmtz$").toupper() == S("^AGMTZ$"));
  assert(S("^AGMTZ$").tolower() == S("^agmtz$"));
}
