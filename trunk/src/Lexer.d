/++
  Author: Aziz Köksal
  License: GPL2
+/
module Lexer;
import Token;
import Keywords;
import Identifier;
import std.stdio;
import std.utf;
import std.uni;
import std.conv;

/// ASCII character properties table.
static const int ptable[256] = [
 0, 0, 0, 0, 0, 0, 0, 0, 0,32, 0,32,32, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 7, 7, 7, 7, 7, 7, 7, 7, 6, 6, 0, 0, 0, 0, 0, 0,
 0,12,12,12,12,12,12, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0,16,
 0,12,12,12,12,12,12, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
];

enum CProperty
{
       Octal = 1,
       Digit = 1<<1,
         Hex = 1<<2,
       Alpha = 1<<3,
  Underscore = 1<<4,
  Whitespace = 1<<5
}

private alias CProperty CP;
int isoctal(char c) { return ptable[c] & CP.Octal; }
int isdigit(char c) { return ptable[c] & CP.Digit; }
int ishexad(char c) { return ptable[c] & CP.Hex; }
int isalpha(char c) { return ptable[c] & CP.Alpha; }
int isalnum(char c) { return ptable[c] & (CP.Alpha | CP.Digit); }
int isidbeg(char c) { return ptable[c] & (CP.Alpha | CP.Underscore); }
int isident(char c) { return ptable[c] & (CP.Alpha | CP.Underscore | CP.Digit); }
int isspace(char c) { return ptable[c] & CP.Whitespace; }

version(gen_ptable)
static this()
{
  // Initialize character properties table.
  for (int i; i < ptable.length; ++i)
  {
    ptable[i] = 0;
    if ('0' <= i && i <= '7')
      ptable[i] |= CP.Octal;
    if ('0' <= i && i <= '9')
      ptable[i] |= CP.Digit;
    if (isdigit(i) || 'a' <= i && i <= 'f' || 'A' <= i && i <= 'F')
      ptable[i] |= CP.Hex;
    if ('a' <= i && i <= 'z' || 'A' <= i && i <= 'Z')
      ptable[i] |= CP.Alpha;
    if (i == '_')
      ptable[i] |= CP.Underscore;
    if (i == ' ' || i == '\t' || i == '\v'|| i == '\f')
      ptable[i] |= CP.Whitespace;
  }
  // Print a formatted array literal.
  char[] array = "[\n";
  for (int i; i < ptable.length; ++i)
  {
    int c = ptable[i];
    array ~= std.string.format("%2d,", c, ((i+1) % 16) ? "":"\n");
  }
  array[$-2..$] = "\n]";
  writefln(array);
}

const char[3] LS = \u2028;
const char[3] PS = \u2029;

const dchar LSd = 0x2028;
const dchar PSd = 0x2029;

/// Index into table of error messages.
enum MID
{
  UnterminatedCharacterLiteral,
  EmptyCharacterLiteral,
  // #line
  ExpectedIdentifierLine,
  NewlineInSpecialToken,
  UnterminatedSpecialToken,
  // x""
  NonHexCharInHexString,
  OddNumberOfDigitsInHexString,
  UnterminatedHexString
}

string[] messages = [
  "unterminated character literal."
  "empty character literal.",
  // #line
  "expected 'line' after '#'."
  "newline not allowed inside special token."
  "expected newline after special token.",
  // x""
  "non-hex character '{1}' found in hex string.",
  "odd number of hex digits in hex string.",
  "unterminated hex string."
];

class Problem
{
  enum Type
  {
    Lexer,
    Parser,
    Semantic
  }

  MID id;
  Type type;
  uint loc;
  this(Type type, MID id, uint loc)
  {
    this.id = id;
    this.type = type;
    this.loc = loc;
  }
}

class Lexer
{
  Token token;
  string text;
  char* p;
  char* end;

  uint loc = 1; /// line of code

  char[] fileName;

  Problem[] errors;

  Identifier[string] idtable;

  this(string text, string fileName)
  {
    this.fileName = fileName;

    this.text = text;
    this.text.length = this.text.length + 1;
    this.text[$-1] = 0;

    this.p = this.text.ptr;
    this.end = this.p + this.text.length;

    loadKeywords();
  }

