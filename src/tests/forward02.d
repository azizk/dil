/// Author: Jari-Matti Mäkelä
/// License: GPL3

// Valid circular composition because of pointer.
struct A { B* b; }
struct B { A a; }
// Equivalent to:
struct A { A* a; }

// Valid circular composition because classes are reference types.
class C { D d; }
class D { C c; }
