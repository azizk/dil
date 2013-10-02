/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.lexer.Identifier;

import dil.lexer.TokensEnum,
       dil.lexer.IDsEnum;
import dil.String;
import common;

/// Represents an identifier as defined in the D specs.
///
/// $(BNF
////Identifier := IdStart IdChar*
////   IdStart := "_" | Letter
////    IdChar := IdStart | "0"-"9"
////    Letter := UniAlpha
////)
/// See_Also:
///  Unicode alphas as defined in Unicode 5.0.0.
align(1)
struct Identifier_
{
  string str; /// The UTF-8 string of the identifier.
  TOK kind;   /// The token kind. Can be TOK.{KEYWORD, SpecialID, Identifier}.
  IDK idKind; /// Only for predefined identifiers.

immutable:
  /// Constructs an Identifier.
  this(string str, TOK kind, IDK idKind = IDK.init)
  {
    this.str = str;
    this.kind = kind;
    this.idKind = idKind;
  }

  /// Calculates a hash for this id.
  hash_t toHash()
  {
    return hashOf(str);
  }

  /// Returns the string of this id.
  string toString()
  {
    return str;
  }

  /// Returns true if this id starts with prefix.
  bool startsWith(string prefix)
  {
    return String(str).startsWith(prefix);
  }
}
// pragma(msg, Identifier.sizeof.stringof);

/// Identifiers are const by default.
alias Identifier = immutable(Identifier_);
