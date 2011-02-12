/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.doc.Doc;

import dil.doc.Parser;
import dil.ast.Node;
import dil.lexer.Funcs;
import dil.Unicode;
import common;

import tango.text.Ascii : icompare;

alias dil.doc.Parser.IdentValueParser.textBody textBody;

/// Represents a sanitized and parsed DDoc comment.
class DDocComment
{
  Section[] sections; /// The sections of this comment.
  Section summary; /// Optional summary section.
  Section description; /// Optional description section.

  /// Constructs a DDocComment object.
  this(Section[] sections, Section summary, Section description)
  {
    this.sections = sections;
    this.summary = summary;
    this.description = description;
  }

  /// Removes the first copyright section and returns it.
  Section takeCopyright()
  {
    foreach (i, section; sections)
      if (section.Is("copyright"))
      {
        sections = sections[0..i] ~ sections[i+1..$];
        return section;
      }
    return null;
  }

  /// Returns true if "ditto" is the only text in this comment.
  bool isDitto()
  {
    return summary && sections.length == 1 &&
           icompare(summary.text, "ditto") == 0;
  }

  /// Returns true when this comment has no text.
  bool isEmpty()
  {
    return sections.length == 0 || sections[0].text.length == 0;
  }
}

/// A namespace for some utility functions.
struct DDocUtils
{
static:
  /// Returns a node's DDocComment.
  DDocComment getDDocComment(Node node)
  {
    DDocParser p;
    auto docTokens = getDocTokens(node);
    if (!docTokens.length)
      return null;
    p.parse(getDDocText(docTokens));
    return new DDocComment(p.sections, p.summary, p.description);
  }

  /// Returns a DDocComment created from a text.
  DDocComment getDDocComment(string text)
  {
    text = sanitize(text, '\0'); // May be unnecessary.
    DDocParser p;
    p.parse(text);
    return new DDocComment(p.sections, p.summary, p.description);
  }

  /// Returns true if token is a Doxygen comment.
  bool isDoxygenComment(Token* token)
  { // Doxygen: '/+!' '/*!' '//!'
    return token.kind == TOK.Comment && token.start[2] == '!';
  }

  /// Returns true if token is a DDoc comment.
  bool isDDocComment(Token* token)
  { // DDOC: '/++' '/**' '///'
    return token.kind == TOK.Comment && token.start[1] == token.start[2];
  }

  /// Returns the surrounding documentation comment tokens.
  /// Params:
  ///   node = the node to find doc comments for.
  ///   isDocComment = a function predicate that checks for doc comment tokens.
  /// Note: this function works correctly only if
  ///       the source text is syntactically correct.
  Token*[] getDocTokens(Node node, bool function(Token*) isDocComment = &isDDocComment)
  {
    Token*[] comments;
    auto isEnumMember = node.kind == NodeKind.EnumMemberDecl;
    // Get preceding comments.
    auto token = node.begin;
    // Scan backwards until we hit another declaration.
  Loop:
    for (; token; token = token.prev)
    {
      if (token.kind == TOK.LBrace ||
          token.kind == TOK.RBrace ||
          token.kind == TOK.Semicolon ||
          /+token.kind == TOK.HEAD ||+/
          (isEnumMember && token.kind == TOK.Comma))
        break;

      if (token.kind == TOK.Comment)
      { // Check that this comment doesn't belong to the previous declaration.
        switch (token.prev.kind)
        {
        case TOK.Semicolon, TOK.RBrace, TOK.Comma:
          break Loop;
        default:
          if (isDocComment(token))
            comments = [token] ~ comments;
        }
      }
    }
    // Get single comment to the right.
    token = node.end.next;
    if (token.kind == TOK.Comment && isDocComment(token))
      comments ~= token;
    else if (isEnumMember)
    {
      token = node.end.nextNWS;
      if (token.kind == TOK.Comma)
      {
        token = token.next;
        if (token.kind == TOK.Comment && isDocComment(token))
          comments ~= token;
      }
    }
    return comments;
  }

  bool isLineComment(Token* t)
  {
    assert(t.kind == TOK.Comment);
    return t.start[1] == '/';
  }

  /// Extracts the text body of the comment tokens.
  string getDDocText(Token*[] tokens)
  {
    if (tokens.length == 0)
      return null;
    string result;
    foreach (token; tokens)
    { // Determine how many characters to slice off from the end of the comment.
      // 0 for "//", 2 for "+/" and "*/".
      auto n = isLineComment(token) ? 0 : 2;
      result ~= sanitize(token.text[3 .. $-n], token.start[1]);
      assert(token.next);
      result ~= (token.next.kind == TOK.Newline) ? '\n' : ' ';
    }
    return result[0..$-1]; // Slice off last '\n' or ' '.
  }

