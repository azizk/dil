/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.Generate;

import dil.ast.DefaultVisitor;
import dil.ast.Node,
       dil.ast.Declaration,
       dil.ast.Statement,
       dil.ast.Expression,
       dil.ast.Types;
import dil.lexer.Lexer;
import dil.parser.Parser;
import dil.SourceText;
import common;

import tango.io.Print;

/// Options for the generate command.
enum DocOption
{
  Empty,
  Tokens = 1,
  Syntax = 1<<1,
  HTML   = 1<<2,
  XML    = 1<<3
}

/// Executes the command.
void execute(string filePath, DocOption options)
{
  assert(options != DocOption.Empty);
  if (options & DocOption.Syntax)
    syntaxToDoc(filePath, Stdout, options);
  else
    tokensToDoc(filePath, Stdout, options);
}

/// Escapes the characters '<', '>' and '&' with named character entities.
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
  if (result.length != text.length)
    return result;
  // Nothing escaped. Return original text.
  delete result;
  return text;
}


/// Find object in subject and return position.
/// Returns -1 if no match was found.
/+int find(char[] subject, char[] object)
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
}+/

/++
  Find the last occurrence of object in subject.
  Returns the index if found, or -1 if not.
+/
int rfind(char[] subject, char object)
{
  foreach_reverse(i, c; subject)
    if (c == object)
      return i;
  return -1;
}

/// Returns: the short class name of an instance descending from Node.
char[] getShortClassName(Node node)
{
  static char[][] name_table;
  if (name_table is null)
    name_table = new char[][NodeKind.max+1]; // Create a new table.
  // Look up in table.
  char[] name = name_table[node.kind];
  if (name !is null)
    return name; // Return cached name.

  name = node.classinfo.name; // Get the fully qualified name of the class.
  name = name[rfind(name, '.')+1 .. $]; // Remove package and module name.

  uint suffixLength;
  switch (node.category)
  {
  alias NodeCategory NC;
  case NC.Declaration:
    suffixLength = "Declaration".length;
    break;
  case NC.Statement:
    suffixLength = "Statement".length;
    break;
  case NC.Expression:
    suffixLength = "Expression".length;
    break;
  case NC.Type:
    suffixLength = "Type".length;
    break;
  case NC.Other:
    break;
  default:
    assert(0);
  }
  // Remove common suffix.
  name = name[0 .. $ - suffixLength];
  // Store the name in the table.
  name_table[node.kind] = name;
  return name;
}

/// Indices into the XML and HTML tag arrays.
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
  `<link href="html.css" rel="stylesheet" type="text/css">`\n
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
  `<span class="chl">{0}</span>`,
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
  `<?xml-stylesheet href="xml.css" type="text/css"?>`\n
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

// The size of the arrays must equal the number of members in enum DocPart.
static assert(html_tags.length == DocPart.max+1);
static assert(xml_tags.length == DocPart.max+1);

/// Extended token structure.
struct TokenEx
{
  Token* token; /// The lexer token.
  Node[] beginNodes; /// beginNodes[n].begin == token
  Node[] endNodes; /// endNodes[n].end == token
}

/// Builds an array of TokenEx items.
class TokenExBuilder : DefaultVisitor
{
  private TokenEx*[Token*] tokenTable;

  TokenEx[] build(Node root, Token* first)
  {
    Token* token = first;

    uint count;
    while (token)
    {
      count++;
      token = token.next;
    }

    auto toks = new TokenEx[count];
    token = first;
    foreach (ref tokEx; toks)
    {
      tokEx.token = token;
      if (!token.isWhitespace)
        tokenTable[token] = &tokEx;
      token = token.next;
    }

    super.visitN(root);
    tokenTable = null;
    return toks;
  }

  TokenEx* getTokenEx()(Token* t)
  {
    auto p = t in tokenTable;
    assert(p, t.srcText~" is not in tokenTable");
    return *p;
  }

  void push()(Node n)
  {
    auto begin = n.begin;
    if (begin)
    { assert(n.end);
      auto txbegin = getTokenEx(begin);
      auto txend = getTokenEx(n.end);
      txbegin.beginNodes ~= n;
      txend.endNodes ~= n;
    }
  }

