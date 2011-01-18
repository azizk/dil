/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.lexer.Keywords;

import dil.lexer.Token,
       dil.lexer.Identifier;

struct Keyword
{
static const:
  Identifier[] list = [
    {"__gshared", TOK.Gshared}, // D2.0
    {"__overloadset", TOK.OverloadSet}, // D2.0
    {"__thread", TOK.Thread}, // D2.0
    {"__traits", TOK.Traits}, // D2.0
    {"abstract", TOK.Abstract},
    {"alias", TOK.Alias},
    {"align", TOK.Align},
    {"asm", TOK.Asm},
    {"assert", TOK.Assert},
    {"auto", TOK.Auto},
    {"body", TOK.Body},
    {"bool", TOK.Bool},
    {"break", TOK.Break},
    {"byte", TOK.Byte},
    {"case", TOK.Case},
    {"cast", TOK.Cast},
    {"catch", TOK.Catch},
    {"cdouble", TOK.Cdouble},
    {"cent", TOK.Cent},
    {"cfloat", TOK.Cfloat},
    {"char", TOK.Char},
    {"class", TOK.Class},
    {"const", TOK.Const},
    {"continue", TOK.Continue},
    {"creal", TOK.Creal},
    {"dchar", TOK.Dchar},
    {"debug", TOK.Debug},
    {"default", TOK.Default},
    {"delegate", TOK.Delegate},
    {"delete", TOK.Delete},
    {"deprecated", TOK.Deprecated},
    {"do", TOK.Do},
    {"double", TOK.Double},
    {"else", TOK.Else},
    {"enum", TOK.Enum},
    {"export", TOK.Export},
    {"extern", TOK.Extern},
    {"false", TOK.False},
    {"final", TOK.Final},
    {"finally", TOK.Finally},
    {"float", TOK.Float},
    {"for", TOK.For},
    {"foreach", TOK.Foreach},
    {"foreach_reverse", TOK.ForeachReverse},
    {"function", TOK.Function},
    {"goto", TOK.Goto},
    {"idouble", TOK.Idouble},
    {"if", TOK.If},
    {"ifloat", TOK.Ifloat},
    {"immutable", TOK.Immutable}, // D2.0
    {"import", TOK.Import},
    {"in", TOK.In},
    {"inout", TOK.Inout},
    {"int", TOK.Int},
    {"interface", TOK.Interface},
    {"invariant", TOK.Invariant},
    {"ireal", TOK.Ireal},
    {"is", TOK.Is},
    {"lazy", TOK.Lazy},
    {"long", TOK.Long},
    {"macro", TOK.Macro}, // D2.0
    {"mixin", TOK.Mixin},
    {"module", TOK.Module},
    {"new", TOK.New},
    {"nothrow", TOK.Nothrow}, // D2.0
    {"null", TOK.Null},
    {"out", TOK.Out},
    {"override", TOK.Override},
    {"package", TOK.Package},
    {"pragma", TOK.Pragma},
    {"private", TOK.Private},
    {"protected", TOK.Protected},
    {"public", TOK.Public},
    {"pure", TOK.Pure}, // D2.0
    {"real", TOK.Real},
    {"ref", TOK.Ref},
    {"return", TOK.Return},
    {"scope", TOK.Scope},
    {"shared", TOK.Shared}, // D2.0
    {"short", TOK.Short},
    {"static", TOK.Static},
    {"struct", TOK.Struct},
    {"super", TOK.Super},
    {"switch", TOK.Switch},
    {"synchronized", TOK.Synchronized},
    {"template", TOK.Template},
    {"this", TOK.This},
    {"throw", TOK.Throw},
    {"true", TOK.True},
    {"try", TOK.Try},
    {"typedef", TOK.Typedef},
    {"typeid", TOK.Typeid},
    {"typeof", TOK.Typeof},
    {"ubyte", TOK.Ubyte},
    {"ucent", TOK.Ucent},
    {"uint", TOK.Uint},
    {"ulong", TOK.Ulong},
    {"union", TOK.Union},
    {"unittest", TOK.Unittest},
    {"ushort", TOK.Ushort},
    {"version", TOK.Version},
    {"void", TOK.Void},
    {"volatile", TOK.Volatile},
    {"wchar", TOK.Wchar},
    {"while", TOK.While},
    {"with", TOK.With},
    // Special tokens:
    {"__FILE__", TOK.FILE},
    {"__LINE__", TOK.LINE},
    {"__DATE__", TOK.DATE},
    {"__TIME__", TOK.TIME},
    {"__TIMESTAMP__", TOK.TIMESTAMP},
    {"__VENDOR__", TOK.VENDOR},
    {"__VERSION__", TOK.VERSION},
    {"__EOF__", TOK.EOF}, // D2.0
  ];