  /// Sanitizes a DDoc comment string.
  ///
  /// Leading padding characters are removed from the lines.
  /// The various newline types are converted to '\n'.
  /// Params:
  ///   comment = the string to be sanitized.
  ///   padding = '/', '+' or '*'
  string sanitize(string comment, char padding)
  {
    bool isNewline = true; // True when at the beginning of a new line.
    char* p = comment.ptr; // Reader.
    char* q = p; // Writer.
    char* end = p + comment.length;

    while (p < end)
    {
      if (isNewline)
      { // Ignore padding at the beginning of each new line.
        isNewline = false;
        auto begin = p;
        while (p < end && isspace(*p)) // Skip spaces.
          p++;
        if (p < end && *p == padding)
          while (++p < end && *p == padding) // Skip padding.
          {}
        else
          p = begin; // Reset. No padding found.
      }
      else
      {
        isNewline = scanNewline(p, end);
        if (isNewline)
          *q++ = '\n'; // Copy newlines as '\n'.
        else
          *q++ = *p++; // Copy character.
      }
    }
    comment.length = q - comment.ptr; // Adjust length.
    if (!comment.length)
      return null;
    // Lastly, strip trailing padding.
    p = q - 1; // q points to the end of the string.
    q = comment.ptr - 1; // Now let q point to the start.
    while (p > q && *p == padding)
      p--; // Go back until no padding characters are left.
    assert(p == q || p >= comment.ptr);
    comment.length = p - comment.ptr + 1;
    return comment;
  }

  /// Unindents all lines in text by the maximum amount possible.
  /// Note: counts tabulators the same as single spaces.
  /// Returns: the unindented text or the original text.
  char[] unindentText(char[] text)
  {
    char* p = text.ptr, end = p + text.length;
    uint indent = uint.max; // Start with the largest number.
    char* lbegin = p; // The beginning of a line.
    // First determine the maximum amount we may remove.
    while (p < end)
    {
      while (p < end && isspace(*p)) // Skip leading whitespace.
        p++;
      if (p < end && *p != '\n') // Don't count blank lines.
        if (p - lbegin < indent)
        {
          indent = p - lbegin;
          if (indent == 0)
            return text; // Nothing to unindent;
        }
      // Skip to the end of the line.
      while (p < end && *p != '\n')
        p++;
      while (p < end && *p == '\n')
        p++;
      lbegin = p;
    }

    p = text.ptr, end = p + text.length;
    lbegin = p;
    char* q = p; // Writer.
    // Remove the determined amount.
    while (p < end)
    {
      while (p < end && isspace(*p)) // Skip leading whitespace.
        *q++ = *p++;
      if (p < end && *p == '\n') // Strip empty lines.
        q -= p - lbegin; // Back up q by the amount of spaces on this line.
      else {//if (indent <= p - lbegin)
        assert(indent <= p - lbegin);
        q -= indent; // Back up q by the indent amount.
      }
      // Skip to the end of the line.
      while (p < end && *p != '\n')
        *q++ = *p++;
      while (p < end && *p == '\n')
        *q++ = *p++;
      lbegin = p;
    }
    text.length = q - text.ptr;
    return text;
  }
}

/// Parses a DDoc comment string.
struct DDocParser
{
  char* p; /// Current character pointer.
  char* textEnd; /// Points one character past the end of the text.
  Section[] sections; /// Parsed sections.
  Section summary; /// Optional summary section.
  Section description; /// Optional description section.

  /// Parses the DDoc text into sections.
  /// All newlines in the text must be converted to '\n'.
  Section[] parse(string text)
  {
    if (!text.length)
      return null;
    p = text.ptr;
    textEnd = p + text.length;

    char* summaryBegin;
    string ident, nextIdent;
    char* bodyBegin, nextBodyBegin;

    while (p < textEnd && (isspace(*p) || *p == '\n'))
      p++;
    summaryBegin = p;

    if (findNextIdColon(ident, bodyBegin))
    { // Check if there's text before the explicit section.
      if (summaryBegin != ident.ptr)
        scanSummaryAndDescription(summaryBegin, ident.ptr);
    }
    else // There are no explicit sections.
    {
      scanSummaryAndDescription(summaryBegin, textEnd);
      return sections;
    }

    assert(ident.length);
    // Continue parsing.
    while (findNextIdColon(nextIdent, nextBodyBegin))
    {
      sections ~= new Section(ident, textBody(bodyBegin, nextIdent.ptr));
      ident = nextIdent;
      bodyBegin = nextBodyBegin;
    }
    // Add last section.
    sections ~= new Section(ident, textBody(bodyBegin, textEnd));
    return sections;
  }

