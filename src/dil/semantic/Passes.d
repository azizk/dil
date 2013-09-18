/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
/// Description: This module is here for testing
/// a different algorithm to do semantic analysis
/// compared to SemanticPass1 and SemanticPass2!
module dil.semantic.Passes;

import dil.ast.DefaultVisitor,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;
import dil.lexer.IdTable,
       dil.lexer.Keywords;
import dil.parser.Parser;
import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Types,
       dil.semantic.Scope,
       dil.semantic.Module,
       dil.semantic.Analysis;
import dil.code.Interpreter;
import dil.i18n.Messages;
import dil.Compilation,
       dil.SourceText,
       dil.Diagnostics,
       dil.Enums;
import common;

import tango.core.Vararg;

/// Some handy aliases.
private alias D = Declaration;
private alias E = Expression; /// ditto
private alias S = Statement; /// ditto
private alias T = TypeNode; /// ditto
private alias P = Parameter; /// ditto
private alias N = Node; /// ditto

/// A Scope class with added semantic information.
/// (May be merged together with class Scope in the future.)
class SemanticScope
{
  Scope scop; /// The current basic scope.
  Module modul; /// The module to be semantically checked.

  /// Constructs a SemanticScope object.
  /// Params:
  ///   modul = The module to be processed.
  this(Module modul)
  {
    this.modul = modul;
    this.scop = new Scope(null, modul);
  }

  /// Returns the ScopeSymbol of this scope (class/function/etc.)
  ScopeSymbol symbol() @property
  {
    return scop.symbol;
  }

  /// Returns true if this is the module scope.
  bool isModuleScope() @property
  {
    return scop.symbol.isModule();
  }

  void enter(ScopeSymbol s)
  {
    scop = scop.enter(s);
  }

  void exit()
  {
    scop = scop.exit();
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
        sym2.to!(OverloadSet).add(sym);
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
    error(modul, s1.loc.t, MID.DeclConflictsWithDecl, name.str, loc.repr());
  }

  /// Error messages are reported for undefined identifiers if true.
  bool reportUndefinedIds;
  /// Incremented when an undefined identifier was found.
  uint undefinedIdsCount;
  /// The symbol that must be ignored and skipped during a symbol search.
  Symbol ignoreSymbol;
  /// The current scope symbol to use for looking up identifiers.
  ///
  /// E.g.:
  /// ---
  /// / // * "object" is looked up in the current scope.
  /// / // * idScope is set if "object" is a ScopeSymbol.
  /// / // * "method" will be looked up in idScope.
  /// object.method();
  /// / // * "dil" is looked up in the current scope
  /// / // * idScope is set if "dil" is a ScopeSymbol.
  /// / // * "ast" will be looked up in idScope.
  /// / // * idScope is set if "ast" is a ScopeSymbol.
  /// / // * etc.
  /// dil.ast.Node.Node node;
  /// ---
  ScopeSymbol idScope;

  /// The root of the Identifier tree.
  Node rootIdNode;

  /// This object is assigned to idScope when a symbol lookup
  /// returned no valid symbol.
  static ScopeSymbol emptyIdScope;
  static this()
  {
    emptyIdScope = new ScopeSymbol();
  }

  // Sets a new idScope symbol.
  void setIdScope(Symbol symbol)
  {
    if (symbol) {
      if (auto scopSymbol = cast(ScopeSymbol)symbol)
        idScope = scopSymbol;
    }
    else
      idScope = emptyIdScope;
  }

  /// Searches for a symbol.
  Symbol search(Token* idTok)
  {
    assert(idTok.kind == TOK.Identifier);
    auto id = idTok.ident;
    Symbol symbol;

    if (idScope is null)
      // Search in the table of another symbol.
      symbol = ignoreSymbol ?
               scop.search(id, ignoreSymbol) :
               scop.search(id);
    else
      // Search: symbol.id
      symbol = idScope.lookup(id);

    if (!symbol)
    {
      if (reportUndefinedIds)
        error(modul, idTok, MID.UndefinedIdentifier, id.str);
      undefinedIdsCount++;
    }

    return symbol;
  }
}

/// Common interface for semantic passes.
interface SemanticPass
{
  void run();
  void run(SemanticScope scop, Node node);
}

/// The first pass only declares symbols and handles imports.
class FirstSemanticPass : DefaultVisitor2, SemanticPass
{
  Module modul; /// The module to be analyzed.
  SemanticScope scop; /// Which scope to use for this pass.
  ImportDecl[] imports; /// Modules to be imported.
  // Attributes:
  LinkageType linkageType; /// Current linkage type.
  Protection protection; /// Current protection attribute.
  StorageClass storageClass; /// Current storage classes.
  uint alignSize; /// Current align size.


  /// Constructs a SemanticPass object.
  /// Params:
  ///   modul = The module to be processed.
  this(Module modul)
  {
    this.alignSize = modul.cc.structAlign;
    this.modul = modul;
  }

  /// Runs the semantic pass on the module.
  override void run()
  {
    modul.semanticPass = 1;
    run(new SemanticScope(modul), modul.root);
  }

  override void run(SemanticScope scop, Node node)
  {
    this.scop = scop;
    visitN(node);
  }

  /// Looks for special classes and stores them in a table.
  /// May modify d.symbol and assign a SpecialClassSymbol to it.
  void lookForSpecialClasses(ClassDecl d)
  {
    if (!scop.isModuleScope)
      return; // Only consider top-level classes.
    modul.cc.tables.classes.lookForSpecialClasses(modul, d,
      (name, format, ...) => error(modul, _arguments, _argptr, format, name));
  }

