/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.Tables;

import dil.lexer.Token,
       dil.lexer.IdTable,
       dil.lexer.Tables;
import dil.ast.Declarations;
import dil.semantic.Types,
       dil.semantic.Symbols,
       dil.semantic.Module;
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
  ClassSymbol throwable; /// Class Throwable.
  ClassSymbol exeption; /// Class Exeption.
  ClassSymbol error; /// Class Error.
  // Classes from runtime library files:
  ClassSymbol tinfo; /// Class TypeInfo.
  ClassSymbol tinfoPointer; /// Class TypeInfo_Pointer.
  ClassSymbol tinfoArray; /// Class TypeInfo_Array.
  ClassSymbol tinfoSArray; /// Class TypeInfo_StaticArray.
  ClassSymbol tinfoAArray; /// Class TypeInfo_AssociativeArray.
  ClassSymbol tinfoFunction; /// Class TypeInfo_Function.
  ClassSymbol tinfoDelegate; /// Class TypeInfo_Delegate.
  ClassSymbol tinfoEnum; /// Class TypeInfo_Enum.
  ClassSymbol tinfoClass; /// Class TypeInfo_Class.
  ClassSymbol tinfoInterface; /// Class TypeInfo_Interface.
  ClassSymbol tinfoStruct; /// Class TypeInfo_Struct.
  ClassSymbol tinfoTuple; /// Class TypeInfo_Tuple.
  ClassSymbol tinfoTypedef; /// Class TypeInfo_Typedef.
  // D2:
  ClassSymbol tinfoVector; /// Class TypeInfo_Vector.
  ClassSymbol tinfoConst; /// Class TypeInfo_Const.
  ClassSymbol tinfoImmutable; /// Class TypeInfo_Invariant.
  ClassSymbol tinfoShared; /// Class TypeInfo_Shared.
  ClassSymbol tinfoInout; /// Class TypeInfo_Inout.

  /// If d.symbol is a special class, it is stored in this table
  /// and a SpecialClassSymbol is assigned to it.
  void lookForSpecialClasses(Module modul, ClassDecl d,
    void delegate(Token* name, cstring format, ...) error)
  {
    ClassSymbol s = d.symbol;
    ClassSymbol* ps; /// Assigned to, if special class.
    auto name = s.name;

    if (name is Ident.Sizeof  ||
        name is Ident.Alignof ||
        name is Ident.Mangleof)
      error(d.name, "the class name ‘{}’ is not allowed", name.str);
    else if (name.startsWith("TypeInfo"))
    {
      switch (name.idKind)
      {
      case IDK.TypeInfo:                  ps = &tinfo;          break;
      case IDK.TypeInfo_Pointer:          ps = &tinfoPointer;   break;
      case IDK.TypeInfo_Array:            ps = &tinfoArray;     break;
      case IDK.TypeInfo_StaticArray:      ps = &tinfoSArray;    break;
      case IDK.TypeInfo_AssociativeArray: ps = &tinfoAArray;    break;
      case IDK.TypeInfo_Function:         ps = &tinfoFunction;  break;
      case IDK.TypeInfo_Delegate:         ps = &tinfoDelegate;  break;
      case IDK.TypeInfo_Enum:             ps = &tinfoEnum;      break;
      case IDK.TypeInfo_Class:            ps = &tinfoClass;     break;
      case IDK.TypeInfo_Interface:        ps = &tinfoInterface; break;
      case IDK.TypeInfo_Struct:           ps = &tinfoStruct;    break;
      case IDK.TypeInfo_Tuple:            ps = &tinfoTuple;     break;
      case IDK.TypeInfo_Typedef:          ps = &tinfoTypedef;   break;
      version(D2)
      {
      case IDK.TypeInfo_Vector:           ps = &tinfoVector;    break;
      case IDK.TypeInfo_Const:            ps = &tinfoConst;     break;
      case IDK.TypeInfo_Invariant:        ps = &tinfoImmutable; break;
      case IDK.TypeInfo_Shared:           ps = &tinfoShared;    break;
      case IDK.TypeInfo_Inout:            ps = &tinfoInout;     break;
      } //version(D2)
      default:
      }
    }
    else
    if (modul.name is Ident.object && modul.parent.parent is null)
    { // If object.d module and if in root package.
      if (name is Ident.Object)
        ps = &object;
      else if (name is Ident.ClassInfo)
        ps = &classInfo;
      else if (name is Ident.ModuleInfo)
        ps = &moduleInfo;
      else if (name is Ident.Throwable)
        ps = &throwable;
      else if (name is Ident.Exception)
        ps = &exeption;
      else if (name is Ident.Error)
        ps = &this.error;
    }

    if (ps)
    {
      if (*ps !is null)
        error(d.name,
          "special class ‘{}’ already defined at ‘{}’",
          name.str, (*ps).node.begin.getErrorLocation(modul.filePath()).repr());
      else // Convert to SpecialClassSymbol, as it handles mangling differently.
        d.symbol = *ps = new SpecialClassSymbol(s.name, s.node);
    }
  }
}
