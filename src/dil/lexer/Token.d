/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.lexer.Token;

import dil.lexer.Identifier,
       dil.lexer.Funcs;
import dil.Location;
import dil.Float : Float;
import common;

import tango.stdc.stdlib : malloc, free;
import tango.core.Exception;

public import dil.lexer.TokensEnum;

/// A Token is a sequence of characters recognized by the lexical analyzer.
///
/// Example:
/// $(PRE ‘    StringValue’
//// ^$(Token ws, ws) ^$(Token start, start)     ^$(Token end, end)
///
///$(Token kind, kind)  = TOK.Identifier
///$(Token flags, flags) = Flags.None
///$(Token union.ident, ident) = $(Identifier)("StringValue", kind))
/// Macros:
///   Token = $(SYMLINK Token.$1, $2)
///   Identifier = $(SYMLINK2 dil.lexer.Identifier, Identifier, Identifier)
struct Token
{ /// Flags set by the Lexer.
  enum Flags : ushort
  {
    None, /// No flags set.
    Whitespace = 1, /// Tokens with this flag are ignored by the Parser.
  }

  TOK kind; /// The token kind.
  Flags flags; /// The flags of the token.
  /// Pointers to the next and previous tokens (doubly-linked list.)
  Token* next, prev;

  /// Start of whitespace characters before token. Null if no WS.
  char* ws;
  char* start; /// Points to the first character of the token.
  char* end;   /// Points one character past the end of the token.

  /// Represents the string value of a string literal.
  struct StringValue
  {
    string str; /// Zero-terminated string. The length includes '\0'.
    char pf = 0;    /// Postfix: 'c', 'w', 'd'. '\0' for none.
    version(D2)
    Token* tok_str; /// Points to the contents of a token string stored as a
                    /// doubly linked list. The last token is always '}' or
                    /// EOF in case the string is not closed properly.
  }

  /// Represents the long/ulong value of a number literal.
  union IntegerValue
  {
    long  long_;  /// A long integer value.
    ulong ulong_; /// An unsigned long integer value.
  }

  /// Represents the data of a newline token.
  struct NewlineValue
  {
    uint lineNum; /// The line number in the source text.
    HashLineInfo* hlinfo; /// Info from a "#line" token.
  }

  /// Represents the value of a "#line Number Filespec?" token.
  struct HashLineValue
  {
    Token* lineNum; /// The Number.
    Token* filespec; /// The optional Filespec.
  }

  /// Represents the info of a #line token. Used for error messages.
  struct HashLineInfo
  {
    uint lineNum; /// Delta line number calculated from #line Number.
    string path;  /// File path set by #line num Filespec.
    /// Calculates and returns the line number.
    uint getLineNum(uint realnum)
    {
      return realnum - lineNum;
    }
    /// Calculates a delta value and sets 'lineNum'.
    void setLineNum(uint realnum, uint hlnum)
    {
      lineNum = realnum - hlnum + 1;
    }
  }

  /// Data associated with this token.
  union /+TokenValue+/
  {
    NewlineValue* nlval; /// Value of a newline token.
    HashLineValue* hlval; /// Value of a #line token.
    StringValue* strval; /// The value of a string token.
    Identifier* ident; /// For keywords and identifiers.
    dchar  dchar_; /// Value of a character literal.
    int    int_; /// Value of an Int32 token.
    uint   uint_; /// Value of a Uint32 token.
    version(X86_64)
    IntegerValue intval; /// Value of a number literal.
    else
    IntegerValue* intval; /// Value of a number literal.
    Float mpfloat; /// A multiple precision float value.
    void* pvoid; /// Associate arbitrary data with this token.
  }
//   static assert(TokenValue.sizeof == (void*).sizeof);

  /// Returns the text of the token.
  string text()
  {
    assert(end && start <= end);
    return start[0 .. end - start];
  }

  /// Returns the preceding whitespace of the token.
  string wsChars()
  {
    assert(ws && start);
    return ws[0 .. start - ws];
  }

