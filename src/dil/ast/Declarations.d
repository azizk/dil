/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.ast.Declarations;

public import dil.ast.Declaration;
import dil.ast.Node,
       dil.ast.Expression,
       dil.ast.Types,
       dil.ast.Statements,
       dil.ast.Parameters,
       dil.ast.NodeCopier,
       dil.ast.Meta;
import dil.lexer.IdTable;
import dil.semantic.Symbols;
import dil.Enums;
import common;

class CompoundDecl : Declaration
{
  this()
  {
    mixin(set_kind);
  }

  this(Declaration[] decls)
  {
    this();
    this.decls = decls;
  }

  void opCatAssign(Declaration d)
  {
    addChild(d);
  }

  void opCatAssign(CompoundDecl ds)
  {
    addChildren(ds.children);
  }

  Declaration[] decls() @property
  {
    return cast(Declaration[])this.children;
  }

  void decls(Declaration[] decls) @property
  {
    this.children = cast(Node[])decls;
  }

  mixin(memberInfo("decls"));

  mixin methods;
}

/// $(BNF ColonBlockDecl := ":" Declaration)
class ColonBlockDecl : Declaration
{
  Declaration decls;
  mixin(memberInfo("decls"));
  this(Declaration decls)
  {
    mixin(set_kind);
    addChild(decls);
    this.decls = decls;
  }
  mixin methods;
}

/// Single semicolon.
class EmptyDecl : Declaration
{
  mixin(memberInfo());
  this()
  {
    mixin(set_kind);
  }
  mixin methods;
}

/// Illegal declarations encompass all tokens that don't
/// start a DeclarationDefinition.
/// See_Also: dil.lexer.Token.isDeclDefStartToken()
class IllegalDecl : Declaration
{
  mixin(memberInfo());
  this()
  {
    mixin(set_kind);
  }
  mixin methods;
}

/// FQN means "fully qualified name".
/// $(BNF ModuleFQN := Identifier ("." Identifier)*)
alias Token*[] ModuleFQN;

class ModuleDecl : Declaration
{
  Token* type; /// safe | system
  Token* name; /// E.g.: Declarations
  Token*[] packages; /// E.g.: [dil, ast]
  Token*[] fqn; /// E.g.: [dil, ast, Declarations]
  mixin(memberInfo("type", "fqn"));

  this(Token* type, ModuleFQN fqn)
  {
    mixin(set_kind);
    assert(fqn.length != 0);
    this.type = type;
    this.fqn = fqn;
    this.name = fqn[$-1];
    this.packages = fqn[0..$-1];
  }

  /// Returns the fully qualified name. E.g.: "dil.ast.Declarations"
  cstring getFQN()
  {
    auto fqn = getPackageName('.');
    if (fqn.length)
      fqn ~= '.';
    fqn ~= getName();
    return fqn;
  }

  /// Returns the name of this module. E.ǵ.: "Declarations"
  cstring getName()
  {
    return name.ident.str;
  }

  /// Returns the packages of this module. E.g.: "dil.ast"
  char[] getPackageName(char separator)
  {
    char[] pname;
    foreach (pckg; packages)
      if (pckg)
        pname ~= pckg.ident.str ~ separator;
    if (pname.length)
      pname = pname[0..$-1]; // Remove last separator
    return pname;
  }

  mixin methods;
}

class ImportDecl : Declaration
{
  private alias Token*[] Ids;
  ModuleFQN[] moduleFQNs;
  Ids moduleAliases;
  Ids bindNames;
  Ids bindAliases;
  mixin(memberInfo("moduleFQNs", "moduleAliases", "bindNames", "bindAliases",
    "isStatic"));

  this(ModuleFQN[] moduleFQNs, Ids moduleAliases, Ids bindNames,
       Ids bindAliases, bool isStatic)
  {
    mixin(set_kind);
    this.moduleFQNs = moduleFQNs;
    this.moduleAliases = moduleAliases;
    this.bindNames = bindNames;
    this.bindAliases = bindAliases;
    if (isStatic)
      this.stcs |= StorageClass.Static;
  }

