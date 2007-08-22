/++
  Author: Aziz Köksal
  License: GPL3
+/
module dparser;
import std.stdio;
import std.file;
import dil.Parser;
import dil.Lexer;
import dil.Token;
import dil.Messages;
import dil.Settings;
import dil.Declarations, dil.Expressions, dil.SyntaxTree;

void main(char[][] args)
{
  GlobalSettings.load();

  if (args.length <= 1)
    return writefln(format(MID.HelpMain, VERSION, usageGenerate, COMPILED_WITH, COMPILED_VERSION, COMPILED_DATE));

  string command = args[1];
  switch (command)
  {
  case "gen", "generate":
    char[] fileName;
    DocOption options = DocOption.Tokens;
    foreach (arg; args[2..$])
    {
      switch (arg)
      {
      case "--syntax":
        options |= DocOption.Syntax; break;
      case "--xml":
        options |= DocOption.XML; break;
      case "--html":
        options |= DocOption.HTML; break;
      default:
        fileName = arg;
      }
    }
    if (!(options & (DocOption.XML | DocOption.HTML)))
      options |= DocOption.XML; // Default to XML.
    if (options & DocOption.Syntax)
      syntaxToDoc(fileName, options);
    else
      tokensToDoc(fileName, options);
    break;
  case "parse":
    if (args.length == 3)
      parse(args[2]);
    break;
  default:
  }
}

enum DocOption
{
  Tokens,
  Syntax = 1<<1,
  HTML = 1<<2,
  XML = 1<<3
}