  public void scan(out Token t)
  {
    assert(p < end);

    uint c = *p;

    while(1)
    {
      t.start = p;

      if (c == 0)
      {
        ++p;
        t.type = TOK.EOF;
        t.end = p;
        return;
      }

      if (c == '\n')
      {
        c = *++p;
        ++loc;
        continue;
      }
      else if (c == '\r')
      {
        c = *++p;
        if (c != '\n')
          ++loc;
        continue;
      }

      if (isidbeg(c))
      {
        if (c == 'r' && p[1] == '"')
          return scanRawStringLiteral(t);
        if (c == 'x' && p[1] == '"')
          return scanHexStringLiteral(t);
      Lidentifier:
        do
        { c = *++p; }
        while (isident(c) || c & 128 && isUniAlpha(decodeUTF()))

        t.end = p;

        string str = t.span;
        Identifier* id = str in idtable;

        if (!id)
        {
          idtable[str] = Identifier.Identifier(TOK.Identifier, str);
          id = str in idtable;
        }
        assert(id);
        t.type = id.type;
        return;
      }

      if (isdigit(c))
        return scanNumber(t);

      if (c == '/')
      {
        c = *++p;
        switch(c)
        {
        case '=':
          ++p;
          t.type = TOK.DivisionAssign;
          t.end = p;
          return;
        case '+':
          uint level = 1;
          do
          {
            c = *++p;
            if (c == 0)
              throw new Error("unterminated /+ +/ comment.");
            else if (c == '/' && p[1] == '+')
            {
              ++p;
              ++level;
            }
            else if (c == '+' && p[1] == '/')
            {
              ++p;
              if (--level == 0)
                break;
            }
          } while (1)
          p += 2;
          t.type = TOK.Comment;
          t.end = p;
          return;
        case '*':
          do
          {
            c = *++p;
            if (c == 0)
              throw new Error("unterminated /* */ comment.");
          } while (c != '*' || p[1] != '/')
          p += 2;
          t.type = TOK.Comment;
          t.end = p;
          return;
        case '/':
          do
          {
            c = *++p;
            if (c == LS[0] && p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
              break;
          } while (c != '\n' && c != 0)
          t.type = TOK.Comment;
          t.end = p;
          return;
        }
      }

      if (c == '"')
      {
        do {
          c = *++p;
          if (c == 0)
            throw new Error("unterminated string literal.");
          if (c == '\\')
            ++p;
        } while (c != '"')
        ++p;
        t.type = TOK.String;
        t.end = p;
        return;
      }

      if (c == '\'')
        return scanCharacterLiteral(t);

      switch(c)
      {
      case '.':
        if (p[1] == '.')
        {
          ++p;
          if (p[1] == '.') {
            ++p;
            t.type = TOK.Ellipses;
          }
          else
            t.type = TOK.Slice;
        }
        else
          t.type = TOK.Dot;
        goto Lcommon;
      case '|':
        c = *++p;
        if (c == '=')
          t.type = TOK.OrAssign;
        else if (c == '|')
          t.type = TOK.OrLogical;
        else {
          t.type = TOK.OrBinary;
          goto Lcommon2;
        }
        goto Lcommon;
      case '&':
        c = *++p;
        if (c == '=')
          t.type = TOK.AndAssign;
        else if (c == '&')
          t.type = TOK.AndLogical;
        else {
          t.type = TOK.AndBinary;
          goto Lcommon2;
        }
        goto Lcommon;
      case '+':
        c = *++p;
        if (c == '=')
          t.type = TOK.PlusAssign;
        else if (c == '+')
          t.type = TOK.PlusPlus;
        else {
          t.type = TOK.Plus;
          goto Lcommon2;
        }
        goto Lcommon;
      case '-':
        c = *++p;
        if (c == '=')
          t.type = TOK.MinusAssign;
        else if (c == '-')
          t.type = TOK.MinusMinus;
        else {
          t.type = TOK.Minus;
          goto Lcommon2;
        }
        goto Lcommon;
      case '=':
        if (p[1] == '=') {
          ++p;
          t.type = TOK.Equal;
        }
        else
          t.type = TOK.Assign;
        goto Lcommon;
      case '~':
         if (p[1] == '=') {
           ++p;
           t.type = TOK.CatAssign;
         }
         else
           t.type = TOK.Tilde;
         goto Lcommon;
      case '*':
         if (p[1] == '=') {
           ++p;
           t.type = TOK.MulAssign;
         }
         else
           t.type = TOK.Mul;
         goto Lcommon;
      case '^':
         if (p[1] == '=') {
           ++p;
           t.type = TOK.XorAssign;
         }
         else
           t.type = TOK.Xor;
         goto Lcommon;
      case '%':
         if (p[1] == '=') {
           ++p;
           t.type = TOK.ModAssign;
         }
         else
           t.type = TOK.Mod;
         goto Lcommon;
      // Single character tokens:
      case '(':
        t.type = TOK.LParen;
        goto Lcommon;
      case ')':
        t.type = TOK.RParen;
        goto Lcommon;
      case '[':
        t.type = TOK.LBracket;
        goto Lcommon;
      case ']':
        t.type = TOK.RBracket;
        goto Lcommon;
      case '{':
        t.type = TOK.LBrace;
        goto Lcommon;
      case '}':
        t.type = TOK.RBrace;
        goto Lcommon;
      case ':':
        t.type = TOK.Colon;
        goto Lcommon;
      case ';':
        t.type = TOK.Semicolon;
        goto Lcommon;
      case '?':
        t.type = TOK.Question;
        goto Lcommon;
      case ',':
        t.type = TOK.Comma;
        goto Lcommon;
      case '$':
        t.type = TOK.Dollar;
      Lcommon:
        ++p;
      Lcommon2:
        t.end = p;
        return;
      case '#':
        ++p;
        scanSpecialToken();
        break;
      default:
      }

      if (c & 128 && isUniAlpha(decodeUTF()))
        goto Lidentifier;
      c = *++p;
    }
  }

  void peek(ref Token t)
  {
    char* tmp = p;
    scan(t);
    p = tmp;
  }

  void scanCharacterLiteral(ref Token t)
  {
    assert(*p == '\'');
    MID id = MID.UnterminatedCharacterLiteral;
    uint c = *++p;
    switch(c)
    {
    case '\\':
      ++p;
      break;
    case 0, 26, '\n', '\r':
      goto Lerr;
    case '\'':
      id = MID.EmptyCharacterLiteral;
      goto Lerr;
    default:
      if (c & 128)
      {
        c = decodeUTF();
        if (c == LSd || c == PSd)
          goto Lerr;
        t.chr = c;
      }
    }

    ++p;
    if (*p != '\'')
    Lerr:
      error(id);
    ++p;
    t.type = TOK.Character;
    t.end = p;
  }

  char scanPostFix()
  {
    switch (*p)
    {
    case 'c':
    case 'w':
    case 'd':
      return *p++;
    default:
      return 0;
    }
  }

  void scanRawStringLiteral(ref Token t)
  {

  }

  void scanHexStringLiteral(ref Token t)
  {
    assert(p[0] == 'x' && p[1] == '"');
    p+=2;
    t.type = TOK.String;

    uint c;
    ubyte[] buffer;
    ubyte h; // hex number
    uint n; // number of hex digits
    MID mid;

    while (1)
    {
      c = *p++;
      switch (c)
      {
      case '"':
        if (n & 1)
        {
          mid = MID.OddNumberOfDigitsInHexString;
          error(mid);
        }
        t.str = cast(string) buffer;
        t.pf = scanPostFix();
        t.end = p;
        return;
      case '\r':
        if (*p == '\n')
          ++p;
      case '\n':
        ++loc;
        continue;
      case LS[0]:
        if (*p == LS[1] && (p[1] == LS[2] || p[1] == PS[2])) {
          p += 2;
          ++loc;
        }
        continue;
      case 0, 26:
        mid = MID.UnterminatedHexString;
        goto Lerr;
      default:
        if (ishexad(c))
        {
          if (c <= '9')
            c -= '0';
          else if (c <= 'F')
            c -= 'A' - 10;
          else
            c -= 'a' - 10;

          if (n & 1)
          {
            h <<= 4;
            h |= c;
            buffer ~= h;
          }
          else
            h = c;
          ++n;
          continue;
        }
        else if (isspace(c))
          continue;
        mid = MID.NonHexCharInHexString;
        goto Lerr;
      }
    }

    return;
  Lerr:
    error(mid);
    t.pf = 0;
    t.end = p;
  }

  void scanNumber(ref Token t)
  {
    while (isdigit(*++p)) {}
    t.type = TOK.Number;
    t.end = p;
    t._uint = toInt(t.span);
  }

  /// Scan special token: #line Integer [Filespec] EndOfLine
  void scanSpecialToken()
  {
    MID mid;
    Token t;

    scan(t);
    if (!(t.type == TOK.Identifier && t.span == "line")) {
      mid = MID.ExpectedIdentifierLine;
      goto Lerr;
    }

    scan(t);
    if (t.type == TOK.Number)
      loc = t._uint - 1;

    uint loc = this.loc;

    char* wsstart = t.end;

    bool hasNewline(char* end)
    {
      alias wsstart p;
      uint c;
      for(; p != end; c = *++p)
        if (c == '\n' || c == '\r' || c == LS[0] && p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2])) {
          mid = MID.NewlineInSpecialToken;
          return true;
        }
      return false;
    }