  Identifier* Gshared; // D2.0
  Identifier* OverloadSet; // D2.0
  Identifier* Thread; // D2.0
  Identifier* Traits; // D2.0
  Identifier* Abstract;
  Identifier* Alias;
  Identifier* Align;
  Identifier* Asm;
  Identifier* Assert;
  Identifier* Auto;
  Identifier* Body;
  Identifier* Bool;
  Identifier* Break;
  Identifier* Byte;
  Identifier* Case;
  Identifier* Cast;
  Identifier* Catch;
  Identifier* Cdouble;
  Identifier* Cent;
  Identifier* Cfloat;
  Identifier* Char;
  Identifier* Class;
  Identifier* Const;
  Identifier* Continue;
  Identifier* Creal;
  Identifier* Dchar;
  Identifier* Debug;
  Identifier* Default;
  Identifier* Delegate;
  Identifier* Delete;
  Identifier* Deprecated;
  Identifier* Do;
  Identifier* Double;
  Identifier* Else;
  Identifier* Enum;
  Identifier* Export;
  Identifier* Extern;
  Identifier* False;
  Identifier* Final;
  Identifier* Finally;
  Identifier* Float;
  Identifier* For;
  Identifier* Foreach;
  Identifier* ForeachReverse;
  Identifier* Function;
  Identifier* Goto;
  Identifier* Idouble;
  Identifier* If;
  Identifier* Ifloat;
  Identifier* Immutable; // D2.0
  Identifier* Import;
  Identifier* In;
  Identifier* Inout;
  Identifier* Int;
  Identifier* Interface;
  Identifier* Invariant;
  Identifier* Ireal;
  Identifier* Is;
  Identifier* Lazy;
  Identifier* Long;
  Identifier* Macro; // D2.0
  Identifier* Mixin;
  Identifier* Module;
  Identifier* New;
  Identifier* Nothrow; // D2.0
  Identifier* Null;
  Identifier* Out;
  Identifier* Override;
  Identifier* Package;
  Identifier* Pragma;
  Identifier* Private;
  Identifier* Protected;
  Identifier* Public;
  Identifier* Pure; // D2.0
  Identifier* Real;
  Identifier* Ref;
  Identifier* Return;
  Identifier* Scope;
  Identifier* Shared; // D2.0
  Identifier* Short;
  Identifier* Static;
  Identifier* Struct;
  Identifier* Super;
  Identifier* Switch;
  Identifier* Synchronized;
  Identifier* Template;
  Identifier* This;
  Identifier* Throw;
  Identifier* True;
  Identifier* Try;
  Identifier* Typedef;
  Identifier* Typeid;
  Identifier* Typeof;
  Identifier* Ubyte;
  Identifier* Ucent;
  Identifier* Uint;
  Identifier* Ulong;
  Identifier* Union;
  Identifier* Unittest;
  Identifier* Ushort;
  Identifier* Version;
  Identifier* Void;
  Identifier* Volatile;
  Identifier* Wchar;
  Identifier* While;
  Identifier* With;
  Identifier* FILE;
  Identifier* LINE;
  Identifier* DATE;
  Identifier* TIME;
  Identifier* TIMESTAMP;
  Identifier* VENDOR;
  Identifier* VERSION;
  Identifier* EOF; // D2.0

  alias Gshared first;
  alias EOF last;
}

/// Initializes the members of Keyword.
/// NB: This function would be unnecessary if DMD supported this:
/// ---
/// static const Identifier[] list = [
///   {"__gshared", TOK.Gshared}, ...
/// ];
/// // Error: non-constant expression &(Identifier("__gshared",cast(TOK)cast(ushort)121u))
/// static const Identifier* Gshared = &list[0];
/// ---
static this()
{
  auto pIdent = Keyword.list.ptr; // Init with first element.
  auto pMember = &Keyword.first; // Init with address of the first member.
  for (auto i=Keyword.list.length; i; --i)
    *pMember++ = pIdent++; // Init members with the Identifiers.
}
