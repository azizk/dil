/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.Generate;

import dil.SyntaxTree;
import dil.Token;
import dil.parser.Parser;
import dil.lexer.Lexer;
import dil.File;
import tango.io.Print;
import common;

enum DocOption
{
  Empty,
  Tokens = 1,
  Syntax = 1<<1,
  HTML   = 1<<2,
  XML    = 1<<3
}

void execute(string fileName, DocOption options)
{
  assert(options != DocOption.Empty);
  if (options & DocOption.Syntax)
    syntaxToDoc(fileName, Stdout, options);
  else
    tokensToDoc(fileName, Stdout, options);
}

char[] xml_escape(char[] text)
{
  char[] result;
  foreach(c; text)
    switch(c)
    {
      case '<': result ~= "&lt;";  break;
      case '>': result ~= "&gt;";  break;
      case '&': result ~= "&amp;"; break;
      default:  result ~= c;
    }
  return result;
}


/// Find object in subject and return position.
/// Returns -1 if no match was found.
int find(char[] subject, char[] object)
{
  if (object.length > subject.length)
    return -1;
  foreach (i, c; subject)
  {
    if (c == object[0])
    {
      if (object.length > (subject.length - i))
        return -1;
      if (object == subject[i..i+object.length])
        return i;
    }
  }
  return -1;
}

char[] getShortClassName(Node n)
{
  static char[][] name_table;
  if (name_table is null)
    name_table = new char[][NodeKind.max+1];
  char[] name = name_table[n.kind];
  if (name !is null)
    return name;

  name = n.classinfo.name;
  name = name[find(name, ".")+1 .. $]; // Remove package name
  name = name[find(name, ".")+1 .. $]; // Remove module name
  char[] remove;
  switch (n.category)
  {
  alias NodeCategory NC;
  case NC.Declaration:
    if (n.kind == NodeKind.Declarations)
      return name;
    remove = "Declaration";
    break;
  case NC.Statement:
    if (n.kind == NodeKind.Statements)
      return name;
    remove = "Statement";
    break;
  case NC.Expression:  remove = "Expression"; break;
  case NC.Type:        remove = "Type"; break;
  case NC.Other:       return name;
  default:
  }
  // Remove common suffix.
  auto idx = find(name, remove);
  if (idx != -1)
    name = name[0 .. idx];
  // Store the name.
  name_table[n.kind] = name;
  return name;
}

enum DocPart
{
  Head,
  CompBegin,
  CompEnd,
  Error,
  SyntaxBegin,
  SyntaxEnd,
  SrcBegin,
  SrcEnd,
  Tail,
  // Tokens:
  Identifier,
  Comment,
  StringLiteral,
  CharLiteral,
  Operator,
  LorG,
  LessEqual,
  GreaterEqual,
  AndLogical,
  OrLogical,
  NotEqual,
  Not,
  Number,
  Bracket,
  SpecialToken,
  Shebang,
  Keyword,
  HLineBegin,
  HLineEnd,
  Filespec,
}