  /// Finds the next non-whitespace token.
  /// Returns: 'this' token if the next token is inexistant or TOK.EOF.
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
    if (token is null || token.kind == TOK.EOF)
      return this;
    return token;
  }

  /// Finds the previous non-whitespace token.
  /// Returns: 'this' token if the previous token is inexistent or TOK.HEAD.
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
    if (token is null || token.kind == TOK.HEAD)
      return this;
    return token;
  }

  /// Returns the string for a token kind.
  static string toString(TOK kind)
  {
    return tokToString[kind];
  }

  /// Returns the kind of this token as a string.
  string kindAsString()
  {
    return tokToString[kind];
  }

  /// Adds Flags.Whitespace to this.flags.
  void setWhitespaceFlag()
  {
    this.flags |= Flags.Whitespace;
  }

  /// Returns true if this is a token that can have newlines in it.
  ///
  /// These can be block and nested comments and any string literal
  /// except for escape string literals.
  bool isMultiline()
  {
    return kind == TOK.String && start[0] != '\\' ||
           kind == TOK.Comment && start[1] != '/';
  }

  /// Returns true if this is a keyword token.
  bool isKeyword()
  {
    return KeywordsBegin <= kind && kind <= KeywordsEnd;
  }

  /// Returns true if this is an integral type token.
  bool isIntegralType()
  {
    return IntegralTypeBegin <= kind && kind <= IntegralTypeEnd;
  }

  /// Returns true if this is a whitespace token.
  bool isWhitespace()
  {
    return !!(flags & Flags.Whitespace);
  }

  /// Returns true if this is a special token.
  bool isSpecialToken()
  {
    return SpecialTokensBegin <= kind && kind <= SpecialTokensEnd;
  }

version(D2)
{
  /// Returns true if this is a token string literal.
  bool isTokenStringLiteral()
  { // strval.tok_str !is null
    return kind == TOK.String && *start == 'q' && start[1] == '{';
  }
}

  /// Returns true if this token starts a DeclarationDefinition.
  bool isDeclDefStart()
  {
    return isDeclDefStartToken(kind);
  }

  /// Returns true if this token starts a Statement.
  bool isStatementStart()
  {
    return isStatementStartToken(kind);
  }

  /// Returns true if this token starts an AsmStatement.
  bool isAsmStatementStart()
  {
    return isAsmStatementStartToken(kind);
  }

  int opEquals(TOK kind2)
  {
    return kind == kind2;
  }

  int opCmp(Token* rhs)
  {
    return start < rhs.start;
  }

  /// Returns the Location of this token.
  Location getLocation(bool realLocation)(string filePath)
  {
    auto search_t = this.prev;
    // Find previous newline token.
    while (search_t.kind != TOK.Newline)
      search_t = search_t.prev;

    auto newline = search_t.nlval;
    auto lineNum = newline.lineNum;
    static if (realLocation)
    {}
    else
    if (auto hlinfo = newline.hlinfo)
    { // Change file path and line number.
      filePath = hlinfo.path;
      lineNum  = hlinfo.getLineNum(newline.lineNum);
    }
    auto lineBegin = search_t.end;
    // Determine actual line begin and line number.
    for (; search_t != this; search_t = search_t.next)
      // Multiline tokens must be rescanned for newlines.
      if (search_t.isMultiline)
        for (auto p = search_t.start, end = search_t.end; p < end;)
          if (scanNewline(p))
            ++lineNum,
            lineBegin = p;
          else
            ++p;
    return new Location(filePath, lineNum, lineBegin, this.start);
  }

  alias getLocation!(true) getRealLocation;
  alias getLocation!(false) getErrorLocation;

  /// Returns the location of the character past the end of this token.
  Location errorLocationOfEnd(string filePath)
  {
    auto loc = getErrorLocation(filePath);
    loc.to = end;
    if (isMultiline) // Mutliline tokens may have newlines.
      for (auto p = start, end_ = end; p < end_;)
        if (scanNewline(p))
          loc.lineBegin = p;
        else
          ++p;
    return loc;
  }

  uint lineCount()
  {
    uint count = 1;
    if (this.isMultiline)
    {
      auto p = this.start, end = this.end;
      while (p != end)
        if (scanNewline(p) == '\n')
          ++count;
        else
          ++p;
    }
    return count;
  }

  /// Return the source text enclosed by the left and right token.
  static char[] textSpan(Token* left, Token* right)
  {
    assert(left.end <= right.start || left is right );
    return left.start[0 .. right.end - left.start];
  }

  /// ditto
  char[] textSpan(Token* right)
  {
    return textSpan(this, right);
  }

  /// Deletes a linked list beginning from this token.
  void deleteList()
  {
    version(token_malloc)
    {
    auto token_iter = this;
    while (token_iter !is null)
    {
      auto token = token_iter; // Remember current token to be deleted.
      token_iter = token_iter.next;
      delete token;
    }
    }
  }

