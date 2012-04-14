/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.Tables;

import dil.lexer.Token,
       dil.lexer.IdTable,
       dil.lexer.Tables;
import dil.semantic.Types,
       dil.semantic.Symbols;
import common;

/// A collection of tables used by the Lexer and other classes.
class Tables
{
  LexerTables lxtables; /// Tables for the Lexer.
  TypeTable types; /// A table for D types.
  ClassTable classes; /// Special classes.
  IdTable idents; /// Alias to lxtables.idents.

  /// Contructs a Tables object.
  this(bool[cstring] options = null)
  {
    // TODO: options should probably be a class.
    this.lxtables = new LexerTables;
    this.types = new TypeTable();
    this.types.init(options);
    this.classes = new ClassTable();
    this.idents = this.lxtables.idents;
  }
}

/// A collection of special classes.
class ClassTable
{
  // Classes from object.d:
  ClassSymbol object; /// Class Object.
  ClassSymbol classInfo; /// Class ClassInfo.
  ClassSymbol moduleInfo; /// Class ModuleInfo.
  ClassSymbol exeption; /// Class Exeption.
  // Classes from runtime library files:
  ClassSymbol tinfo; /// Class TypeInfo.
  ClassSymbol tinfoArray; /// Class TypeInfo_Array.
  ClassSymbol tinfoAArray; /// Class TypeInfo_AssociativeArray.
  ClassSymbol tinfoClass; /// Class TypeInfo_Class.
  ClassSymbol tinfoDelegate; /// Class TypeInfo_Delegate.
  ClassSymbol tinfoEnum; /// Class TypeInfo_Enum.
  ClassSymbol tinfoFunction; /// Class TypeInfo_Function.
  ClassSymbol tinfoInterface; /// Class TypeInfo_Interface.
  ClassSymbol tinfoPointer; /// Class TypeInfo_Pointer.
  ClassSymbol tinfoSArray; /// Class TypeInfo_StaticArray.
  ClassSymbol tinfoStruct; /// Class TypeInfo_Struct.
  ClassSymbol tinfoTuple; /// Class TypeInfo_Tuple.
  ClassSymbol tinfoTypedef; /// Class TypeInfo_Typedef.
  // D2:
  ClassSymbol tinfoConst; /// Class TypeInfo_Const.
  ClassSymbol tinfoInvariant; /// Class TypeInfo_Invariant.
  ClassSymbol tinfoShared; /// Class TypeInfo_Shared.
}
