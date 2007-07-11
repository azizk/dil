/++
  Author: Aziz Köksal
  License: GPL2
+/
module Declarations;
import Expressions;
import Types;
import Statements;

class Declaration
{
  bool hasBody;
  this(bool hasBody)
  {
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

alias string[] ModuleName; // Identifier(.Identifier)*

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
  string[] moduleAliases;
  string[] bindNames;
  string[] bindAliases;
  this(ModuleName[] moduleNames, string[] moduleAliases, string[] bindNames, string[] bindAliases)
  {
    super(false);
    this.moduleNames = moduleNames;
    this.moduleAliases = moduleAliases;
    this.bindNames = bindNames;
    this.bindAliases = bindAliases;
  }
}

class EnumDeclaration : Declaration
{
  string name;
  Type baseType;
  string[] members;
  Expression[] values;
  this(string name, Type baseType, string[] members, Expression[] values, bool hasBody)
  {
    super(hasBody);
    this.name = name;
    this.baseType = baseType;
    this.members = members;
    this.values = values;
  }
}

enum Protection
{
  None,
  Private   = 1,
  Protected = 1<<1,
  Package   = 1<<2,
  Public    = 1<<3
}

class BaseClass
{
  Protection prot;
  string name;
  this(Protection prot, string name)
  {
    this.prot = prot;
    this.name = name;
  }
}

class ClassDeclaration : Declaration
{
  string name;
  BaseClass[] bases;
  Declaration[] decls;
  this(string name, BaseClass[] bases, Declaration[] decls, bool hasBody)
  {
    super(hasBody);
    this.name = name;
    this.bases = bases;
    this.decls = decls;
  }
}

class InterfaceDeclaration : Declaration
{
  string name;
  BaseClass[] bases;
  Declaration[] decls;
  this(string name, BaseClass[] bases, Declaration[] decls, bool hasBody)
  {
    super(hasBody);
    this.name = name;
    this.bases = bases;
    this.decls = decls;
  }
}

class StructDeclaration : Declaration
{
  string name;
  Declaration[] decls;
  this(string name, Declaration[] decls, bool hasBody)
  {
    super(hasBody);
    this.name = name;
    this.decls = decls;
  }
}

class UnionDeclaration : Declaration
{
  string name;
  Declaration[] decls;
  this(string name, Declaration[] decls, bool hasBody)
  {
    super(hasBody);
    this.name = name;
    this.decls = decls;
  }
}

class ConstructorDeclaration : Declaration
{
  Parameters parameters;
  Statement[] statements;
  this(Parameters parameters, Statement[] statements)
  {
    super(true);
    this.parameters = parameters;
    this.statements = statements;
  }
}

class StaticConstructorDeclaration : Declaration
{
  Statement[] statements;
  this(Statement[] statements)
  {
    super(true);
    this.statements = statements;
  }
}

class DestructorDeclaration : Declaration
{
  Statement[] statements;
  this(Statement[] statements)
  {
    super(true);
    this.statements = statements;
  }
}

class StaticDestructorDeclaration : Declaration
{
  Statement[] statements;
  this(Statement[] statements)
  {
    super(true);
    this.statements = statements;
  }
}

class InvariantDeclaration : Declaration
{
  Statement[] statements;
  this(Statement[] statements)
  {
    super(true);
    this.statements = statements;
  }
}

class UnittestDeclaration : Declaration
{
  Statement[] statements;
  this(Statement[] statements)
  {
    super(true);
    this.statements = statements;
  }
}

class DebugDeclaration : Declaration
{
  int levelSpec;
  string identSpec;
  int levelCond;
  string identCond;
  Declaration[] decls, elseDecls;

  this(int levelSpec, string identSpec, int levelCond, string identCond, Declaration[] decls, Declaration[] elseDecls)
  {
    super(decls.length != 0);
    this.levelSpec = levelSpec;
    this.identSpec = identSpec;
    this.levelCond = levelCond;
    this.identCond = identCond;
    this.decls = decls;
    this.elseDecls = elseDecls;
  }
}

class VersionDeclaration : Declaration
{
  int levelSpec;
  string identSpec;
  int levelCond;
  string identCond;
  Declaration[] decls, elseDecls;

  this(int levelSpec, string identSpec, int levelCond, string identCond, Declaration[] decls, Declaration[] elseDecls)
  {
    super(decls.length != 0);
    this.levelSpec = levelSpec;
    this.identSpec = identSpec;
    this.levelCond = levelCond;
    this.identCond = identCond;
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
  string templateName;
  TemplateParameter[] templateParams;
  Declaration[] decls;
  this(string templateName, TemplateParameter[] templateParams, Declaration[] decls)
  {
    super(true);
    this.templateName = templateName;
    this.templateParams = templateParams;
    this.decls = decls;
  }
}