  /// Appends the AliasSymbol to a list of the current ScopeSymbol.
  /// Reports an error if it doesn't support "alias this".
  void insertAliasThis(AliasSymbol s)
  {
    if (auto as = cast(AggregateSymbol)scop.symbol)
      as.aliases ~= s;
    else if (auto ts = cast(TemplateSymbol)scop.symbol)
      ts.aliases ~= s;
    else
      error(modul, s.loc.t, "‘alias this’ works only in classes/structs");
  }

  /// Forwards to SemanticScope.
  void enterScope(ScopeSymbol s)
  {
    scop.enter(s);
  }
  /// ditto
  void exitScope()
  {
    scop.exit();
  }
  /// ditto
  void insert(Symbol s)
  {
    scop.insert(s);
  }
  /// ditto
  void insert(Symbol s, Identifier* name)
  {
    scop.insert(s, name);
  }
  /// ditto
  void insert(Symbol s, ScopeSymbol ss)
  {
    scop.insert(s, ss);
  }
  /// ditto
  void insertOverload(Symbol s)
  {
    scop.insertOverload(s);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                Declarations                               |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  //alias visit = super.visit;

  void visit(CompoundDecl d)
  {
    foreach (decl; d.decls)
      visitD(decl);
  }

  void visit(IllegalDecl)
  { assert(0, "semantic pass on invalid AST"); }

  // void visit(EmptyDecl ed)
  // {}

  // void visit(ModuleDecl)
  // {}

  void visit(ImportDecl d)
  {
    imports ~= d;
  }

  void visit(AliasDecl d)
  {
    auto vd = d.vardecl.to!(VariablesDecl);
    d.symbols = new AliasSymbol[vd.names.length];
    // Insert alias symbols in this declaration into the symbol table.
    foreach (i, name; vd.names)
      insert(d.symbols[i] = new AliasSymbol(name.ident, SLoc(name, d)));
  }

  void visit(AliasesDecl d)
  {
    d.symbols = new AliasSymbol[d.idents.length];
    // Insert alias symbols in this declaration into the symbol table.
    foreach (i, name; d.idents)
    {
      auto s = d.symbols[i] = new AliasSymbol(name.ident, SLoc(name, d));
      if (name.ident is Keyword.This)
        insertAliasThis(s);
      else
        insert(s);
    }
  }

  void visit(AliasThisDecl d)
  {
    insertAliasThis(d.symbol = new AliasSymbol(d.name.ident, SLoc(d.name, d)));
  }

  void visit(TypedefDecl d)
  {
    auto vd = d.vardecl.to!(VariablesDecl);
    d.symbols = new TypedefSymbol[vd.names.length];
    // Insert typedef symbols in this declaration into the symbol table.
    foreach (i, name; vd.names)
      insert(d.symbols[i] = new TypedefSymbol(name.ident, SLoc(name, d)));
  }

  void visit(EnumDecl d)
  {
    if (d.symbol)
      return;
    // Create the symbol.
    d.symbol = new EnumSymbol(d.nameId, SLoc(d.name ? d.name : d.begin, d));
    bool isAnonymous = d.symbol.isAnonymous;
    if (isAnonymous)
      d.symbol.name = modul.cc.tables.idents.genAnonEnumID();
    insert(d.symbol);
    // Visit members.
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
  }

  void visit(EnumMemberDecl d)
  {
    d.symbol = new EnumMemberSymbol(
      d.name.ident, protection, storageClass, linkageType, SLoc(d.name, d));
    insert(d.symbol);
  }

  void visit(ClassDecl d)
  {
    if (d.symbol)
      return;
    // Create the symbol.
    d.symbol = new ClassSymbol(d.nameId, SLoc(d.name, d));
    lookForSpecialClasses(d);
    // Insert into current scope.
    insert(d.symbol);
    enterScope(d.symbol);
    // Continue semantic analysis.
    d.decls && visitD(d.decls);
    exitScope();
  }

  void visit(InterfaceDecl d)
  {
    if (d.symbol)
      return;
    // Create the symbol.
    d.symbol = new InterfaceSymbol(d.nameId, SLoc(d.name, d));
    // Insert into current scope.
    insert(d.symbol);
    enterScope(d.symbol);
      // Continue semantic analysis.
      d.decls && visitD(d.decls);
    exitScope();
  }

  void visit(StructDecl d)
  {
    auto s = d.symbol;
    if (s)
      return;
    // Create the symbol.
    auto loc = SLoc(d.name ? d.name : d.begin, d);
    s = d.symbol = new StructSymbol(d.nameId, loc);
    if (s.isAnonymous)
      s.name = modul.cc.tables.idents.genAnonStructID();
    // Insert into current scope.
    insert(s);
    enterScope(s);
      // Continue semantic analysis.
      d.decls && visitD(d.decls);
    exitScope();
    if (s.isAnonymous)
      // Insert members into parent scope as well.
      foreach (member; s.members)
        insert(member);
  }

  void visit(UnionDecl d)
  {
    auto s = d.symbol;
    if (s)
      return;
    // Create the symbol.
    auto loc = SLoc(d.name ? d.name : d.begin, d);
    s = d.symbol = new UnionSymbol(d.nameId, loc);
    if (s.isAnonymous)
      s.name = modul.cc.tables.idents.genAnonUnionID();
    // Insert into current scope.
    insert(s);
    enterScope(s);
      // Continue semantic analysis.
      d.decls && visitD(d.decls);
    exitScope();
    if (s.isAnonymous)
      // Insert members into parent scope as well.
      foreach (member; s.members)
        insert(member);
  }

  void visit(ConstructorDecl d)
  {
    auto func = new FunctionSymbol(Ident.Ctor, SLoc(d.begin, d));
    insertOverload(func);
    enterScope(func);
    visitN(d.funcBody);
    exitScope();
  }

  void visit(StaticCtorDecl d)
  {
    auto func = new FunctionSymbol(Ident.Ctor, SLoc(d.begin, d));
    func.type = Types.Void_0Args_DFunc;
    insertOverload(func);
    enterScope(func);
    visitN(d.funcBody);
    exitScope();
  }

  void visit(DestructorDecl d)
  {
    auto func = new FunctionSymbol(Ident.Dtor, SLoc(d.begin, d));
    func.type = Types.Void_0Args_DFunc;
    insertOverload(func);
    enterScope(func);
    visitN(d.funcBody);
    exitScope();
  }

  void visit(StaticDtorDecl d)
  {
    auto func = new FunctionSymbol(Ident.Dtor, SLoc(d.begin, d));
    func.type = Types.Void_0Args_DFunc;
    insertOverload(func);
    enterScope(func);
    visitN(d.funcBody);
    exitScope();
  }

  void visit(FunctionDecl d)
  {
    auto func = new FunctionSymbol(d.name.ident, SLoc(d.name, d));
    insertOverload(func);
    enterScope(func);
    visitN(d.funcBody);
    exitScope();
  }

  void visit(VariablesDecl vd)
  { // Error if we are in an interface.
    if (scop.symbol.isInterface &&
        !(vd.isStatic || vd.isConst || vd.isManifest))
      return error(modul, vd, MID.InterfaceCantHaveVariables);
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
  }

  void visit(InvariantDecl d)
  {
    auto func = new FunctionSymbol(Ident.Invariant, SLoc(d.begin, d));
    insert(func);
    enterScope(func);
    visitN(d.funcBody);
    exitScope();
  }

  void visit(UnittestDecl d)
  {
    if (!modul.cc.unittestBuild)
      return;
    // TODO: generate anonymous unittest id?
    auto func = new FunctionSymbol(Ident.Unittest, SLoc(d.begin, d));
    func.type = Types.Void_0Args_DFunc;
    insertOverload(func);
    enterScope(func);
    visitN(d.funcBody);
    exitScope();
  }

  void visit(DebugDecl d)
  {
    if (d.isSpecification)
    { // debug = Id | Int
      if (!scop.isModuleScope)
        error(modul, d, MID.DebugSpecModuleLevel, d.spec.text);
      else if (d.spec.kind == TOK.Identifier)
        modul.cc.addDebugId(d.spec.ident.str);
      else
        modul.cc.debugLevel = d.spec.uint_;
    }
    else
    { // debug ( Condition )
      if (debugBranchChoice(d.cond, modul.cc))
        d.compiledDecls = d.decls;
      else
        d.compiledDecls = d.elseDecls;
      d.compiledDecls && visitD(d.compiledDecls);
    }
  }

  void visit(VersionDecl d)
  {
    if (d.isSpecification)
    { // version = Id | Int
      if (!scop.isModuleScope)
        error(modul, d, MID.VersionSpecModuleLevel, d.spec.text);
      else if (d.spec.kind == TOK.Identifier)
        modul.cc.addVersionId(d.spec.ident.str);
      else
        modul.cc.versionLevel = d.spec.uint_;
    }
    else
    { // version ( Condition )
      if (versionBranchChoice(d.cond, modul.cc))
        d.compiledDecls = d.decls;
      else
        d.compiledDecls = d.elseDecls;
      d.compiledDecls && visitD(d.compiledDecls);
    }
  }

  void visit(TemplateDecl d)
  {
    if (d.symbol)
      return;
    // Create the symbol.
    d.symbol = new TemplateSymbol(d.nameId, SLoc(d.name, d));
    // Insert into current scope.
    insertOverload(d.symbol);
    enterScope(d.symbol);
    // Declare template parameters.
    visitN(d.tparams);
    // Continue with the declarations inside.
    d.decls && visitD(d.decls);
    exitScope();
  }

  void visit(NewDecl d)
  {
    auto func = new FunctionSymbol(Ident.New, SLoc(d.begin, d));
    insert(func);
    enterScope(func);
    visitN(d.funcBody);
    exitScope();
  }

  void visit(DeleteDecl d)
  {
    auto func = new FunctionSymbol(Ident.Delete, SLoc(d.begin, d));
    insert(func);
    enterScope(func);
    visitN(d.funcBody);
    exitScope();
  }

  // Attributes:

  void visit(ProtectionDecl d)
  {
    auto saved = protection; // Save.
    protection = d.prot; // Set.
    visitD(d.decls);
    protection = saved; // Restore.
  }

  void visit(StorageClassDecl d)
  {
    auto saved = storageClass; // Save.
    storageClass = d.stc; // Set.
    visitD(d.decls);
    storageClass = saved; // Restore.
  }

  void visit(LinkageDecl d)
  {
    auto saved = linkageType; // Save.
    linkageType = d.linkageType; // Set.
    visitD(d.decls);
    linkageType = saved; // Restore.
  }

  void visit(AlignDecl d)
  {
    auto saved = alignSize; // Save.
    alignSize = d.size; // Set.
    visitD(d.decls);
    alignSize = saved; // Restore.
  }
} // override
}


