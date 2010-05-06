/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.Tables;

import dil.lexer.Token;
import dil.lexer.IdTable;
import dil.semantic.Types;
import common;

/// A collection of tables used by the Lexer and other classes.
class Tables
{
  /// Contructs a Tables object.
  this()
  {
    idents = new IdTable();
    types = new TypeTable();
  }

  alias Token.StringValue StringValue;
  alias Token.IntegerValue IntegerValue;
  alias Token.NewlineValue NewlineValue;

  TypeTable types; /// A table for D types.

  // A collection of tables for various token values.
  IdTable idents;
  string[hash_t] strings; /// Maps strings to zero-terminated string values.
  Float[hash_t] floats; /// Maps float strings to Float values.
  IntegerValue*[ulong] ulongs; /// Maps a ulong to an IntegerValue.
  /// A list of newline values.
  /// Only instances, where 'hlinfo' is null, are kept here.
  NewlineValue*[] newlines;

  /// Looks up an identifier.
  Identifier* lookupIdentifier(string str)
  {
    return idents.lookup(str);
  }
}
