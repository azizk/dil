/++
  Author: Aziz Köksal
  License: GPL2
+/
module Declarations;
import Expressions;
import Types;

class Declaration
{

}

class ModuleDeclaration : Declaration
{
  string[] idents; // module name sits at end of array
  this(string[] idents)
  {
    this.idents = idents;
  }
}

class EnumDeclaration : Declaration
{
  string name;
  Type baseType;
  string[] members;
  Expression[] values;
  this(string name, Type baseType, string[] members, Expression[] values)
  {
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
  string ident;
  this(Protection prot, string ident)
  {
    this.prot = prot;
    this.ident = ident;
  }
}

class ClassDeclaration : Declaration
{
  string name;
  BaseClass[] bases;
  Declaration[] decls;
  this(string name, BaseClass[] bases, Declaration[] decls)
  {
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
  this(string name, BaseClass[] bases, Declaration[] decls)
  {
    this.name = name;
    this.bases = bases;
    this.decls = decls;
  }
}

class StructDeclaration : Declaration
{
  string name;
  Declaration[] decls;
  this(string name, Declaration[] decls)
  {
    this.name = name;
    this.decls = decls;
  }
}

class UnionDeclaration : Declaration
{
  string name;
  Declaration[] decls;
  this(string name, Declaration[] decls)
  {
    this.name = name;
    this.decls = decls;
  }
}
