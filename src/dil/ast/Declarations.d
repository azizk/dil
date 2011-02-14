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
       dil.ast.NodeCopier;
import dil.lexer.IdTable;
import dil.semantic.Symbols;
import dil.Enums;
import common;

class CompoundDecl : Declaration
{
  this()
  {
    hasBody = true;
    mixin(set_kind);
  }

  void opCatAssign(Declaration d)
  {
    addChild(d);
  }

  void opCatAssign(CompoundDecl ds)
  {
    addChildren(ds.children);
  }

  Declaration[] decls()
  {
    return cast(Declaration[])this.children;
  }

  void decls(Declaration[] decls)
  {
    this.children = decls;
  }

  mixin(copyMethod);
}

/// Single semicolon.
class EmptyDecl : Declaration
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
}

/// Illegal declarations encompass all tokens that don't
/// start a DeclarationDefinition.
/// See_Also: dil.lexer.Token.isDeclDefStartToken()
class IllegalDecl : Declaration
{
  this()
  {
    mixin(set_kind);
  }
  mixin(copyMethod);
}

/// FQN means "fully qualified name".
/// $(BNF ModuleFQN := Identifier ("." Identifier)*)
alias Token*[] ModuleFQN;

class ModuleDecl : Declaration
{
  Token* typeIdent;
  Token* moduleName;
  Token*[] packages;
  this(Token* ident, ModuleFQN moduleFQN)
  {
    mixin(set_kind);
    assert(moduleFQN.length != 0);
    this.typeIdent = ident;
    this.moduleName = moduleFQN[$-1];
    this.packages = moduleFQN[0..$-1];
  }

  char[] getFQN()
  {
    auto pname = getPackageName('.');
    if (pname.length)
      return pname ~ "." ~ getName();
    else
      return getName();
  }

  char[] getName()
  {
    if (moduleName)
      return moduleName.ident.str;
    return null;
  }

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

  mixin(copyMethod);
}

class ImportDecl : Declaration
{
  private alias Token*[] Ids;
  ModuleFQN[] moduleFQNs;
  Ids moduleAliases;
  Ids bindNames;
  Ids bindAliases;

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

  char[][] getModuleFQNs(char separator)
  {
    char[][] FQNs;
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

  mixin(copyMethod);
}

class AliasDecl : Declaration
{
  Declaration decl;
  /// Shortcut that skips any attributes inbetween.
  /// Eg.: alias extern(C) void function() C_funcptr;
  ///        decl^  vardecl^
  Declaration vardecl;
  this(Declaration decl)
  {
    mixin(set_kind);
    addChild(decl);
    this.decl = decl;
  }
  mixin(copyMethod);
}

class AliasThisDecl : Declaration
{
  Token* ident;
  this(Token* ident)
  {
    mixin(set_kind);
    this.ident = ident;
  }
  mixin(copyMethod);
}

class TypedefDecl : Declaration
{
  Declaration decl;
  Declaration vardecl;
  this(Declaration decl)
  {
    mixin(set_kind);
    addChild(decl);
    this.decl = decl;
  }
  mixin(copyMethod);
}

class EnumDecl : Declaration
{
  Token* name;
  TypeNode baseType;
  EnumMemberDecl[] members;
  this(Token* name, TypeNode baseType, EnumMemberDecl[] members, bool hasBody)
  {
    super.hasBody = hasBody;
    mixin(set_kind);
    addOptChild(baseType);
    addOptChildren(members);

    this.name = name;
    this.baseType = baseType;
    this.members = members;
  }

  /// Returns the Identifier object of a variable.
  Identifier* nameId()
  {
    return name ? name.ident : null;
  }

  EnumSymbol symbol;

  mixin(copyMethod);
}

class EnumMemberDecl : Declaration
{
  TypeNode type; // D 2.0
  Token* name;
  Expression value;
  this(Token* name, Expression value)
  {
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

  /// Returns the Identifier object of a variable.
  Identifier* nameId()
  {
    return name ? name.ident : null;
  }

  EnumMember symbol;

  mixin(copyMethod);
}

class TemplateDecl : Declaration
{
  Token* name;
  TemplateParameters tparams;
  Expression constraint; // D 2.0
  CompoundDecl decls;
  bool isMixin; /// Is this a mixin template? (D2 feature.)

  this(Token* name, TemplateParameters tparams, Expression constraint,
       CompoundDecl decls)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(tparams);
    addOptChild(constraint);
    addChild(decls);

    this.name = name;
    this.tparams = tparams;
    this.constraint = constraint;
    this.decls = decls;
  }

  /// Returns the Identifier object of this declaration. May be null.
  Identifier* nameId()
  {
    assert(name !is null);
    return name.ident;
  }

  /// Returns true if this is a template that wraps a class, struct etc.
  bool isWrapper()
  { // "mixin template" is D2.
    return begin.kind != TOK.Template && begin.kind != TOK.Mixin;
  }

