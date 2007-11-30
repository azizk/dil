/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Token;
import common;
import tango.stdc.stdlib : malloc, free;
import tango.core.Exception;

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

struct Token
{
  TOK type; /// The type of the token.
  /// Pointers to the next and previous tokens (doubly-linked list.)
  Token* next, prev;

  char* ws;    /// Start of whitespace characters before token. Null if no WS.
  char* start; /// Start of token in source text.
  char* end;   /// Points one past the end of token in source text.

  union
  {
    /// For newline tokens.
    struct
    {
      char[] filePath;
      uint lineNum;
      uint lineNum_hline;
    }
    /// For #line tokens.
    struct
    {
      Token* tokLineNum; /// #line number
      Token* tokLineFilespec; /// #line number filespec
    }
    /// For string tokens.
    struct
    {
      string str;
      char pf; /// Postfix 'c', 'w', 'd' or 0 for none.
    version(D2)
      Token* tok_str; /// Points to the contents of a token string stored as a
                      /// doubly linked list. The last token is always '}' or
                      /// EOF in case end of source text is "q{" EOF.
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

  /// Find next non-whitespace token. Returns 'this' token if the next token is TOK.EOF or null.
  Token* nextNWS()
  out(token)
  {
    assert(token !is null);
  }
  body
  {
    auto token = next;
    while (token !is null && token.isWhitespace)
      token = token.next;
    if (token is null || token.type == TOK.EOF)
      return this;
    return token;
  }

  /// Find previous non-whitespace token. Returns 'this' token if the previous token is TOK.HEAD or null.
  Token* prevNWS()
  out(token)
  {
    assert(token !is null);
  }
  body
  {
    auto token = prev;
    while (token !is null && token.isWhitespace)
      token = token.prev;
    if (token is null || token.type == TOK.HEAD)
      return this;
    return token;
  }

  static string toString(TOK tok)
  {
    return tokToString[tok];
  }

  /++
    Returns true if this is a token which can have newlines in it.
    These can be any string literal except for escape literals
    and block and nested comments.
  +/
  bool isMultiline()
  {
    return type == TOK.String && start[0] != '\\' ||
           type == TOK.Comment && start[1] != '/';
  }

  /// Returns true if this is a keyword token.
  bool isKeyword()
  {
    return KeywordsBegin <= type && type <= KeywordsEnd;
  }

  /// Returns true if this is a whitespace token.
  bool isWhitespace()
  {
    return !!(type & TOK.Whitespace);
  }

  /// Returns true if this is a special token.
  bool isSpecialToken()
  {
    return *start == '_' && type != TOK.Identifier;
  }

version(D2)
{
  /// Returns true if this is a token string literal.
  bool isTokenStringLiteral()
  {
    return type == TOK.String && tok_str !is null;
  }
}

  int opEquals(TOK type2)
  {
    return type == type2;
  }

  new(size_t size)
  {
    void* p = malloc(size);
    if (p is null)
      throw new OutOfMemoryException(__FILE__, __LINE__);
    *cast(Token*)p = Token.init;
    return p;
  }

  delete(void* p)
  {
    auto token = cast(Token*)p;
    if (token)
    {
      if(token.type == TOK.HashLine)
        token.destructHashLineToken();
      else
      {
      version(D2)
        if (token.isTokenStringLiteral)
          token.destructTokenStringLiteral();
      }
    }
    free(p);
  }

  void destructHashLineToken()
  {
    assert(type == TOK.HashLine);
    delete tokLineNum;
    delete tokLineFilespec;
  }

version(D2)
{
  void destructTokenStringLiteral()
  {
    assert(type == TOK.String);
    assert(start && *start == 'q' && start[1] == '{');
    assert(tok_str !is null);
    auto tok_it = tok_str;
    auto tok_del = tok_str;
    while (tok_it && tok_it.type != TOK.EOF)
    {
      tok_it = tok_it.next;
      assert(tok_del && tok_del.type != TOK.EOF);
      delete tok_del;
      tok_del = tok_it;
    }
  }
}
}

/// A table mapping each TOK to a string.
private const string[] tokToString = [
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
