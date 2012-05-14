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
  int opEquals(ref inout(S) s) inout
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
  int opCmp(ref inout(S) s) inout
  {
    auto l = len, l2 = s.len;
    if (l != l2)
      return l < l2 ? -1 : 1;
    inout(C)* p = ptr, p2 = s.ptr;
    while (p < end)
      if (*p < *p2)
        return -1;
      else
      if (*p++ < *p2++)
        return  1;
    return 0;
  }

  /// Concatenates x copies of this string.
  S opBinary(string op)(uint rhs) inout if (op == "*")
  {
    C[] result;
    for (; rhs; rhs--)
      result ~= this.toChars();
    return S(result);
  }

  /// Concatenates x copies of this string.
  S opBinaryRight(string op)(uint lhs) inout if (op == "*")
  {
    return opBinary!("*")(lhs);
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
  bool isNull() inout
  {
    return ptr is null;
  }

  /// Returns true if the string is empty.
  bool isEmpty() inout
  {
    return ptr is end;
  }

  /// Returns an array string.
  inout(C)[] toChars() inout
  {
    return ptr[0..len];
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
  assert(S() == S("") && "" == null);
  assert(S("verdad") == true);


  assert(S("abce".dup).sub('e', 'd') == S("abcd"));

  assert(S("chica").dup == S("chica"));

  assert(S("a") < S("b"));

  assert(S("ha") * 6 == S("hahahahahaha"));
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
}