/// The second pass resolves variable types, base classes,
/// evaluates static ifs/asserts etc.
class SecondSemanticPass : DefaultVisitor, SemanticPass
{
  Module modul;
  SemanticScope scop;
  Interpreter ip; /// Used to evaluate expressions.

  this(Module modul)
  {
    this.modul = modul;
    this.ip = new Interpreter(modul.cc.diag);
  }

  /// Runs the semantic pass on the module.
  override void run()
  {
    modul.semanticPass = 2;
    run(new SemanticScope(modul), modul.root);
  }

  override void run(SemanticScope scop, Node node)
  {
    this.scop = scop;
    visitN(node);
  }

  Symbol search(Token* idTok)
  {
    return scop.search(idTok);
  }

override
{
  D visit(CompoundDecl d)
  {
    foreach (decl; d.decls)
      visitD(decl);
    return d;
  }

  D visit(AliasDecl d)
  {
    return d;
  }

  D visit(TypedefDecl d)
  {
    return d;
  }

  D visit(EnumDecl d)
  {
    return d;
  }

  D visit(EnumMemberDecl d)
  {
    return d;
  }

  D visit(ClassDecl d)
  {
    return d;
  }

  D visit(InterfaceDecl d)
  {
    return d;
  }

  D visit(StructDecl d)
  {
    return d;
  }

  D visit(UnionDecl d)
  {
    return d;
  }

  D visit(ConstructorDecl d)
  {
    return d;
  }

  D visit(StaticCtorDecl d)
  {
    return d;
  }

  D visit(DestructorDecl d)
  {
    return d;
  }

  D visit(StaticDtorDecl d)
  {
    return d;
  }

  D visit(FunctionDecl d)
  {
    return d;
  }

  D visit(VariablesDecl d)
  {
    return d;
  }

  D visit(InvariantDecl d)
  {
    return d;
  }

  D visit(UnittestDecl d)
  {
    return d;
  }

  D visit(TemplateDecl d)
  {
    return d;
  }

  D visit(NewDecl d)
  {
    return d;
  }

  D visit(DeleteDecl d)
  {
    return d;
  }

  D visit(StaticAssertDecl d)
  {
    d.condition = visitE(d.condition);
    if (d.condition.isChecked())
    {
      auto r = ip.eval(d.condition);
      if (r !is Interpreter.NAR && ip.EM.isBool(r) == 0)
      {
        cstring errorMsg = "static assert is false";
        if (d.message)
        {
          d.message = visitE(d.message);
          r = ip.eval(d.message);
          auto se = r.Is!(StringExpr);
          if (se) // TODO: allow non-string expressions?
            errorMsg = se.getString();
        }
        error(modul, d, errorMsg);
      }
    }
    return d;
  }

  D visit(StaticIfDecl d)
  {
    // Eval condition
    return d;
  }

  D visit(MixinDecl d)
  {
    // Eval d.argument
    return d;
  }

  D visit(PragmaDecl d)
  {
    if (d.name.ident is Ident.msg)
    { // Write arguments to standard output.
      foreach (arg; d.args)
      {
        cstring msg;
        arg = visitE(arg);
        auto r = ip.eval(arg);
        if (auto se = r.Is!(StringExpr))
          msg = se.getString();
        else
          msg = "FIXME: can't print AST yet"; // = astPrinter.print(r)
        Stdout(msg);
      }
    }
    else
    {
      pragmaSemantic(scop.scop, d.begin, d.name.ident, d.args);
      visitD(d.decls);
    }
    return d;
  }
} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                 Statements                                |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// The current surrounding, breakable statement.
  S breakableStmt;

