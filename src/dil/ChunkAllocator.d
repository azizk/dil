/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.ChunkAllocator;

import dil.Array;

/// Custom non-GC allocator for managing a list of chunks.
struct ChunkAllocator
{
  Array chunks; /// List of memory chunks, getting larger progressively.

  /// Constructs a ChunkAllocator.
  this(size_t size)
  {
    initialize(size);
  }

  /// Initializes with one chunk.
  void initialize(size_t size)
  {
    chunks.cap = 10; // Reserve space for 10 chunks.
    chunks ~= Array(size);
  }

  /// Returns chunk number n.
  Array* lastChunk()
  {
    auto chunks = chunks.elems!(Array[]);
    return chunks.ptr + chunks.length - 1;
    //return &((chunks.elems!(Array[]))[$-1]);
  }

  /// Adds a new chunk to the list and returns it.
  Array* newChunk()
  {
    auto cap = lastChunk().cap;
    cap = (cap << 1) - (cap >> 1); // cap *= 1.5;
    cap += PAGESIZE - cap % PAGESIZE; // Round up to PAGESIZE.
    chunks ~= Array(cap);
    return lastChunk();
  }

  /// Returns a chunk that can hold another n bytes.
  Array* getChunk(size_t n)
  {
    auto a = lastChunk();
    if (n > a.rem) // Do n bytes fit in?
      a = newChunk();
    return a;
  }

  /// Returns a pointer to an array of size n bytes.
  void* allocate(size_t n)
  {
    auto a = getChunk(n);
    auto p = a.cur;
    a.cur += n;
    return p;
  }

  /// Frees all the allocated memory.
  void destroy()
  {
    foreach (ref a; chunks.elems!(Array[]))
      a.destroy();
    chunks.destroy();
  }
}
