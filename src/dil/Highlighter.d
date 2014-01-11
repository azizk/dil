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
import dil.String,
       dil.Array;
import util.Path;
import common;

/// A token and syntax highlighter.
class Highlighter
{
  TagMap tags; /// Which tag map to use.
  CharArray buffer; /// Buffer that receives the text.
  CompilationContext cc; /// The compilation context.

  /// Constructs a TokenHighlighter object.
  this(TagMap tags, CompilationContext cc)
  {
    this.tags = tags;
    this.cc = cc;
  }

  /// Empties the buffer and returns its contents.
  char[] takeText()
  {
    return buffer.take();
  }

  /// Writes arguments formatted to the buffer.
  void printf(cstring format, ...)
  {
    buffer ~= Format(_arguments, _argptr, format);
  }

  /// Writes s to the buffer.
  void print(cstring s)
  {
    buffer ~= s;
  }

  /// Writes c to the buffer.
  void print(char c)
  {
    buffer ~= c;
  }

  /// Highlights tokens in a string.
  /// Returns: A string with the highlighted tokens.
  cstring highlightTokens(cstring text, cstring filePath, out uint lines)
  {
    auto src = new SourceText(filePath, text);
    auto lx = new Lexer(src, cc.tables.lxtables, cc.diag);
    lx.scanAll();
    lines = lx.lineNum;
    highlightTokens(lx.tokenList);
    return takeText();
  }

  /// Highlights the tokens from begin to end (both included).
  /// Returns: A string with the highlighted tokens.
  /// Params:
  ///   skipWS = Skips whitespace tokens (e.g. comments) if true.
  void highlightTokens(Token[] tokens, bool skipWS = false)
  {
    // Traverse linked list and print tokens.
    foreach (token; tokens)
    {
      if (skipWS && token.isWhitespace)
        continue;
      token.ws && print(token.wsChars); // Print preceding whitespace.
      printToken(&token);
    }
  }

  /// ditto
  void highlightTokens(ref CharArray buffer, Token[] tokens,
    bool skipWS = false)
  {
    auto buffer_saved = this.buffer;
    this.buffer = buffer;
    highlightTokens(tokens, skipWS);
    buffer = this.buffer; // Update callers instance.
    this.buffer = buffer_saved;
  }

  /// Highlights all tokens of a source file.
  void highlightTokens(cstring filePath, bool opt_printLines)
  {
    auto src = new SourceText(filePath, true);
    auto lx = new Lexer(src, cc.tables.lxtables, cc.diag);
    lx.scanAll();

    printf(tags["DocHead"], Path(filePath).name());
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
    foreach (token; lx.tokenList) {
      token.ws && print(token.wsChars); // Print preceding whitespace.
      printToken(&token);
    }
    print(tags["SourceEnd"]);
    print(tags["DocEnd"]);
  }

  /// Highlights the syntax in a source file.
  void highlightSyntax(cstring filePath, bool printHTML, bool opt_printLines)
  {
    auto modul = new Module(filePath, cc);
    modul.parse();
    highlightSyntax(modul, printHTML, opt_printLines);
  }

  /// ditto
  void highlightSyntax(Module modul, bool printHTML, bool opt_printLines)
  {
    auto parser = modul.parser;
    auto lx = parser.lexer;
    auto tokens = lx.tokenList;
    auto tokenExList = new TokenExBuilder().build(modul.root, tokens);

    printf(tags["DocHead"], modul.getFQN());
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
    foreach (i, ref tokenEx; tokenExList)
    {
      auto token = &tokens[i];
      token.ws && print(token.wsChars); // Print preceding whitespace.
      if (token.isWhitespace) {
        printToken(token);
        continue;
      }
      // <node>
      foreach (node; tokenEx.beginNodes)
        printf(tagNodeBegin, tags.getTag(node.kind),
          node.getShortClassName());
      // Token text.
      printToken(token);
      // </node>
      if (printHTML)
        foreach_reverse (node; tokenEx.endNodes)
          print(tagNodeEnd);
      else
        foreach_reverse (node; tokenEx.endNodes)
          printf(tagNodeEnd, tags.getTag(node.kind));
    }
    print(tags["SourceEnd"]);
    print(tags["DocEnd"]);
  }

  void printErrors(Lexer lx)
  {
    foreach (e; lx.errors)
      printf(tags["LexerError"], e.filePath,
                   e.loc, e.col, xml_escape(e.getMsg));
  }

