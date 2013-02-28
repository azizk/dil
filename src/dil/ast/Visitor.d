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
    text ~= "returnType!("~className~") visit("~className~" node)"~
            "{return unhandled(node).to!("~className~");}\n";
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

/// Calls the visitor method that can handle node n.
Ret callVisitMethod(Ret)(Object visitorInstance, Node n, NodeKind k)
{ // Get the method's address from the vtable.
  const funcIndex = indexOfFirstVisitMethod + k;
  auto funcptr = typeid(visitorInstance).vtbl[funcIndex];
  // Construct a delegate and call it.
  Ret delegate(Node) visitMethod = void;
  visitMethod.ptr = cast(void*)visitorInstance; // Frame pointer.
  visitMethod.funcptr = cast(Ret function(Node))funcptr;
  return visitMethod(n);
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
    return callVisitMethod!(Node)(this, n, n.kind);
  }

  /// Allows calling the visit() method with a null node.
  Node dispatch(Node n, NodeKind k)
  {
    return callVisitMethod!(Node)(this, n, k);
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
    callVisitMethod!(void)(this, n, n.kind);
  }

  /// Allows calling the visit() method with a null node.
  void dispatch(Node n, NodeKind k)
  {
    callVisitMethod!(void)(this, n, k);
  }

  /// Called by visit() methods that were not overridden.
  void unhandled(Node n)
  {}

final:
  alias dispatch visit;
  alias dispatch visitN, visitD, visitS, visitE, visitT;
}

/// Index into the vtable of the Visitor classes.
private static const size_t indexOfFirstVisitMethod;

/// Initializes indexOfFirstVisitMethod for both Visitor classes.
static this()
{
  auto vtbl = typeid(Visitor).vtbl;
  auto vtbl2 = typeid(Visitor2).vtbl;
  assert(vtbl.length == vtbl2.length);
  size_t i;
  foreach (j, func; vtbl)
    if (func is &Visitor._beforeFirstVisitMethod &&
        vtbl2[j] is &Visitor2._beforeFirstVisitMethod)
    {
      i = j + 1;
      assert(i < vtbl.length);
      break;
    }
  assert(i, "couldn't find first visit method in the vtable");
  indexOfFirstVisitMethod = i;
}

void testVisitor()
{
  scope msg = new UnittestMsg("Testing class Visitor.");

  class TestVisitor : Visitor
  {
    alias super.visit visit;
    override Expression visit(NullExpr e)
    {
      return e;
    }
  }

  class TestVisitor2 : Visitor2
  {
    NullExpr ie;
    alias super.visit visit;
    override void visit(NullExpr e)
    {
      ie = e;
    }
  }

  auto ie = new NullExpr();
  auto v1 = new TestVisitor();
  auto v2 = new TestVisitor2();

  assert(v1.visit(ie) is ie, "Visitor.visit(IdentifierExpr) was not called");
  v2.visit(ie);
  assert(v2.ie is ie, "Visitor2.visit(IdentifierExpr) was not called");
}
