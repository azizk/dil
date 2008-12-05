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

/// Generate visit methods.
///
/// E.g.:
/// ---
/// Declaration visit(ClassDeclaration){return null;};
/// Expression visit(CommaExpression){return null;};
/// ---
char[] generateVisitMethods()
{
  char[] text;
  foreach (className; g_classNames)
    text ~= "returnType!(\""~className~"\") visit("~className~" node){return node;}\n";
  return text;
}
// pragma(msg, generateAbstractVisitMethods());

/// Gets the appropriate return type for the provided class.
template returnType(char[] className)
{
  static if (is(typeof(mixin(className)) : Declaration))
    alias Declaration returnType;
  else
  static if (is(typeof(mixin(className)) : Statement))
    alias Statement returnType;
  else
  static if (is(typeof(mixin(className)) : Expression))
    alias Expression returnType;
  else
  static if (is(typeof(mixin(className)) : TypeNode))
    alias TypeNode returnType;
  else
    alias Node returnType;
}

/// Generate functions which do the second dispatch.
///
/// E.g.:
/// ---
/// Expression visitCommaExpression(Visitor visitor, CommaExpression c)
/// { visitor.visit(c); /* Second dispatch. */ }
/// ---
/// The equivalent in the traditional visitor pattern would be:
/// ---
/// class CommaExpression : Expression
/// {
///   void accept(Visitor visitor)
///   { visitor.visit(this); }
/// }
/// ---
char[] generateDispatchFunctions()
{
  char[] text;
  foreach (className; g_classNames)
    text ~= "returnType!(\""~className~"\") visit"~className~"(Visitor visitor, "~className~" c)\n"
            "{ return visitor.visit(c); }\n";
  return text;
}
// pragma(msg, generateDispatchFunctions());

/++
 Generates an array of function pointers.

 ---
 [
   cast(void*)&visitCommaExpression,
   // etc.
 ]
 ---
+/
char[] generateVTable()
{
  char[] text = "[";
  foreach (className; g_classNames)
    text ~= "cast(void*)&visit"~className~",\n";
  return text[0..$-2]~"]"; // slice away last ",\n"
}
// pragma(msg, generateVTable());

/// Implements a variation of the visitor pattern.
///
/// Inherited by classes that need to traverse a D syntax tree
/// and do computations, transformations and other things on it.
abstract class Visitor
{
  mixin(generateVisitMethods());

  static
    mixin(generateDispatchFunctions());

  // This is necessary so that the compiler puts
  // the array into the static data segment.
  mixin("private const _dispatch_vtable = " ~ generateVTable() ~ ";");
  /// The table holding function pointers to the second dispatch functions.
  static const dispatch_vtable = _dispatch_vtable;
  static assert(dispatch_vtable.length == g_classNames.length,
                "vtable length doesn't match number of classes");

  /// Looks up the second dispatch function for n and returns that.
  Node function(Visitor, Node) getDispatchFunction()(Node n)
  {
    return cast(Node function(Visitor, Node))dispatch_vtable[n.kind];
  }

  /// The main and first dispatch function.
  Node dispatch(Node n)
  { // Second dispatch is done in the called function.
    return getDispatchFunction(n)(this, n);
  }

final:
  Declaration visit(Declaration n)
  { return visitD(n); }
  Statement visit(Statement n)
  { return visitS(n); }
  Expression visit(Expression n)
  { return visitE(n); }
  TypeNode visit(TypeNode n)
  { return visitT(n); }
  Node visit(Node n)
  { return visitN(n); }

  Declaration visitD(Declaration n)
  {
    return cast(Declaration)cast(void*)dispatch(n);
  }

  Statement visitS(Statement n)
  {
    return cast(Statement)cast(void*)dispatch(n);
  }

  Expression visitE(Expression n)
  {
    return cast(Expression)cast(void*)dispatch(n);
  }

  TypeNode visitT(TypeNode n)
  {
    return cast(TypeNode)cast(void*)dispatch(n);
  }

  Node visitN(Node n)
  {
    return dispatch(n);
  }
}