  cstring[] getModuleFQNs(char separator)
  {
    cstring[] FQNs;
    foreach (moduleFQN; moduleFQNs)
    {
      char[] FQN;
      foreach (ident; moduleFQN)
        if (ident)
          FQN ~= ident.ident.str ~ separator;
      FQNs ~= FQN[0..$-1]; // Remove last separator
    }
    return FQNs;
  }

  mixin methods;
}

class AliasDecl : Declaration
{
  Declaration decl;
  /// Shortcut that skips any attributes inbetween.
  /// Eg.: alias extern(C) void function() C_funcptr;
  ///        decl^  vardecl^
  Declaration vardecl;
  mixin(memberInfo("decl"));
  this(Declaration decl)
  {
    mixin(set_kind);
    addChild(decl);
    this.decl = decl;
  }
  mixin methods;
}

class AliasThisDecl : Declaration
{
  Token* ident;
  mixin(memberInfo("ident"));
  this(Token* ident)
  {
    mixin(set_kind);
    this.ident = ident;
  }
  mixin methods;
}

class TypedefDecl : Declaration
{
  Declaration decl;
  Declaration vardecl;
  mixin(memberInfo("decl"));
  this(Declaration decl)
  {
    mixin(set_kind);
    addChild(decl);
    this.decl = decl;
  }
  mixin methods;
}

class EnumDecl : Declaration
{
  Token* name;
  TypeNode baseType;
  EnumMemberDecl[] members;
  mixin(memberInfo("name", "baseType", "members"));

  this(Token* name, TypeNode baseType, EnumMemberDecl[] members)
  {
    mixin(set_kind);
    addOptChild(baseType);
    addOptChildren(members);

    this.name = name;
    this.baseType = baseType;
    this.members = members;
  }

  /// Returns the Identifier of this enum, or null if anonymous.
  Identifier* nameId()
  {
    return name ? name.ident : null;
  }

  EnumSymbol symbol;

  mixin methods;
}

class EnumMemberDecl : Declaration
{
  TypeNode type; // D 2.0
  Token* name;
  Expression value;
  mixin(memberInfo("type", "name", "value"));

  private this(Token* name, Expression value)
  {
    assert(name);
    mixin(set_kind);
    addOptChild(value);

    this.name = name;
    this.value = value;
  }

  // D 2.0
  this(TypeNode type, Token* name, Expression value)
  {
    addOptChild(type);
    this.type = type;
    this(name, value);
  }

  EnumMember symbol;

  mixin methods;
}

class TemplateDecl : Declaration
{
  Token* name;
  TemplateParameters tparams;
  Expression constraint; /// If-constraint in D2.
  CompoundDecl decls;
  bool isMixin; /// Is this a mixin template? (D2 feature.)
  bool isWrapper; /// Is this wrapping a func/class/struct/etc. declaration?
  mixin(memberInfo("name", "tparams", "constraint", "decls"));

  this(Token* name, TemplateParameters tparams, Expression constraint,
       CompoundDecl decls)
  {
    mixin(set_kind);
    addChild(tparams);
    addOptChild(constraint);
    addChild(decls);

    assert(name !is null);
    this.name = name;
    this.tparams = tparams;
    this.constraint = constraint;
    this.decls = decls;

    auto list = decls.decls;
    if (list.length == 1)
      switch (list[0].kind)
      {
      alias NodeKind NK;
      case NK.FunctionDecl, NK.ClassDecl, NK.InterfaceDecl,
           NK.StructDecl, NK.UnionDecl, NK.ConstructorDecl:
        this.isWrapper = true;
      default:
      }
  }

  /// Returns the Identifier of this template.
  Identifier* nameId()
  {
    return name.ident;
  }

  TemplateSymbol symbol; /// The template symbol for this declaration.

  mixin methods;
}