    peek(t);

    if (t.type == TOK.String)
    {
      // Check whole token with preceding whitespace for newline.
      if (hasNewline(t.end))
        goto Lerr;
      fileName = t.span[1..$-1]; // contents of "..."
      p = t.end;
    }
    else if (t.type == TOK.Identifier && t.span == "__FILE__")
    {
      // Check preceding whitespace for newline.
      if (hasNewline(t.start))
        goto Lerr;
      p = t.end;
    }

    uint c;
    while (1)
    {
      c = *p++;
      if (isspace(c))
        continue;

      if (c == '\n' || c == '\r' || c == 0 ||
          c == LS[0] && p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
        break;
      else {
        mid = MID.UnterminatedSpecialToken;
        goto Lerr;
      }
    }

    this.loc = loc;
    return;
  Lerr:
    error(mid);
  }

  uint decodeUTF()
  {
    assert(*p & 128);
    size_t idx;
    uint d;
    d = std.utf.decode(p[0 .. end-p], idx);
    p += idx -1;
    return d;
  }

  void loadKeywords()
  {
    foreach(k; keywords)
      idtable[k.str] = k;
  }

  void error(MID id)
  {
    errors ~= new Problem(Problem.Type.Lexer, id, loc);
  }

  public TOK nextToken()
  {
    scan(this.token);
    return this.token.type;
  }

  Token[] getTokens()
  {
    Token[] tokens;
    while (nextToken() != TOK.EOF)
      tokens ~= this.token;
    tokens ~= this.token;
    return tokens;
  }
}
