/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Declarations;

public import dil.ast.Declaration;
import dil.ast.Node;
import dil.ast.Expressions;
import dil.ast.Types;
import dil.ast.Statements;
import dil.ast.Parameters;
import dil.lexer.IdTable;
import dil.semantic.Symbols;
import dil.Enums;
import common;

class CompoundDeclaration : Declaration
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

  void opCatAssign(CompoundDeclaration ds)
  {
    addChildren(ds.children);
  }

  Declaration[] decls()
  {
    return cast(Declaration[])this.children;
  }
}

/// Single semicolon.
class EmptyDeclaration : Declaration
{
  this()
  {
    mixin(set_kind);
  }
}

/++
  Illegal declarations encompass all tokens that don't
  start a DeclarationDefinition.
  See_Also: dil.lexer.Token.isDeclDefStartToken()
+/
class IllegalDeclaration : Declaration
{
  this()
  {
    mixin(set_kind);
  }
}

/// FQN = fully qualified name
alias Identifier*[] ModuleFQN; // Identifier(.Identifier)*

class ModuleDeclaration : Declaration
{
  Identifier* moduleName;
  Identifier*[] packages;
  this(ModuleFQN moduleFQN)
  {
    mixin(set_kind);
    assert(moduleFQN.length != 0);
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
      return moduleName.str;
    return null;
  }

  char[] getPackageName(char separator)
  {
    char[] pname;
    foreach (pckg; packages)
      if (pckg)
        pname ~= pckg.str ~ separator;
    if (pname.length)
      pname = pname[0..$-1]; // Remove last separator
    return pname;
  }
}

class ImportDeclaration : Declaration
{
  private alias Identifier*[] Ids;
  ModuleFQN[] moduleFQNs;
  Ids moduleAliases;
  Ids bindNames;
  Ids bindAliases;

  this(ModuleFQN[] moduleFQNs, Ids moduleAliases, Ids bindNames, Ids bindAliases, bool isStatic)
  {
    mixin(set_kind);
    this.moduleFQNs = moduleFQNs;
    this.moduleAliases = moduleAliases;
    this.bindNames = bindNames;
    this.bindAliases = bindAliases;
    if (isStatic)
      this.stc |= StorageClass.Static;
  }

  char[][] getModuleFQNs(char separator)
  {
    char[][] FQNs;
    foreach (moduleFQN; moduleFQNs)
    {
      char[] FQN;
      foreach (ident; moduleFQN)
        if (ident)
          FQN ~= ident.str ~ separator;
      FQNs ~= FQN[0..$-1]; // Remove last separator
    }
    return FQNs;
  }
}

class AliasDeclaration : Declaration
{
  Declaration decl;
  this(Declaration decl)
  {
    mixin(set_kind);
    addChild(decl);
    this.decl = decl;
  }
}

class TypedefDeclaration : Declaration
{
  Declaration decl;
  this(Declaration decl)
  {
    mixin(set_kind);
    addChild(decl);
    this.decl = decl;
  }
}

class EnumDeclaration : Declaration
{
  Identifier* name;
  TypeNode baseType;
  EnumMemberDeclaration[] members;
  this(Identifier* name, TypeNode baseType, EnumMemberDeclaration[] members, bool hasBody)
  {
    super.hasBody = hasBody;
    mixin(set_kind);
    addOptChild(baseType);
    addOptChildren(members);

    this.name = name;
    this.baseType = baseType;
    this.members = members;
  }

  Enum symbol;
}

class EnumMemberDeclaration : Declaration
{
  Identifier* name;
  Expression value;
  this(Identifier* name, Expression value)
  {
    mixin(set_kind);
    addOptChild(value);

    this.name = name;
    this.value = value;
  }

  EnumMember symbol;
}

class TemplateDeclaration : Declaration
{
  Identifier* name;
  TemplateParameters tparams;
  CompoundDeclaration decls;
  this(Identifier* name, TemplateParameters tparams, CompoundDeclaration decls)
  {
    super.hasBody = true;
    mixin(set_kind);
    addOptChild(tparams);
    addChild(decls);

    this.name = name;
    this.tparams = tparams;
    this.decls = decls;
  }

