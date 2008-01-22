/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Node;

import common;

public import dil.lexer.Token;
public import dil.ast.NodesEnum;

/// This string is mixed into the constructor of a class that inherits from Node.
const string set_kind = `this.kind = mixin("NodeKind." ~ typeof(this).stringof);`;

class Node
{
  NodeCategory category;
  NodeKind kind;
  Node[] children; // Will be probably removed sometime.
  Token* begin, end;

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

  Class Is(Class)()
  {
    if (kind == mixin("NodeKind." ~ typeof(Class).stringof))
      return cast(Class)cast(void*)this;
    return null;
  }

  Class to(Class)()
  {
    return cast(Class)cast(void*)this;
  }
}
