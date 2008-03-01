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

static const string[] unaryExpressions = [
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

static const string[] binaryExpressions = [
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

char[] genBinaryExpArray(char[] expression)
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
// pragma(msg, mixin(genBinaryExpArray("x%y")).stringof);

char[] genBinaryExpsArray()
{
  char[] result = "[\n";
  foreach (expression; binaryExpressions[0..42])
  {
//     pragma(msg, "asd");
    result ~= genBinaryExpArray(expression)/+ ~ ",\n"+/;
    result ~= ",\n";
  }
  result[result.length-2] = ']';
  return result;
}

// pragma(msg, mixin(genBinaryExpsArray()).stringof);

char[] genUnaryExpArray(char[] expression)
{
  char[] result = "[\n";
  foreach (t1; basicTypes)
    result ~= `EType!("`~t1~`", "int", "`~expression~`").result,`\n;
  result[result.length-2] = ']'; // Overwrite last comma.
  return result;
}

char[] genUnaryExpsArray()
{
  char[] result = "[\n";
  foreach (expression; unaryExpressions)
    result ~= genUnaryExpArray(expression) ~ ",\n";
  result[result.length-2] = ']';
  return result;
}

// pragma(msg, mixin(genUnaryExpsArray()).stringof);

void genHTMLTypeRulesTables()
{
  auto unaryExpsResults = mixin(genUnaryExpsArray());
//   auto binaryExpsResults = mixin(genBinaryExpsArray());

  Stdout(
    `<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">`\n
    `<html>`\n
    `<head>`\n
    `  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">`\n
    `  <link href="" rel="stylesheet" type="text/css">`\n
    `</head>`\n
    `<body>`\n
  );

  Stdout.format("<table>\n<tr><th colspan=\"{}\">Unary Expressions</th></tr>", unaryExpressions.length);
  Stdout("<tr><td><!--typecol--></td>");
  foreach (unaryExpression; unaryExpressions)
    Stdout.format("<td>{}</td>", unaryExpression);
  Stdout("</tr>\n");
  foreach (i, basicType; basicTypes)
  {
    Stdout.format("<tr>\n<td>{}</td>", basicType);
    foreach (unaryExpResults; unaryExpsResults)
    {
      assert(unaryExpResults.length == basicTypes.length);
      Stdout.format("<td>{}</td>", unaryExpResults[i]);
    }
    Stdout("\n<tr>\n");
  }
  Stdout("</table>\n");

  foreach (binaryExpression; binaryExpressions)
  {
    Stdout.format("<table>\n<tr><th colspan=\"{}\">Binary Expression</th></tr>", basicTypes.length);
    Stdout.format("<tr><td>{}</td>", binaryExpression);
    Stdout("\n<tr>\n");
    foreach (i, basicType; basicTypes)
    {
      Stdout.format("<tr>\n<td>{}</td>", basicType);
//       foreach (basicType; basicTypes)
      {
      }
      Stdout("\n<tr>\n");
    }
    Stdout("</table>\n");
  }

  Stdout(
    "\n</body>"
    "\n</html>"
  );
}