  TemplateSymbol symbol; /// The template symbol for this declaration.

  mixin(copyMethod);
}

// Note: tparams is commented out because the Parser wraps declarations
//       with template parameters inside a TemplateDecl.

abstract class AggregateDecl : Declaration
{
  Token* name;
//   TemplateParameters tparams;
  CompoundDecl decls;
  this(Token* name, /+TemplateParameters tparams, +/CompoundDecl decls)
  {
    super.hasBody = decls !is null;
    this.name = name;
//     this.tparams = tparams;
    this.decls = decls;
  }

  /// Returns the Identifier object of this declaration. May be null.
  Identifier* nameId()
  {
    return name ? name.ident : null;
  }
}

class ClassDecl : AggregateDecl
{
  BaseClassType[] bases;
  this(Token* name, /+TemplateParameters tparams, +/BaseClassType[] bases, CompoundDecl decls)
  {
    super(name, /+tparams, +/decls);
    mixin(set_kind);
//     addChild(tparams);
    addOptChildren(bases);
    addOptChild(decls);

    this.bases = bases;
  }

  ClassSymbol symbol; /// The class symbol for this declaration.

  mixin(copyMethod);
}

class InterfaceDecl : AggregateDecl
{
  BaseClassType[] bases;
  this(Token* name, /+TemplateParameters tparams, +/BaseClassType[] bases, CompoundDecl decls)
  {
    super(name, /+tparams, +/decls);
    mixin(set_kind);
//     addChild(tparams);
    addOptChildren(bases);
    addOptChild(decls);

    this.bases = bases;
  }

  alias dil.semantic.Symbols.Interface Interface;

  InterfaceSymbol symbol; /// The interface symbol for this declaration.

  mixin(copyMethod);
}

class StructDecl : AggregateDecl
{
  uint alignSize;
  this(Token* name, /+TemplateParameters tparams, +/CompoundDecl decls)
  {
    super(name, /+tparams, +/decls);
    mixin(set_kind);
//     addChild(tparams);
    addOptChild(decls);
  }

  void setAlignSize(uint alignSize)
  {
    this.alignSize = alignSize;
  }

  StructSymbol symbol; /// The struct symbol for this declaration.

  mixin(copyMethod);
}

class UnionDecl : AggregateDecl
{
  this(Token* name, /+TemplateParameters tparams, +/CompoundDecl decls)
  {
    super(name, /+tparams, +/decls);
    mixin(set_kind);
//     addChild(tparams);
    addOptChild(decls);
  }

  UnionSymbol symbol; /// The union symbol for this declaration.

  mixin(copyMethod);
}

class ConstructorDecl : Declaration
{
  Parameters params;
  FuncBodyStmt funcBody;
  this(Parameters params, FuncBodyStmt funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(params);
    addChild(funcBody);

    this.params = params;
    this.funcBody = funcBody;
  }
  mixin(copyMethod);
}

class StaticCtorDecl : Declaration
{
  FuncBodyStmt funcBody;
  this(FuncBodyStmt funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
  mixin(copyMethod);
}

class DestructorDecl : Declaration
{
  FuncBodyStmt funcBody;
  this(FuncBodyStmt funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
  mixin(copyMethod);
}

class StaticDtorDecl : Declaration
{
  FuncBodyStmt funcBody;
  this(FuncBodyStmt funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
  mixin(copyMethod);
}

class FunctionDecl : Declaration
{
  TypeNode returnType;
  Token* name;
//   TemplateParameters tparams;
  Parameters params;
  FuncBodyStmt funcBody;
  LinkageType linkageType;
  bool cantInterpret = false;

  this(TypeNode returnType, Token* name,/+ TemplateParameters tparams,+/
       Parameters params, FuncBodyStmt funcBody)
  {
    super.hasBody = funcBody.funcBody !is null;
    mixin(set_kind);
    addOptChild(returnType);
//     addChild(tparams);
    addChild(params);
    addChild(funcBody);

    this.returnType = returnType;
    this.name = name;
//     this.tparams = tparams;
    this.params = params;
    this.funcBody = funcBody;
  }

  // Sets the LinkageType of this function.
  void setLinkageType(LinkageType linkageType)
  {
    this.linkageType = linkageType;
  }

  bool isTemplatized()
  { // E.g.: void func(T)(T t)
    //                  ^ params.begin.prevNWS
    return params.begin.prevNWS.kind == TOK.RParen;
  }

  mixin(copyMethod);
}

/// $(BNF VariablesDecl :=
///  Type? Identifier ("=" Init)? ("," Identifier ("=" Init)?)* ";")
class VariablesDecl : Declaration
{
  TypeNode typeNode; /// The type of the variables.
  Token*[] names; /// Variable names.
  Expression[] inits; /// Respective initial values.
  LinkageType linkageType; /// They linkage type.

