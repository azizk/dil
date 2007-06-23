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
  Comment,
  String,
  Character,
  DivisionAssign,
  Number,
  EOF
}

struct Token
{
  TOK type;
  Position pos;

  char* start;
  char* end;

  union
  {
    char[] str;
    float f;
    double d;
  }
}