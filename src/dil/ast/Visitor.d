/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.Visitor;

import dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;
import common;

/// Generates visit methods for all classes.
///
/// E.g.:
/// ---
/// Declaration visit(ClassDecl node){return unhandled(node);}
/// Expression visit(CommaExpr node){return unhandled(node);}
/// ---
char[] generateVisitMethods()
{
  char[] text = "void _beforeFirstVisitMethod(){}".dup;
  foreach (className; NodeClassNames)
    text ~= "returnType!("~className~") visit("~
      className~" node){return unhandled(node).to!("~className~");}\n";
  return text;
}

/// Same as generateVisitMethods, but return void instead.
char[] generateVisitMethods2()
{
  char[] text = "void _beforeFirstVisitMethod(){}".dup;
  foreach (className; NodeClassNames)
    text ~= "void visit("~className~" node){unhandled(node);}\n";
  return text;
}

/// Gets the appropriate return type for the provided class.
template returnType(Class)
{
  static if (is(Class : Declaration))
    alias Declaration returnType;
  else
  static if (is(Class : Statement))
    alias Statement returnType;
  else
  static if (is(Class : Expression))
    alias Expression returnType;
  else
  static if (is(Class : TypeNode))
    alias TypeNode returnType;
  else
    alias Node returnType;
}

/// Returns a delegate to the method that can visit the node n.
Ret delegate(Node) getVisitMethod(Ret)(Object o, Node n)
{ // Get the method's address from the vtable.
  assert(indexOfFirstVisitMethod+n.kind < o.classinfo.vtbl.length);
  auto funcptr = o.classinfo.vtbl[indexOfFirstVisitMethod+n.kind];
  // Make a delegate and return it.
  Ret delegate(Node) visitMethod = void;
  visitMethod.ptr = cast(void*)o; // Frame pointer.
  visitMethod.funcptr = cast(Ret function(Node))funcptr;
  return visitMethod;
}

/// Implements a variation of the visitor pattern.
///
/// Inherited by classes that need to traverse a D syntax tree
/// and do computations, transformations and other things on it.
abstract class Visitor
{
  mixin(generateVisitMethods());

  /// Calls the appropriate visit() method for a node.
  Node dispatch(Node n)
  {
    return getVisitMethod!(Node)(this, n)(n);
  }

  /// Called by visit() methods that were not overridden.
  Node unhandled(Node n)
  { return n; }

final:
  // Visits a Declaration and returns a Declaration.
  Declaration visitD(Declaration n)
  {
    return dispatch(n).to!(Declaration);
  }
  // Visits a Statement and returns a Statement.
  Statement visitS(Statement n)
  {
    return dispatch(n).to!(Statement);
  }
  // Visits a Expression and returns an Expression.
  Expression visitE(Expression n)
  {
    return dispatch(n).to!(Expression);
  }
  // Visits a TypeNode and returns a TypeNode.
  TypeNode visitT(TypeNode n)
  {
    return dispatch(n).to!(TypeNode);
  }
  // Visits a Node and returns a Node.
  Node visitN(Node n)
  {
    return dispatch(n);
  }
}

/// The same as class Visitor, but the methods return void.
/// This class is suitable when you don't want to transform the AST.
abstract class Visitor2
{
  mixin(generateVisitMethods2());

  /// Calls the appropriate visit() method for a node.
  void dispatch(Node n)
  {
    getVisitMethod!(void)(this, n)(n);
  }

  /// Called by visit() methods that were not overridden.
  void unhandled(Node n)
  {}

final:
  alias dispatch visit;
  alias dispatch visitN, visitD, visitS, visitE, visitT;
}

/// Index into the vtable of the Visitor classes.
private static const uint indexOfFirstVisitMethod;

/// Initializes indexOfFirstVisitMethod for both Visitor classes.
static this()
{
  auto vtbl = Visitor.classinfo.vtbl;
  auto vtbl2 = Visitor2.classinfo.vtbl;
  uint i;
  foreach (j, func; vtbl)
    if (func is &Visitor._beforeFirstVisitMethod &&
        vtbl2[j] is &Visitor2._beforeFirstVisitMethod)
    {
      i = j + 1;
      assert(vtbl.length > i);
      break;
    }
  assert(i, "couldn't find first visit method in the vtable");
  indexOfFirstVisitMethod = i;
}

/// TODO: implement.
unittest
{}
