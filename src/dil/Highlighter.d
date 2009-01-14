/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.Highlighter;

import dil.ast.DefaultVisitor,
       dil.ast.Node,
       dil.ast.Declaration,
       dil.ast.Statement,
       dil.ast.Expression,
       dil.ast.Types;
import dil.lexer.Lexer;
import dil.parser.Parser;
import dil.semantic.Module;
import dil.SourceText;
import dil.Diagnostics;
import common;

import tango.io.Buffer;
import tango.io.Print;
import tango.io.FilePath;

/// A token and syntax highlighter.
class Highlighter
{
  TagMap tags; /// Which tag map to use.
  /// Used to print formatted strings. Can be a file, stdout or buffer.
  Print!(char) print;
  Diagnostics diag; /// Collects error messages.

  /// Constructs a TokenHighlighter object.
  this(TagMap tags, Print!(char) print, Diagnostics diag)
  {
    this.tags = tags;
    this.print = print;
    this.diag = diag;
  }

  /// Highlights tokens in a text buffer.
  /// Returns: a string with the highlighted tokens.
  string highlightTokens(string text, string filePath, ref uint lines)
  {
    auto buffer = new GrowBuffer(text.length);
    auto print_saved = print; // Save;
    print = new Print!(char)(Format, buffer);

    auto lx = new Lexer(new SourceText(filePath, text), diag);
    lx.scanAll();
    lines = lx.lineNum;

    // Traverse linked list and print tokens.
    for (auto token = lx.firstToken(); token; token = token.next) {
      token.ws && print(token.wsChars); // Print preceding whitespace.
      printToken(token);
    }

    print = print_saved; // Restore.
    return cast(char[])buffer.slice();
  }

  /// Highlights all tokens of a source file.
  void highlightTokens(string filePath, bool opt_printLines)
  {
    auto lx = new Lexer(new SourceText(filePath, true), diag);
    lx.scanAll();

    print.format(tags["DocHead"], (new FilePath(filePath)).name());
    if (lx.errors.length)
    {
      print(tags["CompBegin"]);
      printErrors(lx);
      print(tags["CompEnd"]);
    }

    if (opt_printLines)
    {
      print(tags["LineNumberBegin"]);
      printLines(lx.lineNum);
      print(tags["LineNumberEnd"]);
    }

    print(tags["SourceBegin"]);
    // Traverse linked list and print tokens.
    for (auto token = lx.firstToken(); token; token = token.next) {
      token.ws && print(token.wsChars); // Print preceding whitespace.
      printToken(token);
    }
    print(tags["SourceEnd"]);
    print(tags["DocEnd"]);
  }

  /// Highlights the syntax in a source file.
  void highlightSyntax(string filePath, bool printHTML, bool opt_printLines)
  {
    auto modul = new Module(filePath, diag);
    modul.parse();
    highlightSyntax(modul, printHTML, opt_printLines);
  }

