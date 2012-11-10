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
  alias ubyte E; /// Alias to ubyte. Dereferencing void* gives no value.
  E* ptr; /// Points to the start of the buffer.
  E* cur; /// Points to the end of the contents.
  E* end; /// Points to the end of the reserved space.

  /// Constructs an Array of exactly nbytes size.
  this(size_t nbytes = 0)
  {
    if (nbytes)
      resizex(nbytes);
  }

  invariant()
  {
    if (!ptr)
      assert(cur is null && end is null, "!(ptr == cur == end == 0)");
    else
      assert(ptr <= cur && cur <= end, "!(ptr <= cur <= end)");
  }

  /// Returns the size of the Array in bytes.
  size_t len() @property const
  {
    return cur - ptr;
  }

  /// Sets the size of the Array in bytes. Resizes space if necessary.
  void len(size_t n) @property
  {
    cur = ptr + n;
    if (cur >= end)
      growto(n);
  }

  /// Returns the remaining space in bytes before a reallocation is needed.
  size_t rem() @property const
  {
    return end - cur;
  }

  /// Return the total capacity of the Array.
  size_t cap() @property const
  {
    return end - ptr;
  }

  /// Allocates exactly n bytes.
  /// Destroys if n is zero.
  /// Throws: OutOfMemoryError.
  void resizex(size_t n)
  {
    if (n == 0)
      return destroy();
    auto new_ptr = ptr;
    new_ptr = new_ptr ? cast(E*)realloc(new_ptr, n) : cast(E*)malloc(n);
    if (!new_ptr) {
      destroy();
      throw new OutOfMemoryError();
    }
    cur = new_ptr + (cur - ptr);
    ptr = new_ptr;
    end = new_ptr + n;
    if (cur > end) /// Was the buffer shrunk?
      cur = end;
  }

  /// Grows the memory needed by the value of max(len * 1.5, n, cap).
  void growto(size_t n)
  {
    auto len = this.len;
    len = (len << 1) - (len >> 1); // len *= 0.5
    if (len > n)
      n = len;
    if (n > cap)
      resizex(n);
  }

  /// Grows the Array by n bytes.
  void growby(size_t n)
  {
    growto(len + n);
  }

  /// Shrinks the Array to n bytes.
  void shrinkto(size_t n)
  {
    resizex(n);
  }

  /// Shrinks the Array by n bytes.
  void shrinkby(size_t n)
  {
    shrinkto(n < cap ? cap - n : 0);
  }

  /// Compacts the capacity to the actual length of the Array.
  /// Destroys if the length is zero.
  void compact()
  {
    resizex(len);
  }

  /// Frees the allocated memory.
  void destroy()
  {
    free(ptr);
    ptr = cur = end = null;
  }

  /// Appends x of any type to the Array.
  /// Appends the elements if X is an array.
  void opOpAssign(string op : "~", X)(const X x)
  {
    static if (is(X t : Elem[], Elem))
    {
      auto n = x.length * Elem.sizeof;
      if (cur + n >= end)
        growby(n);
      memcpy(cur, x.ptr, n);
      cur += n;
    }
    else
    {
      enum n = X.sizeof;
      if (cur + n >= end)
        growby(n);
      static if (n <= size_t.sizeof)
      {
        char[] unroll(char[] s, size_t times)
        { return times == 1 ? s : s ~ unroll(s, times-1); }

        auto p = cast(E*)&x;
        mixin(unroll("*cur++ = *p++;".dup, n));
      }
      else
      {
        memcpy(cur, &x, n);
        cur += n;
      }
    }
  }

  /// Hands the memory over to the GC and returns it as an array.
  A get(A = E)()
  {
    auto result = ptr[0..len];
    GC.addRoot(ptr);
    ptr = cur = end = null;
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
}

void testArray()
{
}
