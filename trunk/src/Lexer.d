/++
  Author: Aziz Köksal
  License: GPL2
+/
module Lexer;

/// ASCII character properties table.
static const int ptable[256] = [];

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

static this()
{
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
}

class Lexer
{

}