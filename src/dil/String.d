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
      ptr = s.ptr;
      end = s.end;
    }
    void opAssign(const(S) s)
    {
      set(s);
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

  /// Checks pointers.
  invariant()
  {
    assert(ptr <= end);
    if (ptr is null) assert(end is null);
  }

  /// Returns itself.
  ref inout(S) opSlice() inout
  {
    return this;
  }

  /// Returns a slice.
  /// Params:
  ///   x = Start index. Negative values are subtracted from the end.
  ///   y = End index. Negative values are subtracted from the end.
  inout(S) opSlice(ssize_t x, ssize_t y) inout
  {
    return *new S(x < 0 ? end + x : ptr + x,
                  y < 0 ? end + y : ptr + y);
  }

  /// Returns the character at position x.
  /// Params:
  ///   x = Character index. Negative values are subtracted from the end.
  inout(C) opIndex(ssize_t x) inout
  {
    assert(x < 0 ? end + x >= ptr : ptr + x < end);
    return x < 0 ? end[x] : ptr[x];
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

  /// Compares the bytes of two Strings.
  int opCmp(const(S) s) const
  {
    auto l = len, l2 = s.len;
    if (l != l2)
      return l < l2 ? -1 : 1;
    const(C)* p = ptr, p2 = s.ptr;
    for (; p < end; p++, p2++)
      if (*p < *p2)
        return -1;
      else
      if (*p > *p2)
        return  1;
    return 0;
  }

  /// Concatenates x copies of this string.
  S times(size_t x) const
  {
    auto str = toChars();
    auto slen = str.length;
    C[] result = new C[x * slen];
    for (size_t i, n; i < x; i++, (n += slen))
      result[n .. n+slen] = str;
    return S(result);
  }

  /// ditto
  S opBinary(string op)(size_t rhs) const if (op == "*")
  {
    return times(rhs);
  }

  /// ditto
  S opBinaryRight(string op)(size_t lhs) const if (op == "*")
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
  inout(S)[] opBinary(string op)(size_t rhs) inout if (op == "/")
  {
    return divide(rhs);
  }

  /// Concatenates another string array.
  S opBinary(string op)(const(S) rhs) const if (op == "~")
  {
    return S(toChars() ~ rhs.toChars());
  }

  /// ditto
  S opBinary(string op)(const(C)[] rhs) const if (op == "~")
  {
    return S(toChars() ~ rhs);
  }

  /// Appends another String.
  ref S opOpAssign(string op)(const(S) rhs) if (op == "~=")
  {
    this = this ~ rhs;
    return this;
  }

  /// Returns true if lhs is in this String.
  bool opBinary(string op)(const(S) rhs) const if (op == "in")
  {
    return rhs.find(this) != -1;
  }

  /// Returns true if lhs is in this String.
  bool opBinaryRight(string op)(const(S) lhs) const if (op == "in")
  {
    return find(lhs) != -1;
  }

  /// ditto
  bool opBinaryRight(string op)(const(C)[] lhs) const if (op == "in")
  {
    return find(S(lhs)) != -1;
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
  @property inout(C)[] toChars() inout
  {
    return ptr[0..len];
  }

  /// ditto
  immutable(C)[] toString()
  {
    return toChars().idup;
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

  /// Searches for String s.
  /// Returns: The position index or -1 if not found.
  ssize_t find(const(S) s) const
  {
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

  /// Splits by String s and returns a list of slices.
  inout(S)[] split(const(S) s) inout
  {
    S2[] result;
    const(C)* p = ptr, prev = p;
    if (s.len == 0)
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
    if (s.len == 1)
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
      ssize_t i;
      while ((i = S(p, end).find(s)) != -1)
      {
        result ~= S2(p, p+i);
        p += i + s.len;
        assert(p <= end);
      }
      result ~= S2(p, end);
    }
    return cast(inout(S)[])result;
  }

  /// ditto
  inout(S)[] split(const(C) c) inout
  {
    return split(S(&c, (&c)+1));
  }

  /// ditto
  inout(S)[] split(const(C)[] s) inout
  {
    return split(S(s));
  }

  /// Substitutes a with b.
  ref S sub(C a, C b)
  {
    auto p = ptr;
    for (; p < end; p++)
      if (*p == a)
        *p = b;
    return this;
  }

  /// ditto
  S sub(C a, C b) const
  {
    return dup.sub(a, b);
  }

  /// ditto
  ref S sub(const(S) a, const(S) b)
  {
    auto alen = a.len, blen = b.len;
    //if (alen == 0)
    //{}
    if (alen == 0 && blen == 0)
      return this;
    else
    if (alen == 1 && blen == 1)
      sub(a[0], b[0]);
    //else
    //if (blen == 0)
    //{ //TODO: implement
    //}
    else
    {
      auto i = find(a);
      if (i != -1)
      {
        C[] result;
        const bstr = b.toChars();
        const(C)* p = ptr;

        do
        {
          if (i != 0) // Append previous string?
            result ~= S(p, p + i).toChars();
          result ~= bstr;
          p += i + alen;
        } while ((i = S(p, end).find(a)) != -1);
        if (p < end)
          result ~= S(p, end).toChars();
        this = S(result);
      }
    }
    return this;
  }

  /// ditto
  S sub(const(S) a, const(S) b) const
  {
    return dup.sub(a, b);
  }

  /// ditto
  ref S sub(C a, const(C)[] b)
  {
    return sub(S(&a, (&a)+1), S(b));
  }

  /// ditto
  S sub(C a, const(C)[] b) const
  {
    return dup.sub(S(&a, (&a)+1), S(b));
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

unittest
{
  scope msg = new UnittestMsg("Testing struct String.");
  alias String S;

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
  assert(S("abcd").find(S("cd")) == 2);

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
}
