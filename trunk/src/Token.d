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
    dchar chr;
    float f;
    double d;
  }
}