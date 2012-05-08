/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.lexer.TokensEnum;

import common;

/// Enumeration of token kinds.
enum TOK : ushort
{
  Invalid,

  Illegal,
  Comment,
  Shebang,
  HashLine,
  Filespec,
  Newline,
  Empty,

  Identifier,
  String,
  Character,

  // Special tokens
  FILE,
  LINE,
  DATE,
  TIME,
  TIMESTAMP,
  VENDOR,
  VERSION,

  // Number literals
  Int32, Int64, UInt32, UInt64,
  // Floating point number scanner relies on this order.
  // FloatXY + 3 == IFloatXY
  Float32, Float64, Float80,
  IFloat32, IFloat64, IFloat80,


  // Brackets
  LParen,
  RParen,
  LBracket,
  RBracket,
  LBrace,
  RBrace,

  // Dots
  Dot, Dot2, Dot3,

  // Floating point number operators
  Unordered,
  UorE,
  UorG,
  UorGorE,
  UorL,
  UorLorE,
  LorEorG,
  LorG,

  // Normal operators
  Equal,    Equal2,      EqlGreater,
  Exclaim,  ExclaimEql,
  Less,     LessEql,
  Greater,  GreaterEql,
  Less2,    Less2Eql,
  Greater2, Greater2Eql,
  Greater3, Greater3Eql,
  Pipe,     PipeEql,     Pipe2,
  Amp,      AmpEql,      Amp2,
  Plus,     PlusEql,     Plus2,
  Minus,    MinusEql,    Minus2,
  Slash,    SlashEql,
  Star,     StarEql,
  Percent,  PercentEql,
  Caret,    CaretEql,
  Caret2,   Caret2Eql,
  Tilde,    TildeEql,

  Colon,
  Semicolon,
  Question,
  Comma,
  Dollar,
  At,

  /* Keywords:
     NB.: Token.isKeyword() depends on this list being contiguous.
  */
  Abstract, Alias, Align, Asm, Assert, Auto, Body,
  Break, Case, Cast, Catch,
  Class, Const, Continue,
  Debug, Default, Delegate, Delete, Deprecated, Do,
  Else, Enum, Export, Extern, False, Final,
  Finally, For, Foreach, ForeachReverse, Function, Goto, Gshared/+D2.0+/,
  If, Immutable/+D2.0+/, Import, In, Inout,
  Interface, Invariant, Is, Lazy, Macro/+D2.0+/,
  Mixin, Module, New, Nothrow/+D2.0+/, Null,
  Out, OverloadSet/+D2.0+/, Override, Package,
  Pragma, Private, Protected, Public, Pure/+D2.0+/, Ref, Return,
  Shared/+D2.0+/, Scope, Static, Struct, Super, Switch, Synchronized,
  Template, This, Thread/+D2.0+/, Throw, Traits/+D2.0+/, True, Try, Typedef, Typeid,
  Typeof, Union, Unittest, Vector/*D2.0*/,
  Version, Volatile, While, With,
  // Integral types.
  Char,   Wchar,   Dchar, Bool,
  Byte,   Ubyte,   Short, Ushort,
  Int,    Uint,    Long,  Ulong,
  Cent,   Ucent,
  Float,  Double,  Real,
  Ifloat, Idouble, Ireal,
  Cfloat, Cdouble, Creal, Void,

  HEAD, // start of linked list
  EOF,
  MAX
}

alias TOK.Abstract KeywordsBegin;
alias TOK.Void KeywordsEnd;
alias TOK.Char IntegralTypeBegin;
alias TOK.Void IntegralTypeEnd;
alias TOK.FILE SpecialTokensBegin;
alias TOK.VERSION SpecialTokensEnd;

/// A table that maps each token kind to a string.
const string[TOK.MAX] tokToString = [
  "Invalid",

  "Illegal",
  "Comment",
  "#! /shebang/",
  "#line",
  `"filespec"`,
  "Newline",
  "Empty",

  "Identifier",
  "String",
  "Character",

  "__FILE__",
  "__LINE__",
  "__DATE__",
  "__TIME__",
  "__TIMESTAMP__",
  "__VENDOR__",
  "__VERSION__",

  "Int32", "Int64", "UInt32", "UInt64",
  "Float32", "Float64", "Float80",
  "IFloat32", "IFloat64", "IFloat80",

  "(",
  ")",
  "[",
  "]",
  "{",
  "}",

  ".", "..", "...",

  "!<>=", // Unordered
  "!<>",  // UorE
  "!<=",  // UorG
  "!<",   // UorGorE
  "!>=",  // UorL
  "!>",   // UorLorE
  "<>=",  // LorEorG
  "<>",   // LorG

  "=",   "==", "=>",
  "!",   "!=",
  "<",   "<=",
  ">",   ">=",
  "<<",  "<<=",
  ">>",  ">>=",
  ">>>", ">>>=",
  "|",   "|=", "||",
  "&",   "&=", "&&",
  "+",   "+=", "++",
  "-",   "-=", "--",
  "/",   "/=",
  "*",   "*=",
  "%",   "%=",
  "^",   "^=",
  "^^",  "^^=",
  "~",   "~=",

  ":",
  ";",
  "?",
  ",",
  "$",
  "@",

  "abstract","alias","align","asm","assert","auto","body",
  "break","case","cast","catch",
  "class","const","continue",
  "debug","default","delegate","delete","deprecated","do",
  "else","enum","export","extern","false","final",
  "finally","for","foreach","foreach_reverse","function","goto","__gshared",
  "if","immutable","import","in","inout",
  "interface","invariant","is","lazy","macro",
  "mixin","module","new","nothrow","null",
  "out","__overloadset","override","package",
  "pragma","private","protected","public","pure","ref","return",
  "shared","scope","static","struct","super","switch","synchronized",
  "template","this","__thread","throw","__traits","true","try","typedef",
  "typeid","typeof","union","unittest","__vector",
  "version","volatile","while","with",
  // Integral types.
  "char",   "wchar",   "dchar", "bool",
  "byte",   "ubyte",   "short", "ushort",
  "int",    "uint",    "long",  "ulong",
  "cent",   "ucent",
  "float",  "double",  "real",
  "ifloat", "idouble", "ireal",
  "cfloat", "cdouble", "creal", "void",

  "HEAD",
  "EOF"
];
static assert(tokToString.length == TOK.EOF+1);
