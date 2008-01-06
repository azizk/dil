/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Parameter;

import dil.ast.Node;
import dil.ast.Types;
import dil.ast.Expressions;
import dil.lexer.Identifier;
import dil.Enums;

class Parameter : Node
{
  StorageClass stc;
  TypeNode type;
  Identifier* ident;
  Expression defValue;

  this(StorageClass stc, TypeNode type, Identifier* ident, Expression defValue)
  {
    super(NodeCategory.Other);
    mixin(set_kind);
    // type can be null when param in foreach statement
    addOptChild(type);
    addOptChild(defValue);

    this.stc = stc;
    this.type = type;
    this.ident = ident;
    this.defValue = defValue;
  }

  /// func(...) or func(int[] values ...)
  bool isVariadic()
  {
    return !!(stc & StorageClass.Variadic);
  }

  /// func(...)
  bool isOnlyVariadic()
  {
    return stc == StorageClass.Variadic &&
           type is null && ident is null;
  }
}

class Parameters : Node
{
  this()
  {
    super(NodeCategory.Other);
    mixin(set_kind);
  }

  bool hasVariadic()
  {
    if (children.length != 0)
      return items[$-1].isVariadic();
    return false;
  }

  void opCatAssign(Parameter param)
  { addChild(param); }

  Parameter[] items()
  { return cast(Parameter[])children; }

  size_t length()
  { return children.length; }
}
