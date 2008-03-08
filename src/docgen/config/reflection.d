/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.config.reflection;

import docgen.misc.meta;
import docgen.misc.options;

////
//
// Macros for reading input
//
////

char[] _wrong(char[] key) {
  return `if (val.length != 1) throw new Exception(
    "Wrong number of arguments for `~key~`");`;
}

char[] _switch(char[] stuff) {
  return "switch(key) {" ~ stuff ~ "}";
}

char[] _parseI(char[] key) {
  return `case "` ~ key ~ `":` ~ _wrong(key) ~ key ~
    `= Integer.parse(val[0]); continue;`;
}

char[] _parseS(char[] key) {
  return `case "` ~ key ~ `":` ~ _wrong(key) ~ key ~
    `= val[0]; continue;`;
}

char[] _parseB(char[] key) {
  return `case "` ~ key ~ `":` ~ _wrong(key) ~ key ~
    `= val[0] == "true" ? true : val[0] == "false" ? false : err(); continue;`;
}

char[] _parseList(char[] key) {
  return `case "` ~ key ~ `":foreach(v; val) ` ~
    key ~ `~= v; continue;`;
}

template _parseEnum_(bool list, char[] key, V...) {
  static if (V.length>1)
    const char[] _parseEnum_ =
      `case "` ~ V[0] ~ `":` ~ key ~ (list ? "~" : "") ~ `=` ~ V[1] ~ `; continue;` \n ~
      _parseEnum_!(list, key, V[2..$]);
  else
    const char[] _parseEnum_ = "";
}

template _parseEnum(char[] key, V...) {
  const char[] _parseEnum = `case "` ~ key ~
    `":` ~ _wrong(key) ~ `switch(val[0]) {` ~
    _parseEnum_!(false, key, V) ~
      `default: err(); } continue;`;
}

template _parseEnumList(char[] key, V...) {
  const char[] _parseEnumList = `case "` ~ key ~
    `":` ~ `foreach (item; val) switch(item) {` ~
    _parseEnum_!(true, key, V) ~
      `default: err(); } continue;`;
}

////
//
// Reflection for properties. This code will hopefully get better when the dmdfe bugs get fixed.
//
////

// dmdfe bug -- Seriously WTF?
char[] fixType(char[] type) {
  return type[$-1] == ' ' ? type[0..$-1] : type;
}

// take the last part of field name
char[] getLastName(char[] field) {
  if (field.length == 0) return "";
  int t = 0;
  // dmdfe bug: a while loop causes index out of bounds error
  for (int i=field.length-1; i >= 0; i--)
    if (field[i] == '.') { t = i+1; break; }
  return field[t..$];
}

// dmdfe bug: cannot return evalType alias
template _evalType(char[] type) {
  mixin("alias "~type~" value;");
}

// Note: stuple wrappers needed for tuples, otherwise:
// dmdfe bug: cc1d: ../.././gcc/d/dmd/expression.c:4865: virtual Expression* DotIdExp::semantic(Scope*): Assertion `0' failed.
template evalType(char[] type) {
  alias _evalType!(type).value evalType;
}

// wraps the reflected struct and enum data inside struct because otherwise the handling becomes impossibly hard
template getType(T) {
  static if(is(T == struct))
    alias Struct!(T) getType;
  else static if(is(T == enum))
    alias Enum!(T) getType;
  else static if(isEnumList!(T))
    alias Enum!(enumListType!(T), true) getType;
  else
    alias T getType;
}

template getTypes(alias S, int idx = S.tupleof.length) {
  static if(idx)
    alias Tuple!(getTypes!(S, idx-1), getType!(typeof(S.tupleof[idx-1]))) getTypes;
  else
    alias Tuple!() getTypes;
}

/**
 * Extracts the comma separated struct field names using .tupleof.stringof.
 * This is needed since the struct.tupleof[n].stringof is broken for enums and tuples in dmdfe.
 *
 * Bugs: handling of tuples
 */
char[] __getNames(char[] type) {
  char[] tmp;
  bool end = false;

  foreach(c; type[5..$]) {
    if (c != ' ' && c != '(' && c != ')' && end) tmp ~= c;
    if (c == ',') end = false;
    if (c == '.') end = true;
  }

  return tmp;
}

template _getNames(char[] str, T...) {
  static if (str.length) {
    static if (str[0] == ',')
      alias _getNames!(str[1..$], T, "") _getNames;
    else
      alias _getNames!(str[1..$], T[0..$-1], T[$-1] ~ str[0]) _getNames;
  } else
    alias T _getNames;
}

template getNames(char[] str) {
  alias _getNames!(__getNames(str), "") getNames;
}

struct Struct(alias T) {
  const type = "struct"; // used for pattern matching... apparently there's no other way
  const name = fixType(T.stringof); // dmdfe bug: trailing space
  alias STuple!(getNames!(T.tupleof.stringof)) names;
  alias STuple!(getTypes!(T)) types;
}

