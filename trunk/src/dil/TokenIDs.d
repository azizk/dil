/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.TokenIDs;
import common;

enum TOK : ushort
{
  Invalid,

  /// Flag for whitespace tokens that must be ignored in the parsing phase.
  Whitespace = 0x8000,
  Illegal  = 1 | Whitespace,
  Comment  = 2 | Whitespace,
  Shebang  = 3 | Whitespace,
  HashLine = 4 | Whitespace,
  Filespec = 5 | Whitespace,
  Newline  = 6 | Whitespace,
  Empty    = 7,

  Identifier = 8,
  String,
  CharLiteral, WCharLiteral, DCharLiteral,

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
  CatAssign, Catenate,
  Tilde,
  Identity, NotIdentity,

  Colon,
  Semicolon,
  Question,
  Comma,
  Dollar,

  /* Keywords:
     NB.: Token.isKeyword() depends on this list being contiguous.
  */
  Abstract,Alias,Align,Asm,Assert,Auto,Body,
  Bool,Break,Byte,Case,Cast,Catch,Cdouble,
  Cent,Cfloat,Char,Class,Const,Continue,Creal,
  Dchar,Debug,Default,Delegate,Delete,Deprecated,Do,
  Double,Else,Enum,Export,Extern,False,Final,
  Finally,Float,For,Foreach,Foreach_reverse,Function,Goto,
  Idouble,If,Ifloat,Import,In,Inout,Int,
  Interface,Invariant,Ireal,Is,Lazy,Long,Macro/+D2.0+/,
  Mixin,Module,New,Null,Out,Override,Package,
  Pragma,Private,Protected,Public,Real,Ref/+D2.0+/,Return,
  Scope,Short,Static,Struct,Super,Switch,Synchronized,
  Template,This,Throw,Traits/+D2.0+/,True,Try,Typedef,Typeid,
  Typeof,Ubyte,Ucent,Uint,Ulong,Union,Unittest,
  Ushort,Version,Void,Volatile,Wchar,While,With,

  HEAD, // start of linked list
  EOF,
  MAX
}

alias TOK.Abstract KeywordsBegin;
alias TOK.With KeywordsEnd;
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
  "CharLiteral", "WCharLiteral", "DCharLiteral",

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
  "~=", "~",
  "~",
  "is", "!is",

  ":",
  ";",
  "?",
  ",",
  "$",

  "abstract","alias","align","asm","assert","auto","body",
  "bool","break","byte","case","cast","catch","cdouble",
  "cent","cfloat","char","class","const","continue","creal",
  "dchar","debug","default","delegate","delete","deprecated","do",
  "double","else","enum","export","extern","false","final",
  "finally","float","for","foreach","foreach_reverse","function","goto",
  "idouble","if","ifloat","import","in","inout","int",
  "interface","invariant","ireal","is","lazy","long","macro",
  "mixin","module","new","null","out","override","package",
  "pragma","private","protected","public","real","ref","return",
  "scope","short","static","struct","super","switch","synchronized",
  "template","this","throw","__traits","true","try","typedef","typeid",
  "typeof","ubyte","ucent","uint","ulong","union","unittest",
  "ushort","version","void","volatile","wchar","while","with",

  "HEAD",
  "EOF"
];
static assert(tokToString.length == TOK.MAX);