auto html_tags = [
  // Head
  `<html>`\n
  `<head>`\n
  `<meta http-equiv="Content-Type" content="text/html; charset=utf-8">`\n
  `<link href="dil_html.css" rel="stylesheet" type="text/css">`\n
  `</head>`\n
  `<body>`[],
  // CompBegin
  `<div class="compilerinfo">`,
  // CompEnd
  `</div>`,
  // Error
  `<p class="error {0}">{1}({2}){3}: {4}</p>`,
  // SyntaxBegin
  `<span class="{0} {1}">`,
  // SyntaxEnd
  `</span>`,
  // SrcBegin
  `<pre class="sourcecode">`,
  // SrcEnd
  `</pre>`,
  // Tail
  `</html>`,
  // Identifier
  `<span class="i">{0}</span>`,
  // Comment
  `<span class="c{0}">{1}</span>`,
  // StringLiteral
  `<span class="sl">{0}</span>`,
  // CharLiteral
  `<span class="cl">{0}</span>`,
  // Operator
  `<span class="op">{0}</span>`,
  // LorG
  `<span class="oplg">&lt;&gt;</span>`,
  // LessEqual
  `<span class="ople">&lt;=</span>`,
  // GreaterEqual
  `<span class="opge">&gt;=</span>`,
  // AndLogical
  `<span class="opaa">&amp;&amp;</span>`,
  // OrLogical
  `<span class="opoo">||</span>`,
  // NotEqual
  `<span class="opne">!=</span>`,
  // Not
  `<span class="opn">!</span>`,
  // Number
  `<span class="n">{0}</span>`,
  // Bracket
  `<span class="br">{0}</span>`,
  // SpecialToken
  `<span class="st">{0}</span>`,
  // Shebang
  `<span class="shebang">{0}</span>`,
  // Keyword
  `<span class="k">{0}</span>`,
  // HLineBegin
  `<span class="hl">`,
  // HLineEnd
  "</span>",
  // Filespec
  `<span class="fs">{0}</span>`,
];

auto xml_tags = [
  // Head
  `<?xml version="1.0"?>`\n
  `<?xml-stylesheet href="dil_xml.css" type="text/css"?>`\n
  `<root>`[],
  // CompBegin
  `<compilerinfo>`,
  // CompEnd
  `</compilerinfo>`,
  // Error
  `<error t="{0}">{1}({2}){3}: {4}</error>`,
  // SyntaxBegin
  `<{0} t="{1}">`,
  // SyntaxEnd
  `</{0}>`,
  // SrcBegin
  `<sourcecode>`,
  // SrcEnd
  `</sourcecode>`,
  // Tail
  `</root>`,
  // Identifier
  "<i>{0}</i>",
  // Comment
  `<c t="{0}">{1}</c>`,
  // StringLiteral
  "<sl>{0}</sl>",
  // CharLiteral
  "<cl>{0}</cl>",
  // Operator
  "<op>{0}</op>",
  // LorG
  `<op t="lg">&lt;&gt;</op>`,
  // LessEqual
  `<op t="le">&lt;=</op>`,
  // GreaterEqual
  `<op t="ge">&gt;=</op>`,
  // AndLogical
  `<op t="aa">&amp;&amp;</op>`,
  // OrLogical
  `<op t="oo">||</op>`,
  // NotEqual
  `<op t="ne">!=</op>`,
  // Not
  `<op t="n">!</op>`,
  // Number
  "<n>{0}</n>",
  // Bracket
  "<br>{0}</br>",
  // SpecialToken
  "<st>{0}</st>",
  // Shebang
  "<shebang>{0}</shebang>",
  // Keyword
  "<k>{0}</k>",
  // HLineBegin
  "<hl>",
  // HLineEnd
  "</hl>",
  // Filespec
  "<fs>{0}</fs>",
];

static assert(html_tags.length == DocPart.max+1);
static assert(xml_tags.length == DocPart.max+1);

