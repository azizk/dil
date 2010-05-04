/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.semantic.SymbolTable;

import dil.semantic.Symbol,
       dil.lexer.Identifier,
       dil.lexer.Funcs : hashOf;
import common;

/// Maps an identifier string to a Symbol.
struct SymbolTable
{
  Symbol[hash_t] table; /// The table data structure.

  /// Looks up ident in the table.
  /// Returns: the symbol if there, otherwise null.
  Symbol lookup(Identifier* ident)
  {
    assert(ident !is null);
    auto psym = hashOf(ident.str) in table;
    return psym ? *psym : null;
  }

  /// Inserts a symbol into the table.
  void insert(Symbol symbol, Identifier* ident)
  {
    table[hashOf(ident.str)] = symbol;
  }
}
