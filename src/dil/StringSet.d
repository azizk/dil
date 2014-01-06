/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.StringSet;

import dil.Array;
import dil.String;
import common;

import std.c.string;

/// Binary tree implementation of a hash set with strings as elements.
struct StringSet
{
  struct Node
  {
    size_t left;  /// Index of left branch.
    size_t right; /// Index of right branch.
    hash_t hash;  /// Hash value.
    cbinstr str;  /// Binary string.
    cstring repr()
    {
      return Format("Node(left={},right={},hash={},str={})",
        left, right, hash, str.length > 4 ? str[0..4] : str);
    }
    string toString()
    {
      return cast(string)repr();
    }
  }

  size_t[] list; /// List of 1-based indices to Nodes.
  DArray!Node nodes; /// Instances of Node.

  /// Constructs a StringSet with the desired properties.
  this(size_t nrOfNodes = 0, size_t size = 0)
  {
    nodes.cap = nrOfNodes;
    resize(size);
  }

  /// Allocates and returns the 1-based index of a new uninitialized Node.
  size_t newNode()
  {
    if (nodes.cap == 0)
      nodes.cap = 1;
    else if (nodes.rem == 0)
      nodes.growX1_5();
    //*nodes.cur = Node.init;
    nodes.cur++;
    return nodes.len;
  }

  /// Returns the Node for the 1-based index.
  Node* getNode(size_t nindex)
  {
    assert(nindex);
    return nodes.ptr + nindex - 1;
  }

  /// Resizes the bucket list and reassigns the nodes.
  void resize(size_t size)
  {
    list = new typeof(list[0])[size];
    foreach (i, ref n; nodes[])
    {
      n.left = n.right = 0;
      auto bindex = n.hash % list.length;
      auto pindex = &list[bindex];
      auto hash = n.hash;
      auto str = n.str;
      while (*pindex)
      {
        auto node = getNode(*pindex);
        int_t diff;
        if ((diff = node.hash - hash) == 0 &&
            (diff = node.str.length - str.length) == 0 &&
            (diff = memcmp(node.str.ptr, str.ptr, str.length)) == 0)
          assert(0, "can't have two equal nodes in the same set");
        // Go left or right down the tree.
        pindex = diff < 0 ? &node.left : &node.right;
      }
      *pindex = i + 1;
    }
  }

  /// Finds the Node holding str, or a slot where a new Node can be saved.
  size_t* find(cbinstr str, hash_t hash)
  {
    if (!list.length)
      resize(32);
    auto pindex = &list[hash % list.length];
    while (*pindex)
    {
      auto node = getNode(*pindex);
      int_t diff;
      if ((diff = node.hash - hash) == 0 &&
          (diff = node.str.length - str.length) == 0 &&
          (diff = memcmp(node.str.ptr, str.ptr, str.length)) == 0)
        break; // If equal in hash, length and content.
      // Go left or right down the tree.
      pindex = diff < 0 ? &node.left : &node.right;
    }
    return pindex;
  }

  /// ditto
  size_t* find(cbinstr str)
  {
    return find(str, hashOf(cast(cstring)str));
  }

  /// Returns a reference to str if it exists.
  const(cbinstr)* get(cbinstr str)
  {
    auto p = find(str);
    return *p ? &getNode(*p).str : null;
  }

  /// Returns true if str is contained in the set.
  bool has(cbinstr str)
  {
    return list.length && !!*find(str);
  }

  /// Returns an existing entry or creates a new one.
  const(cbinstr)* add(cbinstr str)
  {
    auto hash = hashOf(cast(cstring)str);
    auto p = find(str, hash);
    Node* node;
    if (*p)
      node = getNode(*p);
    else // Empty spot.
    {
      node = getNode(*p = newNode());
      *node = Node(0, 0, hash, str);
    }
    return &node.str;
  }

  /// Returns a string representation.
  cstring repr()
  {
    return Format("StringSet(list={}, nodes={})", list, nodes[]);
  }
}

inout(ubyte)[] tobin(inout(char)[] str)
{
  return cast(inout(ubyte)[]) str;
}

void testStringSet()
{
  scope msg = new UnittestMsg("Testing struct StringSet.");
  StringSet s;
  auto pstr = s.add("abcd".tobin);
  assert(pstr is s.get("abcd".tobin));
  assert(s.has("abcd".tobin));
  s.resize(64);
  assert(s.has("abcd".tobin));
}
