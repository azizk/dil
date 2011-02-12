/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.code.NotAResult;

import dil.ast.Expression;
import dil.semantic.Types;

/// Not A Result. Similar to NAN in floating point arithmetics.
class NARExpr : Expression
{
  override NARExpr copy(){ return this; }
}

/// A global, unique instance.
/// Returned when an expression could not be interpreted at compile-time.
const NARExpr NAR;

static this()
{
  NAR = new NARExpr;
  NAR.type = Types.Error; // Giving it a type may not be necessary.
}
