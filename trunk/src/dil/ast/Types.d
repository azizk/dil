/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Types;

import dil.ast.Node;
import dil.ast.Expression;
import dil.ast.Parameters;
import dil.lexer.Identifier;
import dil.semantic.Types;
import dil.Enums;

/// The base class of all type nodes.
abstract class TypeNode : Node
{
  TypeNode next;
  Type type; /// The semantic type of this type node.

  this()
  {
    this(null);
  }

  this(TypeNode next)
  {
    super(NodeCategory.Type);
    addOptChild(next);
    this.next = next;
  }
}

/// Syntax error.
class IllegalType : TypeNode
{
  this()
  {
    mixin(set_kind);
  }
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
}

/// Type "." Type
class QualifiedType : TypeNode
{
  alias next left;
  TypeNode right;
  this(TypeNode left, TypeNode right)
  {
    super(left);
    mixin(set_kind);
    addChild(right);
    this.right = right;
  }
}

/// "." Type
class ModuleScopeType : TypeNode
{
  this(TypeNode next)
  {
    super(next);
    mixin(set_kind);
  }
}

/// "typeof" "(" Expression ")
class TypeofType : TypeNode
{
  Expression e;
  this(Expression e)
  {
    this();
    addChild(e);
    this.e = e;
  }

  /// D2.0: "typeof" "(" "return" ")"
  this()
  {
    mixin(set_kind);
  }

  bool isTypeofReturn()
  {
    return e is null;
  }
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
}

/// Type *
class PointerType : TypeNode
{
  this(TypeNode next)
  {
    super(next);
    mixin(set_kind);
  }
}

/// Dynamic array: T[] or
/// Static array: T[E] or
/// Slice array (for tuples): T[E..E] or
/// Associative array: T[T]
class ArrayType : TypeNode
{
  Expression e, e2;
  TypeNode assocType;

  this(TypeNode t)
  {
    super(t);
    mixin(set_kind);
  }

  this(TypeNode t, Expression e, Expression e2)
  {
    this(t);
    addChild(e);
    addOptChild(e2);
    this.e = e;
    this.e2 = e2;
  }

  this(TypeNode t, TypeNode assocType)
  {
    this(t);
    addChild(assocType);
    this.assocType = assocType;
  }
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
}
// } // version(D2)
