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

class Declaration : Node
{
  bool hasBody;
  this(bool hasBody)
  {
    super(NodeType.Declaration);
    this.hasBody = hasBody;
  }
}

class EmptyDeclaration : Declaration
{
  this()
  {
    super(false);
  }
}

class IllegalDeclaration : Declaration
{
  TOK tok;
  this(TOK tok)
  {
    super(false);
    this.tok = tok;
  }
}

alias Token*[] ModuleName; // Identifier(.Identifier)*

class ModuleDeclaration : Declaration
{
  ModuleName moduleName; // module name sits at end of array
  this(ModuleName moduleName)
  {
    super(false);
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
    this.decl = decl;
  }
}

class TypedefDeclaration : Declaration
{
  Declaration decl;
  this(Declaration decl)
  {
    super(false);
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
    this.funcBody = funcBody;
  }
}

class DestructorDeclaration : Declaration
{
  FunctionBody funcBody;
  this(FunctionBody funcBody)
  {
    super(true);
    this.funcBody = funcBody;
  }
}

class StaticDestructorDeclaration : Declaration
{
  FunctionBody funcBody;
  this(FunctionBody funcBody)
  {
    super(true);
    this.funcBody = funcBody;
  }
}

class FunctionDeclaration : Declaration
{
  Token* funcName;
  Type funcType;
  TemplateParameters tparams;
  FunctionBody funcBody;
  this(Token* funcName, Type funcType, TemplateParameters tparams, FunctionBody funcBody)
  {
    super(funcBody.funcBody !is null);
    this.funcName = funcName;
    this.funcType = funcType;
    this.funcBody = funcBody;
  }
}

class VariableDeclaration : Declaration
{
  Token*[] idents;
  Expression[] values;
  this(Token*[] idents, Expression[] values)
  {
    super(false);
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
    this.funcBody = funcBody;
  }
}

class UnittestDeclaration : Declaration
{
  FunctionBody funcBody;
  this(FunctionBody funcBody)
  {
    super(true);
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
    this.condition = condition;
    this.message = message;
  }
}

class TemplateDeclaration : Declaration
{
  Token* templateName;
  TemplateParameters templateParams;
  Declaration[] decls;
  this(Token* templateName, TemplateParameters templateParams, Declaration[] decls)
  {
    super(true);
    this.templateName = templateName;
    this.templateParams = templateParams;
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
    this.linkage = linkage;
  }
}

class AlignDeclaration : AttributeDeclaration
{
  int size;
  this(int size, Declaration[] decls)
  {
    super(TOK.Align, decls);
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
    this.ident = ident;
    this.args = args;
  }
}

class MixinDeclaration : Declaration
{
  Expression[] templateIdent;
  Token* mixinIdent;
  Expression assignExpr; // mixin ( AssignExpression )
  this(Expression[] templateIdent, Token* mixinIdent)
  {
    super(false);
    this.templateIdent = templateIdent;
    this.mixinIdent = mixinIdent;
  }
  this(Expression assignExpr)
  {
    super(false);
    this.assignExpr = assignExpr;
  }
}
