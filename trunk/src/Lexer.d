/++
  Author: Aziz Köksal
  License: GPL2
+/
module Lexer;
import Token;
import std.stdio;
import std.utf;
import std.uni;

/// ASCII character properties table.
static const int ptable[256] = [
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
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
}

private alias CProperty CP;
int isoctal(char c) { return ptable[c] & CP.Octal; }
int isdigit(char c) { return ptable[c] & CP.Digit; }
int ishexad(char c) { return ptable[c] & CP.Hex; }
int isalpha(char c) { return ptable[c] & CP.Alpha; }
int isalnum(char c) { return ptable[c] & (CP.Alpha | CP.Digit); }
int isidbeg(char c) { return ptable[c] & (CP.Alpha | CP.Underscore); }
int isident(char c) { return ptable[c] & (CP.Alpha | CP.Underscore | CP.Digit); }

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

class Lexer
{
  Token token;
  char[] text;
  char* p;
  char* end;

  this(char[] text)
  {
    this.text = text;
    this.text.length = this.text.length + 1;
    this.text[$-1] = 0;

    this.p = this.text.ptr;
    this.end = this.p + this.text.length;
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
        t.type = TOK.EOF;
        t.end = p+1;
        return;
      }

      if (isidbeg(c))
      {
      Lidentifier:
        do
        { c = *++p; }
        while (isident(c) || c & 128 && isUniAlpha(decodeUTF()))
        t.type = TOK.Identifier;
        t.end = p;
        return;
      }

      if (c == '/')
      {
        c = *++p;
        if (c == '+')
        {
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
        }
        else if (c == '*')
        {
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
        }
        else if (c == '/')
        {
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
      {
        do {
          c = *++p;
          if (c == 0)
            throw new Error("unterminated character literal.");
          if (c == '\\')
            ++p;
        } while (c != '\'')
        ++p;
        t.type = TOK.Character;
        t.end = p;
        return;
      }

      if (c & 128 && isUniAlpha(decodeUTF()))
        goto Lidentifier;
      c = *++p;
    }
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
