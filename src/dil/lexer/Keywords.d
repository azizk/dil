/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.lexer.Keywords;

import dil.lexer.Token,
       dil.lexer.Identifier,
       dil.lexer.IdentsGenerator;

struct Keyword
{
static:
  enum string[] list = [
    "Gshared:__gshared", // D2.0
    "OverloadSet:__overloadset", // D2.0
    "Thread:__thread", // D2.0
    "Traits:__traits", // D2.0
    "Vector:__vector", // D2.0
    "Abstract:abstract",
    "Alias:alias",
    "Align:align",
    "Asm:asm",
    "Assert:assert",
    "Auto:auto",
    "Body:body",
    "Bool:bool",
    "Break:break",
    "Byte:byte",
    "Case:case",
    "Cast:cast",
    "Catch:catch",
    "Cdouble:cdouble",
    "Cent:cent",
    "Cfloat:cfloat",
    "Char:char",
    "Class:class",
    "Const:const",
    "Continue:continue",
    "Creal:creal",
    "Dchar:dchar",
    "Debug:debug",
    "Default:default",
    "Delegate:delegate",
    "Delete:delete",
    "Deprecated:deprecated",
    "Do:do",
    "Double:double",
    "Else:else",
    "Enum:enum",
    "Export:export",
    "Extern:extern",
    "False:false",
    "Final:final",
    "Finally:finally",
    "Float:float",
    "For:for",
    "Foreach:foreach",
    "ForeachReverse:foreach_reverse",
    "Function:function",
    "Goto:goto",
    "Idouble:idouble",
    "If:if",
    "Ifloat:ifloat",
    "Immutable:immutable", // D2.0
    "Import:import",
    "In:in",
    "Inout:inout",
    "Int:int",
    "Interface:interface",
    "Invariant:invariant",
    "Ireal:ireal",
    "Is:is",
    "Lazy:lazy",
    "Long:long",
    "Macro:macro", // D2.0
    "Mixin:mixin",
    "Module:module",
    "New:new",
    "Nothrow:nothrow", // D2.0
    "Null:null",
    "Out:out",
    "Override:override",
    "Package:package",
    "Pragma:pragma",
    "Private:private",
    "Protected:protected",
    "Public:public",
    "Pure:pure", // D2.0
    "Real:real",
    "Ref:ref",
    "Return:return",
    "Scope:scope",
    "Shared:shared", // D2.0
    "Short:short",
    "Static:static",
    "Struct:struct",
    "Super:super",
    "Switch:switch",
    "Synchronized:synchronized",
    "Template:template",
    "This:this",
    "Throw:throw",
    "True:true",
    "Try:try",
    "Typedef:typedef",
    "Typeid:typeid",
    "Typeof:typeof",
    "Ubyte:ubyte",
    "Ucent:ucent",
    "Uint:uint",
    "Ulong:ulong",
    "Union:union",
    "Unittest:unittest",
    "Ushort:ushort",
    "Version:version",
    "Void:void",
    "Volatile:volatile",
    "Wchar:wchar",
    "While:while",
    "Wild:wild", // D2.0
    "With:with",
    // Special tokens:
    "FILE:__FILE__",
    "LINE:__LINE__",
    "DATE:__DATE__",
    "TIME:__TIME__",
    "TIMESTAMP:__TIMESTAMP__",
    "VENDOR:__VENDOR__",
    "VERSION:__VERSION__",
    "EOF:__EOF__", // D2.0
  ];

  mixin(generateIdentMembers(list, true));

  /// Returns an array of all keywords.
  Identifier*[] allIds()
  { // "Gshared" is the first Identifier in the list.
    return (&Gshared)[0..list.length];
  }
}

// pragma(msg, generateIdentMembers(Keyword.list, true));