  void printErrors(Parser parser)
  {
    foreach (e; parser.errors)
      printf(tags["ParserError"], e.filePath,
                   e.loc, e.col, xml_escape(e.getMsg));
  }

  void printLines(uint lines)
  {
    auto lineNumberFormat = tags["LineNumber"];
    for (auto lineNum = 1; lineNum <= lines; lineNum++)
      printf(lineNumberFormat, lineNum);
  }

  /// Prints a token to the stream 'print'.
  void printToken(Token* token)
  {
    switch (token.kind)
    {
    case TOK.Identifier:
      printf(tags.Identifier, token.text);
      break;
    case TOK.Comment:
      cstring formatStr;
      switch (token.start[1])
      {
      case '/': formatStr = tags.LineC; break;
      case '*': formatStr = tags.BlockC; break;
      case '+': formatStr = tags.NestedC; break;
      default: assert(0);
      }
      printf(formatStr, xml_escape(token.text));
      break;
    case TOK.String:
      cstring text = token.text;
      assert(text.length);
      if (text.length > 1 && text[0] == 'q' && text[1] == '{')
      {
      version(D2)
      {
        auto buffer_saved = this.buffer; // Save;
        this.buffer = CharArray(text.length);
        print("q{");
        // Traverse and print inner tokens.
        Token* last; // Remember last token.
        for (auto t = token.strval.tokens; t.kind; t++)
        {
          t.ws && print(t.wsChars); // Print preceding whitespace.
          printToken(t);
          last = t;
        }
        if (last) // Print: Whitespace? "}" Postfix?
          print(slice(last.end, token.end));
        text = takeText();
        this.buffer = buffer_saved; // Restore
      }
      }
      else
        text = (text[0] == '"') ?
          scanEscapeSequences(text, tags.Escape) :
          xml_escape(text);
      printf(tags.String, text);
      break;
    case TOK.Character:
      cstring text = token.text;
      text = (text.length > 1 && text[1] == '\\') ?
        scanEscapeSequences(text, tags.Escape) :
        xml_escape(text);
      printf(tags.Char, text);
      break;
    case TOK.Int32, TOK.Int64, TOK.UInt32, TOK.UInt64,
         TOK.Float32, TOK.Float64, TOK.Float80,
         TOK.IFloat32, TOK.IFloat64, TOK.IFloat80:
      printf(tags.Number, token.text);
      break;
    case TOK.Shebang:
      printf(tags.Shebang, xml_escape(token.text));
      break;
    case TOK.HashLine:
      // The text to be inserted into formatStr.
      char[] lineText;

      void printWS(cchar* start, cchar* end)
      {
        if (start != end) lineText ~= start[0 .. end - start];
      }

      auto num = token.hlval.lineNum;
      if (num is null) // Malformed #line
        lineText = token.text.dup;
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
      printf(tags.HLine, lineText);
      break;
    case TOK.Illegal:
      printf(tags.Illegal, token.text);
      break;
    case TOK.Newline:
      printf(tags.Newline, token.text);
      break;
    case TOK.EOF:
      print(tags.EOF);
      break;
    default:
      if (token.isKeyword())
        printf(tags.Keyword, token.text);
      else if (token.isSpecialToken)
        printf(tags.SpecialToken, token.text);
      else
        print(tags[token.kind]);
    }
  }

  /// Highlights escape sequences inside a text. Also escapes XML characters.
  /// Params:
  ///   text = The text to search in.
  ///   fmt  = The format string passed to the function Format().
  static cstring scanEscapeSequences(cstring text, cstring fmt)
  {
    auto p = text.ptr, end = p + text.length;
    auto prev = p; // Remembers the end of the previous escape sequence.
    CharArray result;
    cstring escape_str;

    while (p < end)
    {
      string xml_entity = void;
      switch (*p)
      {
      case '\\': break; // Found beginning of an escape sequence.
      // Code to escape XML chars:
      case '<': xml_entity = "&lt;";  goto Lxml;
      case '>': xml_entity = "&gt;";  goto Lxml;
      case '&': xml_entity = "&amp;"; goto Lxml;
      Lxml:
        if (prev < p) result ~= slice(prev, p); // Append previous string.
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
          escape_str = "\\&amp;" ~ slice(entity_name_begin, p);
          goto Lescape_str_assigned;
        }
        // else
          // continue; // Broken escape sequence.
      }

      escape_str = slice(escape_str_begin, p);
    Lescape_str_assigned:
      if (prev < p) // Append previous string.
        result ~= slice(prev, escape_str_begin);
      result ~= Format(fmt, escape_str); // Finally format the escape sequence.
      prev = p; // Update prev pointer.
    }
    assert(p <= end && prev <= end);