struct Enum(alias T, bool list = false) {
  const type = list ? "enumlist" : "enum"; // used for pattern matching... apparently there's no other way
  const name =  T.stringof[1..$]; // dmdfe bug: returns enum base type instead enum type
  alias evalType!("___"~name).tuple elements;
}

// determines the enumtype[] type
template isEnumList(T : T[]) {
  const isEnumList = T.stringof[0] == '_';
}

template isEnumList(T) {
  const isEnumList = false;
}

template enumListType(T : T[]) {
  alias T enumListType;
}

template enumListType(T) {
  static assert(false, "Not enum list type!");
}

char[] createIParser(char[] field) {
  return `_parseI("` ~ field ~ `") ~` \n;
}

char[] createBParser(char[] field) {
  return `_parseB("` ~ field ~ `") ~` \n;
}
 
char[] createSParser(char[] field) {
  return `_parseS("` ~ field ~ `") ~` \n;
}
 
char[] createLParser(char[] field) {
  return `_parseList("` ~ field ~ `") ~` \n;
}

char[] createEParser(char[] field, char[] contents) {
  return `_parseEnum!("` ~ field ~ `",` ~ contents ~ `) ~` \n;
}

char[] createELParser(char[] field, char[] contents) {
  return `_parseEnumList!("` ~ field ~ `",` ~ contents ~ `) ~` \n;
}

template _makeEnumString(char[] t, E...) {
  static if (E.length)
    const _makeEnumString = `"` ~ E[0] ~ `", "` ~ t ~ "." ~ E[0] ~ `",` ~
                            _makeEnumString!(t, E[1..$]);
  else
    const _makeEnumString = "";
}

// avoids the following dmdfe bugs:
//  - Error: elements is not a type (typeof(T).elements)
//  - Error: tuple is not a valid template value argument (T.elements where T is the complex type def)
template makeEnumString(char[] t, T) {
  const makeEnumString = _makeEnumString!(t, T.elements);
}

/**
 * Generates code for parsing data from the configuration data structure.
 */
template makeTypeString(int i, N, T, char[] prefix) {
  static assert(N.tuple.length == T.tuple.length);
  static if (i < N.tuple.length) {
    static if (is(T.tuple[i] == bool))
      const makeTypeString = createBParser(prefix ~ N.tuple[i]) ~ makeTypeString!(i+1, N, T, prefix);
    else static if (is(T.tuple[i] : int))
      const makeTypeString = createIParser(prefix ~ N.tuple[i]) ~ makeTypeString!(i+1, N, T, prefix);
    else static if (is(T.tuple[i] == char[]))
      const makeTypeString = createSParser(prefix ~ N.tuple[i]) ~ makeTypeString!(i+1, N, T, prefix);
    else static if (is(T.tuple[i] == char[][]))
      const makeTypeString = createLParser(prefix ~ N.tuple[i]) ~ makeTypeString!(i+1, N, T, prefix);
    else static if (is(T.tuple[i] == struct)) {
      static if (T.tuple[i].type == "struct")
        const makeTypeString = makeTypeString!(0, typeof(T.tuple[i].names),
                               typeof(T.tuple[i].types), prefix~N.tuple[i]~".") ~
                               makeTypeString!(i+1, N, T, prefix);
      else static if (T.tuple[i].type == "enum")
        const makeTypeString = createEParser(prefix ~ N.tuple[i],
                               makeEnumString!(T.tuple[i].name, T.tuple[i])[0..$-1]) ~
                               makeTypeString!(i+1, N, T, prefix);
      else static if (T.tuple[i].type == "enumlist")
        const makeTypeString = createELParser(prefix ~ N.tuple[i],
                               makeEnumString!(T.tuple[i].name, T.tuple[i])[0..$-1]) ~
                               makeTypeString!(i+1, N, T, prefix);
      else {
        const makeTypeString = "?" ~ makeTypeString!(i+1, N, T, prefix);
        static assert(false, "Unknown type");
      }
    } else {
      const makeTypeString = "?" ~ makeTypeString!(i+1, N, T, prefix);
      static assert(false, "Unknown type");
    }
  } else
    const makeTypeString = "";
}

template makeTypeStringForStruct(alias opt) {
  const makeTypeStringForStruct = makeTypeString!(0, opt.names, opt.types, opt.name~".")[0..$-2];
}

/* some leftovers 
template handleType(T, char[] prefix="") {
  static if(is(typeof(T) == struct)) {
    static if(T.type == "enum")
      // another dmdfe weirdness: T.stringof == "Enum!(Type)" here, but if do
      // alias T handleType;, the result.stringof is "struct Enum".
      alias T handleType;
  } else
    alias T handleType;
}
*/

