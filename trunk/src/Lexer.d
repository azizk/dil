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

const uint _Z_ = 26; /// Control+Z

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
  UnterminatedHexString,
  // /* */ /+ +/
  UnterminatedBlockComment,
  UnterminatedNestedComment,
  // `` r""
  UnterminatedRawString,
  UnterminatedBackQuoteString,
}

string[] messages = [
  "unterminated character literal.",
  "empty character literal.",
  // #line
  "expected 'line' after '#'.",
  "newline not allowed inside special token.",
  "expected newline after special token.",
  // x""
  "non-hex character '{1}' found in hex string.",
  "odd number of hex digits in hex string.",
  "unterminated hex string.",
  // /* */ /+ +/
  "unterminated block comment (/* */).",
  "unterminated nested comment (/+ +/).",
  // `` r""
  "unterminated raw string.",
  "unterminated back quote string.",
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
    if (text[$-1] != 0)
    {
      this.text.length = this.text.length + 1;
      this.text[$-1] = 0;
    }

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
      else if (c == LS[0] && p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
      {
        p += 3;
        c = *p;
        continue;
      }

      if (isidbeg(c))
      {
        if (c == 'r' && p[1] == '"' && ++p)
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
          t.type = TOK.DivAssign;
          t.end = p;
          return;
        case '+':
          uint level = 1;
          while (1)
          {
            c = *++p;
            switch (c)
            {
            case '\r':
              if (p[1] == '\n')
                ++p;
            case '\n':
              ++loc;
              continue;
            case '/':
              if (p[1] == '+')
              {
                ++p;
                ++level;
              }
              continue;
            case '+':
              if (p[1] == '/')
              {
                ++p;
                if (--level == 0)
                {
                  ++p;
                LreturnNC:
                  t.type = TOK.Comment;
                  t.end = p;
                  return;
                }
              }
              continue;
            case 0, _Z_:
              error(MID.UnterminatedNestedComment);
              goto LreturnNC;
            case LS[0]:
              if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2])) {
                p += 2;
                ++loc;
              }
              continue;
            default:
            }
          }
        case '*':
          while (1)
          {
            c = *++p;
            switch (c)
            {
            case '\r':
              if (p[1] == '\n')
                ++p;
            case '\n':
              ++loc;
              continue;
            case '*':
              if (p[1] == '/')
              {
                p += 2;
            LreturnBC:
                t.type = TOK.Comment;
                t.end = p;
                return;
              }
              break;
            case LS[0]:
              if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2])) {
                p += 2;
                ++loc;
              }
              break;
            case 0, _Z_:
              error(MID.UnterminatedBlockComment);
              goto LreturnBC;
            default:
            }
          }
          assert(0);
        case '/':
          while (1)
          {
            c = *++p;
            switch (c)
            {
            case '\r':
              if (p[1] == '\n')
                ++p;
            case '\n':
            case 0, _Z_:
              break;
            case LS[0]:
              if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
                break;
              continue;
            default:
              continue;
            }
            t.type = TOK.Comment;
            t.end = p;
            return;
          }
        default:
          t.type = TOK.Div;
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

      if (c == '`')
        return scanRawStringLiteral(t);
      switch (c)
      {
      case '>': /* >  >=  >>  >>=  >>>  >>>= */
        c = *++p;
        switch (c)
        {
        case '=':
          t.type = TOK.GreaterEqual;
          goto Lcommon;
        case '>':
          if (p[1] == '>')
          {
            ++p;
            if (p[1] == '=')
            { ++p;
              t.type = TOK.URShiftAssign;
            }
            else
              t.type = TOK.URShift;
          }
          else if (p[1] == '=')
          {
            ++p;
            t.type = TOK.RShiftAssign;
          }
          else
            t.type = TOK.RShift;
          goto Lcommon;
        default:
          t.type = TOK.Greater;
          goto Lcommon2;
        }
        assert(0);
      case '<': /* <  <=  <>  <>=  <<  <<= */
        c = *++p;
        switch (c)
        {
        case '=':
          t.type = TOK.LessEqual;
          goto Lcommon;
        case '<':
          if (p[1] == '=') {
            ++p;
            t.type = TOK.LShiftAssign;
          }
          else
            t.type = TOK.LShift;
          goto Lcommon;
        case '>':
          if (p[1] == '=') {
            ++p;
            t.type = TOK.LorEorG;
          }
          else
            t.type = TOK.LorG;
          goto Lcommon;
        default:
          t.type = TOK.Less;
          goto Lcommon2;
        }
        assert(0);
      case '!': /* !  !<  !>  !<=  !>=  !<>  !<>= */
        c = *++p;
        switch (c)
        {
        case '<':
          c = *++p;
          if (c == '>')
          {
            if (p[1] == '=') {
              ++p;
              t.type = TOK.Unordered;
            }
            else
              t.type = TOK.UorE;
          }
          else if (c == '=')
          {
            t.type = TOK.UorG;
          }
          else {
            t.type = TOK.UorGorE;
            goto Lcommon2;
          }
          goto Lcommon;
        case '>':
          if (p[1] == '=')
          {
            ++p;
            t.type = TOK.UorL;
          }
          else
            t.type = TOK.UorLorE;
          goto Lcommon;
        case '=':
          t.type = TOK.NotEqual;
          goto Lcommon;
        default:
          t.type = TOK.Not;
          goto Lcommon2;
        }
        assert(0);
      case '.': /* .  ..  ... */
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
      case '|': /* |  ||  |= */
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
      case '&': /* &  &&  &= */
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
      case '+': /* +  ++  += */
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
      case '-': /* -  --  -= */
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
      case '=': /* =  == */
        if (p[1] == '=') {
          ++p;
          t.type = TOK.Equal;
        }
        else
          t.type = TOK.Assign;
        goto Lcommon;
      case '~': /* ~  ~= */
         if (p[1] == '=') {
           ++p;
           t.type = TOK.CatAssign;
         }
         else
           t.type = TOK.Tilde;
         goto Lcommon;
      case '*': /* *  *= */
         if (p[1] == '=') {
           ++p;
           t.type = TOK.MulAssign;
         }
         else
           t.type = TOK.Mul;
         goto Lcommon;
      case '^': /* ^  ^= */
         if (p[1] == '=') {
           ++p;
           t.type = TOK.XorAssign;
         }
         else
           t.type = TOK.Xor;
         goto Lcommon;
      case '%': /* %  %= */
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
    case 0, _Z_, '\n', '\r':
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

  char scanPostfix()
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
    uint delim = *p;
    assert(delim == '`' || delim == '"' && p[-1] == 'r');
    t.type = TOK.String;
    char[] buffer;
    uint c;
    while (1)
    {
      c = *++p;
      switch (c)
      {
      case '\r':
        if (p[1] == '\n')
          ++p;
        c = '\n'; // Convert '\r' and '\r\n' to '\n'
      case '\n':
        ++loc;
        continue;
      case '`':
      case '"':
        if (c == delim)
        {
          ++p;
          t.pf = scanPostfix();
        Lreturn:
          t.str = buffer ~ '\0';
          t.end = p;
          return;
        }
        break;
      case LS[0]:
        if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
        {
          // TODO: convert LS or PS to \n?
          buffer ~= p[0..3];
          p += 2;
          ++loc;
          continue;
        }
        break;
      case 0, _Z_:
        if (delim == 'r')
          error(MID.UnterminatedRawString);
        else
          error(MID.UnterminatedBackQuoteString);
        goto Lreturn;
      default:
      }
      buffer ~= c; // copy character to buffer
    }
    assert(0);
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
        t.pf = scanPostfix();
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
      case 0, _Z_:
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

unittest
{
  string[] toks = [
    ">",    ">=", ">>",  ">>=", ">>>", ">>>=", "<",   "<=",  "<>",
    "<>=",  "<<", "<<=", "!",   "!<",  "!>",   "!<=", "!>=", "!<>",
    "!<>=", ".",  "..",  "...", "&",   "&&",   "&=",  "+",   "++",
    "+=",   "-",  "--",  "-=",  "=",   "==",   "~",   "~=",  "*",
    "*=",   "/",  "/=",  "^",   "^=",  "%",    "%=",  "(",   ")",
    "[",    "]",  "{",   "}",   ":",   ";",    "?",   ",",   "$"
  ];

  char[] src;

  foreach (op; toks)
    src ~= op ~ " ";

  auto lx = new Lexer(src, "");
  auto tokens = lx.getTokens();

  tokens = tokens[0..$-1]; // exclude TOK.EOF

  assert(tokens.length == toks.length );

  foreach (i, t; tokens)
    assert(t.span == toks[i], std.string.format("Lexed '%s' but expected '%s'", t.span, toks[i]));
}