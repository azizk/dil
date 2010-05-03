/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.lexer.IdTable;

import dil.lexer.TokensEnum,
       dil.lexer.IdentsGenerator,
       dil.lexer.Keywords,
       dil.lexer.Funcs : String;
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

/// Global table for hoarding and retrieving identifiers.
struct IdTable
{
static:
  /// A set of common, predefined identifiers for fast lookups.
  private Identifier*[string] staticTable;
  /// A table that grows with every newly found, unique identifier.
  private Identifier*[string] growingTable;

  /// Loads keywords and predefined identifiers into the static table.
  static this()
  {
    foreach (ref k; g_reservedIds)
      staticTable[k.str] = &k;
    foreach (id; Ident.allIds())
      staticTable[id.str] = id;
    staticTable.rehash;
  }

  /// Looks up idString in both tables.
  Identifier* lookup(string idString)
  {
    auto id = inStatic(idString);
    if (id)
      return id;
    return inGrowing(idString);
  }

  /// Looks up idString in the static table.
  Identifier* inStatic(string idString)
  {
    auto id = idString in staticTable;
    return id ? *id : null;
  }

  alias Identifier* function(string idString) LookupFunction;
  /// Looks up idString in the growing table.
  LookupFunction inGrowing = &_inGrowing_unsafe; // Default to unsafe function.

  /// Sets the thread safety mode of the growing table.
  void setThreadsafe(bool b)
  {
    if (b)
      inGrowing = &_inGrowing_safe;
    else
      inGrowing = &_inGrowing_unsafe;
  }

  /// Returns true if access to the growing table is thread-safe.
  bool isThreadsafe()
  {
    return inGrowing is &_inGrowing_safe;
  }

  /// Looks up idString in the table.
  ///
  /// Adds idString to the table if not found.
  private Identifier* _inGrowing_unsafe(string idString)
  out(id)
  { assert(id !is null); }
  body
  {
    auto id = idString in growingTable;
    if (id)
      return *id;
    auto newID = Identifier(idString, TOK.Identifier);
    growingTable[idString] = newID;
    return newID;
  }

  /// Looks up idString in the table.
  ///
  /// Adds idString to the table if not found.
  /// Access to the data structure is synchronized.
  private Identifier* _inGrowing_safe(string idString)
  {
    synchronized
      return _inGrowing_unsafe(idString);
  }

  /+
  Identifier* addIdentifiers(char[][] idStrings)
  {
    auto ids = new Identifier*[idStrings.length];
    foreach (i, idString; idStrings)
    {
      Identifier** id = idString in tabulatedIds;
      if (!id)
      {
        auto newID = Identifier(TOK.Identifier, idString);
        tabulatedIds[idString] = newID;
        id = &newID;
      }
      ids[i] = *id;
    }
  }
  +/

  static uint anonCount; /// Counter for anonymous identifiers.

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
