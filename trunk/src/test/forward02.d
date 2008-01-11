/++
  Author: Jari-Matti Mäkelä
+/

// Valid circular composition because of pointer.
struct A { B* b; }
struct B { A a; }
// Equivalent to:
struct A { A* a }
