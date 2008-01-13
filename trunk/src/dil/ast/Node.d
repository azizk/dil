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

Class TryCast(Class)(Node n)
{
  assert(n !is null);
  if (n.kind == mixin("NodeKind." ~ typeof(Class).stringof))
    return cast(Class)cast(void*)n;
  return null;
}

Class CastTo(Class)(Node n)
{
  assert(n !is null && n.kind == mixin("NodeKind." ~ typeof(Class).stringof));
  return cast(Class)cast(void*)n;
}

class Node
{
  NodeCategory category;
  NodeKind kind;
  Node[] children;
  Token* begin, end;

  this(NodeCategory category)
  {
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

  Class iS(Class)()
  {
    if (kind == mixin("NodeKind." ~ typeof(Class).stringof))
      return cast(Class)cast(void*)this;
    return null;
  }

  Class to(Class)()
  {
    return cast(Class)cast(void*)this;
  }

  static bool isDoxygenComment(Token* token)
  { // Doxygen: '/+!' '/*!' '//!'
    return token.type == TOK.Comment && token.start[2] == '!';
  }

  static bool isDDocComment(Token* token)
  { // DDOC: '/++' '/**' '///'
    return token.type == TOK.Comment && token.start[1] == token.start[2];
  }

  /++
    Returns the surrounding documentation comment tokens.
    Note: this function works correctly only if
          the source text is syntactically correct.
  +/
  Token*[] getDocComments(bool function(Token*) isDocComment = &isDDocComment)
  {
    Token*[] comments;
    // Get preceding comments.
    auto token = begin;
    // Scan backwards until we hit another declaration.
    while (1)
    {
      token = token.prev;
      if (token.type == TOK.LBrace ||
          token.type == TOK.RBrace ||
          token.type == TOK.Semicolon ||
          token.type == TOK.HEAD ||
          (kind == NodeKind.EnumMember && token.type == TOK.Comma))
        break;

      if (token.type == TOK.Comment)
      {
        // Check that this comment doesn't belong to the previous declaration.
        if (kind == NodeKind.EnumMember && token.type == TOK.Comma)
          break;
        switch (token.prev.type)
        {
        case TOK.Semicolon, TOK.RBrace:
          break;
        default:
          if (isDocComment(token))
            comments ~= token;
        }
      }
    }
    // Get single comment to the right.
    token = end.next;
    if (token.type == TOK.Comment && isDocComment(token))
      comments ~= token;
    else if (kind == NodeKind.EnumMember)
    {
      token = end.nextNWS;
      if (token.type == TOK.Comma)
      {
        token = token.next;
        if (token.type == TOK.Comment && isDocComment(token))
          comments ~= token;
      }
    }
    return comments;
  }
}
