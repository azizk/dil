/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.Array;

import core.stdc.stdlib,
       core.memory,
       core.exception;
import common;

/// The system size of a memory page. Default to 4k.
static size_t PAGESIZE = 4096;

extern (C) void* memcpy(void*, const void*, size_t);
extern (C) void onOutOfMemoryError();

static this()
{
  version(linux)
  {
    import core.sys.posix.unistd;
    PAGESIZE = cast(size_t)sysconf(_SC_PAGE_SIZE);
  }
}

/// Fast, mutable, resizable array implementation.
struct Array
{
  alias E = ubyte; /// Alias to ubyte. Dereferencing void* gives no value.
  E* ptr; /// Points to the start of the buffer.
  E* cur; /// Points to the end of the contents. Only dereference if cur < end.
  E* end; /// Points to the end of the reserved space.

  /// Constructs an Array and reserves space of n bytes.
  this(size_t n = 0)
  {
    if (n)
      if (auto p = cast(E*)malloc(n))
        end = (ptr = cur = p) + n;
      else
        onOutOfMemoryError();
  }

  invariant()
  {
    if (!ptr)
      assert(cur is null && end is null, "!(ptr == cur == end == 0)");
    else
      assert(ptr <= cur && cur <= end,
        Format("!({} <= {} <= {})", ptr, cur, end));
  }

  /// Returns the size of the Array in bytes.
  size_t len() @property const
  {
    return cur - ptr;
  }

  /// Sets the size of the Array in bytes.
  /// Resizes space if necessary. Does not deallocate if n is zero.
  void len(size_t n) @property
  {
    if ((ptr + n) > end)
      reserve(n);
    cur = ptr + n;
  }

  /// Returns the remaining space in bytes before a reallocation is needed.
  size_t rem() @property const
  {
    return end - cur;
  }

  /// Sets the capacity so that n bytes of space remain.
  void rem(size_t n) @property
  {
    cap = len + n;
  }

  /// Returns the total capacity of the Array.
  size_t cap() @property const
  {
    return end - ptr;
  }

  /// Sets the capacity to exactly n bytes.
  void cap(size_t n) @property
  {
    reserve(n);
  }

  /// Allocates exactly n bytes. May shrink or extend in place if possible.
  /// Does not zero out memory. Destroys if n is zero.
  /// Throws: OutOfMemoryError.
  void reserve(size_t n)
  {
    if (n == 0)
      return destroy();
    auto new_ptr = ptr;
    new_ptr = cast(E*)(new_ptr ? realloc(new_ptr, n) : malloc(n));
    if (!new_ptr)
      onOutOfMemoryError();
    auto len = this.len;
    ptr = new_ptr;
    cur = new_ptr + (len < n ? len : n); // min(len, n)
    end = new_ptr + n;
  }

  /// Frees the allocated memory.
  void destroy()
  {
    free(ptr);
    ptr = cur = end = null;
  }

  /// Grows the capacity by n or cap * 1.5.
  void growcap(size_t n = 0)
  {
    if (!n)
      n = (cap << 1) - (cap >> 1); // cap *= 1.5
    else
      n += cap;
    reserve(n);
  }

  /// Shrinks the Array by n bytes.
  void shrinkby(size_t n)
  {
    reserve(n < cap ? cap - n : 0);
  }

  /// Compacts the capacity to the actual length of the Array.
  /// Destroys if the length is zero.
  void compact()
  {
    reserve(len);
  }

  /// Appends x of any type to the Array.
  /// Appends the elements if X is an array.
  void opOpAssign(string op : "~", X)(const X x)
  {
    static if (is(X : Elem[], Elem))
    {
      auto n = x.length * Elem.sizeof;
      if (cur + n >= end)
        rem = n;
      memcpy(cur, x.ptr, n);
      cur += n;
    }
    else
    {
      enum n = X.sizeof;
      if (cur + n >= end)
        rem = n;
      static if (n <= size_t.sizeof)
      {
        string unroll(string s, size_t times) {
          return times == 1 ? s : s ~ unroll(s, times-1);
        }

        auto p = cast(E*)&x, c = cur;
        mixin(unroll("*c++ = *p++;", n));
        cur = c;
      }
      else
      {
        memcpy(cur, &x, n);
        cur += n;
      }
    }
    assert(cur <= end);
  }

  /// Returns a copy allocated using the GC and destroys this Array.
  A get(A = E)()
  {
    auto result = this[].dup;
    destroy();
    return *cast(A*)&result;
  }

  /// Returns a slice into the Array.
  /// Warning: The memory may leak if not freed, or destroyed prematurely.
  E[] opSlice(size_t i, size_t j)
  {
    assert(i <= j && j < len);
    return ptr[i..j];
  }

  /// ditto
  E[] opSlice()
  {
    return ptr[0..len];
  }

  /// Returns the Array as a dynamic array.
  A elems(A = E[])()
  {
    return cast(A)this[];
  }
}

void testArray()
{
}
