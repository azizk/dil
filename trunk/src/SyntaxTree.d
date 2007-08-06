/++
  Author: Aziz Köksal
  License: GPL3
+/
module SyntaxTree;
import Token;

enum NodeCategory
{
  Declaration,
  Statement,
  Expression,
  Type,
  Other
}

class Node
{
  NodeCategory category;
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
}
