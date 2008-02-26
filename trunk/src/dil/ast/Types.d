/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Types;

public import dil.ast.Type;
import dil.ast.Node;
import dil.ast.Expression;
import dil.ast.Parameters;
import dil.ast.NodeCopier;
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
  this(TypeNode next)
  {
    super(next);
    mixin(set_kind);
  }
  mixin(copyMethod);
}

/// "typeof" "(" Expression ")" or$(BR)
/// "typeof" "(" "return" ")" (D2.0)
class TypeofType : TypeNode
{
  Expression e;
  this(Expression e)
  {
    this();
    addChild(e);
    this.e = e;
  }

  // For D2.0: "typeof" "(" "return" ")"
  this()
  {
    mixin(set_kind);
  }

  bool isTypeofReturn()
  {
    return e is null;
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

/// Type *
class PointerType : TypeNode
{
  this(TypeNode next)
  {
    super(next);
    mixin(set_kind);
  }
  mixin(copyMethod);
}

/// Dynamic array: T[] or$(BR)
/// Static array: T[E] or$(BR)
/// Slice array (for tuples): T[E..E] or$(BR)
/// Associative array: T[T]
class ArrayType : TypeNode
{
  Expression e1, e2;
  TypeNode assocType;

  this(TypeNode t)
  {
    super(t);
    mixin(set_kind);
  }

  this(TypeNode t, Expression e1, Expression e2)
  {
    this(t);
    addChild(e1);
    addOptChild(e2);
    this.e1 = e1;
    this.e2 = e2;
  }

  this(TypeNode t, TypeNode assocType)
  {
    this(t);
    addChild(assocType);
    this.assocType = assocType;
  }

  bool isDynamic()
  {
    return !assocType && !e1;
  }

  bool isStatic()
  {
    return e1 && !e2;
  }

  bool isSlice()
  {
    return e1 && e2;
  }

  bool isAssociative()
  {
    return assocType !is null;
  }

  mixin(copyMethod);
}

/// ReturnType "function" "(" Parameters? ")"
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

/// ReturnType "delegate" "(" Parameters? ")"
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

/// Type "(" BasicType2 Identifier ")" "(" Parameters? ")"
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

/// "class" Identifier : BaseClasses
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
/// "const" "(" Type ")"
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

/// "invariant" "(" Type ")"
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