void syntaxToDoc(string fileName, Print!(char) print, DocOption options)
{
  auto tags = options & DocOption.HTML ? html_tags : xml_tags;
  auto sourceText = loadFile(fileName);
  auto parser = new Parser(sourceText, fileName);
  auto root = parser.start();
  auto lx = parser.lx;

  auto token = lx.head;

  print(tags[DocPart.Head]~\n);
  // Output error messages.
  if (lx.errors.length || parser.errors.length)
  {
    print(tags[DocPart.CompBegin]~\n);
    foreach (error; lx.errors)
    {
      print.formatln(tags[DocPart.Error], "L", error.filePath, Format("{0},{1}", error.loc, error.col), "L", xml_escape(error.getMsg));
    }
    foreach (error; parser.errors)
    {
      print.formatln(tags[DocPart.Error], "P", error.filePath, Format("{0},{1}", error.loc, error.col), "P", xml_escape(error.getMsg));
    }
    print(tags[DocPart.CompEnd]~\n);
  }
  print(tags[DocPart.SrcBegin]);

  Node[][Token*] beginNodes, endNodes;

  void populateAAs(Node[] nodes)
  {
    foreach (node; nodes)
    {
      assert(delegate bool(){
          foreach (child; node.children)
            if (child is null)
              return false;
          return true;
        }() == true, Format("Node '{0}' has a null child", node.classinfo.name)
      );
      auto begin = node.begin;
      if (begin)
      {
        auto end = node.end;
        assert(end);
        beginNodes[begin] ~= node;
        endNodes[end] ~= node;
      }

      if (node.children.length)
        populateAAs(node.children);
    }
  }
  assert(delegate bool(){
      foreach (child; root.children)
        if (child is null)
          return false;
      return true;
    }() == true, Format("Root node has a null child")
  );
  populateAAs(root.children);

  char[] getTag(NodeCategory nc)
  {
    char[] tag;
    switch (nc)
    {
    alias NodeCategory NC;
    case NC.Declaration: tag = "d"; break;
    case NC.Statement:   tag = "s"; break;
    case NC.Expression:  tag = "e"; break;
    case NC.Type:        tag = "t"; break;
    case NC.Other:       tag = "o"; break;
    default:
    }
    return tag;
  }

  // Traverse linked list and print tokens.
  while (token.type != TOK.EOF)
  {
    token = token.next;

    // Print whitespace.
    if (token.ws)
      print(token.ws[0..token.start - token.ws]);

    Node[]* nodes = token in beginNodes;

    if (nodes)
    {
      foreach (node; *nodes)
        print.format(tags[DocPart.SyntaxBegin], getTag(node.category), getShortClassName(node));
    }

    printToken(token, tags, print);

    nodes = token in endNodes;

    if (nodes)
    {
      foreach_reverse (node; *nodes)
        if (options & DocOption.HTML)
          print(tags[DocPart.SyntaxEnd]);
        else
          print.format(tags[DocPart.SyntaxEnd], getTag(node.category));
    }
  }
  print(\n~tags[DocPart.SrcEnd])(\n~tags[DocPart.Tail]);
}

void tokensToDoc(string fileName, Print!(char) print, DocOption options)
{
  auto tags = options & DocOption.HTML ? html_tags : xml_tags;
  auto sourceText = loadFile(fileName);
  auto lx = new Lexer(sourceText, fileName);

  auto token = lx.getTokens();

  print(tags[DocPart.Head]~\n);

  if (lx.errors.length)
  {
    print(tags[DocPart.CompBegin]~\n);
    foreach (error; lx.errors)
    {
      print.formatln(tags[DocPart.Error], "L", error.filePath, Format("{0},{1}", error.loc, error.col), "L", xml_escape(error.getMsg));
    }
    print(tags[DocPart.CompEnd]~\n);
  }
  print(tags[DocPart.SrcBegin]);

  // Traverse linked list and print tokens.
  while (token.type != TOK.EOF)
  {
    token = token.next;
    // Print whitespace.
    if (token.ws)
      print(token.ws[0..token.start - token.ws]);
    printToken(token, tags, print);
  }
  print(\n~tags[DocPart.SrcEnd])(\n~tags[DocPart.Tail]);
}

