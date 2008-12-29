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
import dil.lexer.IdTable;
import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Types,
       dil.semantic.Scope,
       dil.semantic.Module,
       dil.semantic.Analysis;
import dil.Compilation;
import dil.Diagnostics;
import dil.Messages;
import dil.Enums;
import dil.CompilerInfo;
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
  Module delegate(string) importModule; /// Called when importing a module.

  // Attributes:
  LinkageType linkageType; /// Current linkage type.
  Protection protection; /// Current protection attribute.
  StorageClass storageClass; /// Current storage classes.
  uint alignSize; /// Current align size.

  /// Constructs a SemanticPass1 object.
  /// Params:
  ///   modul = the module to be processed.
  ///   context = the compilation context.
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
    {
      // Create a new overload set and add THIS symbol first
      scop.symbol.insert(new OverloadSet(name, sym.node), name);
      auto sym2Internal = scop.symbol.lookup(name);
      (cast(OverloadSet)cast(void*)sym2Internal).add(sym);
    }
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

  /// Creates an error report.
  void error(Token* token, char[] formatMsg, ...)
  {
    if (!modul.diag)
      return;
    auto location = token.getErrorLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    modul.diag ~= new SemanticError(location, msg);
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

  //Check for special dissalowed functions in struct/union/interface
  void checkCtorDtorSpecials(CompoundDeclaration decls, bool StructOrUnion)
  {
    foreach (Declaration decl; decls.decls)
    {
      Declaration innerD = visitD(decl);
      if (innerD.Is!(ConstructorDeclaration))
        error(decl.begin, "constructors are only allowed in a Class");
      else if (innerD.Is!(DestructorDeclaration))
        error(decl.begin, "destructors are only allowed in a Class");

      if (!StructOrUnion)
      {
        if (innerD.Is!(InvariantDeclaration))
          error(decl.begin, "invariant not allowed in interface");
	else if (innerD.Is!(UnittestDeclaration))
          error(decl.begin, "unittests not allowed in interface");
	else if (innerD.Is!(NewDeclaration))
          error(decl.begin, "alloctor 'new' not allowed for interface");
	else if (innerD.Is!(DeleteDeclaration))
          error(decl.begin, "dealloctor 'delete' not allowed for interface");
      }
      
      if (innerD.Is!(FunctionDeclaration))
        if ((cast(FunctionDeclaration)innerD).funcBody)
	  error(innerD.begin, "function body for '{}' is not abstract in interface", (cast(FunctionDeclaration)innerD).name.str);
    }
  }

  private alias Declaration D; /// A handy alias. Saves typing.
  private alias Statement S;
  private alias Node N;

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
    Declaration aliasDecl = visitD(ad.decl);

    if (aliasDecl.Is!(VariablesDeclaration))
    {
      if((cast(VariablesDeclaration)aliasDecl).typeNode.Is!(TemplateInstanceType))
      {
        return aliasDecl;
      }
    }
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

    if ((d.name.str == "sizeof") || (d.name.str == "alignof") || (d.name.str == "mangleof"))
    {
      error(d.begin, "Illegal class name {}", d.name.str);
      return d;
    }

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
      checkCtorDtorSpecials(d.decls, false);
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
      checkCtorDtorSpecials(d.decls, true);
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
      checkCtorDtorSpecials(d.decls, true);
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
    if (d.symbol)
      return d;

    if (d.isConst() || d.isAuto() || d.isScope())
    {
      error(d.begin, "functions cannot be const or auto");
      return d;
    }

    /*TODO: add the isVirtual method to Declaration.d
    if (d.isAbstract() && !d.isVirtual())
    {
      error(d.begin, "function cannot be both abstract and final");
      return d;
    }
    */

    if (d.isAbstract() && d.isFinal())
    {
      error(d.begin, "function cannot be both abstract and final");
      return d;
    }

    if (d.isAbstract() && (d.funcBody !is null))
    {
      error(d.begin, "abstract functions cannot have bodies");
      return d;
    }

    debug(sema)
    {
      Stdout("Function - ");
      Stdout(d.name.str).newline;
    }

    auto func = new Function(d.name, d);
    insertOverload(func);

    d.symbol = func;

    enterScope(func);
      d.params && visitN(d.params);
      d.funcBody && visitS(d.funcBody);
    exitScope();

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
    addDeferred(d);
    return d;
  }

  D visit(StaticIfDeclaration d)
  {
    addDeferred(d);
    return d;
  }

  D visit(MixinDeclaration d)
  {
    addDeferred(d);
    return d;
  }

  D visit(PragmaDeclaration d)
  {
    if (d.ident is Ident.msg)
      addDeferred(d);
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
    if (s.symbol)
      return s;

    s.inBody &&  visitS(s.inBody);
    if (!s.isEmpty())
      visitS(s.funcBody);
    s.outBody && visitS(s.outBody);

    return s;
  }

  S visit(ScopeStatement s)
  {
//     enterScope();
    visitS(s.stmnt);
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
    s.decl && visitD(s.decl);
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
    foreach(pItem; p.items)
    {
      pItem && visitN(pItem);
    }

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