  Template symbol; /// The template symbol for this declaration.
}

abstract class AggregateDeclaration : Declaration
{
  Identifier* name;
//   TemplateParameters tparams;
  CompoundDeclaration decls;
  this(Identifier* name, /+TemplateParameters tparams, +/CompoundDeclaration decls)
  {
    super.hasBody = decls !is null;
    this.name = name;
//     this.tparams = tparams;
    this.decls = decls;
  }
}

class ClassDeclaration : AggregateDeclaration
{
  BaseClassType[] bases;
  this(Identifier* name, /+TemplateParameters tparams, +/BaseClassType[] bases, CompoundDeclaration decls)
  {
    super(name, /+tparams, +/decls);
    mixin(set_kind);
//     addOptChild(tparams);
    addOptChildren(bases);
    addOptChild(decls);

    this.bases = bases;
  }

  Class symbol; /// The class symbol for this declaration.
}

class InterfaceDeclaration : AggregateDeclaration
{
  BaseClassType[] bases;
  this(Identifier* name, /+TemplateParameters tparams, +/BaseClassType[] bases, CompoundDeclaration decls)
  {
    super(name, /+tparams, +/decls);
    mixin(set_kind);
//     addOptChild(tparams);
    addOptChildren(bases);
    addOptChild(decls);

    this.bases = bases;
  }

  alias dil.semantic.Symbols.Interface Interface;

  Interface symbol; /// The interface symbol for this declaration.
}

class StructDeclaration : AggregateDeclaration
{
  uint alignSize;
  this(Identifier* name, /+TemplateParameters tparams, +/CompoundDeclaration decls)
  {
    super(name, /+tparams, +/decls);
    mixin(set_kind);
//     addOptChild(tparams);
    addOptChild(decls);
  }

  void setAlignSize(uint alignSize)
  {
    this.alignSize = alignSize;
  }

  Struct symbol; /// The struct symbol for this declaration.
}

class UnionDeclaration : AggregateDeclaration
{
  this(Identifier* name, /+TemplateParameters tparams, +/CompoundDeclaration decls)
  {
    super(name, /+tparams, +/decls);
    mixin(set_kind);
//     addOptChild(tparams);
    addOptChild(decls);
  }

  Union symbol; /// The union symbol for this declaration.
}

class ConstructorDeclaration : Declaration
{
  Parameters params;
  FuncBodyStatement funcBody;
  this(Parameters params, FuncBodyStatement funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(params);
    addChild(funcBody);

    this.params = params;
    this.funcBody = funcBody;
  }
}

class StaticConstructorDeclaration : Declaration
{
  FuncBodyStatement funcBody;
  this(FuncBodyStatement funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
}

class DestructorDeclaration : Declaration
{
  FuncBodyStatement funcBody;
  this(FuncBodyStatement funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
}

class StaticDestructorDeclaration : Declaration
{
  FuncBodyStatement funcBody;
  this(FuncBodyStatement funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
}

class FunctionDeclaration : Declaration
{
  TypeNode returnType;
  Identifier* name;
//   TemplateParameters tparams;
  Parameters params;
  FuncBodyStatement funcBody;
  LinkageType linkageType;
  this(TypeNode returnType, Identifier* name,/+ TemplateParameters tparams,+/
       Parameters params, FuncBodyStatement funcBody)
  {
    super.hasBody = funcBody.funcBody !is null;
    mixin(set_kind);
    addChild(returnType);
//     addOptChild(tparams);
    addChild(params);
    addChild(funcBody);

    this.returnType = returnType;
    this.name = name;
//     this.tparams = tparams;
    this.params = params;
    this.funcBody = funcBody;
  }

  void setLinkageType(LinkageType linkageType)
  {
    this.linkageType = linkageType;
  }

