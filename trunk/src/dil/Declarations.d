/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Declarations;

import dil.SyntaxTree;
import dil.Expressions;
import dil.Types;
import dil.Statements;
import dil.Token;
import dil.Enums;
import dil.Scope;
import dil.IdTable;
import dil.Semantics;
import dil.Symbols;
import dil.TypeSystem;

abstract class Declaration : Node
{
  bool hasBody;
  this()
  {
    super(NodeCategory.Declaration);
  }

  // Members relevant to semantic phase.
  StorageClass stc; /// The storage class of this declaration.
  Protection prot;  /// The protection attribute of this declaration.

  void semantic(Scope sc)
  {
    foreach (node; this.children)
      if (node.category == NodeCategory.Declaration)
        (cast(Declaration)cast(void*)node).semantic(sc);
  }

  final bool isStatic()
  {
    return !!(stc & StorageClass.Static);
  }

  final bool isPublic()
  {
    return !!(prot & Protection.Public);
  }

  final void setStorageClass(StorageClass stc)
  {
    this.stc = stc;
  }

  final void setProtection(Protection prot)
  {
    this.prot = prot;
  }

}

class Declarations : Declaration
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

  void opCatAssign(Declarations ds)
  {
    addChildren(ds.children);
  }

  override void semantic(Scope scop)
  {
    foreach (node; this.children)
    {
      assert(node.category == NodeCategory.Declaration);
      (cast(Declaration)cast(void*)node).semantic(scop);
    }
  }
}

/// Single semicolon.
class EmptyDeclaration : Declaration
{
  this()
  {
    mixin(set_kind);
  }

  override void semantic(Scope)
  {}
}

/++
  Illegal declarations encompass all tokens that don't
  start a DeclarationDefinition.
  See_Also: dil.Token.isDeclDefStartToken()
+/
class IllegalDeclaration : Declaration
{
  this()
  {
    mixin(set_kind);
  }

  override void semantic(Scope)
  {}
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
  EnumMember[] members;
  this(Identifier* name, TypeNode baseType, EnumMember[] members, bool hasBody)
  {
    super.hasBody = hasBody;
    mixin(set_kind);
    addOptChild(baseType);
    addOptChildren(members);

    this.name = name;
    this.baseType = baseType;
    this.members = members;
  }
}

class EnumMember : Node
{
  Identifier* name;
  Expression value;
  this(Identifier* name, Expression value)
  {
    super(NodeCategory.Other);
    mixin(set_kind);
    addOptChild(value);

    this.name = name;
    this.value = value;
  }
}

class ClassDeclaration : Declaration
{
  Identifier* name;
  TemplateParameters tparams;
  BaseClass[] bases;
  Declarations decls;
  this(Identifier* name, TemplateParameters tparams, BaseClass[] bases, Declarations decls)
  {
    super.hasBody = decls !is null;
    mixin(set_kind);
    addOptChild(tparams);
    addOptChildren(bases);
    addOptChild(decls);

    this.name = name;
    this.tparams = tparams;
    this.bases = bases;
    this.decls = decls;
  }
}

class InterfaceDeclaration : Declaration
{
  Identifier* name;
  TemplateParameters tparams;
  BaseClass[] bases;
  Declarations decls;
  this(Identifier* name, TemplateParameters tparams, BaseClass[] bases, Declarations decls)
  {
    super.hasBody = decls !is null;
    mixin(set_kind);
    addOptChild(tparams);
    addOptChildren(bases);
    addOptChild(decls);

    this.name = name;
    this.tparams = tparams;
    this.bases = bases;
    this.decls = decls;
  }
}

class StructDeclaration : Declaration
{
  Identifier* name;
  TemplateParameters tparams;
  Declarations decls;
  uint alignSize;
  this(Identifier* name, TemplateParameters tparams, Declarations decls)
  {
    super.hasBody = decls !is null;
    mixin(set_kind);
    addOptChild(tparams);
    addOptChild(decls);

    this.name = name;
    this.tparams = tparams;
    this.decls = decls;
  }

  void setAlignSize(uint alignSize)
  {
    this.alignSize = alignSize;
  }
}

class UnionDeclaration : Declaration
{
  Identifier* name;
  TemplateParameters tparams;
  Declarations decls;
  this(Identifier* name, TemplateParameters tparams, Declarations decls)
  {
    super.hasBody = decls !is null;
    mixin(set_kind);
    addOptChild(tparams);
    addOptChild(decls);

    this.name = name;
    this.tparams = tparams;
    this.decls = decls;
  }
}

class ConstructorDeclaration : Declaration
{
  Parameters parameters;
  FunctionBody funcBody;
  this(Parameters parameters, FunctionBody funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(parameters);
    addChild(funcBody);

    this.parameters = parameters;
    this.funcBody = funcBody;
  }
}

class StaticConstructorDeclaration : Declaration
{
  FunctionBody funcBody;
  this(FunctionBody funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
}

class DestructorDeclaration : Declaration
{
  FunctionBody funcBody;
  this(FunctionBody funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
}

class StaticDestructorDeclaration : Declaration
{
  FunctionBody funcBody;
  this(FunctionBody funcBody)
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
  Identifier* funcName;
  TemplateParameters tparams;
  Parameters params;
  FunctionBody funcBody;
  LinkageType linkageType;
  this(TypeNode returnType, Identifier* funcName, TemplateParameters tparams,
       Parameters params, FunctionBody funcBody)
  {
    super.hasBody = funcBody.funcBody !is null;
    mixin(set_kind);
    addChild(returnType);
    addOptChild(tparams);
    addChild(params);
    addChild(funcBody);

    this.returnType = returnType;
    this.funcName = funcName;
    this.tparams = tparams;
    this.params = params;
    this.funcBody = funcBody;
  }