void parse(string fileName)
{
  auto sourceText = cast(char[]) std.file.read(fileName);
  auto parser = new Parser(sourceText, fileName);
  parser.start();
  auto root = parser.parseModule();

void print(Node[] decls, char[] indent)
{
  foreach(decl; decls)
  {
    assert(decl !is null);
    writefln(indent, decl.classinfo.name, ": begin=%s end=%s", decl.begin ? decl.begin.srcText : "\33[31mnull\33[0m", decl.end ? decl.end.srcText : "\33[31mnull\33[0m");
    print(decl.children, indent ~ "  ");
  }
}
print(root.children, "");
foreach (error; parser.errors)
{
  writefln(`%s(%d)P: %s`, parser.lx.fileName, error.loc, error.getMsg);
}
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

char[] getShortClassName(Node n)
{
  static char[][] name_table;
  if (name_table is null)
    name_table = new char[][NodeKind.max+1];
  char[] name = name_table[n.kind];
  if (name !is null)
    return name;

  alias std.string.find find;
  name = n.classinfo.name;
  name = name[find(name, ".")+1 .. $]; // Remove package name
  name = name[find(name, ".")+1 .. $]; // Remove module name
  char[] remove;
  switch (n.category)
  {
  alias NodeCategory NC;
  case NC.Declaration: remove = "Declaration"; break;
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
  `<p class="error %s">%s(%d)%s: %s</p>`,
  // SyntaxBegin
  `<span class="%s %s">`,
  // SyntaxEnd
  `</span>`,
  // SrcBegin
  `<pre class="sourcecode">`,
  // SrcEnd
  `</pre>`,
  // Tail
  `</html>`,
  // Identifier
  `<span class="i">%s</span>`,
  // Comment
  `<span class="c%s">%s</span>`,
  // StringLiteral
  `<span class="sl">%s</span>`,
  // CharLiteral
  `<span class="cl">%s</span>`,
  // Operator
  `<span class="op">%s</span>`,
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
  `<span class="n">%s</span>`,
  // Bracket
  `<span class="br">%s</span>`,
  // SpecialToken
  `<span class="st">%s</span>`,
  // Shebang
  `<span class="shebang">%s</span>`,
  // Keyword
  `<span class="k">%s</span>`,
  // HLineBegin
  `<span class="hl">#line`,
  // HLineEnd
  "</span>",
  // Filespec
  `<span class="fs">%s</span>`,
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
  `<error t="%s">%s(%d)%s: %s</error>`,
  // SyntaxBegin
  `<%s t="%s">`,
  // SyntaxEnd
  `</%s>`,
  // SrcBegin
  `<sourcecode>`,
  // SrcEnd
  `</sourcecode>`,
  // Tail
  `</root>`,
  // Identifier
  "<i>%s</i>",
  // Comment
  `<c t="%s">%s</c>`,
  // StringLiteral
  "<sl>%s</sl>",
  // CharLiteral
  "<cl>%s</cl>",
  // Operator
  "<op>%s</op>",
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
  "<n>%s</n>",
  // Bracket
  "<br>%s</br>",
  // SpecialToken
  "<st>%s</st>",
  // Shebang
  "<shebang>%s</shebang>",
  // Keyword
  "<k>%s</k>",
  // HLineBegin
  "<hl>#line",
  // HLineEnd
  "</hl>",
  // Filespec
  "<fs>%s</fs>",
];

static assert(html_tags.length == DocPart.max+1);
static assert(xml_tags.length == DocPart.max+1);

void syntaxToDoc(string fileName, DocOption options)
{
  auto tags = options & DocOption.HTML ? html_tags : xml_tags;
  auto sourceText = cast(char[]) std.file.read(fileName);
  auto parser = new Parser(sourceText, fileName);
  parser.start();
  auto root = parser.parseModule();
  auto lx = parser.lx;

  auto token = lx.head;
  char* end = lx.text.ptr;

  writefln(tags[DocPart.Head]);
  // Output error messages.
  if (lx.errors.length || parser.errors.length)
  {
    writefln(tags[DocPart.CompBegin]);
    foreach (error; lx.errors)
    {
      writefln(tags[DocPart.Error], "L", lx.fileName, error.loc, "L", xml_escape(error.getMsg));
    }
    foreach (error; parser.errors)
    {
      writefln(tags[DocPart.Error], "P", lx.fileName, error.loc, "P", xml_escape(error.getMsg));
    }
    writefln(tags[DocPart.CompEnd]);
  }
  writef(tags[DocPart.SrcBegin]);

  Node[][Token*] beginNodes, endNodes;

  void populateAAs(Node[] nodes)
  {
    foreach (node; nodes)
    {
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

    // Print whitespace between previous and current token.
    if (end != token.start)
      writef("%s", end[0 .. token.start - end]);

    Node[]* nodes = token in beginNodes;

    if (nodes)
    {
      foreach (node; *nodes)
        writef(tags[DocPart.SyntaxBegin], getTag(node.category), getShortClassName(node));
    }

    printToken(token, tags);

    nodes = token in endNodes;

    if (nodes)
    {
      foreach_reverse (node; *nodes)
        if (options & DocOption.HTML)
          writef(tags[DocPart.SyntaxEnd]);
        else
          writef(tags[DocPart.SyntaxEnd], getTag(node.category));
    }

    end = token.end;
  }
  writef(tags[DocPart.SrcEnd], tags[DocPart.Tail]);
}

void tokensToDoc(string fileName, DocOption options)
{
  auto tags = options & DocOption.HTML ? html_tags : xml_tags;
  auto sourceText = cast(char[]) std.file.read(fileName);
  auto lx = new Lexer(sourceText, fileName);

  auto token = lx.getTokens();
  char* end = lx.text.ptr;

  writefln(tags[DocPart.Head]);

  if (lx.errors.length)
  {
    writefln(tags[DocPart.CompBegin]);
    foreach (error; lx.errors)
    {
      writefln(tags[DocPart.Error], "L", lx.fileName, error.loc, "L", xml_escape(error.getMsg));
    }
    writefln(tags[DocPart.CompEnd]);
  }
  writef(tags[DocPart.SrcBegin]);

  // Traverse linked list and print tokens.
  while (token.type != TOK.EOF)
  {
    token = token.next;

    // Print whitespace between previous and current token.
    if (end != token.start)
      writef("%s", end[0 .. token.start - end]);
    printToken(token, tags);
    end = token.end;
  }
  writef(\n, tags[DocPart.SrcEnd], \n, tags[DocPart.Tail]);
}

void printToken(Token* token, string[] tags)
{
  alias DocPart DP;
  string srcText = xml_escape(token.srcText);

  switch(token.type)
  {
  case TOK.Identifier:
    writef(tags[DP.Identifier], srcText);
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
    writef(tags[DP.Comment], t, srcText);
    break;
  case TOK.String:
    writef(tags[DP.StringLiteral], srcText);
    break;
  case TOK.CharLiteral, TOK.WCharLiteral, TOK.DCharLiteral:
    writef(tags[DP.CharLiteral], srcText);
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
    writef(tags[DP.Operator], srcText);
    break;
  case TOK.LorG:
    writef(tags[DP.LorG]);
    break;
  case TOK.LessEqual:
    writef(tags[DP.LessEqual]);
    break;
  case TOK.GreaterEqual:
    writef(tags[DP.GreaterEqual]);
    break;
  case TOK.AndLogical:
    writef(tags[DP.AndLogical]);
    break;
  case TOK.OrLogical:
    writef(tags[DP.OrLogical]);
    break;
  case TOK.NotEqual:
    writef(tags[DP.NotEqual]);
    break;
  case TOK.Not:
    // Check if this is part of a template instantiation.
    // TODO: comments aren't skipped.
    if (token.prev.type == TOK.Identifier && token.next.type == TOK.LParen)
      goto default;
    writef(tags[DP.Not]);
    break;
  case TOK.Int32, TOK.Int64, TOK.Uint32, TOK.Uint64,
       TOK.Float32, TOK.Float64, TOK.Float80,
       TOK.Imaginary32, TOK.Imaginary64, TOK.Imaginary80:
    writef(tags[DP.Number], srcText);
    break;
  case TOK.LParen, TOK.RParen, TOK.LBracket,
       TOK.RBracket, TOK.LBrace, TOK.RBrace:
    writef(tags[DP.Bracket], srcText);
    break;
  case TOK.Special:
    writef(tags[DP.SpecialToken], srcText);
    break;
  case TOK.Shebang:
    writef(tags[DP.Shebang], srcText);
    break;
  case TOK.HashLine:
    void printWS(char* start, char* end)
    {
      if (start != end)
        writef(start[0 .. end - start]);
    }
    writef(tags[DP.HLineBegin]);
    auto num = token.line_num;
    // Print whitespace between #line and number
    auto ptr = token.start + "#line".length;
    printWS(ptr, num.start);
    printToken(num, tags);
    if (token.line_filespec)
    {
      auto filespec = token.line_filespec;
      // Print whitespace between number and filespec
      printWS(num.end, filespec.start);
      writef(tags[DP.Filespec], xml_escape(filespec.srcText));

      ptr = filespec.end;
    }
    else
      ptr = num.end;
    // Print remaining whitespace
    printWS(ptr, token.end);
    writef(tags[DP.HLineEnd]);
    break;
  default:
    if (token.isKeyword())
      writef(tags[DP.Keyword], srcText);
    else
      writef("%s", srcText);
  }
}
