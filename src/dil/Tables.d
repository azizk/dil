/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.Tables;

import dil.lexer.Token;
import dil.lexer.IdTable;
import dil.semantic.Types,
       dil.semantic.Symbols;
import dil.Float;
import common;

/// A collection of tables used by the Lexer and other classes.
class Tables
{
  /// Contructs a Tables object.
  this()
  {
    idents = new IdTable();
    types = new TypeTable();
    classes = new ClassTable();
  }

  alias Token.StringValue StringValue;
  alias Token.IntegerValue IntegerValue;
  alias Token.NewlineValue NewlineValue;

  TypeTable types; /// A table for D types.
  ClassTable classes; /// Special classes.

  // A collection of tables for various token values.
  IdTable idents;
  string[hash_t] strings; /// Maps strings to their zero-terminated equivalent.
  StringValue*[hash_t] strvals; /// Maps string+postfix to string values.
  Float[hash_t] floats; /// Maps float strings to Float values.
  IntegerValue*[ulong] ulongs; /// Maps a ulong to an IntegerValue.
  /// A list of newline values.
  /// Only instances, where 'hlinfo' is null, are kept here.
  NewlineValue*[] newlines;

  /// Looks up an identifier.
  Identifier* lookupIdentifier(string str)
  {
    return idents.lookup(str);
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
