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
import dil.lexer.IdTable;
import dil.parser.Parser;
import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Types,
       dil.semantic.Scope,
       dil.semantic.Module,
       dil.semantic.Analysis;
import dil.code.Interpreter;
import dil.Compilation;
import dil.SourceText;
import dil.Diagnostics;
import dil.Messages;
import dil.Enums;
import common;

/// Some handy aliases.
private alias Declaration D;
private alias Expression E; /// ditto
private alias Statement S; /// ditto
private alias TypeNode T; /// ditto
private alias Parameter P; /// ditto
private alias Node N; /// ditto

/// Base class of all other semantic pass classes.
abstract class SemanticPass : DefaultVisitor
{
  Scope scop; /// The current scope.
  Module modul; /// The module to be semantically checked.
  CompilationContext context; /// The compilation context.
  Interpreter interp; /// Used to interpret ASTs.
  alias context cc;

  /// Constructs a SemanticPass object.
  /// Params:
  ///   modul = The module to be processed.
  ///   context = The compilation context.
  this(Module modul, CompilationContext context)
  {
    this.modul = modul;
    this.context = context;
    this.interp = new Interpreter(modul.diag);
  }

  void run()
  {

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
      scop.symbol.insert(new OverloadSet(name, sym.node), name);
    // Set the current scope symbol as the parent.
    sym.parent = scop.symbol;
  }

  /// Reports an error: new symbol s1 conflicts with existing symbol s2.
  void reportSymbolConflict(Symbol s1, Symbol s2, Identifier* name)
  {
    auto loc = s2.node.begin.getErrorLocation(modul.filePath());
    auto locString = Format("{}({},{})", loc.filePath, loc.lineNum, loc.colNum);
    error(s1.node, MSG.DeclConflictsWithDecl, name.str, locString);
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
  static const ScopeSymbol emptyIdScope;
  static this()
  {
    this.emptyIdScope = new ScopeSymbol();
  }

  // Sets a new idScope symbol.
  void setIdScope(Symbol symbol)
  {
    if (symbol)
      if (auto scopSymbol = cast(ScopeSymbol)symbol)
        return idScope = scopSymbol;
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
      symbol = idScope.lookup(id);

    if (symbol)
      return symbol;

    if (reportUndefinedIds)
      error(idTok, MSG.UndefinedIdentifier, id.str);
    undefinedIdsCount++;
    return null;
  }

  /// Creates an error report.
  void error(Token* token, char[] formatMsg, ...)
  {
    if (!modul.diag)
      return;
    auto location = token.getErrorLocation(modul.filePath());
    auto msg = Format(_arguments, _argptr, formatMsg);
    modul.diag ~= new SemanticError(location, msg);
  }

  /// ditto
  void error(Node n, char[] formatMsg, ...)
  {
    if (!modul.diag)
      return;
    auto token = n.begin; // Use the begin token of this node.
    auto location = token.getErrorLocation(modul.filePath());
    auto msg = Format(_arguments, _argptr, formatMsg);
    modul.diag ~= new SemanticError(location, msg);
  }
}

class FirstSemanticPass : SemanticPass
{
  Module delegate(string) importModule; /// Called when importing a module.

  // Attributes:
  LinkageType linkageType; /// Current linkage type.
  Protection protection; /// Current protection attribute.
  StorageClass storageClass; /// Current storage classes.
  uint alignSize; /// Current align size.

  /// Constructs a SemanticPass object.
  /// Params:
  ///   modul = The module to be processed.
  ///   context = The compilation context.
  this(Module modul, CompilationContext context)
  {
    super(modul, new CompilationContext(context));
    this.alignSize = context.structAlign;
  }

  override void run()
  {
    assert(modul.root !is null);
    // Create module scope.
    scop = new Scope(null, modul);
    modul.semanticPass = 1;
    visitN(modul.root);
  }

  /// Returns the lvalue of e.
  Expression toLValue(Expression e)
  {
    switch (e.kind)
    {
    alias NodeKind NK;
    case NK.IdentifierExpr,
         NK.ThisExpr,
         NK.IndexExpr,
         NK.StructInitExpr,
         NK.VariablesDecl,
         NK.DerefExpr,
         NK.SliceExpr:
      // Nothing to do.
      break;
    case NK.ArrayLiteralExpr:
      // if (e.type && e.type.baseType().tid == TYP.Void)
      //   error();
      break;
    case NK.CommaExpr:
      e = toLValue(e.to!(CommaExpr).rhs); // (lhs, rhs)
    case NK.CondExpr:
      break;
    case NK.CallExpr:
      if (e.type.baseType().isStruct())
        break;
      goto default;
    default:
      error(e, "‘{}’ is not an lvalue", e.toText());
    }
    return e;
  }

