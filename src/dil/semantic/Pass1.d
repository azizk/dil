/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.semantic.Pass1;

import dil.ast.Visitor,
       dil.ast.Node,
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
import dil.lexer.IdTable;
import dil.i18n.Messages;
import dil.Compilation,
       dil.Diagnostics,
       dil.Enums;
import common;

import tango.io.model.IFile;
alias FileConst.PathSeparatorChar dirSep;

/// The first pass is the declaration pass.
///
/// The basic task of this class is to traverse the parse tree,
/// find all kinds of declarations and add them
/// to the symbol tables of their respective scopes.
class SemanticPass1 : Visitor
{
  Scope scop; /// The current scope.
  Module modul; /// The module to be semantically checked.
  CompilationContext context; /// The compilation context.
  Module delegate(cstring) importModule; /// Called when importing a module.

  // Attributes:
  LinkageType linkageType; /// Current linkage type.
  Protection protection; /// Current protection attribute.
  StorageClass storageClass; /// Current storage classes.
  uint alignSize; /// Current align size.

  /// Constructs a SemanticPass1 object.
  /// Params:
  ///   modul = The module to be processed.
  ///   context = The compilation context.
  this(Module modul, CompilationContext context)
  {
    this.modul = modul;
    this.context = new CompilationContext(context);
    this.alignSize = context.structAlign;
  }

  /// Starts processing the module.
  void run()
  {
    assert(modul.root !is null);
    // Create module scope.
    scop = new Scope(null, modul);
    modul.semanticPass = 1;
    visit(modul.root);
  }

  /// Enters a new scope.
  void enterScope(ScopeSymbol s)
  {
    scop = scop.enter(s);
  }

  /// Exits the current scope.
  void exitScope()
  {
    scop = scop.exit();
  }

  /// Returns true if this is the module scope.
  bool isModuleScope()
  {
    return scop.symbol.isModule();
  }

  /// Inserts a symbol into the current scope.
  void insert(Symbol symbol)
  {
    insert(symbol, symbol.name);
  }

  /// Inserts a symbol into the current scope.
  void insert(Symbol symbol, Identifier* name)
  {
    auto symX = scop.symbol.lookup(name);
    if (symX)
      reportSymbolConflict(symbol, symX, name);
    else
      scop.symbol.insert(symbol, name);
    // Set the current scope symbol as the parent.
    symbol.parent = scop.symbol;
  }

  /// Inserts a symbol into scopeSym.
  void insert(Symbol symbol, ScopeSymbol scopeSym)
  {
    auto symX = scopeSym.lookup(symbol.name);
    if (symX)
      reportSymbolConflict(symbol, symX, symbol.name);
    else
      scopeSym.insert(symbol, symbol.name);
    // Set the current scope symbol as the parent.
    symbol.parent = scopeSym;
  }

  /// Inserts a symbol, overloading on the name, into the current scope.
  void insertOverload(Symbol sym)
  {
    auto name = sym.name;
    auto sym2 = scop.symbol.lookup(name);
    if (sym2)
    {
      if (sym2.isOverloadSet)
        (cast(OverloadSet)cast(void*)sym2).add(sym);
      else
        reportSymbolConflict(sym, sym2, name);
    }
    else
      // Create a new overload set.
      scop.symbol.insert(new OverloadSet(name, sym.loc), name);
    // Set the current scope symbol as the parent.
    sym.parent = scop.symbol;
  }

  /// Reports an error: new symbol s1 conflicts with existing symbol s2.
  void reportSymbolConflict(Symbol s1, Symbol s2, Identifier* name)
  {
    auto loc = s2.loc.t.getErrorLocation(modul.filePath());
    auto locString = modul.cc.diag.format("{}({},{})",
      loc.filePath, loc.lineNum, loc.colNum);
    error(s1.loc.t, MID.DeclConflictsWithDecl, name.str, locString);
  }

  /// Creates an error report.
  void error(Token* token, MID mid, ...)
  {
    auto location = token.getErrorLocation(modul.filePath());
    auto msg = modul.cc.diag.formatMsg(mid, _arguments, _argptr);
    modul.cc.diag ~= new SemanticError(location, msg);
  }

  /// Collects info about nodes which have to be evaluated later.
  static class Deferred
  {
    Node node;
    ScopeSymbol symbol;
    // Saved attributes.
    LinkageType linkageType;
    Protection protection;
    StorageClass storageClass;
    uint alignSize;
  }

  /// List of mixin, static if, static assert and pragma(msg,...) declarations.
  ///
  /// Their analysis must be deferred because they entail
  /// evaluation of expressions.
  Deferred[] deferred;

  /// Adds a deferred node to the list.
  void addDeferred(Node node)
  {
    auto d = new Deferred;
    d.node = node;
    d.symbol = scop.symbol;
    d.linkageType = linkageType;
    d.protection = protection;
    d.storageClass = storageClass;
    d.alignSize = alignSize;
    deferred ~= d;
  }

