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
  /// The possible semantic states of a Node.
  enum State
  {
    Wait,   /// Wait for dependencies.
    Error,  /// There is an error.
    Finish, /// Dependencies are done.
    Done    /// The symbol is done.
  }

  NodeKind kind; /// The kind of this node.
  Node[] children; /// List of subnodes. (May be removed to save space.)
  Token* begin, end; /// The begin and end tokens of this node.
  State state; /// The semantic state of this node.

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
    assert(child !is null, "failed in " ~ typeid(this).name);
    this.children ~= child;
  }

  /// Adss a child node if not null.
  void addOptChild(Node child)
  {
    child is null || addChild(child);
  }

  /// Adds a list of child nodes.
  void addChildren(N)(N children)
  {
    assert(children !is null && delegate{
      foreach (child; children)
        if (child is null)
          return false;
      return true; }(),
      "failed in " ~ typeid(this).name
    );
    this.children ~= cast(Node[])children;
  }

  /// Adds a list of child nodes if not null.
  void addOptChildren(N)(N children)
  {
    children is null || addChildren(children);
  }

  /// Returns the text spanned by the begin and end tokens.
  /// Warning: The Tokens must refer to the same piece of text.
  cstring toText()
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
    auto init = typeid(this).init;
    auto size = init.length;
    alias byte_t = typeof(init[0]); // Get the element type.
    auto bytes = (cast(byte_t*)this)[0..size].dup; // Make an array and copy.
    return cast(Node)bytes.ptr; // Cast back to Node.
  }

  /// This string is mixed into the constructor of a class that inherits
  /// from Node. It sets the member kind. E.g.: this.kind = NodeKind.IfStmt;
  static enum set_kind =
    `this.kind = __traits(getMember, NodeKind, typeof(this).stringof);`;

  /// Returns true if Declaration.
  final bool isDeclaration()
  {
    return kind.isDeclaration;
  }

  /// Returns true if Statement.
  final bool isStatement()
  {
    return kind.isStatement;
  }

  /// Returns true if Expression.
  final bool isExpression()
  {
    return kind.isExpression;
  }

  /// Returns true if Type.
  final bool isType()
  {
    return kind.isType;
  }

  /// Returns true if Parameter.
  final bool isParameter()
  {
    return kind.isParameter;
  }

  bool wait()
  {
    return state == State.Wait;
  }

  bool error()
  {
    return state == State.Error;
  }

  bool finish()
  {
    return state == State.Finish;
  }

  bool done()
  {
    return state == State.Done;
  }

  void setwait()
  {
    state = State.Wait;
  }

  void seterror()
  {
    state = State.Error;
  }

  void setfinish()
  {
    state = State.Finish;
  }

  void setdone()
  {
    state = State.Done;
  }
}
