/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Pass1;

import dil.ast.Visitor;
import dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.BaseClass,
       dil.ast.Parameters;

import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Scope;

class SemanticPass1 : Visitor
{
  Scope scop;

  /+Scope enterScope(Symbol s)
  {
    return null;
  }+/

override
{
  Declaration visit(ClassDeclaration c)
  {
    if (c.symbol)
      return null;
    c.symbol = new Class(c.name, c);
    // Insert into current scope.
    scop.insert(c.symbol, c.name);
    // Enter a new scope.
    this.scop = this.scop.enter(c.symbol);
    // Continue semantic analysis.
    c.decls && visitD(c.decls);
    // Exit scope.
    this.scop = scop.exit();
    return c;
  }

  Expression visit(CommaExpression e)
  {
    if (!e.type)
    {
      e.left = visitE(e.left);
      e.right = visitE(e.right);
      e.type = e.right.type;
    }
    return e;
  }

  Expression visit(OrOrExpression)
  { return null; }

  Expression visit(AndAndExpression)
  { return null; }

  Expression visit(MixinExpression me)
  {
    /+
    if (type)
      return this.expr;
    // TODO:
    auto expr = this.expr.semantic(scop);
    expr = expr.evaluate();
    if (expr is null)
      return this;
    auto strExpr = TryCast!(StringExpression)(expr);
    if (strExpr is null)
     error(scop, MSG.MixinArgumentMustBeString);
    else
    {
      auto loc = this.begin.getLocation();
      auto filePath = loc.filePath;
      auto parser = new_ExpressionParser(strExpr.getString(), filePath, scop.infoMan);
      expr = parser.parse();
      expr = expr.semantic(scop);
    }
    this.expr = expr;
    this.type = expr.type;
    return expr;
    +/
    return null;
  }
} // override
}
