/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.IdTable;
import dil.Identifier;
import dil.IdentsEnum;
import dil.TokensEnum;
import dil.IdentsGenerator;
import dil.Keywords;
import common;

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

  /++
    Returns the Identifier for idString.
    Adds idString to the table if not found.
    Access to the data structure is synchronized.
  +/
  Identifier* inGrowing(string idString)
  out(id)
  { assert(id !is null); }
  body
  {
    synchronized
    {
      auto id = idString in growingTable;
      if (id)
        return *id;
      auto newID = Identifier(idString, TOK.Identifier);
      growingTable[idString] = newID;
      return newID;
    }
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
