/++
  Author: Aziz Köksal
  License: GPL3
+/
module Declarations;
import SyntaxTree;
import Expressions;
import Types;
import Statements;
import Token;

abstract class Declaration : Node
{
  bool hasBody;
  this(bool hasBody)
  {
    super(NodeCategory.Declaration);
    this.hasBody = hasBody;
  }
}

class EmptyDeclaration : Declaration
{
  this()
  {
    super(false);
    mixin(set_kind);
  }
}

class IllegalDeclaration : Declaration
{
  Token* token;
  this(Token* token)
  {
    super(false);
    mixin(set_kind);
    this.token = token;
  }
}

alias Token*[] ModuleName; // Identifier(.Identifier)*

class ModuleDeclaration : Declaration
{
  ModuleName moduleName; // module name sits at end of array
  this(ModuleName moduleName)
  {
    super(false);
    mixin(set_kind);
    this.moduleName = moduleName;
  }
}

class ImportDeclaration : Declaration
{
  ModuleName[] moduleNames;
  Token*[] moduleAliases;
  Token*[] bindNames;
  Token*[] bindAliases;
  this(ModuleName[] moduleNames, Token*[] moduleAliases, Token*[] bindNames, Token*[] bindAliases)
  {
    super(false);
    mixin(set_kind);
    this.moduleNames = moduleNames;
    this.moduleAliases = moduleAliases;
    this.bindNames = bindNames;
    this.bindAliases = bindAliases;
  }
}

class AliasDeclaration : Declaration
{
  Declaration decl;
  this(Declaration decl)
  {
    super(false);
    mixin(set_kind);
    this.children = [decl];
    this.decl = decl;
  }
}

class TypedefDeclaration : Declaration
{
  Declaration decl;
  this(Declaration decl)
  {
    super(false);
    mixin(set_kind);
    this.children = [decl];
    this.decl = decl;
  }
}

class EnumDeclaration : Declaration
{
  Token* name;
  Type baseType;
  Token*[] members;
  Expression[] values;
  this(Token* name, Type baseType, Token*[] members, Expression[] values, bool hasBody)
  {
    super(hasBody);
    mixin(set_kind);
    if (baseType)
      this.children = [baseType];
    foreach(value; values)
      if (value)
        this.children ~= value;
    this.name = name;
    this.baseType = baseType;
    this.members = members;
    this.values = values;
  }
}

