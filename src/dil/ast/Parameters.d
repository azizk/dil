/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.Parameters;

import dil.ast.Node,
       dil.ast.Type,
       dil.ast.Expression,
       dil.ast.NodeCopier,
       dil.ast.Meta;
import dil.lexer.Identifier;
import dil.semantic.Symbols;
import dil.Enums;

import common;

/// A function or foreach parameter.
class Parameter : Node
{
  StorageClass stcs; /// The storage classes of the parameter.
  Token* stok; /// Token of the last storage class.
  TypeNode type; /// The parameter's type.
  Token* name; /// The name of the parameter.
  Expression defValue; /// The default initialization value.
  ParameterSymbol symbol; /// Semantic symbol.
  mixin(memberInfo("stcs", "stok?", "type?", "name?", "defValue?"));

  this(StorageClass stcs, Token* stok, TypeNode type,
    Token* name, Expression defValue)
  {
    mixin(set_kind);
    // type can be null when param in foreach statement
    addOptChild(type);
    addOptChild(defValue);

    this.stcs = stcs;
    this.stok = stok;
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
  cstring nameStr()
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

  /// Returns the token of the storage class that comes before the type.
  Token* tokenOfLastSTC()
  {
    return stok;
  }

  mixin methods;
}

/// Array of parameters.
class Parameters : Node
{
  StorageClass postSTCs;
  ParametersSymbol symbol; /// Semantic symbol.

  this()
  {
    mixin(set_kind);
  }

  /// For ASTSerializer.
  this(Parameter[] params)
  {
    this();
    addChildren(params);
  }

  bool hasVariadic()
  {
    if (children.length != 0)
      return items[$-1].isVariadic();
    return false;
  }

  bool hasLazy()
  {
    foreach (param; items)
      if (param.isLazy())
        return true;
    return false;
  }

  void opCatAssign(Parameter param)
  { addChild(param); }

  Parameter[] items() @property
  { return cast(Parameter[])children; }

  void items(Parameter[] items) @property
  { children = cast(Node[])items; }

  size_t length()
  { return children.length; }

  mixin(memberInfo("items"));
  mixin methods;
}

/*~~~~~~~~~~~~~~~~~~~~~~
~ Template parameters: ~
~~~~~~~~~~~~~~~~~~~~~~*/

/// Abstract base class for all template parameters.
abstract class TemplateParam : Node
{
  Token* name;
  this(Token* name)
  {
    this.name = name;
  }

  /// Returns the name of the parameter as a string.
  cstring nameStr()
  {
    return name.ident.str;
  }

  override TemplateParam copy();
}

/// $(BNF TemplateAliasParam := "alias" Identifier SpecOrDefaultType)
class TemplateAliasParam : TemplateParam
{
  Node spec; /// Specialization. Can be a Type or an Expression (in D2).
  Node def; /// Default. Can be a Type or an Expression (in D2).
  mixin(memberInfo("name", "spec?", "def?"));
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
  mixin methods;
}

/// $(BNF TemplateTypeParam := Identifier SpecOrDefaultType)
class TemplateTypeParam : TemplateParam
{
  TypeNode specType, defType;
  mixin(memberInfo("name", "specType?", "defType?"));
  this(Token* name, TypeNode specType, TypeNode defType)
  {
    super(name);
    mixin(set_kind);
    addOptChild(specType);
    addOptChild(defType);
    this.specType = specType;
    this.defType = defType;
  }
  mixin methods;
}

// version(D2)
// {
/// $(BNF TemplateThisParam  := "this" Identifier SpecOrDefaultType)
class TemplateThisParam : TemplateParam
{
  TypeNode specType, defType;
  mixin(memberInfo("name", "specType?", "defType?"));
  this(Token* name, TypeNode specType, TypeNode defType)
  {
    super(name);
    mixin(set_kind);
    addOptChild(specType);
    addOptChild(defType);
    this.specType = specType;
    this.defType = defType;
  }
  mixin methods;
}
// }

/// $(BNF TemplateValueParamer := Declarator SpecOrDefaultValue)
class TemplateValueParam : TemplateParam
{
  TypeNode valueType;
  Expression specValue, defValue;
  mixin(memberInfo("valueType", "name", "specValue?", "defValue?"));
  this(TypeNode valueType, Token* name, Expression specValue,
    Expression defValue)
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
  mixin methods;
}

/// $(BNF TemplateTupleParam := Identifier "...")
class TemplateTupleParam : TemplateParam
{
  mixin(memberInfo("name"));
  this(Token* name)
  {
    super(name);
    mixin(set_kind);
  }
  mixin methods;
}

/// Array of template parameters.
class TemplateParameters : Node
{
  this()
  {
    mixin(set_kind);
  }

  /// For ASTSerializer.
  this(TemplateParam[] params)
  {
    this();
    addChildren(params);
  }

  void opCatAssign(TemplateParam parameter)
  {
    addChild(parameter);
  }

  TemplateParam[] items() @property
  {
    return cast(TemplateParam[])children;
  }

  void items(TemplateParam[] items) @property
  {
    children = cast(Node[])items;
  }

  mixin(memberInfo("items"));
  mixin methods;
}

/// Array of template arguments.
class TemplateArguments : Node
{
  this()
  {
    mixin(set_kind);
  }

  /// For ASTSerializer.
  this(Node[] args)
  {
    this();
    addChildren(args);
  }

  void opCatAssign(Node argument)
  {
    addChild(argument);
  }

  Node[] items() @property
  {
    return children;
  }

  void items(Node[] items) @property
  {
    children = items;
  }

  mixin(memberInfo("items"));
  mixin methods;
}