  bool isTemplatized()
  { // E.g.: void func(T)(T t)
    //                  ^ params.begin.prevNWS
    return params.begin.prevNWS.kind == TOK.RParen;
  }
}

/// VariablesDeclaration := Type? Identifier ("=" Init)? ("," Identifier ("=" Init)?)* ";"
class VariablesDeclaration : Declaration
{
  TypeNode typeNode;
  Identifier*[] names;
  Expression[] inits;
  this(TypeNode typeNode, Identifier*[] names, Expression[] inits)
  {
    // No empty arrays allowed. Both arrays must be of same size.
    assert(names.length != 0 && names.length == inits.length);
    // If no type (in case of AutoDeclaration), first value mustn't be null.
    assert(typeNode ? 1 : inits[0] !is null);
    mixin(set_kind);
    addOptChild(typeNode);
    foreach(init; inits)
      addOptChild(init);

    this.typeNode = typeNode;
    this.names = names;
    this.inits = inits;
  }

  LinkageType linkageType;

  void setLinkageType(LinkageType linkageType)
  {
    this.linkageType = linkageType;
  }

  Variable[] variables;
}

class InvariantDeclaration : Declaration
{
  FuncBodyStatement funcBody;
  this(FuncBodyStatement funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
}

class UnittestDeclaration : Declaration
{
  FuncBodyStatement funcBody;
  this(FuncBodyStatement funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
}

abstract class ConditionalCompilationDeclaration : Declaration
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
}

class DebugDeclaration : ConditionalCompilationDeclaration
{
  this(Token* spec, Token* cond, Declaration decls, Declaration elseDecls)
  {
    super(spec, cond, decls, elseDecls);
    mixin(set_kind);
  }
}

class VersionDeclaration : ConditionalCompilationDeclaration
{
  this(Token* spec, Token* cond, Declaration decls, Declaration elseDecls)
  {
    super(spec, cond, decls, elseDecls);
    mixin(set_kind);
  }
}

class StaticIfDeclaration : Declaration
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
}

class StaticAssertDeclaration : Declaration
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
}

class NewDeclaration : Declaration
{
  Parameters params;
  FuncBodyStatement funcBody;
  this(Parameters params, FuncBodyStatement funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(params);
    addChild(funcBody);

    this.params = params;
    this.funcBody = funcBody;
  }
}

class DeleteDeclaration : Declaration
{
  Parameters params;
  FuncBodyStatement funcBody;
  this(Parameters params, FuncBodyStatement funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(params);
    addChild(funcBody);

    this.params = params;
    this.funcBody = funcBody;
  }
}

abstract class AttributeDeclaration : Declaration
{
  Declaration decls;
  this(Declaration decls)
  {
    super.hasBody = true;
    addChild(decls);
    this.decls = decls;
  }
}

class ProtectionDeclaration : AttributeDeclaration
{
  Protection prot;
  this(Protection prot, Declaration decls)
  {
    super(decls);
    mixin(set_kind);
    this.prot = prot;
  }
}

class StorageClassDeclaration : AttributeDeclaration
{
  StorageClass storageClass;
  this(StorageClass storageClass, Declaration decl)
  {
    super(decl);
    mixin(set_kind);

    this.storageClass = storageClass;
  }
}

class LinkageDeclaration : AttributeDeclaration
{
  LinkageType linkageType;
  this(LinkageType linkageType, Declaration decls)
  {
    super(decls);
    mixin(set_kind);

    this.linkageType = linkageType;
  }
}

class AlignDeclaration : AttributeDeclaration
{
  int size;
  this(int size, Declaration decls)
  {
    super(decls);
    mixin(set_kind);
    this.size = size;
  }
}

class PragmaDeclaration : AttributeDeclaration
{
  Identifier* ident;
  Expression[] args;
  this(Identifier* ident, Expression[] args, Declaration decls)
  {
    addOptChildren(args); // Add args before calling super().
    super(decls);
    mixin(set_kind);

    this.ident = ident;
    this.args = args;
  }
}

class MixinDeclaration : Declaration
{
  /// IdExpression := IdentifierExpression | TemplateInstanceExpression
  /// MixinTemplate := IdExpression ("." IdExpression)*
  Expression templateExpr;
  Identifier* mixinIdent; /// Optional mixin identifier.
  Expression argument; /// "mixin" "(" AssignExpression ")"
  Declaration decls; /// Initialized in the semantic phase.

  this(Expression templateExpr, Identifier* mixinIdent)
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

  bool isMixinExpression()
  {
    return argument !is null;
  }
}
