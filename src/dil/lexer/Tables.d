/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.lexer.Tables;

import dil.lexer.Token,
       dil.lexer.IdTable;
import dil.Float;
import dil.String;
import common;

/// Tables used by the $(MODLINK2 dil.lexer.Lexer, Lexer).
///
/// The purpose is to keep common Token values
/// stored in a single place, with the added benefit of saving memory.
/// Most importantly, it provides access to unique Identifiers.
/// TODO: Inserting and reading needs to be thread-safe.
class LexerTables
{
  alias StringValue = Token.StringValue;
  alias IntegerValue = Token.IntegerValue;
  alias NewlineValue = Token.NewlineValue;

  IdTable idents; /// Maps id strings to unique Identifier objects.
  cbinstr[hash_t] strings; /// Maps hashes to binary string values.
  StringValue*[hash_t] strvals; /// Maps string+postfix to StringValues.
  Float[hash_t] floats; /// Maps float strings to Float values.
  IntegerValue*[ulong] ulongs; /// Maps a ulong to an IntegerValue.
  /// A list of newline values.
  /// Only instances where the 'hlinfo' member is null are kept here.
  NewlineValue*[] newlines;

  /// Contructs a LexerTables object.
  this()
  {
    idents = new IdTable();
  }

  /// Looks up a StringValue in the table.
  /// Params:
  ///   str = The string to be looked up.
  ///   pf = The postfix character.
  ///   dup = True if str should be copied.
  /// Returns: A stored or new StringValue.
  StringValue* lookupString(cstring str, char postfix, bool dup = true)
  {
    auto hash = hashOf(str);
    if (auto psv = (hash + postfix) in strvals)
      return *psv;
    // Insert a new StringValue into the table.
    auto sv = new StringValue;
    sv.str = lookupString(hash, str, dup);
    sv.pf = postfix;
    strvals[hash + postfix] = sv;
    return sv;
  }

  /// Looks up a string in the table.
  /// Params:
  ///   hash = The hash of str.
  ///   str = The string to be looked up.
  ///   dup = True if str should be copied.
  /// Returns: A stored or new string.
  cbinstr lookupString(hash_t hash, cstring str, bool dup = true)
  {
    assert(hash == hashOf(str));
    auto bstr = cast(cbinstr)str;
    if (auto pstr = hash in strings)
      bstr = *pstr;
    else // Insert a new string into the table.
      bstr = strings[hash] = dup ? bstr.dup : bstr;
    return bstr;
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
    if (auto pintval = num in ulongs)
      return *pintval;
    // Insert a new IntegerValue into the table.
    auto iv = new IntegerValue;
    iv.ulong_ = num;
    ulongs[num] = iv;
    return iv;
  }

  /// Looks up a newline value that can be shared among Lexer instances.
  NewlineValue* lookupNewline(uint_t lineNum)
  {
    assert(lineNum != 0);
    auto i = lineNum - 1;
    if (i >= newlines.length)
      newlines.length = lineNum;
    auto nl = newlines[i];
    if (!nl)
    { // Insert a new NewlineValue.
      newlines[i] = nl = new NewlineValue;
      nl.lineNum = lineNum;
    }
    return nl;
  }
}
