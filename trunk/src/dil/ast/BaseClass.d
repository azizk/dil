/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.BaseClass;

import dil.ast.Node;
import dil.ast.Types;
import dil.Enums;

class BaseClass : Node
{
  Protection prot;
  TypeNode type;
  this(Protection prot, TypeNode type)
  {
    super(NodeCategory.Other);
    mixin(set_kind);
    addChild(type);
    this.prot = prot;
    this.type = type;
  }
}