class ClassDeclaration : Declaration
{
  Token* name;
  TemplateParameters tparams;
  BaseClass[] bases;
  Declaration[] decls;
  this(Token* name, TemplateParameters tparams, BaseClass[] bases, Declaration[] decls, bool hasBody)
  {
    super(hasBody);
    mixin(set_kind);
    if (tparams)
      this.children = [tparams];
    if (bases.length)
      this.children ~= bases;
    if (decls.length)
      this.children ~= decls;
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
  Declaration[] decls;
  this(Token* name, TemplateParameters tparams, BaseClass[] bases, Declaration[] decls, bool hasBody)
  {
    super(hasBody);
    mixin(set_kind);
    this.children = [tparams] ~ cast(Node[])bases ~ decls;
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
  Declaration[] decls;
  this(Token* name, TemplateParameters tparams, Declaration[] decls, bool hasBody)
  {
    super(hasBody);
    mixin(set_kind);
    this.children = [tparams] ~ cast(Node[])decls;
    this.name = name;
    this.tparams = tparams;
    this.decls = decls;
  }
}

class UnionDeclaration : Declaration
{
  Token* name;
  TemplateParameters tparams;
  Declaration[] decls;
  this(Token* name, TemplateParameters tparams, Declaration[] decls, bool hasBody)
  {
    super(hasBody);
    mixin(set_kind);
    this.children = [tparams] ~ cast(Node[])decls;
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
    super(true);
    mixin(set_kind);
    this.children = [cast(Node)parameters, funcBody];
    this.parameters = parameters;
    this.funcBody = funcBody;
  }
}

class StaticConstructorDeclaration : Declaration
{
  FunctionBody funcBody;
  this(FunctionBody funcBody)
  {
    super(true);
    mixin(set_kind);
    this.children = [funcBody];
    this.funcBody = funcBody;
  }
}

class DestructorDeclaration : Declaration
{
  FunctionBody funcBody;
  this(FunctionBody funcBody)
  {
    super(true);
    mixin(set_kind);
    this.children = [funcBody];
    this.funcBody = funcBody;
  }
}

class StaticDestructorDeclaration : Declaration
{
  FunctionBody funcBody;
  this(FunctionBody funcBody)
  {
    super(true);
    mixin(set_kind);
    this.children = [funcBody];
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
  this(Type returnType, Token* funcName, TemplateParameters tparams, Parameters params, FunctionBody funcBody)
  {
    super(funcBody.funcBody !is null);
    mixin(set_kind);
    this.children = [returnType];
    if (tparams)
      this.children ~= tparams;
    this.children ~= [cast(Node)params, funcBody];
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
    super(false);
    mixin(set_kind);
    if (type)
      this.children = [type];
    foreach(value; values)
      if (value)
        this.children ~= value;
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
    super(true);
    mixin(set_kind);
    this.children = [funcBody];
    this.funcBody = funcBody;
  }
}

class UnittestDeclaration : Declaration
{
  FunctionBody funcBody;
  this(FunctionBody funcBody)
  {
    super(true);
    mixin(set_kind);
    this.children = [funcBody];
    this.funcBody = funcBody;
  }
}

class DebugDeclaration : Declaration
{
  Token* spec;
  Token* cond;
  Declaration[] decls, elseDecls;

  this(Token* spec, Token* cond, Declaration[] decls, Declaration[] elseDecls)
  {
    super(decls.length != 0);
    mixin(set_kind);
    this.children = decls ~ elseDecls;
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
  Declaration[] decls, elseDecls;

  this(Token* spec, Token* cond, Declaration[] decls, Declaration[] elseDecls)
  {
    super(decls.length != 0);
    mixin(set_kind);
    this.children = decls ~ elseDecls;
    this.spec = spec;
    this.cond = cond;
    this.decls = decls;
    this.elseDecls = elseDecls;
  }
}

class StaticIfDeclaration : Declaration
{
  Expression condition;
  Declaration[] ifDecls, elseDecls;
  this(Expression condition, Declaration[] ifDecls, Declaration[] elseDecls)
  {
    super(true);
    mixin(set_kind);
    this.children = [condition] ~ cast(Node[])(ifDecls ~ elseDecls);
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
    super(true);
    mixin(set_kind);
    this.children = [condition, message];
    this.condition = condition;
    this.message = message;
  }
}

class TemplateDeclaration : Declaration
{
  Token* name;
  TemplateParameters tparams;
  Declaration[] decls;
  this(Token* name, TemplateParameters tparams, Declaration[] decls)
  {
    super(true);
    mixin(set_kind);
    this.children = [tparams] ~ cast(Node[])decls;
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
    super(true);
    mixin(set_kind);
    this.children = [cast(Node)parameters, funcBody];
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
    super(true);
    mixin(set_kind);
    this.children = [cast(Node)parameters, funcBody];
    this.parameters = parameters;
    this.funcBody = funcBody;
  }
}

class AttributeDeclaration : Declaration
{
  TOK attribute;
  Declaration[] decls;
  this(TOK attribute, Declaration[] decls)
  {
    super(true);
    mixin(set_kind);
    this.children = decls;
    this.attribute = attribute;
    this.decls = decls;
  }
}

class ExternDeclaration : AttributeDeclaration
{
  Linkage linkage;
  this(Linkage linkage, Declaration[] decls)
  {
    super(TOK.Extern, decls);
    mixin(set_kind);
    this.linkage = linkage;
  }
}

class AlignDeclaration : AttributeDeclaration
{
  int size;
  this(int size, Declaration[] decls)
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
  this(Token* ident, Expression[] args, Declaration[] decls)
  {
    super(TOK.Pragma, decls);
    mixin(set_kind);
    this.children ~= args;
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
    super(false);
    mixin(set_kind);
    this.children = templateIdents;
    this.templateIdents = templateIdents;
    this.mixinIdent = mixinIdent;
  }
  this(Expression argument)
  {
    super(false);
    mixin(set_kind);
    this.children = [argument];
    this.argument = argument;
  }
}
