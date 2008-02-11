/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Parameters;

import dil.ast.Node;
import dil.ast.Type;
import dil.ast.Expression;
import dil.lexer.Identifier;
import dil.Enums;

class Parameter : Node
{
  StorageClass stc;
  TypeNode type;
  Identifier* name;
  Expression defValue;

  this(StorageClass stc, TypeNode type, Identifier* name, Expression defValue)
  {
    super(NodeCategory.Other);
    mixin(set_kind);
    // type can be null when param in foreach statement
    addOptChild(type);
    addOptChild(defValue);

    this.stc = stc;
    this.type = type;
    this.name = name;
    this.defValue = defValue;
  }

  /// func(...) or func(int[] values ...)
  bool isVariadic()
  {
    return !!(stc & StorageClass.Variadic);
  }

  /// func(int[] values ...)
  bool isDVariadic()
  {
    return isVariadic && !isCVariadic;
  }

  /// func(...)
  bool isCVariadic()
  {
    return stc == StorageClass.Variadic &&
           type is null && name is null;
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

/*~~~~~~~~~~~~~~~~~~~~~~
~ Template parameters: ~
~~~~~~~~~~~~~~~~~~~~~~*/

abstract class TemplateParameter : Node
{
  Identifier* ident;
  this(Identifier* ident)
  {
    super(NodeCategory.Other);
    this.ident = ident;
  }
}

class TemplateAliasParameter : TemplateParameter
{
  TypeNode specType, defType;
  this(Identifier* ident, TypeNode specType, TypeNode defType)
  {
    super(ident);
    mixin(set_kind);
    addOptChild(specType);
    addOptChild(defType);
    this.ident = ident;
    this.specType = specType;
    this.defType = defType;
  }
}

class TemplateTypeParameter : TemplateParameter
{
  TypeNode specType, defType;
  this(Identifier* ident, TypeNode specType, TypeNode defType)
  {
    super(ident);
    mixin(set_kind);
    addOptChild(specType);
    addOptChild(defType);
    this.ident = ident;
    this.specType = specType;
    this.defType = defType;
  }
}

// version(D2)
// {
class TemplateThisParameter : TemplateParameter
{
  TypeNode specType, defType;
  this(Identifier* ident, TypeNode specType, TypeNode defType)
  {
    super(ident);
    mixin(set_kind);
    addOptChild(specType);
    addOptChild(defType);
    this.ident = ident;
    this.specType = specType;
    this.defType = defType;
  }
}
// }

class TemplateValueParameter : TemplateParameter
{
  TypeNode valueType;
  Expression specValue, defValue;
  this(TypeNode valueType, Identifier* ident, Expression specValue, Expression defValue)
  {
    super(ident);
    mixin(set_kind);
    addChild(valueType);
    addOptChild(specValue);
    addOptChild(defValue);
    this.valueType = valueType;
    this.ident = ident;
    this.specValue = specValue;
    this.defValue = defValue;
  }
}

class TemplateTupleParameter : TemplateParameter
{
  this(Identifier* ident)
  {
    super(ident);
    mixin(set_kind);
    this.ident = ident;
  }
}

class TemplateParameters : Node
{
  this()
  {
    super(NodeCategory.Other);
    mixin(set_kind);
  }

  void opCatAssign(TemplateParameter parameter)
  {
    addChild(parameter);
  }

  TemplateParameter[] items()
  {
    return cast(TemplateParameter[])children;
  }
}

class TemplateArguments : Node
{
  this()
  {
    super(NodeCategory.Other);
    mixin(set_kind);
  }

  void opCatAssign(Node argument)
  {
    addChild(argument);
  }
}
