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

struct Token
{
  enum Type
  {

  }

  Type type;
  Position pos;

  union
  {
    char[] str;
    float f;
    double d;
  }
}