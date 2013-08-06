/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.AArray;

import core.bitop : bsr;

alias size_t Key;
alias void* Value;

/// An item in an associative array. Can be chained together with other items.
struct AANode
{
  Key key; /// A hash value.
  Value value; /// The value associated with the key.
  AANode* next; /// Links to the next node.
}

/// An associative array implementation which grows by powers of two.
/// Relies on the GC for memory.
struct AArray
{
  AANode*[] buckets = [null]; /// The number of buckets is a power of 2.
  size_t count; /// Number of nodes.

  /// Returns the number of nodes.
  size_t len()
  {
    return count;
  }

  /// Returns the number of buckets.
  size_t blen()
  {
    return buckets.length;
  }

  /// Returns the index of a key in the buckets array.
  size_t toindex(Key key)
  { // This is basically a modulo operation: key % blen()
    // But since the length will always be a power of 2,
    // the and-operator can be used as a faster method.
    return key & (blen() - 1);
  }

  /// Returns the value of a key, or null if it doesn't exist.
  Value get(Key key)
  {
    if (auto n = find(key))
      return n.value;
    return null;
  }

  /// Sets the value of a key.
  void set(Key key, Value value)
  {
    getadd(key).value = value;
  }

  /// Adds a pair to the array, assuming it doesn't exist already.
  void add(Key key, Value value)
  {
    assert(find(key) is null);
    auto i = toindex(key);
    auto pbucket = &buckets[i];
    *pbucket = new AANode(key, value, *pbucket);
    count++;
    if (count > blen() * 2)
      rehash();
  }

  /// Finds a node by key or adds a new one if inexistent.
  /// Useful when the AA is on the lhs, e.g.: aa["b"] = 1;
  AANode* getadd(Key key)
  {
    auto i = toindex(key);
    auto pbucket = &buckets[i];
    for (auto n = *pbucket; n; n = n.next)
      if (n.key == key)
        return n; // Found the node.
    *pbucket = new AANode(key, null, *pbucket); // Create a new node.
    count++;
    if (count > blen() * 2)
      rehash();
    return *pbucket;
  }

  /// Removes a key value pair from the array.
  /// Returns: true if the item was removed, false if it didn't exist.
  bool remove(Key key)
  {
    auto i = toindex(key);
    AANode** pn = &buckets[i]; /// Reference to the previous node.
    for (auto n = *pn; n; n = n.next)
    {
      if (n.key == key)
      {
        *pn = n.next;
        count--;
        return true;
      }
      pn = &n.next;
    }
    return false;
  }

  /// Finds the node matching the key.
  AANode* find(Key key)
  {
    auto i = toindex(key);
    for (auto n = buckets[i]; n; n = n.next)
      if (n.key == key)
        return n;
    return null;
  }

  /// Allocates a new bucket list and relocates the nodes from the old one.
  void rehash()
  {
    auto newlen = this.count;
    if (!newlen)
      return;
    // Check if not a power of 2.
    if (newlen & (newlen - 1))
    { // Round up to the next power of 2.
      newlen = 2 << bsr(newlen);
      if (newlen == 0) // Did it overflow?
        newlen = size_t.max / 2 + 1; // Set the highest bit.
    }
    // Allocate a new list of buckets.
    AANode*[] newb = new AANode*[newlen];
    newlen--; // Subtract now to avoid doing it in the loop.
    // Move the nodes to the new array.
    foreach (n; buckets)
      while (n)
      {
        auto next_node = n.next;
        size_t i = n.key & newlen;
        n.next = newb[i];
        newb[i] = n; // n becomes the new head at index i.
        n = next_node; // Continue with the next node in the chain.
      }
    buckets = newb;
  }
}
