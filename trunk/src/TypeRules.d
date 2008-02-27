/++
  Author: Aziz Köksal
  License: GPL3
+/
module TypeRules;

import common;

template ExpressionType(char[] T1, char[] T2, char[] expression)
{
  mixin("alias "~T1~" X;");
  mixin("alias "~T2~" Y;");
  X x;
  Y y;
  static if(is(typeof(mixin(expression)) ResultType))
    const char[] result = ResultType.stringof;
  else
    const char[] result = "Error";
}
alias ExpressionType EType;

// pragma(msg, EType!("char", "int", "&x").result);

static const string[] basicTypes = [
  "char"[],   "wchar",   "dchar", "bool",
  "byte",   "ubyte",   "short", "ushort",
  "int",    "uint",    "long",  "ulong",
  /+"cent",   "ucent",+/
  "float",  "double",  "real",
  "ifloat", "idouble", "ireal",
  "cfloat", "cdouble", "creal"/+, "void"+/
];

static const string[] unaExpressions = [
  "!x",
  "&x",
  "~x",
  "+x",
  "-x",
  "++x",
  "--x",
  "x++",
  "x--",
];

static const string[] binExpressions = [
  "x!<>=y",
  "x!<>y",
  "x!<=y",
  "x!<y",
  "x!>=y",
  "x!>y",
  "x<>=y",
  "x<>y",

  "x=y", "x==y", "x!=y",
  "x<=y", "x<y",
  "x>=y", "x>y",
  "x<<=y", "x<<y",
  "x>>=y","x>>y",
  "x>>>=y", "x>>>y",
  "x|=y", "x||y", "x|y",
  "x&=y", "x&&y", "x&y",
  "x+=y", "x+y",
  "x-=y", "x-y",
  "x/=y", "x/y",
  "x*=y", "x*y",
  "x%=y", "x%y",
  "x^=y", "x^y",
  "x~=y",
  "x~y",
  "x,y"
];

char[] genBinExpArray(char[] expression)
{
  char[] result = "[\n";
  foreach (t1; basicTypes)
  {
    result ~= "[\n";
    foreach (t2; basicTypes)
      result ~= `EType!("`~t1~`", "`~t2~`", "`~expression~`").result,`\n;
    result[result.length-2] = ']'; // Overwrite last comma.
    result[result.length-1] = ','; // Overwrite last \n.
  }
  result[result.length-1] = ']'; // Overwrite last comma.
  return result;
}

char[] genUnaExpArray(char[] expression)
{
  char[] result = "[\n";
  foreach (t1; basicTypes)
    result ~= `EType!("`~t1~`", "int", "`~expression~`").result,`\n;
  result[result.length-2] = ']'; // Overwrite last comma.
  return result;
}

// pragma(msg, mixin(genBinExpArray("x+y")).stringof);
