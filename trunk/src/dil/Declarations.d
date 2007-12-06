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
//     foreach (node; this.children)
//       if (node.category == NodeCategory.Declaration)
//         (cast(Declaration)cast(void*)node).semantic(sc);
  }

  final bool isStatic()
  {
    return !!(stc & StorageClass.Static);
  }

  final bool isPublic()
  {
    return !!(prot & Protection.Public);
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
}

class EmptyDeclaration : Declaration
{
  this()
  {
    mixin(set_kind);
  }
}

class IllegalDeclaration : Declaration
{
  Token* token;
  this(Token* token)
  {
    mixin(set_kind);
    this.token = token;
  }
}

/// FQN = fully qualified name
alias Token*[] ModuleFQN; // Identifier(.Identifier)*

class ModuleDeclaration : Declaration
{
  Token* moduleName;
  Token*[] packages;
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
      return moduleName.identifier;
    return null;
  }

  char[] getPackageName(char separator)
  {
    char[] pname;
    foreach (pckg; packages)
      if (pckg)
        pname ~= pckg.identifier ~ separator;
    if (pname.length)
      pname = pname[0..$-1]; // Remove last separator
    return pname;
  }
}

class ImportDeclaration : Declaration
{
  ModuleFQN[] moduleFQNs;
  Token*[] moduleAliases;
  Token*[] bindNames;
  Token*[] bindAliases;

  this(ModuleFQN[] moduleFQNs, Token*[] moduleAliases, Token*[] bindNames, Token*[] bindAliases, bool isStatic)
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
          FQN ~= ident.identifier ~ separator;
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
  Token* name;
  Type baseType;
  EnumMember[] members;
  this(Token* name, Type baseType, EnumMember[] members, bool hasBody)
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
  Token* name;
  Expression value;
  this(Token* name, Expression value)
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
  Token* name;
  TemplateParameters tparams;
  BaseClass[] bases;
  Declarations decls;
  this(Token* name, TemplateParameters tparams, BaseClass[] bases, Declarations decls, bool hasBody)
  {
    super.hasBody = hasBody;
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
  Token* name;
  TemplateParameters tparams;
  BaseClass[] bases;
  Declarations decls;
  this(Token* name, TemplateParameters tparams, BaseClass[] bases, Declarations decls, bool hasBody)
  {
    super.hasBody = hasBody;
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
  Token* name;
  TemplateParameters tparams;
  Declarations decls;
  this(Token* name, TemplateParameters tparams, Declarations decls, bool hasBody)
  {
    super.hasBody = hasBody;
    mixin(set_kind);
    addOptChild(tparams);
    addOptChild(decls);

    this.name = name;
    this.tparams = tparams;
    this.decls = decls;
  }
}

class UnionDeclaration : Declaration
{
  Token* name;
  TemplateParameters tparams;
  Declarations decls;
  this(Token* name, TemplateParameters tparams, Declarations decls, bool hasBody)
  {
    super.hasBody = hasBody;
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
  Type returnType;
  Token* funcName;
  TemplateParameters tparams;
  Parameters params;
  FunctionBody funcBody;
  this(Type returnType, Token* funcName, TemplateParameters tparams,
       Parameters params, FunctionBody funcBody, StorageClass stc)
  {
    super.hasBody = funcBody.funcBody !is null;
    mixin(set_kind);
    addChild(returnType);
    addOptChild(tparams);
    addChild(params);
    addChild(funcBody);

    this.stc = stc;
    this.returnType = returnType;
    this.funcName = funcName;
    this.tparams = tparams;
    this.params = params;
    this.funcBody = funcBody;
  }
}

class VariableDeclaration : Declaration
{
  Type type;
  Token*[] idents;
  Expression[] values;
  this(Type type, Token*[] idents, Expression[] values)
  {
    mixin(set_kind);
    addOptChild(type);
    foreach(value; values)
      addOptChild(value);

    this.type = type;
    this.idents = idents;
    this.values = values;
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

class DebugDeclaration : Declaration
{
  Token* spec;
  Token* cond;
  Declaration decls, elseDecls;

  this(Token* spec, Token* cond, Declaration decls, Declaration elseDecls)
  {
    super.hasBody = decls !is null;
    mixin(set_kind);
    addOptChild(decls);
    addOptChild(elseDecls);

    this.spec = spec;
    this.cond = cond;
    this.decls = decls;
    this.elseDecls = elseDecls;
  }
}

class VersionDeclaration : Declaration
{
  Token* spec;
  Token* cond;
  Declaration decls, elseDecls;

  this(Token* spec, Token* cond, Declaration decls, Declaration elseDecls)
  {
    super.hasBody = decls !is null;
    mixin(set_kind);
    addOptChild(decls);
    addOptChild(elseDecls);

    this.spec = spec;
    this.cond = cond;
    this.decls = decls;
    this.elseDecls = elseDecls;
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
  Token* name;
  TemplateParameters tparams;
  Declarations decls;
  this(Token* name, TemplateParameters tparams, Declarations decls)
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
  this(Protection prot, Declaration decls)
  {
    super(cast(TOK)0, decls);
    mixin(set_kind);
    super.prot = prot;
  }

  void semantic(Scope scop)
  {
    /+
    void traverse(Node[] nodes)
    {
      foreach (node; nodes)
      {
        if (node.kind == NodeKind.ProtectionDeclaration)
          break;
        if (node.category == NodeCategory.Declaration)
        {
          auto decl = cast(Declaration)cast(void*)node;
          decl.prot = this.prot;
          if (node.children)
            traverse(node.children);
        }
      }
    }
    traverse([this.decls]);
    +/
  }
}

class ExternDeclaration : AttributeDeclaration
{
  Linkage linkage;
  this(Linkage linkage, Declaration decls)
  {
    super(TOK.Extern, decls);
    mixin(set_kind);
    addOptChild(linkage);

    this.linkage = linkage;
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
  Token* ident;
  Expression[] args;
  this(Token* ident, Expression[] args, Declaration decls)
  {
    addOptChildren(args); // Add args before calling super().
    super(TOK.Pragma, decls);
    mixin(set_kind);

    this.ident = ident;
    this.args = args;
  }
}

class MixinDeclaration : Declaration
{
  Expression[] templateIdents;
  Token* mixinIdent;
  Expression argument; // mixin ( AssignExpression )

  this(Expression[] templateIdents, Token* mixinIdent)
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
