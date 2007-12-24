/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.SymbolTable;

import dil.Symbol;
import dil.Identifier;
import common;

/++
  Maps an identifier string to a Symbol.
+/
class SymbolTable
{
  protected Symbol[char[]] table;

  /// Look up ident in the table.
  Symbol lookup(Identifier* ident)
  {
    assert(ident !is null);
    auto psym = ident.str in table;
    return psym ? *psym : null;
  }
}
