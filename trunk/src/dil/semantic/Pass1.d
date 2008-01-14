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
       dil.semantic.Types,
       dil.semantic.Scope,
       dil.semantic.Module;

class SemanticPass1 : Visitor
{
  Scope scop;
  Module modul;

  this(Module modul)
  {
    this.modul = modul;
  }

  /// Start semantic analysis.
  void start()
  {
    assert(modul.root !is null);
    visitN(modul.root);
  }

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
      return d;
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
      return d;
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
      return d;
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
      return d;
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

  Expression visit(SpecialTokenExpression e)
  {
    if (e.type)
      return e.value;
    switch (e.specialToken.type)
    {
    case TOK.LINE, TOK.VERSION:
      e.value = new IntExpression(e.specialToken.uint_, Types.Uint);
      break;
    case TOK.FILE, TOK.DATE, TOK.TIME, TOK.TIMESTAMP, TOK.VENDOR:
      e.value = new StringExpression(e.specialToken.str);
      break;
    default:
      assert(0);
    }
    e.type = e.value.type;
    return e.value;
  }

  Expression visit(DollarExpression e)
  {
    if (e.type)
      return e;
    e.type = Types.Size_t;
    // if (!inArraySubscript)
    //   error("$ can only be in an array subscript.");
    return e;
  }

  Expression visit(NullExpression e)
  {
    if (!e.type)
      e.type = Types.Void_ptr;
    return e;
  }

  Expression visit(BoolExpression e)
  {
    if (e.type)
      return e;
    assert(e.begin !is null);
    auto b = (e.begin.type == TOK.True) ? true : false;
    e.value = new IntExpression(b, Types.Bool);
    e.type = Types.Bool;
    return e;
  }

  Expression visit(IntExpression e)
  {
    if (e.type)
      return e;

    if (e.number & 0x8000_0000_0000_0000)
      e.type = Types.Ulong; // 0xFFFF_FFFF_FFFF_FFFF
    else if (e.number & 0xFFFF_FFFF_0000_0000)
      e.type = Types.Long; // 0x7FFF_FFFF_FFFF_FFFF
    else if (e.number & 0x8000_0000)
      e.type = Types.Uint; // 0xFFFF_FFFF
    else
      e.type = Types.Int; // 0x7FFF_FFFF
    return e;
  }

  Expression visit(RealExpression e)
  {
    if (e.type)
      e.type = Types.Double;
    return e;
  }

  Expression visit(ComplexExpression e)
  {
    if (!e.type)
      e.type = Types.Cdouble;
    return e;
  }

  Expression visit(CharExpression e)
  {
    if (e.type)
      return e;
    if (e.character <= 0xFF)
      e.type = Types.Char;
    else if (e.character <= 0xFFFF)
      e.type = Types.Wchar;
    else
      e.type = Types.Dchar;
    return e;
  }

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
