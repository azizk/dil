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
import dil.lexer.Identifier;
import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Types,
       dil.semantic.Scope,
       dil.semantic.Module,
       dil.semantic.Analysis;
import dil.Location;
import dil.Information;
import dil.Messages;
import dil.Enums;
import dil.CompilerInfo;
import common;

class SemanticPass1 : Visitor
{
  Scope scop; /// The current scope.
  Module modul; /// The module to be semantically checked.

  // Attributes:
  LinkageType linkageType;
  Protection protection;
  StorageClass storageClass;
  uint alignSize = DEFAULT_ALIGN_SIZE;

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
    visit(modul.root);
  }

  void enterScope(ScopeSymbol s)
  {
    scop = scop.enter(s);
  }

  void exitScope()
  {
    scop = scop.exit();
  }

  /// Insert a symbol into the current scope.
  void insert(Symbol sym, Identifier* ident)
  {
    auto sym2 = scop.symbol.lookup(ident);
    if (sym2)
      reportSymbolConflict(sym, sym2, ident);
    else
      scop.symbol.insert(sym, ident);
    // Set the current scope symbol as the parent.
    sym.parent = scop.symbol;
  }

  /// Insert a symbol, overloading on the name, into the current scope.
  void insertOverload(Symbol sym, Identifier* ident)
  {
    auto sym2 = scop.symbol.lookup(ident);
    if (sym2)
    {
      if (sym2.isOverloadSet)
        (cast(OverloadSet)cast(void*)sym2).add(sym);
      else
        reportSymbolConflict(sym, sym2, ident);
    }
    else
      // Create a new overload set.
      scop.symbol.insert(new OverloadSet(ident, sym.node), ident);
    // Set the current scope symbol as the parent.
    sym.parent = scop.symbol;
  }

  /// Report error: new symbol s1 conflicts with existing symbol s2.
  void reportSymbolConflict(Symbol s1, Symbol s2, Identifier* ident)
  {
    auto loc = s2.node.begin.getErrorLocation();
    auto locString = Format("{}({},{})", loc.filePath, loc.lineNum, loc.colNum);
    error(s1.node.begin, MSG.DeclConflictsWithDecl, ident.str, locString);
  }

  void error(Token* token, char[] formatMsg, ...)
  {
    auto location = token.getErrorLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    modul.infoMan ~= new SemanticError(location, msg);
  }

  private alias Declaration D;

