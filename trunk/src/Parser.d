/++
  Author: Aziz Köksal
  License: GPL2
+/
module Parser;
import Lexer;

enum STC
{
  Abstract,
  Auto,
  Const,
  Deprecated,
  Extern,
  Final,
  Invariant,
  Override,
  Scope,
  Static,
  Synchronized
}

class Parser
{
  private Lexer lx;
  alias lx.nextToken nextToken;
}
