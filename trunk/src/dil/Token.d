/++
  Author: Aziz Köksal
  License: GPL3
+/
module Token;
import std.c.stdlib : malloc, free;
import std.outofmemory;

struct Position
{
  size_t loc;
  size_t col;
}

enum TOK : ushort
{
  Invalid,

  /// Flag for whitespace tokens that must be ignored in the parsing phase.
  Whitespace = 0x8000,
  Comment = 1 | Whitespace,
  Shebang = 2 | Whitespace,
  HashLine = 3 | Whitespace,
  Filespec = 4 | Whitespace,

  Identifier = 5,
  String,
  Special,
  CharLiteral, WCharLiteral, DCharLiteral,

  // Numbers
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
  EOF
}

alias TOK.Abstract KeywordsBegin;
alias TOK.With KeywordsEnd;

struct Token
{
  TOK type;
//   Position pos;

  Token* next, prev;

  char* start;
  char* end;

  union
  {
    struct
    {
      Token* line_num; // #line number
      Token* line_filespec; // #line number filespec
    }
    struct
    {
      string str;
      char pf;
    }
    dchar  dchar_;
    long   long_;
    ulong  ulong_;
    int    int_;
    uint   uint_;
    float  float_;
    double double_;
    real   real_;
  }

  alias srcText identifier;

  string srcText()
  {
    assert(start && end);
    return start[0 .. end - start];
  }

  static string toString(TOK tok)
  {
    return tokToString[tok];
  }

  bool isKeyword()
  {
    return KeywordsBegin <= type && type <= KeywordsEnd;
  }

  bool isWhitespace()
  {
    return !!(type & TOK.Whitespace);
  }

  int opEquals(TOK type2)
  {
    return type == type2;
  }

  new(size_t size)
  {
    void* p = malloc(size);
    if (p is null)
      throw new OutOfMemoryException();
    *cast(Token*)p = Token.init;
    return p;
  }

  delete(void* p)
  {
    free(p);
  }
}

string[] tokToString = [
  "Invalid",

  "Comment",
  "#! /shebang/",
  "#line",

  "Identifier",
  "String",
  "Special",
  "CharLiteral", "WCharLiteral", "DCharLiteral",

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

  "Unordered",
  "UorE",
  "UorG",
  "UorGorE",
  "UorL",
  "UorLorE",
  "LorEorG",
  "LorG",

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
  "template","this","throw","true","try","typedef","typeid",
  "typeof","ubyte","ucent","uint","ulong","union","unittest",
  "ushort","version","void","volatile","wchar","while","with",

  "EOF"
];
