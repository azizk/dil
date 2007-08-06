/++
  Author: Aziz Köksal
  License: GPL3
+/
module Identifier;
import Token;

struct Identifier
{
  TOK type;
  string str;

  static Identifier opCall(TOK type, string str)
  {
    Identifier i;
    i.type = type;
    i.str = str;
    return i;
  }

  uint toHash()
  {
    uint hash;
    foreach(c; str) {
      hash *= 9;
      hash += c;
    }
    return hash;
  }
}
