/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.IdTable;

import dil.lexer.TokensEnum;
import dil.IdentsGenerator;
import dil.lexer.Keywords;
import common;

public import dil.lexer.Identifier;
public import dil.IdentsEnum;

struct Ident
{
  const static
  {
    mixin(generateIdentMembers());
  }

  static Identifier*[] allIds()
  {
    return __allIds;
  }
}

/++
  Global table for hoarding and retrieving identifiers.
+/
struct IdTable
{
static:
  /// A set of common, predefined identifiers for fast lookups.
  private Identifier*[string] staticTable;
  /// A table that grows with every newly found, unique identifier.
  /// Access must be synchronized.
  private Identifier*[string] growingTable;

  /// Initializes the static table.
  static this()
  {
    // Load keywords and pre-defined identifiers into the static table.
    foreach (ref k; keywords)
      staticTable[k.str] = &k;
    foreach (id; Ident.allIds())
      staticTable[id.str] = id;
    staticTable.rehash;
  }

  /// Looks in both tables.
  Identifier* lookup(string idString)
  {
    auto id = inStatic(idString);
    if (id)
      return id;
    return inGrowing(idString);
  }

  /// Look up idString in the static table.
  Identifier* inStatic(string idString)
  {
    auto id = idString in staticTable;
    return id ? *id : null;
  }

  alias Identifier* function(string idString) LookupFunction;
  /// Look up idString in the growing table.
  LookupFunction inGrowing = &_inGrowing_unsafe; // Default to unsafe function.

  /++
    Set the thread safety mode of this table.
    Call this function only if you can be sure
    that this table is not being accessed
    (like during lexing, parsing and semantic phase.)
  +/
  void setThreadsafe(bool b)
  {
    if (b)
      IdTable.inGrowing = &_inGrowing_safe;
    else
      IdTable.inGrowing = &_inGrowing_unsafe;
  }

  /++
    Returns the Identifier for idString.
    Adds idString to the table if not found.
  +/
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

  /++
    Returns the Identifier for idString.
    Adds idString to the table if not found.
    Access to the data structure is synchronized.
  +/
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
}

unittest
{
  // TODO: write benchmark.
  // Single table

  // Single table. synchronized

  // Two tables.

  // Two tables. synchronized
}
