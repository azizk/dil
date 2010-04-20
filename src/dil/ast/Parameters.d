/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.Parameters;

import dil.ast.Node,
       dil.ast.Type,
       dil.ast.Expression,
       dil.ast.NodeCopier;
import dil.lexer.Identifier;
import dil.Enums;

/// A function or foreach parameter.
class Parameter : Node
{
  StorageClass stcs; /// The storage classes of the parameter.
  TypeNode type; /// The parameter's type.
  Token* name; /// The name of the parameter.
  Expression defValue; /// The default initialization value.

  this(StorageClass stcs, TypeNode type, Token* name, Expression defValue)
  {
    super(NodeCategory.Other);
    mixin(set_kind);
    // type can be null when param in foreach statement
    addOptChild(type);
    addOptChild(defValue);

    this.stcs = stcs;
    this.type = type;
    this.name = name;
    this.defValue = defValue;
  }

  /// Returns true if this parameter has a name.
  bool hasName()
  {
    return name !is null;
  }

  /// Returns the name of the parameter as a string.
  char[] nameStr()
  {
    assert(hasName);
    return name.ident.str;
  }

  /// Returns true if this is a D-style variadic parameter.
  /// E.g.: func(int[] values ...)
  bool isDVariadic()
  {
    return isVariadic && !isCVariadic;
  }

  /// Returns true if this is a C-style variadic parameter.
  /// E.g.: func(...)
  bool isCVariadic()
  {
    return stcs == StorageClass.Variadic &&
           type is null && name is null;
  }

  /// Returns true if this is a D- or C-style variadic parameter.
  bool isVariadic()
  {
    return !!(stcs & StorageClass.Variadic);
  }

  /// Returns true if this parameter is lazy.
  bool isLazy()
  {
    return !!(stcs & StorageClass.Lazy);
  }

  mixin(copyMethod);
}

/// Array of parameters.
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

  bool hasLazy()
  {
    foreach(param; items)
      if(param.isLazy())
        return true;
    return false;
  }

  void opCatAssign(Parameter param)
  { addChild(param); }

  Parameter[] items()
  { return cast(Parameter[])children; }

  size_t length()
  { return children.length; }

  mixin(copyMethod);
}

/*~~~~~~~~~~~~~~~~~~~~~~
~ Template parameters: ~
~~~~~~~~~~~~~~~~~~~~~~*/

/// Abstract base class for all template parameters.
abstract class TemplateParameter : Node
{
  Token* name;
  this(Token* name)
  {
    super(NodeCategory.Other);
    this.name = name;
  }

  /// Returns the name of the parameter as a string.
  char[] nameStr()
  {
    return name.ident.str;
  }
}

/// $(BNF TemplateAliasParameter := "alias" Identifier SpecOrDefaultType)
class TemplateAliasParameter : TemplateParameter
{
  Node spec; /// Specialization. Can be a Type or an Expression (in D2).
  Node def; /// Default. Can be a Type or an Expression (in D2).
  this(Token* name, Node spec, Node def)
  {
    assert(!spec || spec.isType() || spec.isExpression());
    assert(!def || def.isType() || def.isExpression());
    super(name);
    mixin(set_kind);
    addOptChild(spec);
    addOptChild(def);
    this.spec = spec;
    this.def = def;
  }
  mixin(copyMethod);
}

/// $(BNF TemplateTypeParameter := Identifier SpecOrDefaultType)
class TemplateTypeParameter : TemplateParameter
{
  TypeNode specType, defType;
  this(Token* name, TypeNode specType, TypeNode defType)
  {
    super(name);
    mixin(set_kind);
    addOptChild(specType);
    addOptChild(defType);
    this.specType = specType;
    this.defType = defType;
  }
  mixin(copyMethod);
}

// version(D2)
// {
/// $(BNF TemplateThisParam  := "this" Identifier SpecOrDefaultType)
class TemplateThisParameter : TemplateParameter
{
  TypeNode specType, defType;
  this(Token* name, TypeNode specType, TypeNode defType)
  {
    super(name);
    mixin(set_kind);
    addOptChild(specType);
    addOptChild(defType);
    this.specType = specType;
    this.defType = defType;
  }
  mixin(copyMethod);
}
// }

/// $(BNF TemplateValueParamer := Declarator SpecOrDefaultValue)
class TemplateValueParameter : TemplateParameter
{
  TypeNode valueType;
  Expression specValue, defValue;
  this(TypeNode valueType, Token* name, Expression specValue, Expression defValue)
  {
    super(name);
    mixin(set_kind);
    addChild(valueType);
    addOptChild(specValue);
    addOptChild(defValue);
    this.valueType = valueType;
    this.specValue = specValue;
    this.defValue = defValue;
  }
  mixin(copyMethod);
}

/// $(BNF TemplateTupleParameter := Identifier "...")
class TemplateTupleParameter : TemplateParameter
{
  this(Token* name)
  {
    super(name);
    mixin(set_kind);
  }
  mixin(copyMethod);
}

/// Array of template parameters.
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

  mixin(copyMethod);
}

/// Array of template arguments.
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

  mixin(copyMethod);
}
