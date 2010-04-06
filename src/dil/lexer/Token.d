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
struct Token
{ /// Flags set by the Lexer.
  enum Flags : ushort
  {
    None,
    Whitespace = 1, /// Tokens with this flag are ignored by the Parser.
  }

  TOK kind; /// The token kind.
  Flags flags; /// The flags of the token.
  /// Pointers to the next and previous tokens (doubly-linked list.)
  Token* next, prev;

  /// Start of whitespace characters before token. Null if no WS.
  /// TODO: remove to save space; can be replaced by 'prev.end'.
  char* ws;
  char* start; /// Points to the first character of the token.
  char* end;   /// Points one character past the end of the token.

  /// Data associated with this token.
  /// TODO: move data structures out;
  /// use only pointers here to keep Token.sizeof small.
  union
  {
    /// For newline tokens.
    NewlineData newline;
    /// For #line tokens.
    struct
    {
      Token* tokLineNum; /// #line number
      Token* tokLineFilespec; /// #line number filespec
    }
    /// The value of a string token.
    struct
    {
      string str; /// Zero-terminated string. The length includes '\0'.
      char pf;    /// Postfix: 'c', 'w', 'd'. '\0' for none.
    version(D2)
      Token* tok_str; /// Points to the contents of a token string stored as a
                      /// doubly linked list. The last token is always '}' or
                      /// EOF in case the string is not closed properly.
    }
    Identifier* ident; /// For keywords and identifiers.
    dchar  dchar_;   /// A character value.
    long   long_;    /// A long integer value.
    ulong  ulong_;   /// An unsigned long integer value.
    int    int_;     /// An integer value.
    uint   uint_;    /// An unsigned integer value.
    Float mpfloat;   /// A multiple precision float value.
  }

  /// Returns the text of the token.
  string text()
  {
    assert(start && end);
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
  {
    return kind == TOK.String && tok_str !is null;
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
  Location getLocation(bool realLocation)()
  {
    auto search_t = this.prev;
    // Find previous newline token.
    while (search_t.kind != TOK.Newline)
      search_t = search_t.prev;
    auto newline = search_t.newline;
    static if (realLocation)
    {
      auto filePath  = newline.filePaths.oriPath;
      auto lineNum   = newline.oriLineNum;
    }
    else
    {
      auto filePath  = newline.filePaths.setPath;
      auto lineNum   = newline.oriLineNum - newline.setLineNum;
    }
    auto lineBegin = search_t.end;
    // Determine actual line begin and line number.
    for (; search_t != this; search_t = search_t.next)
      // Multiline tokens must be rescanned for newlines.
      if (search_t.isMultiline)
        for (auto p = search_t.start, end = search_t.end; p < end;)
          if (scanNewline(p))
          {
            lineBegin = p;
            ++lineNum;
          }
          else
            ++p;
    return new Location(filePath, lineNum, lineBegin, this.start);
  }

  alias getLocation!(true) getRealLocation;
  alias getLocation!(false) getErrorLocation;

  uint lineCount()
  {
    uint count = 1;
    if (this.isMultiline)
    {
      auto p = this.start, end = this.end;
      while (p != end)
      {
        if (scanNewline(p) == '\n')
          ++count;
        else
          ++p;
      }
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
      if(token.kind == TOK.HashLine)
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
    delete tokLineNum;
    delete tokLineFilespec;
  }

version(D2)
{
  void destructTokenStringLiteral()
  {
    assert(kind == TOK.String);
    assert(start && *start == 'q' && start[1] == '{');
    assert(tok_str !is null);
    auto tok_it = tok_str;
    auto tok_del = tok_str;
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

/// Data associated with newline tokens.
struct NewlineData
{
  struct FilePaths
  {
    char[] oriPath;   /// Original path to the source text.
    char[] setPath;   /// Path set by #line.
  }
  FilePaths* filePaths;
  uint oriLineNum;  /// Actual line number in the source text.
  uint setLineNum;  /// Delta line number set by #line.
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
  case T.Invariant:
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
  case T.Traits, T.Invariant:
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
  switch(tok)
  {
  alias TOK T;
  // TODO: need to add all opcodes.
  case T.In, T.Int, T.Out, T.Identifier, T.Align, T.Semicolon:
    return true;
  default:
  }
  return false;
}
