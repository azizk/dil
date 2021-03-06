/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.lexer.Token;

import dil.lexer.Identifier,
       dil.lexer.Funcs;
import dil.Location;
import dil.Float;
import dil.Array;
import common;

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
///   Identifier = $(SYMLINK2 dil.lexer.Identifier, Identifier)
struct Token
{
  TOK kind;     /// The token kind.
  cchar* ws;    /// Points to the preceding whitespace characters if present.
  cchar* start; /// Points to the first character of the token.
  cchar* end;   /// Points one character past the end of the token.

  /// Represents the string value of a single string literal,
  /// where possible escape sequences have been converted to their values.
  struct StringValue
  {
    cbinstr str;    /// The typeless string value.
    char pf = 0;    /// Postfix: 'c', 'w', 'd'. '\0' for none.
    version(D2)
    Token* tokens; /// Points to the contents of a token string stored
                   /// as a zero-terminated array.
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
    size_t lineNum; /// The line number in the source text.
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
    size_t lineNum; /// Delta line number calculated from #line Number.
    cstring path;   /// File path set by #line num Filespec.
    /// Calculates and returns the line number.
    size_t getLineNum(size_t realnum)
    {
      return realnum - lineNum;
    }
    /// Calculates a delta value and sets 'lineNum'.
    void setLineNum(size_t realnum, size_t hlnum)
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
    size_t sizet_; /// An integer that fits into the address space.
    int    int_; /// Value of an Int32 token.
    uint   uint_; /// Value of a UInt32 token.
    version(X86_64)
    IntegerValue intval; /// Value of a number literal.
    else
    IntegerValue* intval; /// Value of a number literal.
    Float mpfloat; /// A multiple precision float value.
    void* pvoid; /// Associate arbitrary data with this token.
  }
//   static assert(TokenValue.sizeof == (void*).sizeof);

  /// Returns the text of the token.
  cstring text()
  {
    assert(start <= end);
    return start[0 .. end - start];
  }

  /// Sets the text of the token.
  void text(cstring s)
  {
    start = s.ptr;
    end = s.ptr + s.length;
  }

  /// Returns the preceding whitespace of the token.
  cstring wsChars()
  {
    assert(ws && start);
    return ws[0 .. start - ws];
  }

  /// Returns the next token.
  Token* next()
  {
    assert(kind != TOK.Invalid);
    return &this + 1;
  }

  /// Returns the previous token.
  Token* prev()
  {
    assert(kind != TOK.Invalid);
    return &this - 1;
  }

  /// Finds the next non-whitespace token. Does not go past TOK.EOF.
  Token* nextNWS()
  {
    assert(kind != TOK.Invalid);
    auto token = &this;
    if (kind != TOK.EOF)
      while ((++token).isWhitespace)
      {}
    return token;
  }

  /// Finds the previous non-whitespace token. Does not go past TOK.HEAD.
  Token* prevNWS()
  {
    assert(kind != TOK.Invalid);
    auto token = &this;
    if (kind != TOK.HEAD)
      while ((--token).isWhitespace)
      {}
    return token;
  }

