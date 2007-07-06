/++
  Author: Aziz Köksal
  License: GPL2
+/
module Types;
import Token;
import Expressions;

class Type
{
  TOK type;
  this(TOK type)
  {
    this.type = type;
  }
}

class IdentifierType : Type
{
  string[] idents;

  this(string[] idents)
  {
    super(TOK.Identifier);
    this.idents = idents;
  }

  this(TOK type)
  {
    super(type);
  }

  void opCatAssign(string ident)
  {
    this.idents ~= ident;
  }
}

class TypeofType : IdentifierType
{
  Expression e;
  this(Expression e)
  {
    super(TOK.Typeof);
    this.e = e;
  }
}
