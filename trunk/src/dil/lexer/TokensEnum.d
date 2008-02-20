/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.lexer.TokensEnum;

import common;

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
  CharLiteral,

  // Special tokens
  FILE,
  LINE,
  DATE,
  TIME,
  TIMESTAMP,
  VENDOR,
  VERSION,

  // Number literals
  Int32, Int64, Uint32, Uint64,
  // Floating point number scanner relies on this order. (FloatXY + 3 == ImaginaryXY)
  Float32, Float64, Float80,
  Imaginary32, Imaginary64, Imaginary80,


  // Brackets
  LParen,
  RParen,
  LBracket,
  RBracket,
  LBrace,
  RBrace,

  Dot, Slice, Ellipses,

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
  Assign, Equal, NotEqual, Not,
  LessEqual, Less,
  GreaterEqual, Greater,
  LShiftAssign, LShift,
  RShiftAssign,RShift,
  URShiftAssign, URShift,
  OrAssign, OrLogical, OrBinary,
  AndAssign, AndLogical, AndBinary,
  PlusAssign, PlusPlus, Plus,
  MinusAssign, MinusMinus, Minus,
  DivAssign, Div,
  MulAssign, Mul,
  ModAssign, Mod,
  XorAssign, Xor,
  CatAssign,
  Tilde,

  Colon,
  Semicolon,
  Question,
  Comma,
  Dollar,

  /* Keywords:
     NB.: Token.isKeyword() depends on this list being contiguous.
  */
  Abstract, Alias, Align, Asm, Assert, Auto, Body,
  Break, Case, Cast, Catch,
  Class, Const, Continue,
  Debug, Default, Delegate, Delete, Deprecated, Do,
  Else, Enum, Export, Extern, False, Final,
  Finally, For, Foreach, Foreach_reverse, Function, Goto,
  If, Import, In, Inout,
  Interface, Invariant, Is, Lazy, Macro/+D2.0+/,
  Mixin, Module, New, Nothrow/+D2.0+/, Null, Out, Override, Package,
  Pragma, Private, Protected, Public, Pure/+D2.0+/, Ref, Return,
  Scope, Static, Struct, Super, Switch, Synchronized,
  Template, This, Throw, Traits/+D2.0+/, True, Try, Typedef, Typeid,
  Typeof, Union, Unittest,
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

/// A table mapping each TOK to a string.
const string[] tokToString = [
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
  "CharLiteral",

  "__FILE__",
  "__LINE__",
  "__DATE__",
  "__TIME__",
  "__TIMESTAMP__",
  "__VENDOR__",
  "__VERSION__",

  "Int32", "Int64", "Uint32", "Uint64",
  "Float32", "Float64", "Float80",
  "Imaginary32", "Imaginary64", "Imaginary80",

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

  "=", "==", "!=", "!",
  "<=", "<",
  ">=", ">",
  "<<=", "<<",
  ">>=",">>",
  ">>>=", ">>>",
  "|=", "||", "|",
  "&=", "&&", "&",
  "+=", "++", "+",
  "-=", "--", "-",
  "/=", "/",
  "*=", "*",
  "%=", "%",
  "^=", "^",
  "~=",
  "~",

  ":",
  ";",
  "?",
  ",",
  "$",

  "abstract","alias","align","asm","assert","auto","body",
  "break","case","cast","catch",
  "class","const","continue",
  "debug","default","delegate","delete","deprecated","do",
  "else","enum","export","extern","false","final",
  "finally","for","foreach","foreach_reverse","function","goto",
  "if","import","in","inout",
  "interface","invariant","is","lazy","macro",
  "mixin","module","new","nothrow","null","out","override","package",
  "pragma","private","protected","public","pure","ref","return",
  "scope","static","struct","super","switch","synchronized",
  "template","this","throw","__traits","true","try","typedef","typeid",
  "typeof","union","unittest",
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
