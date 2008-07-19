/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Node;

import common;

public import dil.lexer.Token;
public import dil.ast.NodesEnum;

/// The root class of all D syntax tree elements.
abstract class Node
{
  NodeCategory category; /// The category of this node.
  NodeKind kind; /// The kind of this node.
  Node[] children; // Will be probably removed sometime.
  Token* begin, end; /// The begin and end tokens of this node.

  /// Constructs a node object.
  this(NodeCategory category)
  {
    assert(category != NodeCategory.Undefined);
    this.category = category;
  }

  void setTokens(Token* begin, Token* end)
  {
    this.begin = begin;
    this.end = end;
  }

  Class setToks(Class)(Class node)
  {
    node.setTokens(this.begin, this.end);
    return node;
  }

  void addChild(Node child)
  {
    assert(child !is null, "failed in " ~ this.classinfo.name);
    this.children ~= child;
  }

  void addOptChild(Node child)
  {
    child is null || addChild(child);
  }

  void addChildren(Node[] children)
  {
    assert(children !is null && delegate{
      foreach (child; children)
        if (child is null)
          return false;
      return true; }(),
      "failed in " ~ this.classinfo.name
    );
    this.children ~= children;
  }

  void addOptChildren(Node[] children)
  {
    children is null || addChildren(children);
  }

  /// Returns a reference to Class if this node can be cast to it.
  Class Is(Class)()
  {
    if (kind == mixin("NodeKind." ~ Class.stringof))
      return cast(Class)cast(void*)this;
    return null;
  }

  /// Casts this node to Class.
  Class to(Class)()
  {
    return cast(Class)cast(void*)this;
  }

  /// Returns a deep copy of this node.
  abstract Node copy();

  /// Returns a shallow copy of this object.
  final Node dup()
  {
    // Find out the size of this object.
    alias typeof(this.classinfo.init[0]) byte_t;
    size_t size = this.classinfo.init.length;
    // Copy this object's data.
    byte_t[] data = (cast(byte_t*)this)[0..size].dup;
    return cast(Node)data.ptr;
  }

  /// This string is mixed into the constructor of a class that inherits
  /// from Node. It sets the member kind.
  const string set_kind = `this.kind = mixin("NodeKind." ~ typeof(this).stringof);`;
}