  this(TypeNode typeNode, Token*[] names, Expression[] inits)
  {
    // No empty arrays allowed. Both arrays must be of same size.
    assert(names.length != 0 && names.length == inits.length);
    // If no type (in case of AutoDecl), first value mustn't be null.
    assert(typeNode || inits[0] !is null);
    mixin(set_kind);
    addOptChild(typeNode);
    foreach (init; inits)
      addOptChild(init);

    this.typeNode = typeNode;
    this.names = names;
    this.inits = inits;
  }

  void setLinkageType(LinkageType linkageType)
  {
    this.linkageType = linkageType;
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

  mixin(copyMethod);
}

class InvariantDecl : Declaration
{
  FuncBodyStmt funcBody;
  this(FuncBodyStmt funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
  mixin(copyMethod);
}

class UnittestDecl : Declaration
{
  FuncBodyStmt funcBody;
  this(FuncBodyStmt funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
  mixin(copyMethod);
}

abstract class ConditionalCompilationDecl : Declaration
{
  Token* spec;
  Token* cond;
  Declaration decls, elseDecls;

  this(Token* spec, Token* cond, Declaration decls, Declaration elseDecls)
  {
    super.hasBody = decls !is null;
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
  this(Token* spec, Token* cond, Declaration decls, Declaration elseDecls)
  {
    super(spec, cond, decls, elseDecls);
    mixin(set_kind);
  }
  mixin(copyMethod);
}

class VersionDecl : ConditionalCompilationDecl
{
  this(Token* spec, Token* cond, Declaration decls, Declaration elseDecls)
  {
    super(spec, cond, decls, elseDecls);
    mixin(set_kind);
  }
  mixin(copyMethod);
}

class StaticIfDecl : Declaration
{
  Expression condition;
  Declaration ifDecls, elseDecls;
  this(Expression condition, Declaration ifDecls, Declaration elseDecls)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(condition);
    addChild(ifDecls);
    addOptChild(elseDecls);

    this.condition = condition;
    this.ifDecls = ifDecls;
    this.elseDecls = elseDecls;
  }
  mixin(copyMethod);
}

class StaticAssertDecl : Declaration
{
  Expression condition, message;
  this(Expression condition, Expression message)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(condition);
    addOptChild(message);

    this.condition = condition;
    this.message = message;
  }
  mixin(copyMethod);
}

class NewDecl : Declaration
{
  Parameters params;
  FuncBodyStmt funcBody;
  this(Parameters params, FuncBodyStmt funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(params);
    addChild(funcBody);

    this.params = params;
    this.funcBody = funcBody;
  }
  mixin(copyMethod);
}

class DeleteDecl : Declaration
{
  Parameters params;
  FuncBodyStmt funcBody;
  this(Parameters params, FuncBodyStmt funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(params);
    addChild(funcBody);

    this.params = params;
    this.funcBody = funcBody;
  }
  mixin(copyMethod);
}

abstract class AttributeDecl : Declaration
{
  Declaration decls;
  this(Declaration decls)
  {
    super.hasBody = true;
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
  this(Protection prot, Declaration decls)
  {
    super(decls);
    mixin(set_kind);
    this.prot = prot;
  }
  mixin(copyMethod);
}

class StorageClassDecl : AttributeDecl
{
  StorageClass stcs;
  this(StorageClass stcs, Declaration decls)
  {
    super(decls);
    mixin(set_kind);

    this.stcs = stcs;
  }
  mixin(copyMethod);
}

class LinkageDecl : AttributeDecl
{
  LinkageType linkageType;
  this(LinkageType linkageType, Declaration decls)
  {
    super(decls);
    mixin(set_kind);

    this.linkageType = linkageType;
  }
  mixin(copyMethod);
}

class AlignDecl : AttributeDecl
{
  int size;
  Token* sizetok;
  this(Token* sizetok, Declaration decls)
  {
    super(decls);
    mixin(set_kind);
    this.size = sizetok ? sizetok.int_ : -1;
    this.sizetok = sizetok;
  }
  mixin(copyMethod);
}

class PragmaDecl : AttributeDecl
{
  Token* idtok;
  Expression[] args;
  this(Token* ident, Expression[] args, Declaration decls)
  {
    addOptChildren(args); // Add args before calling super().
    super(decls);
    mixin(set_kind);

    this.idtok = ident;
    this.args = args;
  }

  /// TODO: remove this and rename 'idtok' to 'ident'.
  Identifier* ident()
  {
    return idtok.ident;
  }

  mixin(copyMethod);
}

class MixinDecl : Declaration
{
  /// IdExpr := IdentifierExpr | TmplInstanceExpr
  /// MixinTemplate := IdExpr ("." IdExpr)*
  Expression templateExpr;
  Token* mixinIdent; /// Optional mixin identifier.
  Expression argument; /// "mixin" "(" AssignExpr ")"
  Declaration decls; /// Initialized in the semantic phase.

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

  bool isMixinExpr()
  {
    return argument !is null;
  }

  mixin(copyMethod);
}
