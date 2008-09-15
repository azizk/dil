/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Passes;

import dil.ast.DefaultVisitor;
import dil.ast.Node,
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
       dil.semantic.Analysis,
       dil.semantic.Interpreter;
import dil.Compilation;
import dil.SourceText;
import dil.Location;
import dil.Information;
import dil.Messages;
import dil.Enums;
import dil.CompilerInfo;
import common;

// This module is here for testing out
// a different algorithm to do semantic analysis
// compared to SemanticPass1 and SemanticPass2!

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

  /// Constructs a SemanticPass object.
  /// Params:
  ///   modul = the module to be processed.
  ///   context = the compilation context.
  this(Module modul, CompilationContext context)
  {
    this.modul = modul;
    this.context = context;
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
    auto loc = s2.node.begin.getErrorLocation();
    auto locString = Format("{}({},{})", loc.filePath, loc.lineNum, loc.colNum);
    error(s1.node.begin, MSG.DeclConflictsWithDecl, name.str, locString);
  }

  /// Error messages are reported for undefined identifiers if true.
  bool reportUndefinedIds;

  /// Incremented when an undefined identifier was found.
  uint undefinedIdsCount;

  /// The symbol that must be ignored an skipped during a symbol search.
  Symbol ignoreSymbol;

  /// The current scope symbol to use for looking up identifiers.
  /// E.g.:
  /// ---
  /// object.method(); // *) object is looked up in the current scope.
  ///                  // *) idScope is set if object is a ScopeSymbol.
  ///                  // *) method will be looked up in idScope.
  /// dil.ast.Node.Node node; // A fully qualified type.
  /// ---
  ScopeSymbol idScope;

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
    if (!modul.infoMan)
      return;
    auto location = token.getErrorLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    modul.infoMan ~= new SemanticError(location, msg);
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
  ///   modul = the module to be processed.
  ///   context = the compilation context.
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

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                Declarations                               |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  D visit(CompoundDeclaration d)
  {
    foreach (decl; d.decls)
      visitD(decl);
    return d;
  }

  D visit(IllegalDeclaration)
  { assert(0, "semantic pass on invalid AST"); return null; }

  // D visit(EmptyDeclaration ed)
  // { return ed; }

  // D visit(ModuleDeclaration)
  // { return null; }

  D visit(ImportDeclaration d)
  {
    if (importModule is null)
      return d;
    foreach (moduleFQNPath; d.getModuleFQNs(dirSep))
    {
      auto importedModule = importModule(moduleFQNPath);
      if (importedModule is null)
        error(d.begin, MSG.CouldntLoadModule, moduleFQNPath ~ ".d");
      modul.modules ~= importedModule;
    }
    return d;
  }

  D visit(AliasDeclaration ad)
  {
    return ad;
  }

  D visit(TypedefDeclaration td)
  {
    return td;
  }

  D visit(EnumDeclaration d)
  {
    if (d.symbol)
      return d;

    // Create the symbol.
    d.symbol = new Enum(d.name, d);

    bool isAnonymous = d.symbol.isAnonymous;
    if (isAnonymous)
      d.symbol.name = IdTable.genAnonEnumID();

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

  D visit(EnumMemberDeclaration d)
  {
    d.symbol = new EnumMember(d.name, protection, storageClass, linkageType, d);
    insert(d.symbol);
    return d;
  }

  D visit(ClassDeclaration d)
  {
    if (d.symbol)
      return d;
    // Create the symbol.
    d.symbol = new Class(d.name, d);
    // Insert into current scope.
    insert(d.symbol);
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
    // Create the symbol.
    d.symbol = new dil.semantic.Symbols.Interface(d.name, d);
    // Insert into current scope.
    insert(d.symbol);
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
    // Create the symbol.
    d.symbol = new Struct(d.name, d);

    if (d.symbol.isAnonymous)
      d.symbol.name = IdTable.genAnonStructID();
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

  D visit(UnionDeclaration d)
  {
    if (d.symbol)
      return d;
    // Create the symbol.
    d.symbol = new Union(d.name, d);

    if (d.symbol.isAnonymous)
      d.symbol.name = IdTable.genAnonUnionID();

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

  D visit(ConstructorDeclaration d)
  {
    auto func = new Function(Ident.Ctor, d);
    insertOverload(func);
    return d;
  }

  D visit(StaticConstructorDeclaration d)
  {
    auto func = new Function(Ident.Ctor, d);
    insertOverload(func);
    return d;
  }

  D visit(DestructorDeclaration d)
  {
    auto func = new Function(Ident.Dtor, d);
    insertOverload(func);
    return d;
  }

  D visit(StaticDestructorDeclaration d)
  {
    auto func = new Function(Ident.Dtor, d);
    insertOverload(func);
    return d;
  }

  D visit(FunctionDeclaration d)
  {
    auto func = new Function(d.name, d);
    insertOverload(func);
    return d;
  }

  D visit(VariablesDeclaration vd)
  {
    // Error if we are in an interface.
    if (scop.symbol.isInterface && !vd.isStatic)
      return error(vd.begin, MSG.InterfaceCantHaveVariables), vd;

    // Insert variable symbols in this declaration into the symbol table.
    foreach (i, name; vd.names)
    {
      auto variable = new Variable(name, protection, storageClass, linkageType, vd);
      variable.value = vd.inits[i];
      vd.variables ~= variable;
      insert(variable);
    }
    return vd;
  }

  D visit(InvariantDeclaration d)
  {
    auto func = new Function(Ident.Invariant, d);
    insert(func);
    return d;
  }

  D visit(UnittestDeclaration d)
  {
    auto func = new Function(Ident.Unittest, d);
    insertOverload(func);
    return d;
  }

  D visit(DebugDeclaration d)
  {
    if (d.isSpecification)
    { // debug = Id | Int
      if (!isModuleScope())
        error(d.begin, MSG.DebugSpecModuleLevel, d.spec.srcText);
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

  D visit(VersionDeclaration d)
  {
    if (d.isSpecification)
    { // version = Id | Int
      if (!isModuleScope())
        error(d.begin, MSG.VersionSpecModuleLevel, d.spec.srcText);
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

  D visit(TemplateDeclaration d)
  {
    if (d.symbol)
      return d;
    // Create the symbol.
    d.symbol = new Template(d.name, d);
    // Insert into current scope.
    insertOverload(d.symbol);
    return d;
  }

  D visit(NewDeclaration d)
  {
    auto func = new Function(Ident.New, d);
    insert(func);
    return d;
  }

  D visit(DeleteDeclaration d)
  {
    auto func = new Function(Ident.Delete, d);
    insert(func);
    return d;
  }

  // Attributes:

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

  // Deferred declarations:

  D visit(StaticAssertDeclaration d)
  {
    return d;
  }

  D visit(StaticIfDeclaration d)
  {
    return d;
  }

  D visit(MixinDeclaration d)
  {
    return d;
  }

  D visit(PragmaDeclaration d)
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
  S breakableStatement;

  S setBS(S s)
  {
    auto old = breakableStatement;
    breakableStatement = s;
    return old;
  }

  void restoreBS(S s)
  {
    breakableStatement = s;
  }

override
{
  S visit(CompoundStatement s)
  {
    foreach (stmnt; s.stmnts)
      visitS(stmnt);
    return s;
  }

  S visit(IllegalStatement)
  { assert(0, "semantic pass on invalid AST"); return null; }

  S visit(EmptyStatement s)
  {
    return s;
  }

  S visit(FuncBodyStatement s)
  {
    return s;
  }

  S visit(ScopeStatement s)
  {
//     enterScope();
    visitS(s.s);
//     exitScope();
    return s;
  }

  S visit(LabeledStatement s)
  {
    return s;
  }

  S visit(ExpressionStatement s)
  {
    return s;
  }

  S visit(DeclarationStatement s)
  {
    return s;
  }

  S visit(IfStatement s)
  {
    return s;
  }

  S visit(WhileStatement s)
  {
    auto saved = setBS(s);
    // TODO:
    restoreBS(saved);
    return s;
  }

  S visit(DoWhileStatement s)
  {
    auto saved = setBS(s);
    // TODO:
    restoreBS(saved);
    return s;
  }

  S visit(ForStatement s)
  {
    auto saved = setBS(s);
    // TODO:
    restoreBS(saved);
    return s;
  }

  S visit(ForeachStatement s)
  {
    auto saved = setBS(s);
    // TODO:
    // find overload opApply or opApplyReverse.
    restoreBS(saved);
    return s;
  }

  // D2.0
  S visit(ForeachRangeStatement s)
  {
    auto saved = setBS(s);
    // TODO:
    restoreBS(saved);
    return s;
  }

  S visit(SwitchStatement s)
  {
    auto saved = setBS(s);
    // TODO:
    restoreBS(saved);
    return s;
  }

  S visit(CaseStatement s)
  {
    auto saved = setBS(s);
    // TODO:
    restoreBS(saved);
    return s;
  }

  S visit(DefaultStatement s)
  {
    auto saved = setBS(s);
    // TODO:
    restoreBS(saved);
    return s;
  }

  S visit(ContinueStatement s)
  {
    return s;
  }

  S visit(BreakStatement s)
  {
    return s;
  }

  S visit(ReturnStatement s)
  {
    return s;
  }

  S visit(GotoStatement s)
  {
    return s;
  }

  S visit(WithStatement s)
  {
    return s;
  }

  S visit(SynchronizedStatement s)
  {
    return s;
  }

  S visit(TryStatement s)
  {
    return s;
  }

  S visit(CatchStatement s)
  {
    return s;
  }

  S visit(FinallyStatement s)
  {
    return s;
  }

  S visit(ScopeGuardStatement s)
  {
    return s;
  }

  S visit(ThrowStatement s)
  {
    return s;
  }

  S visit(VolatileStatement s)
  {
    return s;
  }

  S visit(AsmBlockStatement s)
  {
    foreach (stmnt; s.statements.stmnts)
      visitS(stmnt);
    return s;
  }

  S visit(AsmStatement s)
  {
    return s;
  }

  S visit(AsmAlignStatement s)
  {
    return s;
  }

  S visit(IllegalAsmStatement)
  { assert(0, "semantic pass on invalid AST"); return null; }

  S visit(PragmaStatement s)
  {
    return s;
  }

  S visit(MixinStatement s)
  {
    return s;
  }

  S visit(StaticIfStatement s)
  {
    return s;
  }

  S visit(StaticAssertStatement s)
  {
    return s;
  }

  S visit(DebugStatement s)
  {
    return s;
  }

  S visit(VersionStatement s)
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

  /// Reports an error if 'e' is of type bool.
  void errorIfBool(Expression e)
  {
    error(e.begin, "the operation is not defined for the type bool");
  }

  /// Returns a call expression if 'e' overrides
  /// an operatorwith the name 'id'.
  /// Params:
  ///   e = the binary expression to be checked.
  ///   id = the name of the overload function.
  Expression findOverload(UnaryExpression e, Identifier* id)
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
  ///   e = the binary expression to be checked.
  ///   id = the name of the overload function.
  ///   id_r = the name of the reverse overload function.
  Expression findOverload(BinaryExpression e, Identifier* id, Identifier* id_r)
  {
    // TODO:
    return null;
  }

override
{
  E visit(IllegalExpression)
  { assert(0, "semantic pass on invalid AST"); return null; }

  E visit(CondExpression e)
  {
    return e;
  }

  E visit(CommaExpression e)
  {
    if (!e.hasType)
    {
      e.lhs = visitE(e.lhs);
      e.rhs = visitE(e.rhs);
      e.type = e.rhs.type;
    }
    return e;
  }

  E visit(OrOrExpression e)
  {
    return e;
  }

  E visit(AndAndExpression e)
  {
    return e;
  }

  E visit(OrExpression e)
  {
    if (auto o = findOverload(e, Ident.opOr, Ident.opOr_r))
      return o;
    return e;
  }

  E visit(XorExpression e)
  {
    if (auto o = findOverload(e, Ident.opXor, Ident.opXor_r))
      return o;
    return e;
  }

  E visit(AndExpression e)
  {
    if (auto o = findOverload(e, Ident.opAnd, Ident.opAnd_r))
      return o;
    return e;
  }

  E visit(EqualExpression e)
  {
    if (auto o = findOverload(e, Ident.opEquals, null))
      return o;
    return e;
  }

  E visit(IdentityExpression e)
  {
    return e;
  }

  E visit(RelExpression e)
  {
    if (auto o = findOverload(e, Ident.opCmp, null))
      return o;
    return e;
  }

  E visit(InExpression e)
  {
    if (auto o = findOverload(e, Ident.opIn, Ident.opIn_r))
      return o;
    return e;
  }

  E visit(LShiftExpression e)
  {
    if (auto o = findOverload(e, Ident.opShl, Ident.opShl_r))
      return o;
    return e;
  }

  E visit(RShiftExpression e)
  {
    if (auto o = findOverload(e, Ident.opShr, Ident.opShr_r))
      return o;
    return e;
  }

  E visit(URShiftExpression e)
  {
    if (auto o = findOverload(e, Ident.opUShr, Ident.opUShr_r))
      return o;
    return e;
  }

  E visit(PlusExpression e)
  {
    if (auto o = findOverload(e, Ident.opAdd, Ident.opAdd_r))
      return o;
    return e;
  }

  E visit(MinusExpression e)
  {
    if (auto o = findOverload(e, Ident.opSub, Ident.opSub_r))
      return o;
    return e;
  }

  E visit(CatExpression e)
  {
    if (auto o = findOverload(e, Ident.opCat, Ident.opCat_r))
      return o;
    return e;
  }

  E visit(MulExpression e)
  {
    if (auto o = findOverload(e, Ident.opMul, Ident.opMul_r))
      return o;
    return e;
  }

  E visit(DivExpression e)
  {
    if (auto o = findOverload(e, Ident.opDiv, Ident.opDiv_r))
      return o;
    return e;
  }

  E visit(ModExpression e)
  {
    if (auto o = findOverload(e, Ident.opMod, Ident.opMod_r))
      return o;
    return e;
  }

  E visit(AssignExpression e)
  {
    if (auto o = findOverload(e, Ident.opAssign, null))
      return o;
    // TODO: also check for opIndexAssign and opSliceAssign.
    return e;
  }

  E visit(LShiftAssignExpression e)
  {
    if (auto o = findOverload(e, Ident.opShlAssign, null))
      return o;
    return e;
  }

  E visit(RShiftAssignExpression e)
  {
    if (auto o = findOverload(e, Ident.opShrAssign, null))
      return o;
    return e;
  }

  E visit(URShiftAssignExpression e)
  {
    if (auto o = findOverload(e, Ident.opUShrAssign, null))
      return o;
    return e;
  }

  E visit(OrAssignExpression e)
  {
    if (auto o = findOverload(e, Ident.opOrAssign, null))
      return o;
    return e;
  }

  E visit(AndAssignExpression e)
  {
    if (auto o = findOverload(e, Ident.opAndAssign, null))
      return o;
    return e;
  }

  E visit(PlusAssignExpression e)
  {
    if (auto o = findOverload(e, Ident.opAddAssign, null))
      return o;
    return e;
  }

  E visit(MinusAssignExpression e)
  {
    if (auto o = findOverload(e, Ident.opSubAssign, null))
      return o;
    return e;
  }

  E visit(DivAssignExpression e)
  {
    auto o = findOverload(e, Ident.opDivAssign, null);
    if (o)
      return o;
    return e;
  }

  E visit(MulAssignExpression e)
  {
    auto o = findOverload(e, Ident.opMulAssign, null);
    if (o)
      return o;
    return e;
  }

  E visit(ModAssignExpression e)
  {
    auto o = findOverload(e, Ident.opModAssign, null);
    if (o)
      return o;
    return e;
  }

  E visit(XorAssignExpression e)
  {
    auto o = findOverload(e, Ident.opXorAssign, null);
    if (o)
      return o;
    return e;
  }

  E visit(CatAssignExpression e)
  {
    auto o = findOverload(e, Ident.opCatAssign, null);
    if (o)
      return o;
    return e;
  }

  E visit(AddressExpression e)
  {
    if (e.hasType)
      return e;
    e.e = visitE(e.e);
    e.type = e.e.type.ptrTo();
    return e;
  }

  E visit(PreIncrExpression e)
  {
    if (e.hasType)
      return e;
    // TODO: rewrite to e+=1
    e.e = visitE(e.e);
    e.type = e.e.type;
    errorIfBool(e.e);
    return e;
  }

  E visit(PreDecrExpression e)
  {
    if (e.hasType)
      return e;
    // TODO: rewrite to e-=1
    e.e = visitE(e.e);
    e.type = e.e.type;
    errorIfBool(e.e);
    return e;
  }

  E visit(PostIncrExpression e)
  {
    if (e.hasType)
      return e;
    if (auto o = findOverload(e, Ident.opPostInc))
      return o;
    e.e = visitE(e.e);
    e.type = e.e.type;
    errorIfBool(e.e);
    return e;
  }

  E visit(PostDecrExpression e)
  {
    if (e.hasType)
      return e;
    if (auto o = findOverload(e, Ident.opPostDec))
      return o;
    e.e = visitE(e.e);
    e.type = e.e.type;
    errorIfBool(e.e);
    return e;
  }

  E visit(DerefExpression e)
  {
    if (e.hasType)
      return e;
  version(D2)
    if (auto o = findOverload(e, Ident.opStar))
      return o;
    e.e = visitE(e.e);
    e.type = e.e.type.next;
    if (!e.e.type.isPointer)
    {
      error(e.e.begin,
        "dereference operator '*x' not defined for expression of type '{}'",
        e.e.type.toString());
      e.type = Types.Error;
    }
    // TODO:
    // if (e.e.type.isVoid)
    //   error();
    return e;
  }

  E visit(SignExpression e)
  {
    if (e.hasType)
      return e;
    if (auto o = findOverload(e, e.isNeg ? Ident.opNeg : Ident.opPos))
      return o;
    e.e = visitE(e.e);
    e.type = e.e.type;
    errorIfBool(e.e);
    return e;
  }

  E visit(NotExpression e)
  {
    if (e.hasType)
      return e;
    e.e = visitE(e.e);
    e.type = Types.Bool;
    // TODO: e.e must be convertible to bool.
    return e;
  }

  E visit(CompExpression e)
  {
    if (e.hasType)
      return e;
    if (auto o = findOverload(e, Ident.opCom))
      return o;
    e.e = visitE(e.e);
    e.type = e.e.type;
    if (e.type.isFloating || e.type.isBool)
    {
      error(e.begin, "the operator '~x' is not defined for the type '{}'", e.type.toString());
      e.type = Types.Error;
    }
    return e;
  }

  E visit(CallExpression e)
  {
    if (auto o = findOverload(e, Ident.opCall))
      return o;
    return e;
  }

  E visit(NewExpression e)
  {
    return e;
  }

  E visit(NewAnonClassExpression e)
  {
    return e;
  }

  E visit(DeleteExpression e)
  {
    return e;
  }

  E visit(CastExpression e)
  {
    if (auto o = findOverload(e, Ident.opCast))
      return o;
    return e;
  }

  E visit(IndexExpression e)
  {
    if (auto o = findOverload(e, Ident.opIndex))
      return o;
    return e;
  }

  E visit(SliceExpression e)
  {
    if (auto o = findOverload(e, Ident.opSlice))
      return o;
    return e;
  }

  E visit(DotExpression e)
  {
    if (e.hasType)
      return e;
    bool resetIdScope = idScope is null;
    // TODO:
    resetIdScope && (idScope = null);
    return e;
  }

  E visit(ModuleScopeExpression e)
  {
    if (e.hasType)
      return e;
    bool resetIdScope = idScope is null;
    idScope = modul;
    e.e = visitE(e.e);
    e.type = e.e.type;
    resetIdScope && (idScope = null);
    return e;
  }

  E visit(IdentifierExpression e)
  {
    if (e.hasType)
      return e;
    debug(sema) Stdout.formatln("", e);
    auto idToken = e.idToken();
    e.symbol = search(idToken);
    return e;
  }

  E visit(TemplateInstanceExpression e)
  {
    if (e.hasType)
      return e;
    debug(sema) Stdout.formatln("", e);
    auto idToken = e.idToken();
    e.symbol = search(idToken);
    return e;
  }

  E visit(SpecialTokenExpression e)
  {
    if (e.hasType)
      return e.value;
    switch (e.specialToken.kind)
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

  E visit(ThisExpression e)
  {
    return e;
  }

  E visit(SuperExpression e)
  {
    return e;
  }

  E visit(NullExpression e)
  {
    if (!e.hasType)
      e.type = Types.Void_ptr;
    return e;
  }

  E visit(DollarExpression e)
  {
    if (e.hasType)
      return e;
    e.type = Types.Size_t;
    // if (!inArraySubscript)
    //   error("$ can only be in an array subscript.");
    return e;
  }

  E visit(BoolExpression e)
  {
    assert(e.hasType);
    return e.value;
  }

  E visit(IntExpression e)
  {
    if (e.hasType)
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

  E visit(RealExpression e)
  {
    if (!e.hasType)
      e.type = Types.Double;
    return e;
  }

  E visit(ComplexExpression e)
  {
    if (!e.hasType)
      e.type = Types.Cdouble;
    return e;
  }

  E visit(CharExpression e)
  {
    assert(e.hasType);
    return e.value;
  }

  E visit(StringExpression e)
  {
    assert(e.hasType);
    return e;
  }

  E visit(ArrayLiteralExpression e)
  {
    return e;
  }

  E visit(AArrayLiteralExpression e)
  {
    return e;
  }

  E visit(AssertExpression e)
  {
    return e;
  }

  E visit(MixinExpression e)
  {
    return e;
  }

  E visit(ImportExpression e)
  {
    return e;
  }

  E visit(TypeofExpression e)
  {
    return e;
  }

  E visit(TypeDotIdExpression e)
  {
    return e;
  }

  E visit(TypeidExpression e)
  {
    return e;
  }

  E visit(IsExpression e)
  {
    return e;
  }

  E visit(ParenExpression e)
  {
    if (!e.hasType)
    {
      e.next = visitE(e.next);
      e.type = e.next.type;
    }
    return e;
  }

  E visit(FunctionLiteralExpression e)
  {
    return e;
  }

  E visit(TraitsExpression e) // D2.0
  {
    return e;
  }

  E visit(VoidInitExpression e)
  {
    return e;
  }

  E visit(ArrayInitExpression e)
  {
    return e;
  }

  E visit(StructInitExpression e)
  {
    return e;
  }

  E visit(AsmTypeExpression e)
  {
    return e;
  }

  E visit(AsmOffsetExpression e)
  {
    return e;
  }

  E visit(AsmSegExpression e)
  {
    return e;
  }

  E visit(AsmPostBracketExpression e)
  {
    return e;
  }

  E visit(AsmBracketExpression e)
  {
    return e;
  }

  E visit(AsmLocalSizeExpression e)
  {
    return e;
  }

  E visit(AsmRegisterExpression e)
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
    // A table mapping the kind of a token to its corresponding semantic Type.
    TypeBasic[TOK] tok2Type = [
      TOK.Char : Types.Char,   TOK.Wchar : Types.Wchar,   TOK.Dchar : Types.Dchar, TOK.Bool : Types.Bool,
      TOK.Byte : Types.Byte,   TOK.Ubyte : Types.Ubyte,   TOK.Short : Types.Short, TOK.Ushort : Types.Ushort,
      TOK.Int : Types.Int,    TOK.Uint : Types.Uint,    TOK.Long : Types.Long,  TOK.Ulong : Types.Ulong,
      TOK.Cent : Types.Cent,   TOK.Ucent : Types.Ucent,
      TOK.Float : Types.Float,  TOK.Double : Types.Double,  TOK.Real : Types.Real,
      TOK.Ifloat : Types.Ifloat, TOK.Idouble : Types.Idouble, TOK.Ireal : Types.Ireal,
      TOK.Cfloat : Types.Cfloat, TOK.Cdouble : Types.Cdouble, TOK.Creal : Types.Creal, TOK.Void : Types.Void
    ];
    assert(t.tok in tok2Type);
    t.type = tok2Type[t.tok];
    return t;
  }

  T visit(QualifiedType t)
  {
    // Reset idScope at the end if this the root QualifiedType.
    bool resetIdScope = idScope is null;
//     if (t.lhs.Is!(QualifiedType) is null)
//       idScope = null; // Reset at left-most type.
    visitT(t.lhs);
    // Assign the symbol of the left-hand side to idScope.
    setIdScope(t.lhs.symbol);
    visitT(t.rhs);
//     setIdScope(t.rhs.symbol);
    // Assign members of the right-hand side to this type.
    t.type = t.rhs.type;
    t.symbol = t.rhs.symbol;
    // Reset idScope.
    resetIdScope && (idScope = null);
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
    t.e = visitE(t.e);
    t.type = t.e.type;
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

  T visit(CFuncPointerType t)
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

  T visit(InvariantType t) // D2.0
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

  N visit(TemplateAliasParameter p)
  {
    return p;
  }

  N visit(TemplateTypeParameter p)
  {
    return p;
  }

  N visit(TemplateThisParameter p) // D2.0
  {
    return p;
  }

  N visit(TemplateValueParameter p)
  {
    return p;
  }

  N visit(TemplateTupleParameter p)
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
