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

  void enterScope(ScopeSymbol s)
  {
    scop = scop.enter(s);
  }

  void exitScope()
  {
    scop = scop.exit();
  }

override
{
  Declaration visit(Declarations d)
  {
    foreach (node; d.children)
    {
      assert(node.category == NodeCategory.Declaration);
      visitD(node.to!(Declaration));
    }
    return d;
  }

  Declaration visit(IllegalDeclaration)
  { assert(0, "semantic pass on invalid AST"); return null; }
  Declaration visit(EmptyDeclaration)
  { return null; }
  Declaration visit(ModuleDeclaration)
  { return null; }
  Declaration visit(ImportDeclaration)
  { return null; }
  Declaration visit(AliasDeclaration)
  { return null; }
  Declaration visit(TypedefDeclaration)
  { return null; }
  Declaration visit(EnumDeclaration)
  { return null; }
  Declaration visit(EnumMember)
  { return null; }

  Declaration visit(ClassDeclaration d)
  {
    if (d.symbol)
      return null;
    d.symbol = new Class(d.name, d);
    // Insert into current scope.
    scop.insert(d.symbol, d.name);
    enterScope(d.symbol);
    // Continue semantic analysis.
    d.decls && visitD(d.decls);
    exitScope();
    return d;
  }

  Declaration visit(InterfaceDeclaration d)
  {
    if (d.symbol)
      return null;
    d.symbol = new dil.semantic.Symbols.Interface(d.name, d);
    // Insert into current scope.
    scop.insert(d.symbol, d.name);
    enterScope(d.symbol);
    // Continue semantic analysis.
    d.decls && visitD(d.decls);
    exitScope();
    return d;
  }

  Declaration visit(StructDeclaration d)
  {
    if (d.symbol)
      return null;
    d.symbol = new Struct(d.name, d);
    // Insert into current scope.
    scop.insert(d.symbol, d.name);
    enterScope(d.symbol);
    // Continue semantic analysis.
    d.decls && visitD(d.decls);
    exitScope();
    return d;
  }

  Declaration visit(UnionDeclaration d)
  {
    if (d.symbol)
      return null;
    d.symbol = new Union(d.name, d);
    // Insert into current scope.
    scop.insert(d.symbol, d.name);
    enterScope(d.symbol);
    // Continue semantic analysis.
    d.decls && visitD(d.decls);
    exitScope();
    return d;
  }

  Declaration visit(ConstructorDeclaration)
  { return null; }
  Declaration visit(StaticConstructorDeclaration)
  { return null; }
  Declaration visit(DestructorDeclaration)
  { return null; }
  Declaration visit(StaticDestructorDeclaration)
  { return null; }
  Declaration visit(FunctionDeclaration)
  { return null; }
  Declaration visit(VariableDeclaration)
  { return null; }
  Declaration visit(InvariantDeclaration)
  { return null; }
  Declaration visit(UnittestDeclaration)
  { return null; }
  Declaration visit(DebugDeclaration)
  { return null; }
  Declaration visit(VersionDeclaration)
  { return null; }
  Declaration visit(StaticIfDeclaration)
  { return null; }
  Declaration visit(StaticAssertDeclaration)
  { return null; }
  Declaration visit(TemplateDeclaration)
  { return null; }
  Declaration visit(NewDeclaration)
  { return null; }
  Declaration visit(DeleteDeclaration)
  { return null; }
  Declaration visit(AttributeDeclaration)
  { return null; }
  Declaration visit(ProtectionDeclaration)
  { return null; }
  Declaration visit(StorageClassDeclaration)
  { return null; }
  Declaration visit(LinkageDeclaration)
  { return null; }
  Declaration visit(AlignDeclaration)
  { return null; }
  Declaration visit(PragmaDeclaration)
  { return null; }
  Declaration visit(MixinDeclaration)
  { return null; }

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
