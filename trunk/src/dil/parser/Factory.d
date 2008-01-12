/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.parser.Factory;

import dil.parser.ExpressionParser;
import dil.parser.Parser;
import dil.ast.Expression;
import dil.Information;
import common;

static this()
{
  dil.parser.ExpressionParser.new_ExpressionParser =
    function ExpressionParser(char[] srcText, string filePath, InfoManager infoMan = null)
    {
      class ExpressionParser_ : Parser, ExpressionParser
      {
        this(char[] srcText, string filePath, InfoManager infoMan = null)
        { super(srcText, filePath, infoMan); }

        Expression parse()
        {
          return Parser.start2();
        }
      }
      return new ExpressionParser_(srcText, filePath, infoMan);
    };
}
