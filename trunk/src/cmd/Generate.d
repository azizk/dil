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
import dil.semantic.Module;
import dil.SourceText;
import dil.Information;
import dil.SettingsLoader;
import dil.Settings;
import common;

import tango.io.GrowBuffer;
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
void execute(string filePath, DocOption options, InfoManager infoMan)
{
  assert(options != DocOption.Empty);
  auto mapFilePath = options & DocOption.HTML ? GlobalSettings.htmlMapFile
                                              : GlobalSettings.xmlMapFile;
  auto map = TagMapLoader(infoMan).load(mapFilePath);
  auto tags = new TagMap(map);

  if (infoMan.hasInfo)
    return;

  if (options & DocOption.Syntax)
    highlightSyntax(filePath, tags, Stdout, options);
  else
    highlightTokens(filePath, tags, Stdout);
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

class TagMap
{
  string[string] table;

  this(string[string] table)
  {
    this.table = table;
    Identifier   = this["Identifier", "{0}"];
    String       = this["String", "{0}"];
    Char         = this["Char", "{0}"];
    Number       = this["Number", "{0}"];
    Keyword      = this["Keyword", "{0}"];
    LineC        = this["LineC", "{0}"];
    BlockC       = this["BlockC", "{0}"];
    NestedC      = this["NestedC", "{0}"];
    Shebang      = this["Shebang", "{0}"];
    HLine        = this["HLine", "{0}"];
    Filespec     = this["Filespec", "{0}"];
    Illegal      = this["Illegal", "{0}"];
    Newline      = this["Newline", "{0}"];
    SpecialToken = this["SpecialToken", "{0}"];
    Declaration  = this["Declaration", "d"];
    Statement    = this["Statement", "s"];
    Expression   = this["Expression", "e"];
    Type         = this["Type", "t"];
    Other        = this["Other", "o"];
    EOF          = this["EOF", ""];
  }

  string opIndex(string str, string fallback = "")
  {
    auto p = str in table;
    if (p)
      return *p;
    return fallback;
  }

  string Identifier, String, Char, Number, Keyword, LineC, BlockC,
         NestedC, Shebang, HLine, Filespec, Illegal, Newline, SpecialToken,
         Declaration, Statement, Expression, Type, Other, EOF;

  /// Returns the tag for the category 'nc'.
  string getTag(NodeCategory nc)
  {
    string tag;
    switch (nc)
    { alias NodeCategory NC;
    case NC.Declaration: tag = Declaration; break;
    case NC.Statement:   tag = Statement; break;
    case NC.Expression:  tag = Expression; break;
    case NC.Type:        tag = Type; break;
    case NC.Other:       tag = Other; break;
    default: assert(0);
    }
    return tag;
  }
}

/// Find the last occurrence of object in subject.
/// Returns: the index if found, or -1 if not.
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
    auto token = first;

    uint count; // Count tokens.
    for (; token; token = token.next)
      count++;
    // Creat the exact number of TokenEx instances.
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

  // Override dispatch function.
  override Node dispatch(Node n)
  {
    auto begin = n.begin;
    if (begin)
    { assert(n.end);
      auto txbegin = getTokenEx(begin);
      auto txend = getTokenEx(n.end);
      txbegin.beginNodes ~= n;
      txend.endNodes ~= n;
    }
    return super.dispatch(n);
  }
}

void printErrors(Lexer lx, TagMap tags, Print!(char) print)
{
  foreach (e; lx.errors)
    print.format(tags["LexerError"], e.filePath, e.loc, e.col, xml_escape(e.getMsg));
}

void printErrors(Parser parser, TagMap tags, Print!(char) print)
{
  foreach (e; parser.errors)
    print.format(tags["ParserError"], e.filePath, e.loc, e.col, xml_escape(e.getMsg));
}

void highlightSyntax(string filePath, TagMap tags, Print!(char) print, DocOption options)
{
  auto parser = new Parser(new SourceText(filePath, true));
  auto root = parser.start();
  auto lx = parser.lexer;

  auto builder = new TokenExBuilder();
  auto tokenExList = builder.build(root, lx.firstToken());

  print(tags["DocHead"]);
  if (lx.errors.length || parser.errors.length)
  { // Output error messages.
    print(tags["CompBegin"]);
    printErrors(lx, tags, print);
    printErrors(parser, tags, print);
    print(tags["CompEnd"]);
  }
  print(tags["SourceBegin"]);

  auto tagNodeBegin = tags["NodeBegin"];
  auto tagNodeEnd = tags["NodeEnd"];

  // Iterate over list of tokens.
  foreach (ref tokenEx; tokenExList)
  {
    auto token = tokenEx.token;

    token.ws && print(token.wsChars); // Print preceding whitespace.
    if (token.isWhitespace) {
      printToken(token, tags, print);
      continue;
    }
    // <node>
    foreach (node; tokenEx.beginNodes)
      print.format(tagNodeBegin, tags.getTag(node.category), getShortClassName(node));
    // Token text.
    printToken(token, tags, print);
    // </node>
    if (options & DocOption.HTML)
      foreach_reverse (node; tokenEx.endNodes)
        print(tagNodeEnd);
    else
      foreach_reverse (node; tokenEx.endNodes)
        print.format(tagNodeEnd, tags.getTag(node.category));
  }
  print(tags["SourceEnd"]);
  print(tags["DocEnd"]);
}