  S setBS(S s)
  {
    auto old = breakableStmt;
    breakableStmt = s;
    return old;
  }

  void restoreBS(S s)
  {
    breakableStmt = s;
  }

override
{
  S visit(CompoundStmt s)
  {
    foreach (stmnt; s.stmnts)
      visitS(stmnt);
    return s;
  }

  S visit(IllegalStmt)
  { assert(0, "semantic pass on invalid AST"); return null; }

  S visit(EmptyStmt s)
  {
    return s;
  }

  S visit(FuncBodyStmt s)
  {
    return s;
  }

  S visit(ScopeStmt s)
  {
//     enterScope();
    visitS(s.stmnt);
//     exitScope();
    return s;
  }

  S visit(LabeledStmt s)
  {
    return s;
  }

  S visit(ExpressionStmt s)
  {
    return s;
  }

  S visit(DeclarationStmt s)
  {
    return s;
  }

  S visit(IfStmt s)
  {
    return s;
  }

  S visit(WhileStmt s)
  {
    auto saved = setBS(s);
    // TODO:
    restoreBS(saved);
    return s;
  }

  S visit(DoWhileStmt s)
  {
    auto saved = setBS(s);
    // TODO:
    restoreBS(saved);
    return s;
  }

  S visit(ForStmt s)
  {
    auto saved = setBS(s);
    // TODO:
    restoreBS(saved);
    return s;
  }

  S visit(ForeachStmt s)
  {
    auto saved = setBS(s);
    // TODO:
    // find overload opApply or opApplyReverse.
    restoreBS(saved);
    return s;
  }

  S visit(SwitchStmt s)
  {
    auto saved = setBS(s);
    // TODO:
    restoreBS(saved);
    return s;
  }

  S visit(CaseStmt s)
  {
    auto saved = setBS(s);
    // TODO:
    restoreBS(saved);
    return s;
  }

  S visit(DefaultStmt s)
  {
    auto saved = setBS(s);
    // TODO:
    restoreBS(saved);
    return s;
  }

  S visit(ContinueStmt s)
  {
    return s;
  }

  S visit(BreakStmt s)
  {
    return s;
  }

  S visit(ReturnStmt s)
  {
    return s;
  }

  S visit(GotoStmt s)
  {
    return s;
  }

  S visit(WithStmt s)
  {
    return s;
  }

  S visit(SynchronizedStmt s)
  {
    return s;
  }

  S visit(TryStmt s)
  {
    return s;
  }

  S visit(CatchStmt s)
  {
    return s;
  }

  S visit(FinallyStmt s)
  {
    return s;
  }

  S visit(ScopeGuardStmt s)
  {
    return s;
  }

  S visit(ThrowStmt s)
  {
    return s;
  }

  S visit(VolatileStmt s)
  {
    return s;
  }

  S visit(AsmBlockStmt s)
  {
    foreach (stmnt; s.statements.stmnts)
      visitS(stmnt);
    return s;
  }

  S visit(AsmStmt s)
  {
    return s;
  }

  S visit(AsmAlignStmt s)
  {
    return s;
  }

  S visit(IllegalAsmStmt)
  { assert(0, "semantic pass on invalid AST"); return null; }

  S visit(PragmaStmt s)
  {
    return s;
  }

  S visit(MixinStmt s)
  {
    return s;
  }

  S visit(StaticIfStmt s)
  {
    return s;
  }

  S visit(StaticAssertStmt s)
  {
    return s;
  }

  S visit(DebugStmt s)
  {
    return s;
  }

  S visit(VersionStmt s)
  {
    return s;
  }
} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                Expressions                                |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// Determines whether to issue an error when a symbol couldn't be found.
  bool errorOnUndefinedSymbol;
  //bool errorOnUnknownSymbol;

