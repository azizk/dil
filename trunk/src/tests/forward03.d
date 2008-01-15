/++
  Author: Aziz Köksal
+/

// Impossible static circular reference.
const x = y;
const y = x;
