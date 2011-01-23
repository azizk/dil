/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
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

  /// Sets the begin and end tokens.
  void setTokens(Token* begin, Token* end)
  {
    this.begin = begin;
    this.end = end;
  }

  /// Sets the location tokens (begin and end) using another node.
  void setLoc(Node other)
  {
    this.begin = other.begin;
    this.end = other.end;
  }

  /// Adds a child node.
  void addChild(Node child)
  {
    assert(child !is null, "failed in " ~ this.classinfo.name);
    this.children ~= child;
  }

  /// Adss a child node if not null.
  void addOptChild(Node child)
  {
    child is null || addChild(child);
  }

  /// Adds a list of child nodes.
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

  /// Adds a list of child nodes if not null.
  void addOptChildren(Node[] children)
  {
    children is null || addChildren(children);
  }

  /// Returns the text spanned by the begin and end tokens.
  string toText()
  {
    assert(begin && end);
    return begin.textSpan(end);
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

  /// Returns true if Declaration.
  final bool isDeclaration()
  {
    return category == NodeCategory.Declaration;
  }

  /// Returns true if Statement.
  final bool isStatement()
  {
    return category == NodeCategory.Statement;
  }

  /// Returns true if Expression.
  final bool isExpression()
  {
    return category == NodeCategory.Expression;
  }

  /// Returns true if Type.
  final bool isType()
  {
    return category == NodeCategory.Type;
  }

  /// Returns true if Other.
  final bool isOther()
  {
    return category == NodeCategory.Other;
  }
  /// The only nodes in this category are Parameter classes.
  alias isOther isParameter;
}