void printToken(Token* token, string[] tags, Print!(char) print)
{
  alias DocPart DP;
  string srcText = xml_escape(token.srcText);

  switch(token.type)
  {
  case TOK.Identifier:
    print.format(tags[DP.Identifier], srcText);
    break;
  case TOK.Comment:
    string t;
    switch (token.start[1])
    {
    case '/': t = "l"; break;
    case '*': t = "b"; break;
    case '+': t = "n"; break;
    default:
      assert(0);
    }
    print.format(tags[DP.Comment], t, srcText);
    break;
  case TOK.String:
    print.format(tags[DP.StringLiteral], srcText);
    break;
  case TOK.CharLiteral:
    print.format(tags[DP.CharLiteral], srcText);
    break;
  case TOK.Assign,        TOK.Equal,
       TOK.Less,          TOK.Greater,
       TOK.LShiftAssign,  TOK.LShift,
       TOK.RShiftAssign,  TOK.RShift,
       TOK.URShiftAssign, TOK.URShift,
       TOK.OrAssign,      TOK.OrBinary,
       TOK.AndAssign,     TOK.AndBinary,
       TOK.PlusAssign,    TOK.PlusPlus,   TOK.Plus,
       TOK.MinusAssign,   TOK.MinusMinus, TOK.Minus,
       TOK.DivAssign,     TOK.Div,
       TOK.MulAssign,     TOK.Mul,
       TOK.ModAssign,     TOK.Mod,
       TOK.XorAssign,     TOK.Xor,
       TOK.CatAssign,
       TOK.Tilde,
       TOK.Unordered,
       TOK.UorE,
       TOK.UorG,
       TOK.UorGorE,
       TOK.UorL,
       TOK.UorLorE,
       TOK.LorEorG:
    print.format(tags[DP.Operator], srcText);
    break;
  case TOK.LorG:
    print(tags[DP.LorG]);
    break;
  case TOK.LessEqual:
    print(tags[DP.LessEqual]);
    break;
  case TOK.GreaterEqual:
    print(tags[DP.GreaterEqual]);
    break;
  case TOK.AndLogical:
    print(tags[DP.AndLogical]);
    break;
  case TOK.OrLogical:
    print(tags[DP.OrLogical]);
    break;
  case TOK.NotEqual:
    print(tags[DP.NotEqual]);
    break;
  case TOK.Not:
    // Check if this is part of a template instantiation.
    // TODO: comments aren't skipped. Use Token.nextNWS and Token.prevNWS
    if (token.prev.type == TOK.Identifier && token.next.type == TOK.LParen)
      goto default;
    print(tags[DP.Not]);
    break;
  case TOK.Int32, TOK.Int64, TOK.Uint32, TOK.Uint64,
       TOK.Float32, TOK.Float64, TOK.Float80,
       TOK.Imaginary32, TOK.Imaginary64, TOK.Imaginary80:
    print.format(tags[DP.Number], srcText);
    break;
  case TOK.LParen, TOK.RParen, TOK.LBracket,
       TOK.RBracket, TOK.LBrace, TOK.RBrace:
    print.format(tags[DP.Bracket], srcText);
    break;
  case TOK.Shebang:
    print.format(tags[DP.Shebang], srcText);
    break;
  case TOK.HashLine:
    void printWS(char* start, char* end)
    {
      if (start != end)
        print(start[0 .. end - start]);
    }
    print(tags[DP.HLineBegin]);
    auto num = token.tokLineNum;
    if (num is null)
    {
      print(token.srcText);
      print(tags[DP.HLineEnd]);
      break;
    }
    // Print whitespace between #line and number
    auto ptr = token.start;
    printWS(ptr, num.start); // prints "#line" as well
    printToken(num, tags, print);
    if (token.tokLineFilespec)
    {
      auto filespec = token.tokLineFilespec;
      // Print whitespace between number and filespec
      printWS(num.end, filespec.start);
      print.format(tags[DP.Filespec], xml_escape(filespec.srcText));

      ptr = filespec.end;
    }
    else
      ptr = num.end;
    // Print remaining whitespace
    printWS(ptr, token.end);
    print(tags[DP.HLineEnd]);
    break;
  default:
    if (token.isKeyword())
      print.format(tags[DP.Keyword], srcText);
    else if (token.isSpecialToken)
      print.format(tags[DP.SpecialToken], srcText);
    else
      print(srcText);
  }
}
