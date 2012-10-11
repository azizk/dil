/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.lexer.Tables;

import dil.lexer.Token,
       dil.lexer.IdTable;
import dil.Float;
import common;

/// Tables used by the $(MODLINK2 dil.lexer.Lexer, Lexer).
///
/// The purpose is to keep common Token values
/// stored in a single place, with the added benefit of saving memory.
/// Most importantly, it provides access to unique Identifiers.
/// TODO: Inserting and reading needs to be thread-safe.
class LexerTables
{
  alias Token.StringValue StringValue;
  alias Token.IntegerValue IntegerValue;
  alias Token.NewlineValue NewlineValue;

  IdTable idents; /// Maps id strings to unique Identifier objects.
  cbinstr[hash_t] strings; /// Maps hashes to binary string values.
  StringValue*[hash_t] strvals; /// Maps string+postfix to StringValues.
  Float[hash_t] floats; /// Maps float strings to Float values.
  IntegerValue*[ulong] ulongs; /// Maps a ulong to an IntegerValue.
  /// A list of newline values.
  /// Only instances, where the 'hlinfo' member is null, are kept here.
  NewlineValue*[] newlines;

  /// Contructs a LexerTables object.
  this()
  {
    idents = new IdTable();
  }

  /// Looks up an identifier.
  Identifier* lookupIdentifier(cstring str)
  {
    return idents.lookup(str);
  }

  /// Looks up a ulong in the table.
  /// Params:
  ///   num = The number value.
  IntegerValue* lookupUlong(ulong num)
  {
    auto pintval = num in ulongs;
    if (!pintval)
    { // Insert a new IntegerValue into the table.
      auto iv = new IntegerValue;
      iv.ulong_ = num;
      ulongs[num] = iv;
      return iv;
    }
    return *pintval;
  }
}
