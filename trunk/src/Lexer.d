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
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,23,23,23,23,23,23,23,23,22,22, 0, 0, 0, 0, 0, 0,
 0,28,28,28,28,28,28,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24, 0, 0, 0, 0,16,
 0,28,28,28,28,28,28,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
];

enum CProperty
{
       Octal = 1,
       Digit = 1<<1,
         Hex = 1<<2,
       Alpha = 1<<3,
  Identifier = 1<<4
}

int isoctal(char c) { return ptable[c] & CProperty.Octal; }
int isdigit(char c) { return ptable[c] & CProperty.Digit; }
int ishexad(char c) { return ptable[c] & CProperty.Hex; }
int isalpha(char c) { return ptable[c] & CProperty.Alpha; }
int isalnum(char c) { return ptable[c] & (CProperty.Alpha | CProperty.Digit); }
int isident(char c) { return ptable[c] & CProperty.Identifier; }
/+
static this()
{
  // Initialize character properties table.
  for (int i; i < ptable.length; ++i)
  {
    if ('0' <= i && i <= '7')
      ptable[i] |= CProperty.Octal;
    if ('0' <= i && i <= '9')
      ptable[i] |= CProperty.Digit;
    if (isdigit(i) || 'a' <= i && i <= 'f' || 'A' <= i && i <= 'F')
      ptable[i] |= CProperty.Hex;
    if ('a' <= i && i <= 'z' || 'A' <= i && i <= 'Z')
      ptable[i] |= CProperty.Alpha;
    if (isalnum(i) || i == '_')
      ptable[i] |= CProperty.Identifier;
  }
  // Print a formatted array literal.
  char[] array = "[\n";
  for (int i; i < ptable.length; ++i)
  {
    char c = ptable[i];
    array ~= std.string.format("%2d,", c, ((i+1) % 32) ? "":"\n");
  }
  array.length = array.length - 2; // remove ",\n"
  array ~= "\n]";
  writefln(array);
}
+/

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
    t.start = p;

    char c = *p;

    if (c == '\0')
    {
      t.type = TOK.EOF;
      t.end = p+1;
      return;
    }

    if (!isident(c) || isdigit(c))
    {
      do
        c = *++p;
      while ((!isident(c) || isdigit(c)) && c != '\0')
      t.type = TOK.Whitespace;
      t.end = p;
      return;
    }

    if (isident(c) && !isdigit(c))
    {
      do
      { c = *++p; }
      while (isident(c))
      t.type = TOK.Identifier;
      t.end = p;
      return;
    }
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