  /// Returns the expression &e.
  Expression addressOf(Expression e)
  {
    auto e2 = new AddressExpr(toLValue(e));
    e2.setLoc(e);
    e2.type = e.type.ptrTo();
    return e2;
  }

  /// Looks for special classes and stores them in a table.
  /// May modify d.symbol and assign a SpecialClassSymbol to it.
  void lookForSpecialClasses(ClassDecl d)
  {
    if (!isModuleScope())
      return; // Only consider top-level classes.

    ClassSymbol s = d.symbol;
    ClassSymbol* ps; /// Assigned to, if special class.
    auto name = s.name;
    auto table = cc.tables.classes;

    if (name is Ident.Sizeof  ||
        name is Ident.Alignof ||
        name is Ident.Mangleof)
      error(d.name, "illegal class name ‘{}’", s.name);
    else if (name.startsWith("TypeInfo"))
    {
      switch (name.idKind)
      {
      case IDK.TypeInfo:
        ps = &table.tinfo; break;
      case IDK.TypeInfo_Array:
        ps = &table.tinfoArray; break;
      case IDK.TypeInfo_AssociativeArray:
        ps = &table.tinfoAArray; break;
      case IDK.TypeInfo_Class:
        ps = &table.tinfoClass; break;
      case IDK.TypeInfo_Delegate:
        ps = &table.tinfoDelegate; break;
      case IDK.TypeInfo_Enum:
        ps = &table.tinfoEnum; break;
      case IDK.TypeInfo_Function:
        ps = &table.tinfoFunction; break;
      case IDK.TypeInfo_Interface:
        ps = &table.tinfoInterface; break;
      case IDK.TypeInfo_Pointer:
        ps = &table.tinfoPointer; break;
      case IDK.TypeInfo_StaticArray:
        ps = &table.tinfoSArray; break;
      case IDK.TypeInfo_Struct:
        ps = &table.tinfoStruct; break;
      case IDK.TypeInfo_Tuple:
        ps = &table.tinfoTuple; break;
      case IDK.TypeInfo_Typedef:
        ps = &table.tinfoTypedef; break;
      version(D2)
      {
      case IDK.TypeInfo_Const:
        ps = &table.tinfoConst; break;
      case IDK.TypeInfo_Invariant:
        ps = &table.tinfoInvariant; break;
      case IDK.TypeInfo_Shared:
        ps = &table.tinfoShared; break;
      } //version(D2)
      default:
      }
    } // If object.d module and if in root package.
    else if (modul.name is Ident.object &&
      modul.parent.parent is null) // root package = modul.parent
    {
      if (name is Ident.Object)
        ps = &table.object;
      else if (name is Ident.ClassInfo)
        ps = &table.classInfo;
      else if (name is Ident.ModuleInfo)
        ps = &table.moduleInfo;
      else if (name is Ident.Exception)
        ps = &table.exeption;
    }

    if (ps)
    { // Convert to subclass. (Handles mangling differently.)
      if (*ps !is null)
        error(d.name,
          "special class ‘{}’ already defined at ‘{}’",
          name, *ps.getFQN());
      else
        d.symbol = *ps = new SpecialClassSymbol(s.name, s.node);
    }
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                Declarations                               |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
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
        error(d, MSG.CouldntLoadModule, moduleFQNPath ~ ".d");
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
    d.symbol = new EnumSymbol(d.nameId, d);

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
    d.symbol = new EnumMember(d.nameId, protection, storageClass, linkageType, d);
    insert(d.symbol);
    return d;
  }

  D visit(ClassDecl d)
  {
    if (d.symbol)
      return d;
    // Create the symbol.
    d.symbol = new ClassSymbol(d.nameId, d);
    lookForSpecialClasses(d);
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
    d.symbol = new InterfaceSymbol(d.nameId, d);
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
    d.symbol = new StructSymbol(d.nameId, d);

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
    d.symbol = new UnionSymbol(d.nameId, d);

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
    auto func = new FunctionSymbol(Ident.Ctor, d);
    //func.type = null;
    insertOverload(func);
    return d;
  }

  D visit(StaticCtorDecl d)
  {
    auto func = new FunctionSymbol(Ident.Ctor, d);
    //func.type = cc.tables.types.Void_0Args_DFunc;
    insertOverload(func);
    return d;
  }

  D visit(DestructorDecl d)
  {
    auto func = new FunctionSymbol(Ident.Dtor, d);
    //func.type = cc.tables.types.Void_0Args_DFunc;
    insertOverload(func);
    return d;
  }

