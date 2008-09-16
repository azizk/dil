/// Author: Jari-Matti Mäkelä
/// License: GPL3

// Impossible circular composition.
struct A { B b; }
struct B { A a; }
