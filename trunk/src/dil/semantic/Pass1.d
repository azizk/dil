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
       dil.ast.Parameters;
import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Types,
       dil.semantic.Scope,
       dil.semantic.Module,
       dil.semantic.Analysis;
import dil.Location;
import dil.Information;
import dil.Messages;
import common;

class SemanticPass1 : Visitor
{
  Scope scop; /// The current scope.
  Module modul; /// The module to be semantically checked.

  this(Module modul)
  {
    this.modul = modul;
  }

  /// Start semantic analysis.
  void start()
  {
    assert(modul.root !is null);
    // Create module scope.
    scop = new Scope();
    scop.symbol = modul; // Set this module as the scope's symbol.
    scop.infoMan = modul.infoMan;
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

  void error(Token* token, char[] formatMsg, ...)
  {
    auto location = token.getLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    modul.infoMan ~= new SemanticError(location, msg);
  }

override
{
  Declaration visit(Declarations d)
  {
    foreach (node; d.children)
    {
      assert(node.category == NodeCategory.Declaration, Format("{}", node));
      visitD(cast(Declaration)cast(void*)node);
    }
    return d;
  }

  Declaration visit(IllegalDeclaration)
  { assert(0, "semantic pass on invalid AST"); return null; }

  Declaration visit(EmptyDeclaration ed)
  { return ed; }

  Declaration visit(ModuleDeclaration)
  { return null; }
  Declaration visit(ImportDeclaration)
  { return null; }

  Declaration visit(AliasDeclaration ad)
  {
    /+
    decl.semantic(scop); // call semantic() or do SA in if statements?
    if (auto fd = TryCast!(FunctionDeclaration)(decl))
    {
      // TODO: do SA here?
    }
    else if (auto vd = TryCast!(VariableDeclaration)(decl))
    {
      // TODO: do SA here?
    }
    +/
    return ad;
  }

  Declaration visit(TypedefDeclaration td)
  {
    /+
    decl.semantic(scop); // call semantic() or do SA in if statements?
    if (auto fd = TryCast!(FunctionDeclaration)(decl))
    {
      // TODO: do SA here?
    }
    else if (auto vd = TryCast!(VariableDeclaration)(decl))
    {
      // TODO: do SA here?
    }
    +/
    return td;
  }

  Declaration visit(EnumDeclaration ed)
  {
    /+
    // Create the symbol.
    symbol = new Enum(name, this);
    // Type semantics.
    Type type = Types.Int; // Default to integer.
    if (baseType)
      type = baseType.semantic(scop);
    auto enumType = new EnumType(symbol, type);
    // Set the base type of the enum symbol.
    symbol.setType(enumType);
    if (name)
    { // Insert named enum into scope.
      scop.insert(symbol, symbol.ident);
      // Create new scope.
      scop = scop.push(symbol);
    }
    // Semantic on members.
    foreach (member; members)
    {
      auto value = member.value;
      if (value)
      {
        // value = value.semantic(scop);
        // value = value.evaluate();
      }
      auto variable = new Variable(StorageClass.Const, LinkageType.None, type, member.name, member);
      scop.insert(variable, variable.ident);
    }
    if (name)
      scop.pop();
    +/
    return ed;
  }

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
    if (d.name)
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
    if (d.name)
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

  Declaration visit(VariableDeclaration vd)
  {
    Type type = Types.Undefined;

    if (vd.typeNode)
      // Get type from typeNode.
      type = visitT(vd.typeNode).type;
    else
    { // Infer type from first initializer.
      auto firstInit = vd.values[0];
      firstInit = visitE(firstInit);
      type = firstInit.type;
    }
    //assert(type !is null);

    // Check if we are in an interface.
    if (scop.isInterface)
      return error(vd.begin, MSG.InterfaceCantHaveVariables), vd;

    // Iterate over variable identifiers in this declaration.
    foreach (i, ident; vd.idents)
    {
      // Perform semantic analysis on value.
      if (vd.values[i])
        vd.values[i] = visitE(vd.values[i]);
      // Create a new variable symbol.
      // TODO: pass 'prot' to constructor.
      auto variable = new Variable(vd.stc, vd.linkageType, type, ident, vd);
      vd.variables ~= variable;
      // Add to scope.
      scop.insert(variable);
    }
    return vd;
  }

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

  Declaration visit(ProtectionDeclaration d)
  { visitD(d.decls); return d; }
  Declaration visit(StorageClassDeclaration d)
  { visitD(d.decls); return d; }
  Declaration visit(LinkageDeclaration d)
  { visitD(d.decls); return d; }
  Declaration visit(AlignDeclaration d)
  { visitD(d.decls); return d; }

  Declaration visit(PragmaDeclaration d)
  {
    pragmaSemantic(scop, d.begin, d.ident, d.args);
    visitD(d.decls);
    return d;
  }

  Statement visit(PragmaStatement s)
  {
    pragmaSemantic(scop, s.begin, s.ident, s.args);
    visitS(s.pragmaBody);
    return s;
  }

  Declaration visit(MixinDeclaration)
  { return null; }

  Expression visit(ParenExpression e)
  {
    if (!e.type)
    {
      e.next = visitE(e.next);
      e.type = e.next.type;
    }
    return e;
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

  Expression visit(StringExpression e)
  {
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