abstract class AggregateDecl : Declaration
{
  Token* name;
  CompoundDecl decls;
  this(Token* name, CompoundDecl decls)
  {
    this.name = name;
    this.decls = decls;
  }

  /// Returns the Identifier of this declaration, or null if anonymous.
  Identifier* nameId()
  {
    return name ? name.ident : null;
  }
}

class ClassDecl : AggregateDecl
{
  BaseClassType[] bases;
  mixin(memberInfo("name", "bases", "decls"));
  this(Token* name, BaseClassType[] bases, CompoundDecl decls)
  {
    super(name, decls);
    mixin(set_kind);
    addOptChildren(bases);
    addOptChild(decls);

    this.bases = bases;
  }

  ClassSymbol symbol; /// The class symbol for this declaration.

  mixin methods;
}

class InterfaceDecl : AggregateDecl
{
  BaseClassType[] bases;
  mixin(memberInfo("name", "bases", "decls"));
  this(Token* name, BaseClassType[] bases, CompoundDecl decls)
  {
    super(name, decls);
    mixin(set_kind);
    addOptChildren(bases);
    addOptChild(decls);

    this.bases = bases;
  }

  alias dil.semantic.Symbols.Interface Interface;

  InterfaceSymbol symbol; /// The interface symbol for this declaration.

  mixin methods;
}

class StructDecl : AggregateDecl
{
  uint alignSize;
  mixin(memberInfo("name", "decls", "alignSize"));
  this(Token* name, CompoundDecl decls)
  {
    super(name, decls);
    mixin(set_kind);
    addOptChild(decls);
  }

  /// For ASTSerializer.
  this(Token* name, CompoundDecl decls, uint alignSize)
  {
    this(name, decls);
    setAlignSize(alignSize);
  }

  void setAlignSize(uint alignSize)
  {
    this.alignSize = alignSize;
  }

  StructSymbol symbol; /// The struct symbol for this declaration.

  mixin methods;
}

class UnionDecl : AggregateDecl
{
  mixin(memberInfo("name", "decls"));
  this(Token* name, CompoundDecl decls)
  {
    super(name, decls);
    mixin(set_kind);
    addOptChild(decls);
  }

  UnionSymbol symbol; /// The union symbol for this declaration.

  mixin methods;
}

class ConstructorDecl : Declaration
{
  Parameters params;
  FuncBodyStmt funcBody;
  mixin(memberInfo("params", "funcBody"));
  this(Parameters params, FuncBodyStmt funcBody)
  {
    mixin(set_kind);
    addChild(params);
    addChild(funcBody);

    this.params = params;
    this.funcBody = funcBody;
  }
  mixin methods;
}

class StaticCtorDecl : Declaration
{
  FuncBodyStmt funcBody;
  mixin(memberInfo("funcBody"));
  this(FuncBodyStmt funcBody)
  {
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
  mixin methods;
}

class DestructorDecl : Declaration
{
  FuncBodyStmt funcBody;
  mixin(memberInfo("funcBody"));
  this(FuncBodyStmt funcBody)
  {
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
  mixin methods;
}

class StaticDtorDecl : Declaration
{
  FuncBodyStmt funcBody;
  mixin(memberInfo("funcBody"));
  this(FuncBodyStmt funcBody)
  {
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
  mixin methods;
}

class FunctionDecl : Declaration
{
  TypeNode returnType;
  Token* name;
  Parameters params;
  FuncBodyStmt funcBody;
  LinkageType lnkg;
  bool cantInterpret = false;

  mixin(memberInfo("returnType", "name", "params", "funcBody", "lnkg"));
  this(TypeNode returnType, Token* name,
       Parameters params, FuncBodyStmt funcBody,
       LinkageType lnkg = LinkageType.None)
  {
    mixin(set_kind);
    addOptChild(returnType);
    addChild(params);
    addChild(funcBody);

    this.returnType = returnType;
    this.name = name;
    this.params = params;
    this.funcBody = funcBody;
    this.lnkg = lnkg;
  }

