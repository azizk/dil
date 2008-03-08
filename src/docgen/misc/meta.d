/**
 * Author: Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.misc.meta;

/// tuple literal workaround
template Tuple(T...) { alias T Tuple; }

/// another tuple literal workaround (can be nested & avoids at least one dmdfe bug)
struct STuple(T...) { alias T tuple; }


// (a -> b), [a] -> [b]
template map(alias S, T...) {
  static if (T.length)
    alias Tuple!(S!(T[0]), map!(S, T[1..$])) map;
  else
    alias T map;
}

/// (a -> Bool), [a] -> [a]
template filter(alias S, T...) {
  static if (!T.length)
    alias Tuple!() filter;
  else static if (S!(T[0]))
    alias Tuple!(T[0], filter!(S, T[1..$])) filter;
  else
    alias filter!(S, T[1..$]) filter;
}

/// Int -> Bool
template odd(int T) {
  const odd = T%2 == 1;
}

/// Int -> Bool
template even(int T) {
  const even = !odd!(T);
}

/// a [a] -> a  -- max x y = max2 x (max y)
T max(T, U...)(T a, U b) {
  static if (b.length)
    return a > max(b) ? a : max(b);
  else
    return a;
}

/// a [a] -> a  -- min x y = min2 x (min y)
T min(T, U...)(T a, U b) {
  static if (b.length)
    return a < min(b) ? a : min(b);
  else
    return a;
}

/// Upcasts derivatives of B to B
template UpCast(B, T) { alias T UpCast; }
template UpCast(B, T : B) { alias B UpCast; }

/// converts integer to ascii, base 10
char[] itoa(int i) {
  char[] ret;
  auto numbers = "0123456789ABCDEF";

  do {
    ret = numbers[i%10] ~ ret;
    i /= 10;
  } while (i)

  return ret;
}

/// Enum stuff

template _genList(char[] pre, char[] post, T...) {
  static if (T.length)
    const _genList = pre ~ T[0] ~ post ~ (T.length>1 ? "," : "") ~
                     _genList!(pre, post, T[1..$]);
  else
    const _genList = ``;
}

/**
 * Creates
 *   - a typedef for enum (workaround for .tupleof.stringof)
 *   - the enum structure
 *   - string array of enum items (for runtime programming)
 *   - string tuple of enum items (for metaprogramming - char[][] doesn't work)
 */
template createEnum(char[] tName, char[] eName, char[] arName, char[] alName, T...) {
  const createEnum =
    "typedef int " ~ tName ~ ";" ~
    "enum " ~ eName ~ ":" ~ tName ~ "{" ~ _genList!("", "", T) ~ "};" ~
    "char[][] " ~ arName ~ "=[" ~ _genList!(`"`, `"[]`, T) ~ "];" ~
    "alias STuple!(" ~ _genList!(`"`, `"`, T) ~ ") " ~ alName ~ ";";
}
