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
    "assert(argtypes.length == " ~ itoa(argtypes.length) ~ ");\n";
  char[] ctorArgs;
  foreach (i, t; argtypes)
  {
    auto istr = itoa(i);
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
  alias Class = typeof(this);

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

/// Generates information on Node members, which is used to generate code
/// for copying or visiting methods.
///
/// E.g.:
/// ---
/// static enum _members = ["una","args",];
/// static enum _mayBeNull = [false,true,];
/// static alias _mtypes = Tuple!(typeof(una),typeof(args),);
/// static enum _mtypesArray = [typeof(una).stringof,typeof(args).stringof,];
/// ---
char[] memberInfo(string[] members...)
{
  char[] namesList, mayBeNull, mtypes, mtypesA, names;
  foreach (m; members)
  {
    auto isOpt = m[$-1] == '?';
    mayBeNull ~= (isOpt ? "true" : "false") ~ ",";
    m = isOpt ? m[0..$-1] : m; // Strip '?'.
    namesList ~= '"' ~ m ~ `",`;
    names ~= m ~ `,`;
    mtypes ~= "typeof(" ~ m ~ "),";
    mtypesA ~= "typeof(" ~ m ~ ").stringof,";
  }
  return "static enum _members = [" ~ namesList ~ "];\n" ~
         "static enum _mayBeNull = [" ~ mayBeNull ~ "];\n" ~
         "static alias _mtypes = Tuple!(" ~ mtypes ~ ");\n" ~
         "static enum _mtypesArray = [" ~ mtypesA ~ "];\n";
}

//pragma(msg, memberInfo("una", "args?"));
