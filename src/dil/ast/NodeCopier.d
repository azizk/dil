/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.NodeCopier;

import dil.ast.NodesEnum,
       dil.ast.NodeMembers;

import common;

/// Mixed into the body of a class that inherits from Node.
const string copyMethod =
  "override typeof(this) copy()"
  "{"
  "  alias typeof(this) this_t;"
  "  mixin(genCopyCode(mixin(`NodeKind.`~this_t.stringof)));"
  "  return n;"
  "}";

/// Mixed into the body of abstract class BinaryExpression.
const string copyMethodBinaryExpression =
  "override typeof(this) copy()"
  "{"
  "  alias typeof(this) this_t;"
  "  assert(is(CommaExpression : BinaryExpression), `CommaExpression doesn't inherit from BinaryExpression`);"
  "  mixin(genCopyCode(NodeKind.CommaExpression));"
  "  return n;"
  "}";

/// Mixed into the body of abstract class UnaryExpression.
const string copyMethodUnaryExpression =
  "override typeof(this) copy()"
  "{"
  "  alias typeof(this) this_t;"
  "  assert(is(AddressExpression : UnaryExpression), `AddressExpression doesn't inherit from UnaryExpression`);"
  "  mixin(genCopyCode(NodeKind.AddressExpression));"
  "  return n;"
  "}";

/// Generates the actual code for copying the provided members.
private string createCode(string[] members)
{
  string[2][] list = parseMembers(members);
  string code;
  foreach (m; list)
  {
    auto name = m[0], type = m[1];
    switch (type)
    {
    case "": // Copy a member, must not be null.
      // n.member = n.member.copy();
      code ~= "n."~name~" = n."~name~".copy();\n";
      break;
    case "?": // Copy a member, may be null.
      // n.member && (n.member = n.member.copy());
      code ~= "n."~name~" && (n."~name~" = n."~name~".copy());\n";
      break;
    case "[]": // Copy an array of nodes.
      code ~= "n."~name~" = n."~name~".dup;\n" // n.member = n.member.dup;
              "foreach (ref x; n."~name~")\n"  // foreach (ref x; n.member)
              "  x = x.copy();\n";             //   x = x.copy();
      break;
    case "[?]": // Copy an array of nodes, items may be null.
      code ~= "n."~name~" = n."~name~".dup;\n" // n.member = n.member.dup;
              "foreach (ref x; n."~name~")\n"  // foreach (ref x; n.member)
              "  x && (x = x.copy());\n";      //   x && (x = x.copy());
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

// pragma(msg, createCode(["expr?", "decls[]", "type"]));

/// Generates code for copying a node.
string genCopyCode(NodeKind nodeKind)
{
  string[] m; // Array of member names to be copied.

  // Handle special cases.
  if (nodeKind == NodeKind.StringExpression)
    m = ["%n.str = n.str.dup;"];
  else
    // Look up members for this kind of node in the table.
    m = g_membersTable[nodeKind];

  char[] code =
  // First do a shallow copy.
  "auto n = cast(this_t)cast(void*)this.dup;\n";

  // Then copy the members.
  if (m.length)
    code ~= createCode(m);

  return code;
}

// pragma(msg, genCopyCode("ArrayType"));