  /// Reports an error if the type of e is not bool.
  void errorIfBool(Expression e)
  {
    assert(e.type !is null);
    if (e.type.isBaseBool())
      error(modul, e, "the operation is undefined for type bool");
  }

  /// Reports an error if e has no boolean result.
  void errorIfNonBool(Expression e)
  {
    assert(e.type !is null);
    switch (e.kind)
    {
    case NodeKind.DeleteExpr:
      error(modul, e, "the delete operator has no boolean result");
      break;
    case NodeKind.AssignExpr:
      error(modul, e, "the assignment operator '=' has no boolean result");
      break;
    case NodeKind.CondExpr:
      auto cond = e.to!(CondExpr);
      errorIfNonBool(cond.lhs);
      errorIfNonBool(cond.rhs);
      break;
    default:
      if (!e.type.isBaseScalar()) // Only scalar types can be bool.
        error(modul, e, "expression has no boolean result");
    }
  }

  /// Returns a call expression if 'e' overrides
  /// an operatorwith the name 'id'.
  /// Params:
  ///   e = The binary expression to be checked.
  ///   id = The name of the overload function.
  Expression findOverload(UnaryExpr e, Identifier* id)
  {
    // TODO:
    // check e for struct or class
    // search for function named id
    // return call expression: e.opXYZ()
    return null;
  }

  /// Returns a call expression if 'e' overrides
  /// an operator with the name 'id' or 'id_r'.
  /// Params:
  ///   e = The binary expression to be checked.
  ///   id = The name of the overload function.
  ///   id_r = The name of the reverse overload function.
  Expression findOverload(BinaryExpr e, Identifier* id, Identifier* id_r)
  {
    // TODO:
    return null;
  }

