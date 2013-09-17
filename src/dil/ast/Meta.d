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

  static Class ctor(Class.CTTI_Types args)
  {
    return new Class(args);
  }

  static Class create(TypeInfo[] argtypes, void*[] args)
  {
    mixin(makeNewClass(Class.CTTI_TypeStrs));
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
/// static enum CTTI_Members = ["una","args",];
/// static enum CTTI_MayBeNull = [false,true,];
/// static alias CTTI_Types = Tuple!(typeof(una),typeof(args),);
/// static enum CTTI_TypeStrs = [typeof(una).stringof,typeof(args).stringof,];
/// ---
char[] memberInfo(string[] members...)
{
  char[] names, mayBeNull, types, typeStrs;
  foreach (m; members)
  {
    auto isOpt = m[$-1] == '?';
    m = isOpt ? m[0..$-1] : m; // Strip '?'.
    names ~= '"' ~ m ~ `",`;
    mayBeNull ~= (isOpt ? "true" : "false") ~ ",";
    types ~= "typeof(" ~ m ~ "),";
    typeStrs ~= "typeof(" ~ m ~ ").stringof,";
  }
  return "static enum CTTI_Members = [" ~ names ~ "];\n" ~
         "static enum CTTI_MayBeNull = [" ~ mayBeNull ~ "];\n" ~
         "static alias CTTI_Types = Tuple!(" ~ types ~ ");\n" ~
         "static enum CTTI_TypeStrs = [" ~ typeStrs ~ "];\n";
}

//pragma(msg, memberInfo("una", "args?"));
