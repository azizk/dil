/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.TypeSystem;

import dil.Symbol;

abstract class Type : Symbol
{
  Type next;
}

class TypeBasic : Type
{

}

class TypeDArray : Type
{

}

class TypeAArray : Type
{

}

class TypePointer : Type
{

}

class TypeReference : Type
{

}
