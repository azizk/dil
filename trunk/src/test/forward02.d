/++
  Author: Jari-Matti Mäkelä
+/

// Possible circular composition.
struct A { B* b; /*because of pointer*/ }
struct B { A a; }
// Equivalent to:
struct A { A* a }