  /// Visit the operands of a binary operator.
  void visitBinary(BinaryExpr e)
  {
    e.lhs = visitE(e.lhs);
    e.rhs = visitE(e.rhs);
  }

override
{
  E visit(IllegalExpr)
  { assert(0, "semantic pass on invalid AST"); return null; }

  E visit(CondExpr e)
  {
    return e;
  }

  E visit(CommaExpr e)
  {
    if (!e.isChecked)
    {
      e.lhs = visitE(e.lhs);
      e.rhs = visitE(e.rhs);
      e.type = e.rhs.type; // Take the type of the right hand side.
    }
    return e;
  }

  E visit(OrOrExpr e)
  {
    if (!e.isChecked)
    {
      e.lhs = visitE(e.lhs);
      errorIfNonBool(e.lhs); // Left operand must be bool.
      e.rhs = visitE(e.rhs);
      if (e.rhs.type is Types.Void)
        e.type = Types.Void; // According to spec.
      else
        (e.type = Types.Bool), // Otherwise type is bool and
        errorIfNonBool(e.rhs); // right operand must be bool.
    }
    return e;
  }

  E visit(AndAndExpr e)
  {
    if (!e.isChecked)
    {
      e.lhs = visitE(e.lhs);
      errorIfNonBool(e.lhs); // Left operand must be bool.
      e.rhs = visitE(e.rhs);
      if (e.rhs.type is Types.Void)
        e.type = Types.Void; // According to spec.
      else
        (e.type = Types.Bool), // Otherwise type is bool and
        errorIfNonBool(e.rhs); // right operand must be bool.
    }
    return e;
  }

  E visit(OrExpr e)
  {
    if (auto o = findOverload(e, Ident.opOr, Ident.opOr_r))
      return o;
    return e;
  }

  E visit(XorExpr e)
  {
    if (auto o = findOverload(e, Ident.opXor, Ident.opXor_r))
      return o;
    return e;
  }

  E visit(AndExpr e)
  {
    if (auto o = findOverload(e, Ident.opAnd, Ident.opAnd_r))
      return o;
    return e;
  }

  E visit(EqualExpr e)
  {
    visitBinary(e);
    if (auto o = findOverload(e, Ident.opEquals, null))
      return o;
    // TODO:
    e.type = Types.Bool;
    return e;
  }

  E visit(IdentityExpr e)
  {
    return e;
  }

  E visit(RelExpr e)
  {
    visitBinary(e);
    if (auto o = findOverload(e, Ident.opCmp, null))
      return o;
    // TODO: check for more errors?
    if (e.lhs.type.isBaseComplex() || e.rhs.type.isBaseComplex())
    {
      auto whichOp = e.lhs.type.isBaseComplex() ? e.lhs.begin : e.rhs.begin;
      error(modul, whichOp,
        "the operator '{}' is undefined for complex numbers", e.optok.text);
    }
    e.type = Types.Bool;
    return e;
  }

  E visit(InExpr e)
  {
    visitBinary(e);
    if (auto o = findOverload(e, Ident.opIn, Ident.opIn_r))
      return o;
    if (!e.rhs.type.baseType().isAArray())
    {
      error(modul, e.rhs,
        "right operand of 'in' operator must be an associative array");
      // Don't use Types.Error. Cascading error msgs are irritating.
      e.type = e.rhs.type;
    }
    else
      // Result type is pointer to element type of AA.
      e.type = e.rhs.type.next.ptrTo();
    return e;
  }

  E visit(LShiftExpr e)
  {
    if (auto o = findOverload(e, Ident.opShl, Ident.opShl_r))
      return o;
    return e;
  }

  E visit(RShiftExpr e)
  {
    if (auto o = findOverload(e, Ident.opShr, Ident.opShr_r))
      return o;
    return e;
  }

  E visit(URShiftExpr e)
  {
    if (auto o = findOverload(e, Ident.opUShr, Ident.opUShr_r))
      return o;
    return e;
  }

  E visit(PlusExpr e)
  {
    if (auto o = findOverload(e, Ident.opAdd, Ident.opAdd_r))
      return o;
    return e;
  }

  E visit(MinusExpr e)
  {
    if (auto o = findOverload(e, Ident.opSub, Ident.opSub_r))
      return o;
    return e;
  }

  E visit(CatExpr e)
  {
    visitBinary(e);
    if (auto o = findOverload(e, Ident.opCat, Ident.opCat_r))
      return o;
    // Need to check the base types if they are arrays.
    // This will allow for concatenating typedef types:
    // typedef Handle[] Handles; Handles hlist; hlist ~ element;
    auto tl = e.lhs.type.baseType(),
         tr = e.rhs.type.baseType();
    if (tl.isDorSArray() || tr.isDorSArray())
    {
      // TODO:
      // e.type = ;
    }
    else
    {
      error(modul, e.optok,
        "concatenation operator '~' is undefined for: {} ~ {}", e.lhs, e.rhs);
      e.type = e.lhs.type; // Use Types.Error if e.lhs.type is not a good idea.
    }
    return e;
  }

  E visit(MulExpr e)
  {
    if (auto o = findOverload(e, Ident.opMul, Ident.opMul_r))
      return o;
    return e;
  }

  E visit(DivExpr e)
  {
    if (auto o = findOverload(e, Ident.opDiv, Ident.opDiv_r))
      return o;
    return e;
  }

  E visit(ModExpr e)
  {
    if (auto o = findOverload(e, Ident.opMod, Ident.opMod_r))
      return o;
    return e;
  }

  E visit(AssignExpr e)
  {
    if (auto o = findOverload(e, Ident.opAssign, null))
      return o;
    // TODO: also check for opIndexAssign and opSliceAssign.
    return e;
  }

  E visit(LShiftAssignExpr e)
  {
    if (auto o = findOverload(e, Ident.opShlAssign, null))
      return o;
    return e;
  }

  E visit(RShiftAssignExpr e)
  {
    if (auto o = findOverload(e, Ident.opShrAssign, null))
      return o;
    return e;
  }

  E visit(URShiftAssignExpr e)
  {
    if (auto o = findOverload(e, Ident.opUShrAssign, null))
      return o;
    return e;
  }

  E visit(OrAssignExpr e)
  {
    if (auto o = findOverload(e, Ident.opOrAssign, null))
      return o;
    return e;
  }

  E visit(AndAssignExpr e)
  {
    if (auto o = findOverload(e, Ident.opAndAssign, null))
      return o;
    return e;
  }

  E visit(PlusAssignExpr e)
  {
    if (auto o = findOverload(e, Ident.opAddAssign, null))
      return o;
    return e;
  }

  E visit(MinusAssignExpr e)
  {
    if (auto o = findOverload(e, Ident.opSubAssign, null))
      return o;
    return e;
  }

  E visit(DivAssignExpr e)
  {
    auto o = findOverload(e, Ident.opDivAssign, null);
    if (o)
      return o;
    return e;
  }

  E visit(MulAssignExpr e)
  {
    auto o = findOverload(e, Ident.opMulAssign, null);
    if (o)
      return o;
    return e;
  }

  E visit(ModAssignExpr e)
  {
    auto o = findOverload(e, Ident.opModAssign, null);
    if (o)
      return o;
    return e;
  }

  E visit(XorAssignExpr e)
  {
    auto o = findOverload(e, Ident.opXorAssign, null);
    if (o)
      return o;
    return e;
  }

  E visit(CatAssignExpr e)
  {
    auto o = findOverload(e, Ident.opCatAssign, null);
    if (o)
      return o;
    return e;
  }

  E visit(AddressExpr e)
  {
    if (e.isChecked)
      return e;
    e.una = visitE(e.una);
    e.type = e.una.type.ptrTo();
    return e;
  }

  E visit(PreIncrExpr e)
  {
    if (e.isChecked)
      return e;
    // TODO: rewrite to e+=1
    e.una = visitE(e.una);
    e.type = e.una.type;
    errorIfBool(e.una);
    return e;
  }

  E visit(PreDecrExpr e)
  {
    if (e.isChecked)
      return e;
    // TODO: rewrite to e-=1
    e.una = visitE(e.una);
    e.type = e.una.type;
    errorIfBool(e.una);
    return e;
  }

  E visit(PostIncrExpr e)
  {
    if (e.isChecked)
      return e;
    if (auto o = findOverload(e, Ident.opPostInc))
      return o;
    e.una = visitE(e.una);
    e.type = e.una.type;
    errorIfBool(e.una);
    return e;
  }

  E visit(PostDecrExpr e)
  {
    if (e.isChecked)
      return e;
    if (auto o = findOverload(e, Ident.opPostDec))
      return o;
    e.una = visitE(e.una);
    e.type = e.una.type;
    errorIfBool(e.una);
    return e;
  }

  E visit(DerefExpr e)
  {
    if (e.isChecked)
      return e;
  version(D2)
    if (auto o = findOverload(e, Ident.opStar))
      return o;
    e.una = visitE(e.una);
    e.type = e.una.type.next;
    if (!e.una.type.isPointer)
    {
      error(modul, e.una,
        "dereference operator '*x' not defined for expression of type '{}'",
        e.una.type.toString());
      e.type = Types.Error;
    }
    // TODO:
    // if (e.una.type.isVoid)
    //   error();
    return e;
  }

  E visit(SignExpr e)
  {
    if (e.isChecked)
      return e;
    if (auto o = findOverload(e, e.isNeg ? Ident.opNeg : Ident.opPos))
      return o;
    e.una = visitE(e.una);
    e.type = e.una.type;
    errorIfBool(e.una);
    return e;
  }

  E visit(NotExpr e)
  {
    if (e.isChecked)
      return e;
    e.una = visitE(e.una);
    e.type = Types.Bool;
    errorIfNonBool(e.una);
    return e;
  }

  E visit(CompExpr e)
  {
    if (e.isChecked)
      return e;
    if (auto o = findOverload(e, Ident.opCom))
      return o;
    e.una = visitE(e.una);
    e.type = e.una.type;
    if (e.type.isBaseFloating() || e.type.isBaseBool())
    {
      error(modul, e, "the operator '~x' is undefined for the type '{}'",
            e.type.toString());
      e.type = Types.Error;
    }
    return e;
  }

  E visit(CallExpr e)
  {
    if (auto o = findOverload(e, Ident.opCall))
      return o;
    return e;
  }

  E visit(NewExpr e)
  {
    return e;
  }

  E visit(NewClassExpr e)
  {
    return e;
  }

  E visit(DeleteExpr e)
  {
    return e;
  }

  E visit(CastExpr e)
  {
    if (auto o = findOverload(e, Ident.opCast))
      return o;
    return e;
  }

  E visit(IndexExpr e)
  {
    if (auto o = findOverload(e, Ident.opIndex))
      return o;
    return e;
  }

  E visit(SliceExpr e)
  {
    if (auto o = findOverload(e, Ident.opSlice))
      return o;
    return e;
  }

  E visit(ModuleScopeExpr e)
  {
    return e;
  }

  E visit(IdentifierExpr e)
  {
    if (e.isChecked)
      return e;
    debug(sema) Stdout.formatln("", e);
    e.symbol = search(e.name);
    return e;
  }

  E visit(TmplInstanceExpr e)
  {
    if (e.isChecked)
      return e;
    debug(sema) Stdout.formatln("", e);
    e.symbol = search(e.name);
    return e;
  }

  E visit(SpecialTokenExpr e)
  {
    if (e.isChecked)
      return e.value;
    switch (e.specialToken.kind)
    {
    case TOK.LINE, TOK.VERSION:
      e.value = new IntExpr(e.specialToken.uint_, Types.UInt32);
      break;
    case TOK.FILE, TOK.DATE, TOK.TIME, TOK.TIMESTAMP, TOK.VENDOR:
      e.value = new StringExpr(e.specialToken.strval.str);
      break;
    default:
      assert(0);
    }
    e.type = e.value.type;
    return e.value;
  }

  E visit(ThisExpr e)
  {
    return e;
  }

  E visit(SuperExpr e)
  {
    return e;
  }

  E visit(NullExpr e)
  {
    if (!e.isChecked)
      e.type = Types.Void_ptr;
    return e;
  }

  E visit(DollarExpr e)
  {
    if (e.isChecked)
      return e;
    e.type = modul.cc.tables.types.Size_t;
    // if (!inArraySubscript)
    //   error("$ can only be in an array subscript.");
    return e;
  }

  E visit(BoolExpr e)
  {
    assert(e.isChecked);
    return e.value;
  }

  E visit(IntExpr e)
  {
    if (e.isChecked)
      return e;

    if (e.number & 0x8000_0000_0000_0000)
      e.type = Types.UInt64; // 0xFFFF_FFFF_FFFF_FFFF
    else if (e.number & 0xFFFF_FFFF_0000_0000)
      e.type = Types.Int64; // 0x7FFF_FFFF_FFFF_FFFF
    else if (e.number & 0x8000_0000)
      e.type = Types.UInt32; // 0xFFFF_FFFF
    else
      e.type = Types.Int32; // 0x7FFF_FFFF
    return e;
  }

  E visit(FloatExpr e)
  {
    if (!e.isChecked)
      e.type = Types.Float64;
    return e;
  }

  E visit(ComplexExpr e)
  {
    if (!e.isChecked)
      e.type = Types.CFloat64;
    return e;
  }

  E visit(CharExpr e)
  {
    assert(e.isChecked);
    return e.value;
  }

  E visit(StringExpr e)
  {
    assert(e.isChecked);
    return e;
  }

  E visit(ArrayLiteralExpr e)
  {
    return e;
  }

  E visit(AArrayLiteralExpr e)
  {
    return e;
  }

  E visit(AssertExpr e)
  {
    return e;
  }

  E visit(MixinExpr e)
  {
    return e;
  }

  E visit(ImportExpr e)
  {
    return e;
  }

  E visit(TypeofExpr e)
  {
    return e;
  }

  E visit(TypeDotIdExpr e)
  {
    return e;
  }

  E visit(TypeidExpr e)
  {
    return e;
  }

  E visit(IsExpr e)
  {
    return e;
  }

  E visit(ParenExpr e)
  {
    if (!e.isChecked)
    {
      e.next = visitE(e.next);
      e.type = e.next.type;
    }
    return e;
  }

  E visit(FuncLiteralExpr e)
  {
    return e;
  }

  E visit(LambdaExpr e)
  {
    return e;
  }

  E visit(TraitsExpr e) // D2.0
  {
    return e;
  }

  E visit(VoidInitExpr e)
  {
    return e;
  }

  E visit(ArrayInitExpr e)
  {
    return e;
  }

  E visit(StructInitExpr e)
  {
    return e;
  }

  E visit(AsmTypeExpr e)
  {
    return e;
  }

  E visit(AsmOffsetExpr e)
  {
    return e;
  }

  E visit(AsmSegExpr e)
  {
    return e;
  }

  E visit(AsmPostBracketExpr e)
  {
    return e;
  }

  E visit(AsmBracketExpr e)
  {
    return e;
  }

  E visit(AsmLocalSizeExpr e)
  {
    return e;
  }

  E visit(AsmRegisterExpr e)
  {
    return e;
  }
} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                   Types                                   |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  T visit(IllegalType)
  { assert(0, "semantic pass on invalid AST"); return null; }

