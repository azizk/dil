/++
  Author: Jari-Matti Mäkelä
+/

// Impossible circular composition.
struct A { B b; }
struct B { A a; }
