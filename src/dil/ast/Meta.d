/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.ast.Meta;

import dil.String;
import common;

/// Generates code declaring variables with the correct type and value,
/// which are then passed on to ctor().
///
/// E.g.: makeNewClass("Expression", "Token*")
/// ---
/// assert(argtypes.length == args.length);
/// assert(argtypes.length == 2);
/// assert(argtypes[0] == typeid(Expression));
/// auto _0 = *cast(Expression*)args[0];
/// assert(argtypes[1] == typeid(Token*));
/// auto _1 = *cast(Token**)args[1];
/// auto node = ctor(_0,_1,);
/// ---
char[] makeNewClass(cstring[] argtypes)
{
  char[] args = "assert(argtypes.length == args.length);\n" ~
    "assert(argtypes.length == " ~ itoactf(argtypes.length) ~ ");\n";
  char[] ctorArgs;
  foreach (i, t; argtypes)
  {
    auto istr = itoactf(i);
    args ~=
      "assert(argtypes[" ~ istr ~ "] == typeid(" ~ t ~ "));\n" ~
      "auto _" ~ istr ~ " = *cast(" ~ t ~ "*)args[" ~ istr ~ "];\n";
    ctorArgs ~= "_" ~ istr ~ ",";
  }
  return args ~ "auto node = ctor(" ~ ctorArgs ~ ");";
}

//pragma(msg, makeNewClass(["A","B","C"]));

/// Provides functions for constructing a class from run-time arguments.
mixin template createMethod()
{
  alias typeof(this) Class;

  static Class ctor(Class._mtypes args)
  {
    return new Class(args);
  }

  static Class create(TypeInfo[] argtypes, void*[] args)
  {
    mixin(makeNewClass(Class._mtypesArray));
    return node;
  }
}

/// Provides a collection of methods.
mixin template methods()
{
  mixin copyMethod;
  mixin createMethod;
}

/// Must be mixed into the module scope to avoid circular imports.
//mixin template TypeTupleOfTemplate()
//{
//  template TypeTupleOf_(alias C, alias MS)
//  {
//    static if (MS.length == 0)
//      alias Tuple!() Result;
//    else
//    { // E.g.:     typeof(mixin("CommaExpr"~ "." ~ "lhs"))
//      alias Tuple!(typeof(mixin(C.stringof ~ "." ~ MS[0]))) First;
//      static if (MS.length == 1)
//        alias First Result;
//      else
//        alias Tuple!(First, TypeTupleOf_!(C, MS[1..$]).Result) Result;
//    }
//  }

//  /// Returns the types of C's members as a Tuple.
//  template TypeTupleOf(alias C)
//  {
//    alias TypeTupleOf_!(C, C._members).Result TypeTupleOf;
//  }
//}

/// Returns a TypeTuple of members.
char[] typeTupleOf(string[] members)
{
  char[] result = "Tuple!( ".dup;
  foreach (m; members)
    result ~= "typeof(" ~ m ~ "),";
  result[$-1] = ')'; // Replace last comma or space.
  return result;
}

/// Returns a TypeTuple with string elements.
char[] strTypeTupleOf(string[] members)
{
  char[] result = "[ ".dup;
  foreach (m; members)
    result ~= "typeof(" ~ m ~ ").stringof,";
  result[$-1] = ']'; // Replace last comma or space.
  return result;
}

//pragma(msg, typeTupleOf("CommaExpr", ["lhs", "rhs", "optok"]));

/// E.g.:
/// ---
/// static enum _members = ["una","args",];
/// static alias Tuple!( typeof(una),typeof(args)) _mtypes;
/// static enum _mtypesArray = [ typeof(una).stringof,typeof(args).stringof];
/// ---
char[] memberInfo(string[] members...)
{
  //members = members && members[0].length == 0 ? null : members;
  char[] s;
  foreach (m; members)
    s ~= '"' ~ m ~ `",`;
  s = "static enum _members = [" ~ s ~ "];\n" ~
      "static alias " ~ typeTupleOf(members) ~ " _mtypes;\n" ~
      "static enum _mtypesArray = " ~ strTypeTupleOf(members) ~ ";";
  return s;
}

//pragma(msg, memberInfo("una", "args"));