  T visit(IntegralType t)
  {
    t.type = Types.fromTOK(t.tok);
    return t;
  }

  T visit(ModuleScopeType t)
  {
    return t;
  }

  T visit(IdentifierType t)
  {
    //auto idToken = t.begin;
    //auto symbol = search(idToken);
    // TODO: save symbol or its type in t.
    return t;
  }

  T visit(TypeofType t)
  {
    t.expr = visitE(t.expr);
    t.type = t.expr.type;
    return t;
  }

  T visit(TmplInstanceType t)
  {
    auto idToken = t.begin;
    auto symbol = search(idToken);
    // TODO: save symbol or its type in t.
    return t;
  }

  T visit(PointerType t)
  {
    t.type = visitT(t.next).type.ptrTo();
    return t;
  }

  T visit(ArrayType t)
  {
    auto baseType = visitT(t.next).type;
    if (t.isAssociative)
      t.type = baseType.arrayOf(visitT(t.assocType).type);
    else if (t.isDynamic)
      t.type = baseType.arrayOf();
    else if (t.isStatic)
    {}
    else
      assert(t.isSlice);
    return t;
  }

  T visit(FunctionType t)
  {
    return t;
  }

  T visit(DelegateType t)
  {
    return t;
  }

  T visit(BaseClassType t)
  {
    return t;
  }

