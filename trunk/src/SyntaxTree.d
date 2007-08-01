/++
  Author: Aziz Köksal
  License: GPL3
+/
module SyntaxTree;
import Token;

enum NodeType
{
  Declaration,
  Statement,
  Expression,
  Type,
  Other
}

class Node
{
  NodeType nodeType;
  Token* begin, end;

  this(NodeType nodeType)
  {
    this.nodeType = nodeType;
  }

  void setTokens(Token* begin, Token* end)
  {
    this.begin = begin;
    this.end = end;
  }
}
