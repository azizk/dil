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
import dil.lexer.Lexer,
       dil.lexer.Funcs;
import dil.parser.Parser;
import dil.semantic.Module;
import dil.Compilation;
import dil.SourceText;
import util.Path;
import common;

import tango.io.device.Array;

/// A token and syntax highlighter.
class Highlighter
{
  TagMap tags; /// Which tag map to use.
  /// Used to print formatted strings. Can be a file, stdout or a buffer.
  FormatOut print;
  CompilationContext cc; /// The compilation context.

  /// Constructs a TokenHighlighter object.
  this(TagMap tags, FormatOut print, CompilationContext cc)
  {
    this.tags = tags;
    this.print = print;
    this.cc = cc;
  }

  /// Highlights tokens in a string.
  /// Returns: A string with the highlighted tokens.
  string highlightTokens(string text, string filePath, ref uint lines)
  {
    auto src = new SourceText(filePath, text);
    auto lx = new Lexer(src, cc.tables.lxtables, cc.diag);
    lx.scanAll();
    lines = lx.lineNum;
    return highlightTokens(lx.firstToken(), lx.tail);
  }

  /// Highlights the tokens from begin to end (both included).
  /// Returns: A string with the highlighted tokens.
  /// Params:
  ///   skipWS = Skips whitespace tokens (e.g. comments) if true.
  string highlightTokens(Token* begin, Token* end, bool skipWS = false)
  {
    scope buffer = new Array(512, 512); // Allocate 512B, grow by 512B.
    auto print_saved = this.print; // Save;
    auto print = this.print = new FormatOut(Format, buffer);

    // Traverse linked list and print tokens.
    for (auto token = begin; token; token = token.next)
    {
      if (skipWS && token.isWhitespace())
        continue;
      token.ws && print(token.wsChars); // Print preceding whitespace.
      printToken(token);
      if (token is end)
        break;
    }

    this.print = print_saved; // Restore.
    return cast(char[])buffer.slice().dup; // Return a copy.
  }

  /// Highlights all tokens of a source file.
  void highlightTokens(string filePath, bool opt_printLines)
  {
    auto src = new SourceText(filePath, true);
    auto lx = new Lexer(src, cc.tables.lxtables, cc.diag);
    lx.scanAll();

    print.format(tags["DocHead"], Path(filePath).name());
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
    auto modul = new Module(filePath, cc);
    if (!modul.isDDocFile)
      modul.parse();
    highlightSyntax(modul, printHTML, opt_printLines);
  }

