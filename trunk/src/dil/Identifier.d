/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Identifier;
import dil.Token;
import common;

struct Identifier
{
  TOK type;
  string str;

  static Identifier* opCall(TOK type, string str)
  {
    auto i = new Identifier;
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