  T visit(ModifierType t) // D2.0
  {
    return t;
  }
} // override

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                 Parameters                                |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  N visit(Parameter p)
  {
    return p;
  }

  N visit(Parameters p)
  {
    return p;
  }

  N visit(TemplateAliasParam p)
  {
    return p;
  }

  N visit(TemplateTypeParam p)
  {
    return p;
  }

  N visit(TemplateThisParam p) // D2.0
  {
    return p;
  }

  N visit(TemplateValueParam p)
  {
    return p;
  }

  N visit(TemplateTupleParam p)
  {
    return p;
  }

  N visit(TemplateParameters p)
  {
    return p;
  }

  N visit(TemplateArguments p)
  {
    return p;
  }
} // override
}

/// Creates an error report.
void error(Module m, Token* token, cstring formatMsg, ...)
{
  error(m, _arguments, _argptr, formatMsg, token);
}

/// ditto
void error(Module m, Node n, cstring formatMsg, ...)
{
  error(m, _arguments, _argptr, formatMsg, n.begin);
}

/// ditto
void error(Module m, Token* token, MID mid, ...)
{
  error(m, _arguments, _argptr, m.cc.diag.msg(mid), token);
}

/// ditto
void error(Module m, Node n, MID mid, ...)
{
  error(m, _arguments, _argptr, m.cc.diag.msg(mid), n.begin);
}

/// ditto
void error(Module m, TypeInfo[] _arguments, va_list _argptr,
  cstring msg, Token* token)
{
  auto loc = token.getErrorLocation(m.filePath());
  msg = m.cc.diag.format(_arguments, _argptr, msg);
  m.cc.diag ~= new SemanticError(loc, msg);
}
