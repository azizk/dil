/// Author: Aziz Köksal
/// License: GPL3
module dil.lexer.Identifier;

import dil.lexer.TokensEnum,
       dil.lexer.IdentsEnum;
import common;

/// Represents an identifier as defined in the D specs.
///
/// $(PRE
///  Identifier := IdStart IdChar*
///  IdStart := "_" | Letter
///  IdChar := IdStart | "0"-"9"
///  Letter := UniAlpha
/// )
/// See_Also:
///  Unicode alphas are defined in Unicode 5.0.0.
align(1)
struct Identifier
{
  string str; /// The UTF-8 string of the identifier.
  TOK kind;   /// The token kind.
  IDK idKind; /// Only for predefined identifiers.

  static Identifier* opCall(string str, TOK kind)
  {
    auto id = new Identifier;
    id.str = str;
    id.kind = kind;
    return id;
  }

  static Identifier* opCall(string str, TOK kind, IDK idKind)
  {
    auto id = new Identifier;
    id.str = str;
    id.kind = kind;
    id.idKind = idKind;
    return id;
  }

  uint toHash()
  {
    uint hash;
    foreach(c; str) {
      hash *= 11;
      hash += c;
    }
    return hash;
  }
}
// pragma(msg, Identifier.sizeof.stringof);
