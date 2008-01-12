/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.parser.ExpressionParser;

import dil.ast.Expression;
import dil.Information;
import common;

interface ExpressionParser
{
  Expression parse();
}

ExpressionParser function(char[] srcText,
                          string filePath,
                          InfoManager infoMan = null)
  new_ExpressionParser;
