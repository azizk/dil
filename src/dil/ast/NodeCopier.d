/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.NodeCopier;

import dil.ast.NodesEnum,
       dil.ast.NodeMembers;

import common;

/// Mixed into the body of a class that inherits from Node.
const string copyMethod =
  `override typeof(this) copy()
  {
    alias typeof(this) this_t;
    mixin(genCopyCode(mixin("NodeKind."~this_t.stringof)));
    return n;
  }`;

/// Mixed into the body of abstract class BinaryExpr.
const string copyMethodBinaryExpr =
  `override typeof(this) copy()
  {
    alias typeof(this) this_t;
    // BinaryExpr is an abstract class and not a member of NodeKind.
    // Just take CommaExpr instead.
    static assert(is(CommaExpr : BinaryExpr),
      "CommaExpr doesn't inherit from BinaryExpr");
    mixin(genCopyCode(NodeKind.CommaExpr));
    return n;
  }`;

/// Mixed into the body of abstract class UnaryExpr.
const string copyMethodUnaryExpr =
  `override typeof(this) copy()
  {
    alias typeof(this) this_t;
    static assert(is(AddressExpr : UnaryExpr),
      "AddressExpr doesn't inherit from UnaryExpr");
    mixin(genCopyCode(NodeKind.AddressExpr));
    return n;
  }`;

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
      // if(n.member) n.member = n.member.copy();
      code ~= "if(n."~name~") n."~name~" = n."~name~".copy();\n";
      break;
    case "[]": // Copy an array of nodes.
      code ~= "n."~name~" = n."~name~".dup;\n" // n.member = n.member.dup;
              "foreach (ref x; n."~name~")\n"  // foreach (ref x; n.member)
              "  x = x.copy();\n";             //   x = x.copy();
      break;
    case "[?]": // Copy an array of nodes, items may be null.
      code ~= "n."~name~" = n."~name~".dup;\n" // n.member = n.member.dup;
              "foreach (ref x; n."~name~")\n"  // foreach (ref x; n.member)
              "  if(x) x = x.copy();\n";       //   if(x) x = x.copy();
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
char[] genCopyCode(NodeKind nodeKind)
{
   string[] m; // Array of member names to be copied.

   // Handle special cases.
   if (nodeKind == NodeKind.StringExpr)
     m = ["%n.data = n.data.dup;"];
   else
     // Look up members for this kind of node in the table.
     m = NodeMembersTable[nodeKind];

  char[] code =
    // First do a shallow copy.
    "auto n = cast(this_t)cast(void*)this.dup;\n".dup;

  // Then copy the members.
  if (m.length)
    code ~= createCode(m);

  return code;
}

// pragma(msg, genCopyCode("ArrayType"));
