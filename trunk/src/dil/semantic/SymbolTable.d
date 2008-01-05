/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.SymbolTable;

import dil.semantic.Symbol;
import dil.lexer.Identifier;
import common;

/++
  Maps an identifier string to a Symbol.
+/
struct SymbolTable
{
  Symbol[char[]] table;

  /// Look up ident in the table.
  Symbol lookup(Identifier* ident)
  {
    assert(ident !is null);
    auto psym = ident.str in table;
    return psym ? *psym : null;
  }

  void insert(Symbol s, Identifier* ident)
  {
    table[ident.str] = s;
  }
}
