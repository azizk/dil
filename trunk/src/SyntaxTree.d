/++
  Author: Aziz Köksal
  License: GPL2
+/
module SyntaxTree;

enum NodeType
{
  Declaration,
  Statement,
  Expression,
  Type
}

class Node
{
  NodeType nodeType;
  this(NodeType nodeType)
  {
    this.nodeType = nodeType;
  }
}
