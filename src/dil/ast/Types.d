/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.ast.Types;

public import dil.ast.Type;
import dil.ast.Node,
       dil.ast.Expression,
       dil.ast.Parameters,
       dil.ast.NodeCopier;
import dil.lexer.Identifier;
import dil.semantic.Types;
import dil.Enums;

/// Syntax error.
class IllegalType : TypeNode
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
}

/// char, int, float etc.
class IntegralType : TypeNode
{
  TOK tok;
  this(TOK tok)
  {
    mixin(set_kind);
    this.tok = tok;
  }
  mixin(copyMethod);
}

/// Identifier
class IdentifierType : TypeNode
{
  Identifier* ident;
  this(Identifier* ident)
  {
    mixin(set_kind);
    this.ident = ident;
  }
  mixin(copyMethod);
}

/// Type "." Type
class QualifiedType : TypeNode
{
  alias next lhs; /// Left-hand side type.
  TypeNode rhs; /// Right-hand side type.
  this(TypeNode lhs, TypeNode rhs)
  {
    super(lhs);
    mixin(set_kind);
    addChild(rhs);
    this.rhs = rhs;
  }
  mixin(copyMethod);
}

/// "." Type
class ModuleScopeType : TypeNode
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
}

/// $(BNF TypeofType := typeof "(" (Expression | return) ")")
class TypeofType : TypeNode
{
  Expression expr;
  /// $(BNF typeof "(" Expression ")")
  this(Expression e)
  {
    this();
    addChild(e);
    this.expr = e;
  }

  /// For D2.0: $(BNF typeof "(" return ")")
  this()
  {
    mixin(set_kind);
  }

  /// Returns true if this is a "typeof(return)".
  bool isTypeofReturn()
  {
    return expr is null;
  }

  mixin(copyMethod);
}

/// Identifier "!" "(" TemplateParameters? ")"
class TemplateInstanceType : TypeNode
{
  Identifier* ident;
  TemplateArguments targs;
  this(Identifier* ident, TemplateArguments targs)
  {
    mixin(set_kind);
    addOptChild(targs);
    this.ident = ident;
    this.targs = targs;
  }
  mixin(copyMethod);
}

/// $(BNF PointerType:= Type "*")
class PointerType : TypeNode
{
  this(TypeNode next)
  {
    super(next);
    mixin(set_kind);
  }
  mixin(copyMethod);
}

/// $(BNF
////ArrayType := DynamicArray | StaticArray | SliceArray | AssociativeArray
////DynamicArray     := T "[" "]"
////StaticArray      := T "[" E "]"
////SliceArray       := T "[" E ".." E "]" # for slicing tuples
////AssociativeArray := T "[" T "]"
////)
class ArrayType : TypeNode
{
  Expression index1, index2;
  TypeNode assocType;

  /// DynamicArray.
  this(TypeNode t)
  {
    super(t);
    mixin(set_kind);
  }

  /// StaticArray or SliceArray.
  this(TypeNode t, Expression e1, Expression e2 = null)
  {
    this(t);
    addChild(e1);
    addOptChild(e2);
    this.index1 = e1;
    this.index2 = e2;
  }

  /// AssociativeArray.
  this(TypeNode t, TypeNode assocType)
  {
    this(t);
    addChild(assocType);
    this.assocType = assocType;
  }

  bool isDynamic()
  {
    return assocType is null && index1 is null;
  }

  bool isStatic()
  {
    return index1 !is null && index2 is null;
  }

  bool isSlice()
  {
    return index1 !is null && index2 !is null;
  }

  bool isAssociative()
  {
    return assocType !is null;
  }

  mixin(copyMethod);
}

/// $(BNF FunctionType := ReturnType function ParameterList?)
class FunctionType : TypeNode
{
  alias next returnType;
  Parameters params;
  this(TypeNode returnType, Parameters params)
  {
    super(returnType);
    mixin(set_kind);
    addChild(params);
    this.params = params;
  }
  mixin(copyMethod);
}

/// $(BNF DelegateType := ReturnType delegate ParameterList?)
class DelegateType : TypeNode
{
  alias next returnType;
  Parameters params;
  this(TypeNode returnType, Parameters params)
  {
    super(returnType);
    mixin(set_kind);
    addChild(params);
    this.params = params;
  }
  mixin(copyMethod);
}

/// $(BNF
///CFuncPointerType := Type "(" BasicType2 Identifier ")" ParameterList?)
class CFuncPointerType : TypeNode
{
  Parameters params;
  this(TypeNode type, Parameters params)
  {
    super(type);
    mixin(set_kind);
    addOptChild(params);
  }
  mixin(copyMethod);
}

/// $(BNF BaseClassType := Protection? BasicType)
class BaseClassType : TypeNode
{
  Protection prot;
  this(Protection prot, TypeNode type)
  {
    super(type);
    mixin(set_kind);
    this.prot = prot;
  }
  mixin(copyMethod);
}

// version(D2)
// {
/// $(BNF ConstType := const "(" Type ")")
class ConstType : TypeNode
{
  this(TypeNode next)
  {
    // If t is null: cast(const)
    super(next);
    mixin(set_kind);
  }
  mixin(copyMethod);
}

/// $(BNF InvariantType := invariant "(" Type ")")
class InvariantType : TypeNode
{
  this(TypeNode next)
  {
    // If t is null: cast(invariant)
    super(next);
    mixin(set_kind);
  }
  mixin(copyMethod);
}
// } // version(D2)