    if (prev is text.ptr)
      return text; // Nothing escaped. Return original, unchanged text.
    if (prev < end)
      result ~= slice(prev, end);
    return result[];
  }
}

/// Escapes '<', '>' and '&' with named HTML entities.
/// Returns: The escaped text, or the original if no entities were found.
cstring xml_escape(cstring text)
{
  auto p = text.ptr, end = p + text.length;
  auto prev = p; // Points to the end of the previous escape char.
  string entity; // Current entity to be appended.
  CharArray result;
  while (p < end)
    switch (*p)
    {
    case '<': entity = "&lt;";  goto Lcommon;
    case '>': entity = "&gt;";  goto Lcommon;
    case '&': entity = "&amp;"; goto Lcommon;
    Lcommon:
      if (!result.ptr)
        result.cap = text.length;
      prev != p && (result ~= slice(prev, p)); // Append previous string.
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
    result ~= slice(prev, end);
  return result[];
}

/// Maps tokens to (format) strings.
class TagMap
{
  cstring[hash_t] table;
  cstring[TOK.MAX] tokenTable;

  this(cstring[hash_t] table)
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
  cstring opIndex(cstring str, cstring fallback = "")
  {
    if (auto p = hashOf(str) in table)
      return *p;
    return fallback;
  }

  /// Returns the value for tok in O(1) time.
  cstring opIndex(TOK tok)
  {
    return tokenTable[tok];
  }

  /// Assigns str to tokenTable[tok].
  void opIndexAssign(cstring str, TOK tok)
  {
    tokenTable[tok] = str;
  }

  /// Shortcuts for quick access.
  cstring Identifier, String, Char, Number, Keyword, LineC, BlockC, Escape,
         NestedC, Shebang, HLine, Filespec, Illegal, Newline, SpecialToken,
         Declaration, Statement, Expression, Type, Other, EOF;

  /// Returns the tag for the category 'k'.
  cstring getTag(NodeKind k)
  {
    cstring tag;
    if (k.isDeclaration)
      tag = Declaration;
    else if (k.isStatement)
      tag = Statement;
    else if (k.isExpression)
      tag = Expression;
    else if (k.isType)
      tag = Type;
    else if (k.isParameter)
      tag = Other;
    return tag;
  }
}

/// Returns the short class name of a class descending from Node.$(BR)
/// E.g.: dil.ast.Declarations.ClassDecl -> Class
string getShortClassName(Node node)
{
  static string[] name_table;
  if (name_table is null)
    name_table = new string[NodeKind.max+1]; // Create a new table.
  // Look up in table.
  auto pname = &name_table[node.kind];
  if (!pname.ptr)
  { // Get fully qualified name of the class and extract just the name.
    auto name = IString(typeid(node).name).rpartition('.')[1];
    // Decl, Stmt, Expr, Type have length 4.
    size_t suffixLength = node.isParameter ? 0 : 4;
    // Remove common suffix and store.
    *pname = name[0..Neg(suffixLength)][];
  }
  return *pname;
}

/// Extended token structure.
struct TokenEx
{
  //Token* token; /// The lexer token.
  Node[] beginNodes; /// beginNodes[n].begin == token
  Node[] endNodes; /// endNodes[n].end == token
}

/// Builds an array of TokenEx items.
class TokenExBuilder : DefaultVisitor
{
  TokenEx[] tokenExs; /// Extended tokens.
  Token[] tokens; /// Original tokens.

  TokenEx[] build(Node root, Token[] tokens)
  { // Creat the exact number of TokenEx instances.
    this.tokens = tokens;
    tokenExs = new TokenEx[tokens.length];
    super.visitN(root);
    return tokenExs;
  }

  TokenEx* getTokenEx(Token* t)
  {
    assert(tokens.ptr <= t && t < tokens.ptr+tokens.length);
    return &tokenExs[t - tokens.ptr];
  }

  /// Override dispatch function.
  override Node dispatch(Node n)
  {
    assert(n && n.begin && n.end);
    getTokenEx(n.begin).beginNodes ~= n;
    getTokenEx(n.end).endNodes ~= n;
    return super.dispatch(n);
  }
}