  bool isTemplatized()
  { // E.g.: void func(T)(T t)
    //                  ^ params.begin.prevNWS
    return params.begin.prevNWS.kind == TOK.RParen;
  }

  mixin methods;
}

/// $(BNF VariablesDecl :=
///  Type? Identifier ("=" Init)? ("," Identifier ("=" Init)?)* ";")
class VariablesDecl : Declaration
{
  TypeNode type; /// The type of the variables.
  Token*[] names; /// Variable names.
  Expression[] inits; /// Respective initial values.
  LinkageType lnkg; /// They linkage type.
  mixin(memberInfo("type", "names", "inits", "lnkg"));

  this(TypeNode type, Token*[] names, Expression[] inits,
       LinkageType lnkg = LinkageType.None)
  {
    // No empty arrays allowed. Both arrays must be of same size.
    assert(names.length != 0 && names.length == inits.length);
    // If no type (in case of AutoDecl), first value mustn't be null.
    assert(type || inits[0] !is null);
    mixin(set_kind);
    addOptChild(type);
    foreach (init; inits)
      addOptChild(init);

    this.type = type;
    this.names = names;
    this.inits = inits;
    this.lnkg = lnkg;
  }

  /// Returns the first non-null init expression, or null if there is none.
  Expression firstInit()
  {
    foreach (init; inits)
      if (init !is null)
        return init;
    return null;
  }

  VariableSymbol[] variables;

  mixin methods;
}

class InvariantDecl : Declaration
{
  FuncBodyStmt funcBody;
  mixin(memberInfo("funcBody"));
  this(FuncBodyStmt funcBody)
  {
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
  mixin methods;
}

class UnittestDecl : Declaration
{
  FuncBodyStmt funcBody;
  mixin(memberInfo("funcBody"));
  this(FuncBodyStmt funcBody)
  {
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
  mixin methods;
}

abstract class ConditionalCompilationDecl : Declaration
{
  Token* spec;
  Token* cond;
  Declaration decls, elseDecls;

  this(Token* spec, Token* cond, Declaration decls, Declaration elseDecls)
  {
    addOptChild(decls);
    addOptChild(elseDecls);

    this.spec = spec;
    this.cond = cond;
    this.decls = decls;
    this.elseDecls = elseDecls;
  }

  bool isSpecification()
  {
    return decls is null;
  }

  bool isCondition()
  {
    return decls !is null;
  }

  /// The branch to be compiled in.
  Declaration compiledDecls;
}

class DebugDecl : ConditionalCompilationDecl
{
  mixin(memberInfo("spec", "cond", "decls", "elseDecls"));
  this(Token* spec, Token* cond, Declaration decls, Declaration elseDecls)
  {
    super(spec, cond, decls, elseDecls);
    mixin(set_kind);
  }
  mixin methods;
}

class VersionDecl : ConditionalCompilationDecl
{
  mixin(memberInfo("spec", "cond", "decls", "elseDecls"));
  this(Token* spec, Token* cond, Declaration decls, Declaration elseDecls)
  {
    super(spec, cond, decls, elseDecls);
    mixin(set_kind);
  }
  mixin methods;
}

class StaticIfDecl : Declaration
{
  Expression condition;
  Declaration ifDecls, elseDecls;
  mixin(memberInfo("condition", "ifDecls", "elseDecls"));
  this(Expression condition, Declaration ifDecls, Declaration elseDecls)
  {
    mixin(set_kind);
    addChild(condition);
    addChild(ifDecls);
    addOptChild(elseDecls);

    this.condition = condition;
    this.ifDecls = ifDecls;
    this.elseDecls = elseDecls;
  }
  mixin methods;
}

class StaticAssertDecl : Declaration
{
  Expression condition, message;
  mixin(memberInfo("condition", "message"));
  this(Expression condition, Expression message)
  {
    mixin(set_kind);
    addChild(condition);
    addOptChild(message);

    this.condition = condition;
    this.message = message;
  }
  mixin methods;
}

class NewDecl : Declaration
{
  Parameters params;
  FuncBodyStmt funcBody;
  mixin(memberInfo("params", "funcBody"));
  this(Parameters params, FuncBodyStmt funcBody)
  {
    mixin(set_kind);
    addChild(params);
    addChild(funcBody);

    this.params = params;
    this.funcBody = funcBody;
  }
  mixin methods;
}

class DeleteDecl : Declaration
{
  Parameters params;
  FuncBodyStmt funcBody;
  mixin(memberInfo("params", "funcBody"));
  this(Parameters params, FuncBodyStmt funcBody)
  {
    mixin(set_kind);
    addChild(params);
    addChild(funcBody);

    this.params = params;
    this.funcBody = funcBody;
  }
  mixin methods;
}

abstract class AttributeDecl : Declaration
{
  Declaration decls;
  this(Declaration decls)
  {
    addChild(decls);
    this.decls = decls;
  }

