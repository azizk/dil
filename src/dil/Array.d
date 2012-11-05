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
  alias void E;
  E* ptr; /// Points to the start of the buffer.
  E* cur; /// Points to the end of the contents.
  E* end; /// Points to the end of the reserved space.

  /// Constructs an Array, optionally reserving space.
  this(size_t nbytes = 0)
  {
    resizeto(nbytes);
  }

  /// Returns the size of the Array in bytes.
  size_t len() @property
  {
    return cur - ptr;
  }

  /// Sets the size of the Array in bytes. Resizes space if necessary.
  void len(size_t n) @property
  {
    cur = ptr + n;
    if (cur >= end)
      resizeto(n);
  }

  /// Returns the remaining space in bytes before a reallocation is needed.
  size_t rem() @property
  {
    return end - cur;
  }

  /// Allocates space for the Array using malloc/realloc.
  /// Throws: OutOfMemoryError.
  void resizeto(size_t nbytes)
  {
    if (nbytes == 0)
      return destroy();

    size_t newsize() // At least PAGESIZE or nbytes * 1.5
    { return nbytes <= PAGESIZE ? PAGESIZE : (nbytes << 1) - (nbytes >> 1); }

    auto new_ptr = ptr;
    new_ptr = new_ptr ? cast(E*)realloc(new_ptr, newsize()) :
                        cast(E*)malloc(nbytes);
    if (!new_ptr) {
      free(ptr);
      throw new OutOfMemoryError();
    }
    cur = new_ptr + (cur - ptr);
    ptr = new_ptr;
    end = new_ptr + nbytes;
    if (cur > end) /// Was the buffer shrunk?
      cur = end;
  }

  /// Enlarges or shrinks the Array by n bytes.
  void resizeby(ssize_t n)
  {
    resizeto(len + n);
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
        resizeby(n);
      memcpy(cur, x.ptr, n);
      cur += n;
    }
    else
    {
      enum n = X.sizeof;
      if (cur + n >= end)
        resizeby(n);
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
  A get(A = void[])()
  {
    auto result = ptr[0..len];
    GC.addRoot(ptr);
    ptr = cur = end = null;
    return *cast(A*)&result;
  }
}

void testArray()
{
}