version(token_malloc)
{ // Don't use custom allocation by default.
  // See: http://code.google.com/p/dil/issues/detail?id=11

  /// Uses malloc() to allocate memory for a token.
  new(size_t size)
  {
    void* p = malloc(size);
    if (p is null)
      throw new OutOfMemoryException(__FILE__, __LINE__);
    // TODO: Token.init should be all zeros.
    // Maybe use calloc() to avoid this line?
    *cast(Token*)p = Token.init;
    return p;
  }

  /// Deletes a token using free().
  delete(void* p)
  {
    auto token = cast(Token*)p;
    if (token)
    {
      if (token.kind == TOK.HashLine)
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
    assert(kind == TOK.HashLine);
    delete hlval.lineNum;
    delete hlval.filespec;
  }

version(D2)
{
  void destructTokenStringLiteral()
  {
    assert(kind == TOK.String);
    assert(start && *start == 'q' && start[1] == '{');
    assert(strval.tok_str !is null);
    auto tok_it = strval.tok_str;
    auto tok_del = tok_it;
    while (tok_it && tok_it.kind != TOK.EOF)
    {
      tok_it = tok_it.next;
      assert(tok_del && tok_del.kind != TOK.EOF);
      delete tok_del;
      tok_del = tok_it;
    }
  }
}
}
}

/// Returns true if this token starts a DeclarationDefinition.
bool isDeclDefStartToken(TOK tok)
{
  switch (tok)
  {
  alias TOK T;
  case  T.Align, T.Pragma, T.Export, T.Private, T.Package, T.Protected,
        T.Public, T.Extern, T.Deprecated, T.Override, T.Abstract,
        T.Synchronized, T.Static, T.Final, T.Const,
        T.Auto, T.Scope, T.Alias, T.Typedef, T.Import, T.Enum, T.Class,
        T.Interface, T.Struct, T.Union, T.This, T.Tilde, T.Unittest, T.Debug,
        T.Version, T.Template, T.New, T.Delete, T.Mixin, T.Semicolon,
        T.Identifier, T.Dot, T.Typeof:
    return true;
  version(D2)
  {
  case T.At, T.Invariant, T.Immutable:
    return true;
  }
  default:
    if (IntegralTypeBegin <= tok && tok <= IntegralTypeEnd)
      return true;
  }
  return false;
}

/// Returns true if this token starts a Statement.
bool isStatementStartToken(TOK tok)
{
  switch (tok)
  {
  alias TOK T;
  case  T.Align, T.Extern, T.Final, T.Const, T.Auto, T.Identifier, T.Dot,
        T.Typeof, T.If, T.While, T.Do, T.For, T.Foreach, T.ForeachReverse,
        T.Switch, T.Case, T.Default, T.Continue, T.Break, T.Return, T.Goto,
        T.With, T.Synchronized, T.Try, T.Throw, T.Scope, T.Volatile, T.Asm,
        T.Pragma, T.Mixin, T.Static, T.Debug, T.Version, T.Alias, T.Semicolon,
        T.Enum, T.Class, T.Interface, T.Struct, T.Union, T.LBrace, T.Typedef,
        T.This, T.Super, T.Null, T.True, T.False, T.Int32, T.Int64, T.Uint32,
        T.Uint64, T.Float32, T.Float64, T.Float80, T.Imaginary32,
        T.Imaginary64, T.Imaginary80, T.CharLiteral, T.String, T.LBracket,
        T.Function, T.Delegate, T.Assert, T.Import, T.Typeid, T.Is, T.LParen,
        T.AndBinary, T.PlusPlus, T.MinusMinus, T.Mul,
        T.Minus, T.Plus, T.Not, T.Tilde, T.New, T.Delete, T.Cast:
    return true;
  version(D2)
  {
  case T.At, T.Traits, T.Invariant, T.Immutable:
    return true;
  }
  default:
    if (IntegralTypeBegin <= tok && tok <= IntegralTypeEnd ||
        SpecialTokensBegin <= tok && tok <= SpecialTokensEnd)
      return true;
  }
  return false;
}

/// Returns true if this token starts an AsmStatement.
bool isAsmStatementStartToken(TOK tok)
{
  switch (tok)
  {
  alias TOK T;
  // TODO: need to add all opcodes.
  case T.In, T.Int, T.Out, T.Identifier, T.Align, T.Semicolon:
    return true;
  default:
  }
  return false;
}
