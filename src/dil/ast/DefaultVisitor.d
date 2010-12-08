/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.DefaultVisitor;

import dil.ast.Visitor,
       dil.ast.NodeMembers,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;
import common;

/// Generates the actual code for visiting a node's members.
private string createCode(NodeKind nodeKind)
{
  string[] members; // Array of member names to be visited.

  // Look up members for this kind of node in the table.
  members = g_membersTable[nodeKind];

  if (!members.length)
    return "";

  string[2][] list = parseMembers(members);
  string code;
  foreach (m; list)
  {
    auto name = m[0], type = m[1];
    switch (type)
    {
    case "": // Visit node.
      code ~= "visitN(n."~name~");\n"; // visitN(n.member);
      break;
    case "?": // Visit node, may be null.
      // n.member && visitN(n.member);
      code ~= "n."~name~" && visitN(n."~name~");\n";
      break;
    case "[]": // Visit nodes in the array.
      code ~= "foreach (x; n."~name~")\n" // foreach (x; n.member)
              "  visitN(x);\n";           //   visitN(x);
      break;
    case "[?]": // Visit nodes in the array, items may be null.
      code ~= "foreach (x; n."~name~")\n" // foreach (x; n.member)
              "  x && visitN(x);\n";      //   x && visitN(x);
      break;
    case "%": // Copy code verbatim.
      code ~= name ~ "\n";
      break;
    default:
      assert(0, "unknown member type.");
    }
  }
  return code;
}

/// Generates the default visit methods.
///
/// E.g.:
/// ---
/// override returnType!("ClassDeclaration") visit(ClassDeclaration n)
/// { /* Code that visits the subnodes... */ return n; }
/// ---
string generateDefaultVisitMethods()
{
  string code;
  foreach (i, className; g_classNames)
    code ~= "override returnType!(`"~className~"`) visit("~className~" n)"
            "{"
            "  "~createCode(cast(NodeKind)i)~
            "  return n;"
            "}\n";
  return code;
}
// pragma(msg, generateDefaultVisitMethods());

/// Same as above but returns void.
string generateDefaultVisitMethods2()
{
  string code;
  foreach (i, className; g_classNames)
    code ~= "override void visit("~className~" n)"
            "{"
            "  "~createCode(cast(NodeKind)i)~
            "}\n";
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
