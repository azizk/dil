/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.DefaultVisitor;

import dil.ast.Visitor,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;
import common;

/// Provides a visit() method which calls Visitor.visitN() on subnodes.
mixin template visitDefault(N, Ret = returnType!(N))
{
  override Ret visit(N n)
  {
    foreach (i, T; N._mtypes)
    {
      enum m = N._members[i];
      static if (is(T : Node)) // A Node?
      {
        static if (N._mayBeNull[i])
          mixin("if(n."~m~") visitN(n."~m~");");
        else
          mixin("visitN(n."~m~");");
      }
      else static if (is(T t : E[], E) && is(E : Node)) // A Node array?
      {
        static if (N._mayBeNull[i])
          mixin("foreach (x; n."~m~") if (x) visitN(x);");
        else
          mixin("foreach (x; n."~m~") visitN(x);");
      }
    }
    static if (!is(Ret : void))
      return n;
  }
}

/// Generates the default visit methods.
///
/// E.g.:
/// ---
/// mixin visitDefault!(ClassDecl);
/// mixin visitDefault!(InterfaceDecl);
/// ---
char[] generateDefaultVisitMethods()
{
  char[] code;
  foreach (className; NodeClassNames)
    code ~= "mixin visitDefault!(" ~ className ~ ");\n";
  return code;
}
//pragma(msg, generateDefaultVisitMethods());

/// Same as above but returns void.
char[] generateDefaultVisitMethods2()
{
  char[] code;
  foreach (className; NodeClassNames)
    code ~= "mixin visitDefault!(" ~ className ~ ", void);\n";
  return code;
}


/// This class provides default methods for
/// traversing nodes and their subnodes.
class DefaultVisitor : Visitor
{
  // Comment out if too many errors are shown.
  mixin(generateDefaultVisitMethods());
}

/// This class provides default methods for
/// traversing nodes and their subnodes.
class DefaultVisitor2 : Visitor2
{
  // Comment out if too many errors are shown.
  mixin(generateDefaultVisitMethods2());
}