  void setDecls(Declaration decls)
  {
    this.decls = decls;
    if (children.length)
      children[0] = decls;
    else
      addChild(decls);
  }
}

class ProtectionDecl : AttributeDecl
{
  Protection prot;
  mixin(memberInfo("prot", "decls"));
  this(Protection prot, Declaration decls)
  {
    super(decls);
    mixin(set_kind);
    this.prot = prot;
  }
  mixin methods;
}

class StorageClassDecl : AttributeDecl
{
  StorageClass stc;
  mixin(memberInfo("stc", "decls"));
  this(StorageClass stc, Declaration decls)
  {
    super(decls);
    mixin(set_kind);

    this.stc = stc;
  }
  mixin methods;
}

class LinkageDecl : AttributeDecl
{
  LinkageType linkageType;
  mixin(memberInfo("linkageType", "decls"));
  this(LinkageType linkageType, Declaration decls)
  {
    super(decls);
    mixin(set_kind);

    this.linkageType = linkageType;
  }
  mixin methods;
}

class AlignDecl : AttributeDecl
{
  int size;
  Token* sizetok;
  mixin(memberInfo("sizetok", "decls"));
  this(Token* sizetok, Declaration decls)
  {
    super(decls);
    mixin(set_kind);
    this.size = sizetok ? sizetok.int_ : -1;
    this.sizetok = sizetok;
  }
  mixin methods;
}

class PragmaDecl : AttributeDecl
{
  Token* ident;
  Expression[] args;
  mixin(memberInfo("ident", "args", "decls"));
  this(Token* ident, Expression[] args, Declaration decls)
  {
    addOptChildren(args); // Add args before calling super().
    super(decls);
    mixin(set_kind);

    this.ident = ident;
    this.args = args;
  }

  mixin methods;
}

class MixinDecl : Declaration
{
  /// IdExpr := IdentifierExpr | TmplInstanceExpr
  /// MixinTemplate := IdExpr ("." IdExpr)*
  Expression templateExpr;
  Token* mixinIdent; /// Optional mixin identifier.
  Expression argument; /// "mixin" "(" AssignExpr ")"

  mixin(memberInfo("templateExpr", "mixinIdent", "argument"));
  this(Expression templateExpr, Token* mixinIdent)
  {
    mixin(set_kind);
    addChild(templateExpr);

    this.templateExpr = templateExpr;
    this.mixinIdent = mixinIdent;
  }

  this(Expression argument)
  {
    mixin(set_kind);
    addChild(argument);

    this.argument = argument;
  }

  /// Constructor for the deserializer.
  this(Expression templateExpr, Token* mixinIdent, Expression argument)
  {
    if (argument)
      this(argument);
    else
      this(templateExpr, mixinIdent);
  }

  bool isMixinExpr()
  {
    return argument !is null;
  }

  Declaration decls; /// Initialized in the semantic phase.

  mixin methods;
}
