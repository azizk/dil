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
