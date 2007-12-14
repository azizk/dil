/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Symbols;
import dil.Symbol;
import common;

class Aggregate : Symbol
{
  Function[] funcs;
  Variable[] fields;
}

class Class : Aggregate
{

}

class Union : Aggregate
{

}

class Struct : Aggregate
{

}

class Function : Symbol
{

}

class Variable : Symbol
{

}