/// Prints all tokens of a source file using the buffer print.
void highlightTokens(string filePath, TagMap tags, Print!(char) print)
{
  auto lx = new Lexer(new SourceText(filePath, true));
  lx.scanAll();

  print(tags["DocHead"]);
  if (lx.errors.length)
  {
    print(tags["CompBegin"]);
    printErrors(lx, tags, print);
    print(tags["CompEnd"]);
  }
  print(tags["SourceBegin"]);
  // Traverse linked list and print tokens.
  for (auto token = lx.firstToken(); token; token = token.next) {
    token.ws && print(token.wsChars); // Print preceding whitespace.
    printToken(token, tags, print);
  }
  print(tags["SourceEnd"]);
  print(tags["DocEnd"]);
}

class TokenHighlighter
{
  TagMap tags;
  this(InfoManager infoMan, bool useHTML = true)
  {
    auto map = TagMapLoader(infoMan).load(GlobalSettings.htmlMapFile);
    tags = new TagMap(map);
  }

  /// Highlights tokens in a DDoc code section.
  /// Returns: a string with the highlighted tokens (in HTML tags.)
  string highlight(string text, string filePath)
  {
    auto buffer = new GrowBuffer(text.length);
    auto print = new Print!(char)(Format, buffer);

    auto lx = new Lexer(new SourceText(filePath, text));
    lx.scanAll();

    // Traverse linked list and print tokens.
    print("$(D_CODE\n");
    if (lx.errors.length)
    { // Output error messages.
      print(tags["CompBegin"]);
      printErrors(lx, tags, print);
      print(tags["CompEnd"]);
    }
    // Traverse linked list and print tokens.
    for (auto token = lx.firstToken(); token; token = token.next) {
      token.ws && print(token.wsChars); // Print preceding whitespace.
      printToken(token, tags, print);
    }
    print("\n)");
    return cast(char[])buffer.slice();
  }
}

/// Prints a token with tags using the buffer print.
void printToken(Token* token, TagMap tags, Print!(char) print)
{
  switch(token.kind)
  {
  case TOK.Identifier:
    print.format(tags.Identifier, token.srcText);
    break;
  case TOK.Comment:
    string formatStr;
    switch (token.start[1])
    {
    case '/': formatStr = tags.LineC; break;
    case '*': formatStr = tags.BlockC; break;
    case '+': formatStr = tags.NestedC; break;
    default: assert(0);
    }
    print.format(formatStr, xml_escape(token.srcText));
    break;
  case TOK.String:
    print.format(tags.String, xml_escape(token.srcText));
    break;
  case TOK.CharLiteral:
    print.format(tags.Char, xml_escape(token.srcText));
    break;
  case TOK.Int32, TOK.Int64, TOK.Uint32, TOK.Uint64,
       TOK.Float32, TOK.Float64, TOK.Float80,
       TOK.Imaginary32, TOK.Imaginary64, TOK.Imaginary80:
    print.format(tags.Number, token.srcText);
    break;
  case TOK.Shebang:
    print.format(tags.Shebang, xml_escape(token.srcText));
    break;
  case TOK.HashLine:
    auto formatStr = tags.HLine;
    // The text to be inserted into formatStr.
    auto buffer = new GrowBuffer;
    auto print2 = new Print!(char)(Format, buffer);

    void printWS(char* start, char* end)
    {
      start != end && print2(start[0 .. end - start]);
    }

    auto num = token.tokLineNum;
    if (num is null)
    { // Malformed #line
      print.format(formatStr, token.srcText);
      break;
    }

    // Print whitespace between #line and number.
    printWS(token.start, num.start); // Prints "#line" as well.
    printToken(num, tags, print2); // Print the number.

    if (auto filespec = token.tokLineFilespec)
    { // Print whitespace between number and filespec.
      printWS(num.end, filespec.start);
      print2.format(tags.Filespec, xml_escape(filespec.srcText));
    }
    // Finally print the whole token.
    print.format(formatStr, cast(char[])buffer.slice());
    break;
  case TOK.Illegal:
    print.format(tags.Illegal, token.srcText());
    break;
  case TOK.Newline:
    print.format(tags.Newline, token.srcText());
    break;
  case TOK.EOF:
    print(tags.EOF);
    break;
  default:
    if (token.isKeyword())
      print.format(tags.Keyword, token.srcText);
    else if (token.isSpecialToken)
      print.format(tags.SpecialToken, token.srcText);
    else
      print(tags[token.srcText]);
  }
}