  private alias Declaration D; /// A handy alias. Saves typing.

override
{
  alias super.visit visit;

  D visit(CompoundDecl d)
  {
    foreach (decl; d.decls)
      visitD(decl);
    return d;
  }

  D visit(IllegalDecl)
  { assert(0, "semantic pass on invalid AST"); return null; }

  // D visit(EmptyDecl ed)
  // { return ed; }

  // D visit(ModuleDecl)
  // { return null; }

  D visit(ImportDecl d)
  {
    if (importModule is null)
      return d;
    foreach (moduleFQNPath; d.getModuleFQNs(dirSep))
    {
      auto importedModule = importModule(moduleFQNPath);
      if (importedModule is null)
        error(d.begin, MID.CouldntLoadModule, moduleFQNPath ~ ".d");
      modul.modules ~= importedModule;
    }
    return d;
  }

  D visit(AliasDecl ad)
  {
    return ad;
  }

  D visit(TypedefDecl td)
  {
    return td;
  }

  D visit(EnumDecl d)
  {
    if (d.symbol)
      return d;

    // Create the symbol.
    d.symbol = new EnumSymbol(d.nameId, SLoc(d.name ? d.name : d.begin, d));

    bool isAnonymous = d.symbol.isAnonymous;
    if (isAnonymous)
      d.symbol.name = context.tables.idents.genAnonEnumID();

    insert(d.symbol);

    auto parentScopeSymbol = scop.symbol;
    auto enumSymbol = d.symbol;
    enterScope(d.symbol);
    // Declare members.
    foreach (member; d.members)
    {
      visitD(member);

      if (isAnonymous) // Also insert into parent scope if enum is anonymous.
        insert(member.symbol, parentScopeSymbol);

      member.symbol.type = enumSymbol.type; // Assign TypeEnum.
    }
    exitScope();
    return d;
  }

  D visit(EnumMemberDecl d)
  {
    d.symbol = new EnumMemberSymbol(
      d.name.ident, protection, storageClass, linkageType, SLoc(d.name, d));
    insert(d.symbol);
    return d;
  }

  D visit(ClassDecl d)
  {
    if (d.symbol)
      return d;
    // Create the symbol.
    d.symbol = new ClassSymbol(d.nameId, SLoc(d.name, d));
    // Insert into current scope.
    insert(d.symbol);
    enterScope(d.symbol);
    // Continue semantic analysis.
    d.decls && visitD(d.decls);
    exitScope();
    return d;
  }

  D visit(InterfaceDecl d)
  {
    if (d.symbol)
      return d;
    // Create the symbol.
    d.symbol = new InterfaceSymbol(d.nameId, SLoc(d.name, d));
    // Insert into current scope.
    insert(d.symbol);
    enterScope(d.symbol);
      // Continue semantic analysis.
      d.decls && visitD(d.decls);
    exitScope();
    return d;
  }

  D visit(StructDecl d)
  {
    if (d.symbol)
      return d;
    // Create the symbol.
    d.symbol = new StructSymbol(d.nameId, SLoc(d.name ? d.name : d.begin, d));

    if (d.symbol.isAnonymous)
      d.symbol.name = context.tables.idents.genAnonStructID();
    // Insert into current scope.
    insert(d.symbol);

    enterScope(d.symbol);
      // Continue semantic analysis.
      d.decls && visitD(d.decls);
    exitScope();

    if (d.symbol.isAnonymous)
      // Insert members into parent scope as well.
      foreach (member; d.symbol.members)
        insert(member);
    return d;
  }

  D visit(UnionDecl d)
  {
    if (d.symbol)
      return d;
    // Create the symbol.
    d.symbol = new UnionSymbol(d.nameId, SLoc(d.name ? d.name : d.begin, d));

    if (d.symbol.isAnonymous)
      d.symbol.name = context.tables.idents.genAnonUnionID();

    // Insert into current scope.
    insert(d.symbol);

    enterScope(d.symbol);
      // Continue semantic analysis.
      d.decls && visitD(d.decls);
    exitScope();

    if (d.symbol.isAnonymous)
      // Insert members into parent scope as well.
      foreach (member; d.symbol.members)
        insert(member);
    return d;
  }

  D visit(ConstructorDecl d)
  {
    auto func = new FunctionSymbol(Ident.Ctor, SLoc(d.begin, d));
    insertOverload(func);
    return d;
  }

  D visit(StaticCtorDecl d)
  {
    auto func = new FunctionSymbol(Ident.Ctor, SLoc(d.begin, d));
    insertOverload(func);
    return d;
  }

  D visit(DestructorDecl d)
  {
    auto func = new FunctionSymbol(Ident.Dtor, SLoc(d.begin, d));
    insertOverload(func);
    return d;
  }

  D visit(StaticDtorDecl d)
  {
    auto func = new FunctionSymbol(Ident.Dtor, SLoc(d.begin, d));
    insertOverload(func);
    return d;
  }

  D visit(FunctionDecl d)
  {
    auto func = new FunctionSymbol(d.name.ident, SLoc(d.name, d));
    insertOverload(func);
    return d;
  }

  D visit(VariablesDecl vd)
  {
    // Error if we are in an interface.
    if (scop.symbol.isInterface &&
        !(vd.isStatic || vd.isConst || vd.isManifest))
      return error(vd.begin, MID.InterfaceCantHaveVariables), vd;

    // Insert variable symbols in this declaration into the symbol table.
    vd.variables = new VariableSymbol[vd.names.length];
    foreach (i, name; vd.names)
    {
      auto variable = new VariableSymbol(name.ident, protection, storageClass,
        linkageType, SLoc(name, vd));
      variable.value = vd.inits[i];
      vd.variables[i] = variable;
      insert(variable);
    }
    return vd;
  }

  D visit(InvariantDecl d)
  {
    auto func = new FunctionSymbol(Ident.Invariant, SLoc(d.begin, d));
    insert(func);
    return d;
  }

  D visit(UnittestDecl d)
  {
    auto func = new FunctionSymbol(Ident.Unittest, SLoc(d.begin, d));
    insertOverload(func);
    return d;
  }

  D visit(DebugDecl d)
  {
    if (d.isSpecification)
    { // debug = Id | Int
      if (!isModuleScope())
        error(d.begin, MID.DebugSpecModuleLevel, d.spec.text);
      else if (d.spec.kind == TOK.Identifier)
        context.addDebugId(d.spec.ident.str);
      else
        context.debugLevel = d.spec.uint_;
    }
    else
    { // debug ( Condition )
      if (debugBranchChoice(d.cond, context))
        d.compiledDecls = d.decls;
      else
        d.compiledDecls = d.elseDecls;
      d.compiledDecls && visitD(d.compiledDecls);
    }
    return d;
  }

  D visit(VersionDecl d)
  {
    if (d.isSpecification)
    { // version = Id | Int
      if (!isModuleScope())
        error(d.begin, MID.VersionSpecModuleLevel, d.spec.text);
      else if (d.spec.kind == TOK.Identifier)
        context.addVersionId(d.spec.ident.str);
      else
        context.versionLevel = d.spec.uint_;
    }
    else
    { // version ( Condition )
      if (versionBranchChoice(d.cond, context))
        d.compiledDecls = d.decls;
      else
        d.compiledDecls = d.elseDecls;
      d.compiledDecls && visitD(d.compiledDecls);
    }
    return d;
  }

  D visit(TemplateDecl d)
  {
    if (d.symbol)
      return d;
    // Create the symbol.
    d.symbol = new TemplateSymbol(d.nameId, SLoc(d.name, d));
    // Insert into current scope.
    insertOverload(d.symbol);
    return d;
  }

  D visit(NewDecl d)
  {
    auto func = new FunctionSymbol(Ident.New, SLoc(d.begin, d));
    insert(func);
    return d;
  }

  D visit(DeleteDecl d)
  {
    auto func = new FunctionSymbol(Ident.Delete, SLoc(d.begin, d));
    insert(func);
    return d;
  }

  // Attributes:

  D visit(ProtectionDecl d)
  {
    auto saved = protection; // Save.
    protection = d.prot; // Set.
    visitD(d.decls);
    protection = saved; // Restore.
    return d;
  }

  D visit(StorageClassDecl d)
  {
    auto saved = storageClass; // Save.
    storageClass = d.stc; // Set.
    visitD(d.decls);
    storageClass = saved; // Restore.
    return d;
  }

  D visit(LinkageDecl d)
  {
    auto saved = linkageType; // Save.
    linkageType = d.linkageType; // Set.
    visitD(d.decls);
    linkageType = saved; // Restore.
    return d;
  }

  D visit(AlignDecl d)
  {
    auto saved = alignSize; // Save.
    alignSize = d.size; // Set.
    visitD(d.decls);
    alignSize = saved; // Restore.
    return d;
  }

  // Deferred declarations:

  D visit(StaticAssertDecl d)
  {
    addDeferred(d);
    return d;
  }

  D visit(StaticIfDecl d)
  {
    addDeferred(d);
    return d;
  }

  D visit(MixinDecl d)
  {
    addDeferred(d);
    return d;
  }

  D visit(PragmaDecl d)
  {
    if (d.name.ident is Ident.msg)
      addDeferred(d);
    else
    {
      pragmaSemantic(scop, d.begin, d.name.ident, d.args);
      visitD(d.decls);
    }
    return d;
  }
} // override
}
