#!/usr/bin/rdmd
/++
  Author: Aziz Köksal
  License: GPL3
+/
module TypeRules;

import tango.io.Stdout;

void main(char[][] args)
{
  Stdout(
    `<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <link href="" rel="stylesheet" type="text/css">
  <style type="text/css">
    .E { color: darkred; } /* Error */
    .R { font-size: 0.8em; } /* Result */
    .X { color: darkorange; }
    .Y { color: darkblue; }
  </style>
</head>
<body>
<p>The following tables show the type results of different expressions. Compiler used: `
  );

  Stdout.format("{} {}.{,:d3}.</p>\n", __VENDOR__, __VERSION__/1000, __VERSION__%1000);

  Stdout.format("<table>\n<tr><th colspan=\"{}\">Unary Expressions</th></tr>\n", unaryExpressions.length);
  Stdout("<tr><td><!--typecol--></td>");
  foreach (unaryExpression; unaryExpressions)
    Stdout.format("<td>{}</td>", {
      if (unaryExpression[0] == 'x')
        return `<span class="X">x</span>` ~ xml_escape(unaryExpression[1..$]);
      else
        return xml_escape(unaryExpression[0..$-1]) ~ `<span class="X">x</span>`;
    }());
  Stdout("</tr>\n");
  foreach (i, basicType; basicTypes)
  {
    Stdout.format("<tr>\n"`<td class="X">{}</td>`, basicType);
    foreach (expResults; unaryExpsResults)
    {
      auto result =  expResults[i];
      Stdout.format(`<td class="R">{}</td>`, result[0] == 'E' ? `<span class="E">Error</span>`[] : result);
    }
    Stdout("\n<tr>\n");
  }
  Stdout("</table>\n");

  foreach (i, expResults; binaryExpsResults)
  {
    const(char)[] binaryExpression = binaryExpressions[i];
    binaryExpression = `<span class="X">x</span> ` ~
                       xml_escape(binaryExpression[1..$-1]) ~
                       ` <span class="Y">y</span>`;
    Stdout.format("<table>\n<tr><th colspan=\"{}\">{}</th></tr>\n", basicTypes.length, binaryExpression);
    Stdout.format("<tr><td><!--typecol--></td>");
    foreach (basicType; basicTypes)
      Stdout.format(`<td class="Y">{}</td>`, basicType);
    Stdout("\n<tr>\n");
    foreach (j, results; expResults)
    {
      Stdout.format("<tr>\n"`<td class="X">{}</td>`, basicTypes[j]);
      foreach (result; results)
        Stdout.format(`<td class="R">{}</td>`, result[0] == 'E' ? `<span class="E">Error</span>`[] : result);
      Stdout("\n<tr>\n");
    }
    Stdout("</table>\n");
  }

  Stdout(
    "\n</body>"
    "\n</html>"
  );
}

/// Escapes the characters '<', '>' and '&' with named character entities.
/// Taken from module cmd.Highlight;
const(char)[] xml_escape(const(char)[] text)
{
  char[] result;
  foreach (c; text)
    switch (c)
    {
      case '<': result ~= "&lt;";  break;
      case '>': result ~= "&gt;";  break;
      case '&': result ~= "&amp;"; break;
      default:  result ~= c;
    }
  if (result.length != text.length)
    return result;
  // Nothing escaped. Return original text.
  delete result;
  return text;
}

char char_; wchar wchar_; dchar dchar_; bool bool_;
byte byte_; ubyte ubyte_; short short_; ushort ushort_;
int int_; uint uint_; long long_; ulong ulong_;
/+cent cent_;   ucent ucent_;+/
float float_; double double_; real real_;
ifloat ifloat_; idouble idouble_; ireal ireal_;
cfloat cfloat_; cdouble cdouble_; creal creal_;

enum string[] basicTypes = [
  "char"[],   "wchar",   "dchar", "bool",
  "byte",   "ubyte",   "short", "ushort",
  "int",    "uint",    "long",  "ulong",
  /+"cent",   "ucent",+/
  "float",  "double",  "real",
  "ifloat", "idouble", "ireal",
  "cfloat", "cdouble", "creal"/+, "void"+/
];

enum string[] unaryExpressions = [
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

enum string[] binaryExpressions = [
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

template ExpressionType(alias x, alias y, string expression)
{
  static if (is(typeof(mixin(expression)) ResultType))
    immutable result = ResultType.stringof;
  else
    immutable result = "Error";
}
alias ExpressionType EType;

char[] genBinaryExpArray(string expression)
{
  char[] result = "[\n".dup;
  foreach (t1; basicTypes)
  {
    result ~= "[\n".dup;
    foreach (t2; basicTypes)
      result ~= `EType!(`~t1~`_, `~t2~`_, "`~expression~`").result,`"\n";
    result[result.length-2] = ']'; // Overwrite last comma.
    result[result.length-1] = ','; // Overwrite last \n.
  }
  result[result.length-1] = ']'; // Overwrite last comma.
  return result;
}
// pragma(msg, mixin(genBinaryExpArray("x%y")).stringof);

char[] genBinaryExpsArray()
{
  char[] result = "[\n".dup;
  foreach (expression; binaryExpressions)
    result ~= genBinaryExpArray(expression) ~ ",\n";
  result[result.length-2] = ']';
  return result;
}

// pragma(msg, mixin(genBinaryExpsArray()).stringof);

char[] genUnaryExpArray(string expression)
{
  char[] result = "[\n".dup;
  foreach (t1; basicTypes)
    result ~= `EType!(`~t1~`_, int_, "`~expression~`").result,`"\n";
  result[result.length-2] = ']'; // Overwrite last comma.
  return result;
}

char[] genUnaryExpsArray()
{
  char[] result = "[\n".dup;
  foreach (expression; unaryExpressions)
    result ~= genUnaryExpArray(expression) ~ ",\n";
  result[result.length-2] = ']';
  return result;
}

// pragma(msg, mixin(genUnaryExpsArray()).stringof);

auto unaryExpsResults = mixin(genUnaryExpsArray());
auto binaryExpsResults = mixin(genBinaryExpsArray());