  /// Returns the text of this token.
  cstring toString()
  {
    return text();
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
  { // Tokens from TOK.init to TOK.LastWhitespace are whitespace.
    return kind <= TOK.LastWhitespace;
  }

  /// Returns true if this is a special token.
  bool isSpecialToken()
  {
    return kind == TOK.SpecialID;
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

  /// Compares a token's kind to kind2.
  int opEquals(TOK kind2)
  {
    return kind == kind2;
  }

  /// Compares the position of two tokens.
  /// Assumes they are from the same source text.
  int opCmp(Token* rhs)
  { // Returns: (lower, equal, greater) = (-1, 0, 1)
    return start < rhs.start ? -1 : start !is rhs.start;
  }

  /// Returns the Location of this token.
  Location getLocation(bool realLocation)(cstring filePath)
  {
    auto search_t = &this;
    // Find previous newline token.
    while ((--search_t).kind != TOK.Newline)
    {}
    auto newline = search_t.nlval;
    auto lineNum = newline.lineNum;
    static if (!realLocation)
      if (auto hlinfo = newline.hlinfo)
      { // Change file path and line number.
        filePath = hlinfo.path;
        lineNum  = hlinfo.getLineNum(newline.lineNum);
      }
    auto lineBegin = search_t.end;
    // Determine actual line begin and line number.
    while (++search_t < &this)
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

  alias getRealLocation = getLocation!(true);
  alias getErrorLocation = getLocation!(false);

  /// Returns the location of the character past the end of this token.
  Location errorLocationOfEnd(cstring filePath)
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

  /// Counts the newlines in this token.
  uint lineCount()
  {
    uint count;
    if (this.isMultiline)
      for (auto p = start, end_ = end; p < end_;)
        if (scanNewline(p, end_))
          count++;
        else
          p++;
    return count;
  }

  /// Return the source text enclosed by the left and right token.
  static cstring textSpan(Token* left, Token* right)
  {
    assert(left.end <= right.start || left is right );
    return left.start[0 .. right.end - left.start];
  }

  /// ditto
  cstring textSpan(Token* right)
  {
    return textSpan(&this, right);
  }
}

alias TokenArray = DArray!Token;

/// Returns true if this token starts a DeclarationDefinition.
bool isDeclDefStartToken(TOK tok)
{
  switch (tok)
  {
  alias T = TOK;
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
  case T.Immutable, T.Pure, T.Shared, T.Gshared,
       T.Ref, T.Nothrow, T.At:
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
  alias T = TOK;
  case  T.Align, T.Extern, T.Final, T.Const, T.Auto, T.Identifier, T.Dot,
        T.Typeof, T.If, T.While, T.Do, T.For, T.Foreach, T.ForeachReverse,
        T.Switch, T.Case, T.Default, T.Continue, T.Break, T.Return, T.Goto,
        T.With, T.Synchronized, T.Try, T.Throw, T.Scope, T.Volatile, T.Asm,
        T.Pragma, T.Mixin, T.Static, T.Debug, T.Version, T.Alias, T.Semicolon,
        T.Enum, T.Class, T.Interface, T.Struct, T.Union, T.LBrace, T.Typedef,
        T.This, T.Super, T.Null, T.True, T.False, T.Int32, T.Int64, T.UInt32,
        T.UInt64, T.Float32, T.Float64, T.Float80, T.IFloat32,
        T.IFloat64, T.IFloat80, T.Character, T.String, T.LBracket,
        T.Function, T.Delegate, T.Assert, T.Import, T.Typeid, T.Is, T.LParen,
        T.Amp, T.Plus2, T.Minus2, T.Star,
        T.Minus, T.Plus, T.Exclaim, T.Tilde, T.New, T.Delete, T.Cast:
    return true;
  version(D2)
  {
  case T.Traits, T.Immutable, T.Pure, T.Shared, T.Gshared,
       T.Ref, T.Nothrow, T.At:
    return true;
  }
  default:
    if (IntegralTypeBegin <= tok && tok <= IntegralTypeEnd ||
        tok == T.SpecialID)
      return true;
  }
  return false;
}

/// Returns true if this token starts an AsmStatement.
bool isAsmStatementStartToken(TOK tok)
{
  switch (tok)
  {
  alias T = TOK;
  // TODO: need to add all opcodes.
  case T.In, T.Int, T.Out, T.Identifier, T.Align, T.Semicolon:
    return true;
  default:
  }
  return false;
}

/// A list of tokens that point to tokToString[kind] as their text.
static Token[TOK.MAX] staticTokens;

/// Returns the token corresponding to a token kind.
Token* toToken(TOK kind)
{
  return &staticTokens[kind];
}

/// Initializes staticTokens.
static this()
{
  import dil.lexer.IDs;

  foreach (i, ref t; staticTokens)
  {
    auto kind = cast(TOK)i;
    auto text = kind.toString();
    t.kind = kind;
    t.start = text.ptr;
    t.end = text.ptr + text.length;
  }

  /// Set the ident member of the keyword tokens and the one Identifier token.
  foreach (ref kw; IDs.getKeywordIDs())
    kw.kind.toToken().ident = &kw;
  TOK.Identifier.toToken().ident = &IDs.Identifier_;
  TOK.SpecialID.toToken().ident = &IDs.SpecialID;
}
