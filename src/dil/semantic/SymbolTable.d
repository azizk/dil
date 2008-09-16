/// Author: Aziz Köksal
/// License: GPL3
module dil.semantic.SymbolTable;

import dil.semantic.Symbol;
import dil.lexer.Identifier;
import common;

/// Maps an identifier string to a Symbol.
struct SymbolTable
{
  Symbol[char[]] table; /// The table data structure.

  /// Looks up ident in the table.
  /// Returns: the symbol if there, otherwise null.
  Symbol lookup(Identifier* ident)
  {
    assert(ident !is null);
    auto psym = ident.str in table;
    return psym ? *psym : null;
  }

  /// Inserts a symbol into the table.
  void insert(Symbol symbol, Identifier* ident)
  {
    table[ident.str] = symbol;
  }
}