override
{
  D visit(CompoundDeclaration d)
  {
    foreach (node; d.children)
    {
      assert(node.category == NodeCategory.Declaration, Format("{}", node));
      visitD(cast(Declaration)cast(void*)node);
    }
    return d;
  }

  D visit(IllegalDeclaration)
  { assert(0, "semantic pass on invalid AST"); return null; }

  D visit(EmptyDeclaration ed)
  { return ed; }

  D visit(ModuleDeclaration)
  { return null; }
  D visit(ImportDeclaration)
  { return null; }

  D visit(AliasDeclaration ad)
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

  D visit(TypedefDeclaration td)
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

  D visit(EnumDeclaration d)
  {
    // Create the symbol.
    d.symbol = new Enum(d.name, d);
    if (d.name)
    { // Declare named enum.
      insert(d.symbol, d.name);
      enterScope(d.symbol);
    }
    // Declare members.
    foreach (member; d.members)
    {
      auto variable = new Variable(member.name, protection, storageClass, linkageType, member);
      insert(variable, variable.name);
    }
    if (d.name)
      exitScope();
    return d;
  }

  D visit(EnumMemberDeclaration)
  { return null; }

  D visit(ClassDeclaration d)
  {
    if (d.symbol)
      return d;
    d.symbol = new Class(d.name, d);
    // Insert into current scope.
    if (d.tparams)
      insertOverload(d.symbol, d.name);
    else
      insert(d.symbol, d.name);
    enterScope(d.symbol);
    // Continue semantic analysis.
    d.decls && visitD(d.decls);
    exitScope();
    return d;
  }

  D visit(InterfaceDeclaration d)
  {
    if (d.symbol)
      return d;
    d.symbol = new dil.semantic.Symbols.Interface(d.name, d);
    // Insert into current scope.
    if (d.tparams)
      insertOverload(d.symbol, d.name);
    else
      insert(d.symbol, d.name);
    enterScope(d.symbol);
    // Continue semantic analysis.
    d.decls && visitD(d.decls);
    exitScope();
    return d;
  }

  D visit(StructDeclaration d)
  {
    if (d.symbol)
      return d;
    d.symbol = new Struct(d.name, d);
    // Insert into current scope.
    if (d.name)
    {
      if (d.tparams)
        insertOverload(d.symbol, d.name);
      else
        insert(d.symbol, d.name);
    }
    enterScope(d.symbol);
    // Continue semantic analysis.
    d.decls && visitD(d.decls);
    exitScope();
    return d;
  }

  D visit(UnionDeclaration d)
  {
    if (d.symbol)
      return d;
    d.symbol = new Union(d.name, d);
    // Insert into current scope.
    if (d.name)
    {
      if (d.tparams)
        insertOverload(d.symbol, d.name);
      else
        insert(d.symbol, d.name);
    }
    enterScope(d.symbol);
    // Continue semantic analysis.
    d.decls && visitD(d.decls);
    exitScope();
    return d;
  }

  D visit(ConstructorDeclaration)
  { return null; }
  D visit(StaticConstructorDeclaration)
  { return null; }
  D visit(DestructorDeclaration)
  { return null; }
  D visit(StaticDestructorDeclaration)
  { return null; }
  D visit(FunctionDeclaration)
  { return null; }

  D visit(VariablesDeclaration vd)
  {
    // Error if we are in an interface.
    if (scop.isInterface)
      return error(vd.begin, MSG.InterfaceCantHaveVariables), vd;

    // Insert variable symbols in this declaration into the symbol table.
    foreach (name; vd.names)
    {
      auto variable = new Variable(name, protection, storageClass, linkageType, vd);
      vd.variables ~= variable;
      insert(variable, name);
    }
    return vd;
  }

  D visit(InvariantDeclaration)
  { return null; }
  D visit(UnittestDeclaration)
  { return null; }
  D visit(DebugDeclaration)
  { return null; }
  D visit(VersionDeclaration)
  { return null; }

  D visit(StaticIfDeclaration d)
  {
    visitE(d.condition);
    visitD(d.ifDecls);
    d.elseDecls && visitD(d.elseDecls);
    return null;
  }

  D visit(StaticAssertDeclaration d)
  { return d; } // SP2

  D visit(TemplateDeclaration d)
  {
    if (d.symbol)
      return d;
    d.symbol = new Template(d.name, d);
    // Insert into current scope.
    insertOverload(d.symbol, d.name);
    enterScope(d.symbol);
    // Continue semantic analysis.
    visitD(d.decls);
    exitScope();
    return d;
  }

  D visit(NewDeclaration)
  { /*add id to env*/return null; }
  D visit(DeleteDeclaration)
  { /*add id to env*/return null; }

  D visit(ProtectionDeclaration d)
  {
    auto saved = protection; // Save.
    protection = d.prot; // Set.
    visitD(d.decls);
    protection = saved; // Restore.
    return d;
  }

  D visit(StorageClassDeclaration d)
  {
    auto saved = storageClass; // Save.
    storageClass = d.storageClass; // Set.
    visitD(d.decls);
    storageClass = saved; // Restore.
    return d;
  }

  D visit(LinkageDeclaration d)
  {
    auto saved = linkageType; // Save.
    linkageType = d.linkageType; // Set.
    visitD(d.decls);
    linkageType = saved; // Restore.
    return d;
  }

  D visit(AlignDeclaration d)
  {
    auto saved = alignSize; // Save.
    alignSize = d.size; // Set.
    visitD(d.decls);
    alignSize = saved; // Restore.
    return d;
  }

  D visit(PragmaDeclaration d)
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

  D visit(MixinDeclaration md)
  {
    // Add md to vector of (Scope, MixinDeclaration)
    // and evaluate them in 2nd pass?
    // TODO: store all attributes in md; they have to be applied
    // to the content that is mixed in.
    return md;
  }
} // override
}
