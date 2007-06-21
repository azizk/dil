/++
  Author: Aziz Köksal
  License: GPL2
+/
module Token;

struct Position
{
  size_t loc;
  size_t col;
}

enum TOK
{
  Identifier,
  Whitespace,
  Comment
}

struct Token
{
  TOK type;
  Position pos;

  union
  {
    char[] str;
    float f;
    double d;
  }
}