  /// ditto
  void highlightSyntax(Module modul, bool printHTML, bool opt_printLines)
  {
    auto parser = modul.parser;
    auto lx = parser.lexer;
    auto builder = new TokenExBuilder();
    auto tokenExList = builder.build(modul.root, lx.firstToken());

    print.format(tags["DocHead"], modul.getFQN());
    if (lx.errors.length || parser.errors.length)
    { // Output error messages.
      print(tags["CompBegin"]);
      printErrors(lx);
      printErrors(parser);
      print(tags["CompEnd"]);
    }

    if (opt_printLines)
    {
      print(tags["LineNumberBegin"]);
      printLines(lx.lineNum);
      print(tags["LineNumberEnd"]);
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
        printToken(token);
        continue;
      }
      // <node>
      foreach (node; tokenEx.beginNodes)
        print.format(tagNodeBegin, tags.getTag(node.category), getShortClassName(node));
      // Token text.
      printToken(token);
      // </node>
      if (printHTML)
        foreach_reverse (node; tokenEx.endNodes)
          print(tagNodeEnd);
      else
        foreach_reverse (node; tokenEx.endNodes)
          print.format(tagNodeEnd, tags.getTag(node.category));
    }
    print(tags["SourceEnd"]);
    print(tags["DocEnd"]);
  }

  void printErrors(Lexer lx)
  {
    foreach (e; lx.errors)
      print.format(tags["LexerError"], e.filePath,
                   e.loc, e.col, xml_escape(e.getMsg));
  }

  void printErrors(Parser parser)
  {
    foreach (e; parser.errors)
      print.format(tags["ParserError"], e.filePath,
                   e.loc, e.col, xml_escape(e.getMsg));
  }

  void printLines(uint lines)
  {
    auto lineNumberFormat = tags["LineNumber"];
    for (auto lineNum = 1; lineNum <= lines; lineNum++)
      print.format(lineNumberFormat, lineNum);
  }

  /// Prints a token to the stream print.
  void printToken(Token* token)
  {
    switch(token.kind)
    {
    case TOK.Identifier:
      print.format(tags.Identifier, token.text);
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
      print.format(formatStr, xml_escape(token.text));
      break;
    case TOK.String:
      print.format(tags.String, xml_escape(token.text));
      break;
    case TOK.CharLiteral:
      print.format(tags.Char, xml_escape(token.text));
      break;
    case TOK.Int32, TOK.Int64, TOK.Uint32, TOK.Uint64,
        TOK.Float32, TOK.Float64, TOK.Float80,
        TOK.Imaginary32, TOK.Imaginary64, TOK.Imaginary80:
      print.format(tags.Number, token.text);
      break;
    case TOK.Shebang:
      print.format(tags.Shebang, xml_escape(token.text));
      break;
    case TOK.HashLine:
      // The text to be inserted into formatStr.
      char[] lineText;

      void printWS(char* start, char* end)
      {
        if (start != end) lineText ~= start[0 .. end - start];
      }

      auto num = token.tokLineNum;
      if (num is null) // Malformed #line
        lineText = token.text;
      else
      {
        // Print whitespace between #line and number.
        printWS(token.start, num.start); // Prints "#line" as well.
        lineText ~= Format(tags.Number, num.text); // Print the number.

        if (auto filespec = token.tokLineFilespec)
        { // Print whitespace between number and filespec.
          printWS(num.end, filespec.start);
          lineText ~= Format(tags.Filespec, xml_escape(filespec.text));
        }
      }
      // Finally print the whole token.
      print.format(tags.HLine, lineText);
      break;
    case TOK.Illegal:
      print.format(tags.Illegal, token.text());
      break;
    case TOK.Newline:
      print.format(tags.Newline, token.text());
      break;
    case TOK.EOF:
      print(tags.EOF);
      break;
    default:
      if (token.isKeyword())
        print.format(tags.Keyword, token.text);
      else if (token.isSpecialToken)
        print.format(tags.SpecialToken, token.text);
      else
        print(tags[token.kind]);
    }
  }
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

/// Maps tokens to (format) strings.
class TagMap
{
  string[string] table;
  string[TOK.MAX] tokenTable;

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

    foreach (i, tokStr; tokToString)
      if (auto pStr = tokStr in this.table)
        tokenTable[i] = *pStr;
  }

  /// Returns the value for str, or 'fallback' if str is not in the table.
  string opIndex(string str, string fallback = "")
  {
    auto p = str in table;
    if (p)
      return *p;
    return fallback;
  }

  /// Returns the value for tok in O(1) time.
  string opIndex(TOK tok)
  {
    return tokenTable[tok];
  }

  /// Shortcuts for quick access.
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

/// Returns the short class name of a class descending from Node.$(BR)
/// E.g.: dil.ast.Declarations.ClassDeclaration -> Class
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
    assert(p, t.text~" is not in tokenTable");
    return *p;
  }

  // Override dispatch function.
  override Node dispatch(Node n)
  { assert(n !is null);
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
