/++
  Author: Aziz Köksal
  License: GPL3
+/
module TypeRules;

import cmd.Generate : xml_escape;

import TypeRulesData;
import common;

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

void genHTMLTypeRulesTables()
{
  Stdout(
    `<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">`\n
    `<html>`\n
    `<head>`\n
    `  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">`\n
    `  <link href="" rel="stylesheet" type="text/css">`\n
    `  <style type="text/css">`\n
    `    .E { color: darkred; } /* Error */`\n
    `    .R { font-size: 0.8em; } /* Result */`\n
    `    .X { color: darkorange; }`\n
    `    .Y { color: darkblue; }`\n
    `  </style>`\n
    `</head>`\n
    `<body>`\n
    `<p>These tables show what the type results of certain expressions are.</p>`\n
  );

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
    auto binaryExpression = binaryExpressions[i];
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