  void setLinkageType(LinkageType linkageType)
  {
    this.linkageType = linkageType;
  }
}

class VariableDeclaration : Declaration
{
  TypeNode typeNode;
  Identifier*[] idents;
  Expression[] values;
  LinkageType linkageType;
  this(TypeNode typeNode, Identifier*[] idents, Expression[] values)
  {
    // No empty arrays allowed. Both arrays must be of same size.
    assert(idents.length != 0 && idents.length == values.length);
    // If no type (in case of AutoDeclaration), first value mustn't be null.
    assert(typeNode ? 1 : values[0] !is null);
    mixin(set_kind);
    addOptChild(typeNode);
    foreach(value; values)
      addOptChild(value);

    this.typeNode = typeNode;
    this.idents = idents;
    this.values = values;
  }

  void setLinkageType(LinkageType linkageType)
  {
    this.linkageType = linkageType;
  }

  Variable[] variables;

  override void semantic(Scope scop)
  {
    Type type;

    if (typeNode)
      // Get type from typeNode.
      type = typeNode.semantic(scop);
    else
    { // Infer type from first initializer.
      auto firstValue = values[0];
      firstValue = firstValue.semantic(scop);
      type = firstValue.type;
    }
    assert(type !is null);

    // Iterate over variable identifiers in this declaration.
    foreach (i, ident; idents)
    {
      // Perform semantic analysis on value.
      values[i] = values[i].semantic(scop);
      // Create a new variable symbol.
      auto variable = new Variable(stc, linkageType, type, ident, this);
      variables ~= variable;
      // Add to scope.
      scop.insert(variable);
    }
  }
}

class InvariantDeclaration : Declaration
{
  FunctionBody funcBody;
  this(FunctionBody funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(funcBody);

    this.funcBody = funcBody;
  }
}

class UnittestDeclaration : Declaration
{
  FunctionBody funcBody;
  this(FunctionBody funcBody)
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
    addOptChild(ifDecls);
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

class TemplateDeclaration : Declaration
{
  Identifier* name;
  TemplateParameters tparams;
  Declarations decls;
  this(Identifier* name, TemplateParameters tparams, Declarations decls)
  {
    super.hasBody = true;
    mixin(set_kind);
    addOptChild(tparams);
    addChild(decls);

    this.name = name;
    this.tparams = tparams;
    this.decls = decls;
  }
}

class NewDeclaration : Declaration
{
  Parameters parameters;
  FunctionBody funcBody;
  this(Parameters parameters, FunctionBody funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(parameters);
    addChild(funcBody);

    this.parameters = parameters;
    this.funcBody = funcBody;
  }
}

class DeleteDeclaration : Declaration
{
  Parameters parameters;
  FunctionBody funcBody;
  this(Parameters parameters, FunctionBody funcBody)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(parameters);
    addChild(funcBody);

    this.parameters = parameters;
    this.funcBody = funcBody;
  }
}

class AttributeDeclaration : Declaration
{
  TOK attribute;
  Declaration decls;
  this(TOK attribute, Declaration decls)
  {
    super.hasBody = true;
    mixin(set_kind);
    addChild(decls);

    this.attribute = attribute;
    this.decls = decls;
  }
}

class ProtectionDeclaration : AttributeDeclaration
{
  Protection prot;
  this(Protection prot, Declaration decls)
  {
    super(cast(TOK)0, decls);
    mixin(set_kind);
    this.prot = prot;
  }
}

class StorageClassDeclaration : AttributeDeclaration
{
  StorageClass storageClass;
  this(StorageClass storageClass, TOK tok, Declaration decl)
  {
    super(tok, decl);
    mixin(set_kind);

    this.storageClass = storageClass;
  }
}

class LinkageDeclaration : AttributeDeclaration
{
  LinkageType linkageType;
  this(LinkageType linkageType, Declaration decls)
  {
    super(TOK.Extern, decls);
    mixin(set_kind);

    this.linkageType = linkageType;
  }
}

class AlignDeclaration : AttributeDeclaration
{
  int size;
  this(int size, Declaration decls)
  {
    super(TOK.Align, decls);
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
    super(TOK.Pragma, decls);
    mixin(set_kind);

    this.ident = ident;
    this.args = args;
  }

  override void semantic(Scope scop)
  {
    pragmaSemantic(scop, begin, ident, args);
    decls.semantic(scop);
  }
}

class MixinDeclaration : Declaration
{
  Expression[] templateIdents;
  Identifier* mixinIdent;
  Expression argument; // mixin ( AssignExpression )

  this(Expression[] templateIdents, Identifier* mixinIdent)
  {
    mixin(set_kind);
    addChildren(templateIdents);

    this.templateIdents = templateIdents;
    this.mixinIdent = mixinIdent;
  }

  this(Expression argument)
  {
    mixin(set_kind);
    addChild(argument);

    this.argument = argument;
  }
}