  // Override dispatch functions.
override:
  Declaration visitD(Declaration n)
  { return push(n), super.visitD(n); }
  Statement visitS(Statement n)
  { return push(n), super.visitS(n); }
  Expression visitE(Expression n)
  { return push(n), super.visitE(n); }
  TypeNode visitT(TypeNode n)
  { return push(n), super.visitT(n); }
  Node visitN(Node n)
  { return push(n), super.visitN(n); }
}

char getTag(NodeCategory nc)
{
  char tag;
  switch (nc)
  {
  alias NodeCategory NC;
  case NC.Declaration: tag = 'd'; break;
  case NC.Statement:   tag = 's'; break;
  case NC.Expression:  tag = 'e'; break;
  case NC.Type:        tag = 't'; break;
  case NC.Other:       tag = 'o'; break;
  default:
    assert(0);
  }
  return tag;
}

void printErrors(Lexer lx, string[] tags, Print!(char) print)
{
  foreach (error; lx.errors)
  {
    print.formatln(tags[DocPart.Error], "L", error.filePath, Format("{0},{1}", error.loc, error.col), "L", xml_escape(error.getMsg));
  }
}

void printErrors(Parser parser, string[] tags, Print!(char) print)
{
  foreach (error; parser.errors)
  {
    print.formatln(tags[DocPart.Error], "P", error.filePath, Format("{0},{1}", error.loc, error.col), "P", xml_escape(error.getMsg));
  }
}

void syntaxToDoc(string filePath, Print!(char) print, DocOption options)
{
  auto tags = options & DocOption.HTML ? html_tags : xml_tags;
  auto parser = new Parser(new SourceText(filePath, true));
  auto root = parser.start();
  auto lx = parser.lexer;

  auto builder = new TokenExBuilder();
  auto tokenExList = builder.build(root, lx.firstToken());

  print(tags[DocPart.Head]~\n);
  if (lx.errors.length || parser.errors.length)
  { // Output error messages.
    print(tags[DocPart.CompBegin]~\n);
    printErrors(lx, tags, print);
    printErrors(parser, tags, print);
    print(tags[DocPart.CompEnd]~\n);
  }
  print(tags[DocPart.SrcBegin]);

  // Iterate over list of tokens.
  foreach (ref tokenEx; tokenExList)
  {
    auto token = tokenEx.token;
    // Print whitespace.
    if (token.ws)
      print(token.wsChars);

    foreach (node; tokenEx.beginNodes)
      print.format(tags[DocPart.SyntaxBegin], getTag(node.category), getShortClassName(node));

    printToken(token, tags, print);

    if (options & DocOption.HTML)
      foreach_reverse (node; tokenEx.endNodes)
        print(tags[DocPart.SyntaxEnd]);
    else
      foreach_reverse (node; tokenEx.endNodes)
        print.format(tags[DocPart.SyntaxEnd], getTag(node.category));
  }
  print(\n~tags[DocPart.SrcEnd])(\n~tags[DocPart.Tail]);
}

/// Prints all tokens of a source file using the buffer print.
void tokensToDoc(string filePath, Print!(char) print, DocOption options)
{
  auto tags = options & DocOption.HTML ? html_tags : xml_tags;
  auto lx = new Lexer(new SourceText(filePath, true));
  lx.scanAll();

  print(tags[DocPart.Head]~\n);
  if (lx.errors.length)
  {
    print(tags[DocPart.CompBegin]~\n);
    printErrors(lx, tags, print);
    print(tags[DocPart.CompEnd]~\n);
  }
  print(tags[DocPart.SrcBegin]);

  // Traverse linked list and print tokens.
  auto token = lx.firstToken();
  while (token.kind != TOK.EOF)
  {
    // Print whitespace.
    if (token.ws)
      print(token.wsChars);
    printToken(token, tags, print);
    token = token.next;
  }
  print(\n~tags[DocPart.SrcEnd])(\n~tags[DocPart.Tail]);
}

/// Prints a token with tags using the buffer print.
void printToken(Token* token, string[] tags, Print!(char) print)
{
  alias DocPart DP;
  string srcText = xml_escape(token.srcText);

  switch(token.kind)
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
    if (token.prevNWS.kind == TOK.Identifier && token.nextNWS.kind == TOK.LParen)
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
