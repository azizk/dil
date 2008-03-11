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
import dil.lexer.IdTable;
import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Types,
       dil.semantic.Scope,
       dil.semantic.Module,
       dil.semantic.Analysis;
import dil.Compilation;
import dil.Location;
import dil.Information;
import dil.Messages;
import dil.Enums;
import dil.CompilerInfo;
import common;

import tango.io.FileConst;
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
  void insertOverload(Symbol sym, Identifier* name)
  {
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

  /// Creates an error report.
  void error(Token* token, char[] formatMsg, ...)
  {
    if (!modul.infoMan)
      return;
    auto location = token.getErrorLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    modul.infoMan ~= new SemanticError(location, msg);
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
    // Create the symbol.
    d.symbol = new Enum(d.name, d);
    auto isAnonymous = d.name is null;
    if (isAnonymous)
      d.symbol.name = IdTable.genAnonEnumID();
    insert(d.symbol, d.symbol.name);
    auto parentScopeSymbol = scop.symbol;
    enterScope(d.symbol);
    // Declare members.
    foreach (member; d.members)
    {
      visitD(member);
      if (isAnonymous) // Also insert into parent scope if enum is anonymous.
        insert(member.symbol, parentScopeSymbol);
      member.symbol.parent = d.symbol;
    }
    exitScope();
    return d;
  }

  D visit(EnumMemberDeclaration d)
  {
    d.symbol = new EnumMember(d.name, protection, storageClass, linkageType, d);
    insert(d.symbol, d.symbol.name);
    return d;
  }

  D visit(ClassDeclaration d)
  {
    if (d.symbol)
      return d;
    d.symbol = new Class(d.name, d);
    // Insert into current scope.
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
      insert(d.symbol, d.name);
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
      insert(d.symbol, d.name);
    enterScope(d.symbol);
    // Continue semantic analysis.
    d.decls && visitD(d.decls);
    exitScope();
    return d;
  }

  D visit(ConstructorDeclaration d)
  {
    auto func = new Function(Ident.__ctor, d);
    insertOverload(func, func.name);
    return d;
  }

  D visit(StaticConstructorDeclaration d)
  {
    auto func = new Function(Ident.__ctor, d);
    insertOverload(func, func.name);
    return d;
  }

  D visit(DestructorDeclaration d)
  {
    auto func = new Function(Ident.__dtor, d);
    insertOverload(func, func.name);
    return d;
  }

  D visit(StaticDestructorDeclaration d)
  {
    auto func = new Function(Ident.__dtor, d);
    insertOverload(func, func.name);
    return d;
  }

  D visit(FunctionDeclaration d)
  {
    auto func = new Function(d.name, d);
    insertOverload(func, func.name);
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
      insert(variable, name);
    }
    return vd;
  }

  D visit(InvariantDeclaration d)
  {
    auto func = new Function(Ident.__invariant, d);
    insert(func, func.name);
    return d;
  }

  D visit(UnittestDeclaration d)
  {
    auto func = new Function(Ident.__unittest, d);
    insertOverload(func, func.name);
    return d;
  }

  D visit(DebugDeclaration d)
  {
    if (d.isSpecification)
    {
      if (!isModuleScope())
        error(d.begin, MSG.DebugSpecModuleLevel, d.spec.srcText);
      else if (d.spec.kind == TOK.Identifier)
        context.addDebugId(d.spec.ident.str);
      else
        context.debugLevel = d.spec.uint_;
    }
    else
    {
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
    {
      if (!isModuleScope())
        error(d.begin, MSG.VersionSpecModuleLevel, d.spec.srcText);
      else if (d.spec.kind == TOK.Identifier)
        context.addVersionId(d.spec.ident.str);
      else
        context.versionLevel = d.spec.uint_;
    }
    else
    {
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
    d.symbol = new Template(d.name, d);
    // Insert into current scope.
    insertOverload(d.symbol, d.name);
    enterScope(d.symbol);
    // Continue semantic analysis.
    visitD(d.decls);
    exitScope();
    return d;
  }

  D visit(NewDeclaration d)
  {
    auto func = new Function(Ident.__new, d);
    insert(func, func.name);
    return d;
  }

  D visit(DeleteDeclaration d)
  {
    auto func = new Function(Ident.__delete, d);
    insert(func, func.name);
    return d;
  }

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
}
