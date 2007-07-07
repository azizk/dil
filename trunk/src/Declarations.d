/++
  Author: Aziz Köksal
  License: GPL2
+/
module Declarations;

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

