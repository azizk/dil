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
  int opEquals(inout(S) s) inout
  {
    if (len != s.len)
      return 0;
    inout(C)* p = ptr, p2 = s.ptr;
    while (p < end)
      if (*p++ != *p2++)
        return 0;
    return 1;
  }

  /// Compares to a boolean value.
  int opEquals(bool b) inout
  {
    return cast(bool)this == b;
  }

  /// Compares the bytes of two Strings.
  int opCmp(inout(S) s) inout
  {
    auto l = len, l2 = s.len;
    if (l != l2)
      return l < l2 ? -1 : 1;
    inout(C)* p = ptr, p2 = s.ptr;
    for (; p < end; p++, p2++)
      if (*p < *p2)
        return -1;
      else
      if (*p > *p2)
        return  1;
    return 0;
  }

  /// Concatenates x copies of this string.
  S times(size_t x) inout
  {
    auto str = toChars();
    auto slen = str.length;
    C[] result = new C[x * slen];
    for (size_t i, n; i < x; i++, (n += slen))
      result[n .. n+slen] = str;
    return S(result);
  }

  /// ditto
  S opBinary(string op)(size_t rhs) inout if (op == "*")
  {
    return times(rhs);
  }

  /// ditto
  S opBinaryRight(string op)(size_t lhs) inout if (op == "*")
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
    inout(C)* p = ptr;
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
    inout(C)* p = ptr;
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
  S opBinary(string op)(inout(S) rhs) inout if (op == "~")
  {
    return S(toChars() ~ rhs.toChars());
  }

  /// ditto
  S opBinary(string op)(inout(C)[] rhs) inout if (op == "~")
  {
    return S(toChars() ~ rhs);
  }

  /// Appends another String.
  ref S opOpAssign(string op)(inout(S) rhs) if (op == "~=")
  {
    this = this ~ rhs;
    return this;
  }

  /// Returns true if lhs is in this String.
  bool opBinary(string op)(inout(S) rhs) inout if (op == "in")
  {
    return rhs.find(this) != size_t.max;
  }

  /// Returns true if lhs is in this String.
  bool opBinaryRight(string op)(inout(S) lhs) inout if (op == "in")
  {
    return find(lhs) != size_t.max;
  }

  /// ditto
  bool opBinaryRight(string op)(inout(C)[] lhs) inout if (op == "in")
  {
    return find(/+*new +/S(lhs)) != size_t.max;
  }

  /// Converts to bool.
  bool opCast(T : bool)() inout
  {
    return !isEmpty();
  }

  /// Converts to an array string.
  inout(C)[] opCast(T : inout(C)[])() inout
  {
    return ptr[0..len];
  }

  /// Returns the byte length.
  @property size_t len() inout
  {
    return end - ptr;
  }

  /// Returns a copy.
  @property S dup() inout
  {
    return S(ptr[0..len].dup);
  }

  /// Returns true if pointers are null.
  @property bool isNull() inout
  {
    return ptr is null;
  }

  /// Returns true if the string is empty.
  @property bool isEmpty() inout
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

  /// Searches for character c.
  size_t find(const(C) c) const
  {
    const(C)* p = ptr;
    for (; p < end; p++)
      if (*p == c)
        return p - ptr;
    return -1;
  }

  /// Searches for String s.
  /// Returns: The position index or -1 if not found.
  size_t find(inout(S) s) inout
  {
    if (s.len == 1)
      return find(s[0]);
    else
    if (s.len <= len) // Return when the argument string is longer.
    {
      inout(C)* p = ptr;
      const firstChar = *s.ptr;

      for (; p < end; p++)
      {
        if (*p == firstChar) // Find first matching character.
        {
          inout(C)* p2 = s.ptr, matchBegin = p;
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

  /// Splits by character c and returns a list of string slices.
  inout(S)[] split(inout(C) c) inout
  {
    inout(S)[] result;
    inout(C)* p = ptr, prev = p;
    for (; p < end; p++)
      if (*p == c) {
        result ~= *new S(prev, p);
        prev = p;
      }
    return result;
  }

  /// Substitutes a with b in this string.
  /// Returns: Itself.
  ref S sub(C a, C b)
  {
    auto p = ptr;
    for (; p < end; p++)
      if (*p == a)
        *p = b;
    return this;
  }
}

alias StringT!(char)  String;  /// Instantiation for char.
alias StringT!(wchar) WString; /// Instantiation for wchar.
alias StringT!(dchar) DString; /// Instantiation for dchar.

unittest
{
  scope msg = new UnittestMsg("Testing struct String.");
  alias String S;

  if (S("is cool")) {}
  else assert(0);
  assert(S() == false && !S());
  assert(S("") == false && !S(""));
  assert(S("verdad") == true);


  assert(S("abce".dup).sub('e', 'd') == S("abcd"));

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

  // Searching.
  assert("Mundo" in S("¡Hola Mundo!"));
  assert(S("abcd").find(S("cd")) == 2);
}