  /// Separates the text between p and end
  /// into a summary and an optional description section.
  void scanSummaryAndDescription(char* p, char* end)
  {
    assert(p <= end);
    char* sectionBegin = p;
    // Search for the end of the first paragraph.
    while (p < end && !(*p == '\n' && p+1 < end && p[1] == '\n'))
      if (skipCodeSection(p, end) == false)
        p++;
    assert(p == end || (*p == '\n' && p[1] == '\n'));
    // The first paragraph is the summary.
    summary = new Section("", textBody(sectionBegin, p));
    sections ~= summary;
    // The rest is the description section.
    if (auto descText = textBody(p, end))
      sections ~= (description = new Section("", descText));
    assert(description ? description.text !is null : true);
  }

  /// Returns true if p points to "$(DDD)".
  static bool isCodeSection(char* p, char* end)
  {
    return p < end && *p == '-' && p+2 < end && p[1] == '-' && p[2] == '-';
  }

  /// Skips over a code section and sets p one character past it.
  ///
  /// Note: apparently DMD doesn't skip over code sections when
  /// parsing DDoc sections. However, from experience it seems
  /// to be a good idea to do that.
  /// Returns: true if a code section was skipped.
  static bool skipCodeSection(ref char* p, char* end)
  {
    if (!isCodeSection(p, end))
      return false;
    p += 3; // Skip "---".
    while (p < end && *p == '-')
      p++;
    while (p < end && !(*p == '-' && p+2 < end && p[1] == '-' && p[2] == '-'))
      p++;
    while (p < end && *p == '-')
      p++;
    assert(p is end || p[-1] == '-');
    return true;
  }

  /// Find next "Identifier:".
  /// Params:
  ///   ident = set to the Identifier.
  ///   bodyBegin = set to the beginning of the text body (whitespace skipped.)
  /// Returns: true if found.
  bool findNextIdColon(ref char[] ident, ref char* bodyBegin)
  {
    while (p < textEnd)
    {
      skipWhitespace();
      if (p is textEnd)
        break;
      if (skipCodeSection(p, textEnd))
        continue;
      assert(p < textEnd && (isascii(*p) || isLeadByte(*p)));
      ident = scanIdentifier(p, textEnd);
      if (ident && p < textEnd && *p == ':')
        if (!(++p < textEnd && *p == '/')) // Ignore links: http:// ftp:// etc.
        {
          bodyBegin = p;
          skipLine();
          return true;
        }
      skipLine();
    }
    assert(p is textEnd);
    return false;
  }

  /// Skips $(SYMLINK3 dil.lexer.Funcs, CProperty.Whitespace, whitespace).
  void skipWhitespace()
  {
    while (p < textEnd && isspace(*p))
      p++;
  }

  /// Skips to the beginning of the next non-blank line.
  void skipLine()
  {
    while (p < textEnd && *p != '\n')
      p++;
    while (p < textEnd && *p == '\n')
      p++;
  }
}

/// Represents a DDoc section.
class Section
{
  string name; /// The name of the section.
  string text; /// The text of the section.
  /// Constructs a Section object.
  this(string name, string text)
  {
    this.name = name;
    this.text = text;
  }

  /// Case-insensitively compares the section's name with name2.
  bool Is(char[] name2)
  {
    return icompare(name, name2) == 0;
  }

  /// Returns the section's text including its name.
  char[] wholeText()
  {
    if (name.length == 0)
      return text;
    return String(name.ptr, text.ptr+text.length);
  }
}

/// Represents a params section.
class ParamsSection : Section
{
  string[] paramNames; /// Parameter names.
  string[] paramDescs; /// Parameter descriptions.
  /// Constructs a ParamsSection object.
  this(string name, string text)
  {
    super(name, text);
    IdentValueParser parser;
    auto idvalues = parser.parse(text);
    this.paramNames = new string[idvalues.length];
    this.paramDescs = new string[idvalues.length];
    foreach (i, idvalue; idvalues)
    {
      this.paramNames[i] = idvalue.ident;
      this.paramDescs[i] = idvalue.value;
    }
  }
}

/// Represents a macros section.
class MacrosSection : Section
{
  string[] macroNames; /// Macro names.
  string[] macroTexts; /// Macro texts.
  /// Constructs a MacrosSection object.
  this(string name, string text)
  {
    super(name, text);
    IdentValueParser parser;
    auto idvalues = parser.parse(text);
    this.macroNames = new string[idvalues.length];
    this.macroTexts = new string[idvalues.length];
    foreach (i, idvalue; idvalues)
    {
      this.macroNames[i] = idvalue.ident;
      this.macroTexts[i] = idvalue.value;
    }
  }
}