  D visit(StaticDtorDecl d)
  {
    auto func = new FunctionSymbol(Ident.Dtor, d);
    //func.type = cc.tables.types.Void_0Args_DFunc;
    insertOverload(func);
    return d;
  }

  D visit(FunctionDecl d)
  {
    auto func = new FunctionSymbol(d.nameId, d);
    insertOverload(func);
    return d;
  }

  D visit(VariablesDecl vd)
  {
    // Error if we are in an interface.
    if (scop.symbol.isInterface && !(vd.isStatic || vd.isConst))
      return error(vd, MSG.InterfaceCantHaveVariables), vd;

    // Insert variable symbols in this declaration into the symbol table.
    vd.variables = new VariableSymbol[vd.names.length];
    foreach (i, name; vd.names)
    {
      auto nameId = vd.nameId(i);
      auto variable = new VariableSymbol(nameId, protection, storageClass,
        linkageType, vd);
      variable.value = vd.inits[i];
      vd.variables[i] = variable;
      insert(variable);
    }
    return vd;
  }

  D visit(InvariantDecl d)
  {
    auto func = new FunctionSymbol(Ident.Invariant, d);
    insert(func);
    return d;
  }

  D visit(UnittestDecl d)
  {
    auto func = new FunctionSymbol(Ident.Unittest, d);
    insertOverload(func);
    return d;
  }

  D visit(DebugDecl d)
  {
    if (d.isSpecification)
    { // debug = Id | Int
      if (!isModuleScope())
        error(d, MSG.DebugSpecModuleLevel, d.spec.text);
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
        error(d, MSG.VersionSpecModuleLevel, d.spec.text);
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
    d.symbol = new TemplateSymbol(d.nameId, d);
    // Insert into current scope.
    insertOverload(d.symbol);
    return d;
  }

  D visit(NewDecl d)
  {
    auto func = new FunctionSymbol(Ident.New, d);
    insert(func);
    return d;
  }

  D visit(DeleteDecl d)
  {
    auto func = new FunctionSymbol(Ident.Delete, d);
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
    storageClass = d.stcs; // Set.
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

  D visit(StaticAssertDecl d)
  {
    return d;
  }

  D visit(StaticIfDecl d)
  {
    return d;
  }

  D visit(MixinDecl d)
  {
    return d;
  }

  D visit(PragmaDecl d)
  {
    if (d.ident is Ident.msg)
    {
      // TODO
    }
    else
    {
      pragmaSemantic(scop, d.begin, d.ident, d.args);
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

  // D2.0
  S visit(ForeachRangeStmt s)
  {
    auto saved = setBS(s);
    // TODO:
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
      error(e, "the operation is undefined for type bool");
  }

  /// Reports an error if e has no boolean result.
  void errorIfNonBool(Expression e)
  {
    assert(e.type !is null);
    switch (e.kind)
    {
    case NodeKind.DeleteExpr:
      error(e, "the delete operator has no boolean result");
      break;
    case NodeKind.AssignExpr:
      error(e, "the assignment operator '=' has no boolean result");
      break;
    case NodeKind.CondExpr:
      auto cond = e.to!(CondExpr);
      errorIfNonBool(cond.lhs);
      errorIfNonBool(cond.rhs);
      break;
    default:
      if (!e.type.isBaseScalar()) // Only scalar types can be bool.
        error(e, "expression has no boolean result");
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
      error(whichOp, "the operator '{}' is undefined for complex numbers",
            e.optok.text());
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
      error(e.rhs, "right operand of 'in' operator must be an associative array");
      e.type = e.rhs.type; // Don't use Types.Error. Cascading error msgs are irritating.
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
      error(e.optok, "concatenation operator '~' is undefined for: {} ~ {}",
            e.lhs, e.rhs);
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
      error(e.una,
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
      error(e, "the operator '~x' is undefined for the type '{}'",
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
    auto idToken = e.idToken();
    e.symbol = search(idToken);
    return e;
  }

  E visit(TmplInstanceExpr e)
  {
    if (e.isChecked)
      return e;
    debug(sema) Stdout.formatln("", e);
    auto idToken = e.idToken();
    e.symbol = search(idToken);
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
    e.type = cc.tables.types.Size_t;
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
    idScope = modul;
    return t;
  }

  T visit(IdentifierType t)
  {
    auto idToken = t.begin;
    auto symbol = search(idToken);
    // TODO: save symbol or its type in t.
    return t;
  }

  T visit(TypeofType t)
  {
    t.expr = visitE(t.expr);
    t.type = t.expr.type;
    return t;
  }

  T visit(TemplateInstanceType t)
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

  T visit(ConstType t) // D2.0
  {
    return t;
  }

  T visit(ImmutableType t) // D2.0
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
