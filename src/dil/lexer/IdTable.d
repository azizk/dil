/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.lexer.IdTable;

import dil.lexer.TokensEnum,
       dil.lexer.IdentsGenerator,
       dil.lexer.Keywords,
       dil.lexer.Funcs;
import dil.Unicode;
import common;

public import dil.lexer.Identifier,
              dil.lexer.IdentsEnum;

/// A namespace for the predefined identifiers.
struct Ident
{
  const static
  {
    mixin(generateIdentMembers());
  }

  /// Returns an array of all predefined identifiers.
  static Identifier*[] allIds()
  {
    return __allIds;
  }

  /// Returns true for assembler jump opcode identifiers.
  static bool isJumpOpcode(IDK kind)
  {
    return IDK.ja <= kind && kind <= IDK.jz;
  }
}

/// A table for hoarding and retrieving identifiers.
class IdTable
{
  /// A set of common, predefined identifiers for fast lookups.
  static Identifier*[hash_t] staticTable;
  /// A table that grows with every newly found, unique identifier.
  Identifier*[hash_t] growingTable;

  alias Identifier* delegate(hash_t, string) LookupMethod;
  /// Looks up idString in the growing table.
  LookupMethod inGrowing;

  /// Constructs an IdTable object.
  ///
  /// Loads keywords and predefined identifiers into the static table.
  this()
  {
    inGrowing = &_inGrowing_unsafe; // Default to unsafe function.

    if (staticTable is null) // Initialize global static table?
    {
      foreach (ref k; g_reservedIds)
        staticTable[hashOf(k.str)] = &k;
      staticTable.rehash;
    }
    foreach (id; Ident.allIds())
      staticTable[hashOf(id.str)] = id;
  }

  /// Returns true if str is a valid D identifier.
  static bool isIdentifierString(string str)
  {
    if (str.length == 0 || isdigit(str[0]))
      return false;
    size_t idx;
    do
    {
      auto c = dil.Unicode.decode(str, idx);
      if (c == ERROR_CHAR || !(isident(c) || !isascii(c) && isUniAlpha(c)))
        return false;
    } while (idx < str.length)
    return true;
  }

  /// Returns true if str is a keyword or
  /// a special token (__FILE__, __LINE__ etc.)
  bool isReservedIdentifier(string str)
  {
    if (str.length == 0)
      return false;
    auto id = inStatic(str);
    // True if id is in the table and if it's not a normal identifier.
    return id && id.kind != TOK.Identifier;
  }

  /// Returns true if this is a valid identifier and if it's not reserved.
  bool isValidUnreservedIdentifier(string str)
  {
    return isIdentifierString(str) && !isReservedIdentifier(str);
  }

  /// Looks up idString in both tables.
  Identifier* lookup(string idString)
  {
    auto idHash = hashOf(idString);
    auto id = inStatic(idHash);
    assert(!id || idString == id.str,
      Format("bad hash function:\n ‘{}’ != ‘{}’; hash={}",
        idString, id.str, idHash));
    if (id)
      return id;
    return inGrowing(idHash, idString);
  }

  /// Looks up the hash of an id in the static table.
  Identifier* inStatic(hash_t idHash)
  {
    auto id = idHash in staticTable;
    return id ? *id : null;
  }

  /// Looks up idString in the static table.
  Identifier* inStatic(string idString)
  {
    auto id = hashOf(idString) in staticTable;
    return id ? *id : null;
  }

  /// Sets the thread safety mode of the growing table.
  void setThreadsafe(bool safe)
  {
    inGrowing = safe ? &_inGrowing_safe : &_inGrowing_unsafe;
  }

  /// Returns true if access to the growing table is thread-safe.
  bool isThreadsafe()
  {
    return inGrowing is &_inGrowing_safe;
  }

  /// Looks up idString in the table.
  ///
  /// Adds idString to the table if not found.
  private Identifier* _inGrowing_unsafe(hash_t idHash, string idString)
  out(id)
  { assert(id !is null); }
  body
  {
    auto id = idHash in growingTable;
    assert(!id || idString == (*id).str,
      Format("bad hash function:\n ‘{}’ != ‘{}’", idString, (*id).str));
    if (id)
      return *id;
    auto newID = Identifier(idString, TOK.Identifier);
    growingTable[idHash] = newID;
    return newID;
  }

  /// Looks up idString in the table.
  ///
  /// Adds idString to the table if not found.
  /// Access to the data structure is synchronized.
  private Identifier* _inGrowing_safe(hash_t idHash, string idString)
  {
    synchronized
      return _inGrowing_unsafe(idHash, idString);
  }

  /// Counter for anonymous identifiers.
  static uint anonCount;

  /// Generates an anonymous identifier.
  ///
  /// Concatenates prefix with anonCount.
  /// The identifier is not inserted into the table.
  Identifier* genAnonymousID(string prefix)
  {
    auto num = String(++anonCount);
    return Identifier(prefix ~ num, TOK.Identifier);
  }

  /// Generates an identifier for an anonymous enum.
  Identifier* genAnonEnumID()
  {
    return genAnonymousID("__anonenum");
  }

  /// Generates an identifier for an anonymous class.
  Identifier* genAnonClassID()
  {
    return genAnonymousID("__anonclass");
  }

  /// Generates an identifier for an anonymous struct.
  Identifier* genAnonStructID()
  {
    return genAnonymousID("__anonstruct");
  }

  /// Generates an identifier for an anonymous union.
  Identifier* genAnonUnionID()
  {
    return genAnonymousID("__anonunion");
  }

  /// Generates an identifier for a module which has got no valid name.
  Identifier* genModuleID()
  {
    return genAnonymousID("__module");
  }
}

unittest
{
  // TODO: write benchmark.
  // Single table

  // Single table. synchronized

  // Two tables.

  // Two tables. synchronized
}
