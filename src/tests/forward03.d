/++
  Author: Aziz Köksal
+/

// Impossible static circular reference.
const x = y;
const y = x;

// Impossible static circular reference.
struct A
{ const int a = B.b; }
struct B
{ const int b = A.a; }

struct C
{
  const x = C.x;
}