  /// ditto
  void highlightSyntax(Module modul, bool printHTML, bool opt_printLines)
  {
    if (modul.isDDocFile)
    {
      print.format(tags["DocHead"], modul.getFQN());

      auto text = modul.sourceText.text;

      if (opt_printLines)
      {
        size_t lineCount;
        foreach (dchar c; text)
        {
          if (c == '\n')
            ++lineCount;
        }

        print(tags["LineNumberBegin"]);
        printLines(lineCount);
        print(tags["LineNumberEnd"]);
      }

      print(tags["SourceBegin"]);
      print(text);
      print(tags["SourceEnd"]);
      print(tags["DocEnd"]);
      return;
    }

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

  /// Prints a token to the stream 'print'.
  void printToken(Token* token)
  {
    switch (token.kind)
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
      auto text = token.text;
      assert(text.length);
      if (text.length > 1 && text[0] == 'q' && text[1] == '{')
      {
      version(D2)
      {
        scope buffer = new Array(128, 128);
        auto print_saved = this.print; // Save;
        auto print = this.print = new FormatOut(Format, buffer);
        print("q{");
        // Traverse linked list and print tokens.
        for (auto t = token.strval.tok_str; t; t = t.next)
        {
          t.ws && print(t.wsChars); // Print preceding whitespace.
          printToken(t);
        }
        auto postfix = token.strval.pf;
        if (postfix != 0)
          print(postfix); // Postfix character.
        this.print = print_saved; // Restore.
        text = cast(char[])buffer.slice().dup; // Take a copy.
      }
      }
      else
        text = (text[0] == '"') ?
          scanEscapeSequences(text, tags.Escape) :
          xml_escape(text);
      print.format(tags.String, text);
      break;
    case TOK.Character:
      auto text = token.text;
      text = (text.length > 1 && text[1] == '\\') ?
        scanEscapeSequences(text, tags.Escape) :
        xml_escape(text);
      print.format(tags.Char, text);
      break;
    case TOK.Int32, TOK.Int64, TOK.UInt32, TOK.UInt64,
         TOK.Float32, TOK.Float64, TOK.Float80,
         TOK.IFloat32, TOK.IFloat64, TOK.IFloat80:
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

      auto num = token.hlval.lineNum;
      if (num is null) // Malformed #line
        lineText = token.text;
      else
      {
        // Print whitespace between #line and number.
        printWS(token.start, num.start); // Prints "#line" as well.
        lineText ~= Format(tags.Number, num.text); // Print the number.

        if (auto filespec = token.hlval.filespec)
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

  /// Highlights escape sequences inside a text. Also escapes XML characters.
  /// Params:
  ///   text = The text to search in.
  ///   fmt  = The format string passed to the function Format().
  static char[] scanEscapeSequences(char[] text, char[] fmt)
  {
    char* p = text.ptr, end = p + text.length;
    char* prev = p;
    char[] result, escape_str;

    while (p < end)
    {
      char[] xml_entity = void;
      switch (*p)
      {
      case '\\': break; // Found beginning of an escape sequence.
      // Code to escape XML chars:
      case '<': xml_entity = "&lt;";  goto Lxml;
      case '>': xml_entity = "&gt;";  goto Lxml;
      case '&': xml_entity = "&amp;"; goto Lxml;
      Lxml:
        if (prev < p) result ~= String(prev, p); // Append previous string.
        result ~= xml_entity; // Append entity.
        prev = ++p;
        continue; // End of "XML" code.
      default:
        p++;
        continue; // Nothing to escape. Continue.
      }

      auto escape_str_begin = p;
      assert(*p == '\\');
      p++;
      if (p >= end)
        break;

      uint digits = void;
      switch (*p)
      {
      case 'x':
        digits = 2+1;
      case_Unicode:
        assert(digits == 2+1 || digits == 4+1 || digits == 8+1);
        if (p+digits >= end)
          p++; // Broken sequence. Only skip the letter.
        else // +1 was added everywhere else, so that the digits are skipped.
          p += digits;
        break;
      case 'u': digits = 4+1; goto case_Unicode;
      case 'U': digits = 8+1; goto case_Unicode;
      default:
        if (char2ev(*p)) // Table lookup.
          p++;
        else if (isoctal(*p))
        {
          if (++p < end && isoctal(*p))
            if (++p < end && isoctal(*p))
              p++;
        }
        else if (*p == '&')
        { // Skip to ";". Assume valid sequence.
          auto entity_name_begin = p+1;
          while (++p < end && isalnum(*p))
          {}
          if (p < end && *p == ';')
            p++; // Skip ';'.
          escape_str = "\\&amp;" ~ String(entity_name_begin, p);
          goto Lescape_str_assigned;
        }
        // else
          // continue; // Broken escape sequence.
      }

      escape_str = String(escape_str_begin, p);
    Lescape_str_assigned:
      if (prev < p) // Append previous string.
        result ~= String(prev, escape_str_begin);
      result ~= Format(fmt, escape_str); // Finally format the escape sequence.
      prev = p; // Update prev pointer.
    }
    assert(p <= end && prev <= end);

    if (prev is text.ptr)
      return text; // Nothing escaped. Return original, unchanged text.
    if (prev < end)
      result ~= String(prev, end);
    return result;
  }
}

/// Escapes '<', '>' and '&' with named HTML entities.
/// Returns: The escaped text, or the original if no entities were found.
char[] xml_escape(char[] text)
{
  char* p = text.ptr, end = p + text.length;
  char* prev = p; // Points to the end of the previous escape char.
  char[] entity; // Current entity to be appended.
  char[] result;
  while (p < end)
    switch (*p)
    {
    case '<': entity = "&lt;";  goto Lcommon;
    case '>': entity = "&gt;";  goto Lcommon;
    case '&': entity = "&amp;"; goto Lcommon;
    Lcommon:
      prev != p && (result ~= String(prev, p)); // Append previous string.
      result ~= entity; // Append entity.
      p++; // Skip '<', '>' or '&'.
      prev = p;
      break;
    default:
      p++;
    }
  if (prev is text.ptr)
    return text; // Nothing escaped. Return original, unchanged text.
  if (prev < end)
    result ~= String(prev, end);
  return result;
}

/// Maps tokens to (format) strings.
class TagMap
{
  string[hash_t] table;
  string[TOK.MAX] tokenTable;

  this(string[hash_t] table)
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
    Escape       = this["Escape", "{0}"];
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
      if (auto pStr = hashOf(tokStr) in this.table)
        tokenTable[i] = *pStr;
  }

  /// Returns the value for str, or 'fallback' if str is not in the table.
  string opIndex(string str, string fallback = "")
  {
    if (auto p = hashOf(str) in table)
      return *p;
    return fallback;
  }

  /// Returns the value for tok in O(1) time.
  string opIndex(TOK tok)
  {
    return tokenTable[tok];
  }

  /// Assigns str to tokenTable[tok].
  void opIndexAssign(string str, TOK tok)
  {
    tokenTable[tok] = str;
  }

  /// Shortcuts for quick access.
  string Identifier, String, Char, Number, Keyword, LineC, BlockC, Escape,
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
  foreach_reverse (i, c; subject)
    if (c == object)
      return i;
  return -1;
}

/// Returns the short class name of a class descending from Node.$(BR)
/// E.g.: dil.ast.Declarations.ClassDecl -> Class
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
    suffixLength = "Decl".length;
    break;
  case NC.Statement:
    suffixLength = "Stmt".length;
    break;
  case NC.Expression:
    suffixLength = "Expr".length;
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
