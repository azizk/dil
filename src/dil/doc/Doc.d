/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.doc.Doc;

import dil.doc.Parser;
import dil.ast.Node;
import dil.lexer.Funcs;
import dil.Unicode,
       dil.String;
import common;

alias textBody = dil.doc.Parser.IdentValueParser.textBody;

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
           String(summary.text).ieql("ditto");
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
  DDocComment getDDocComment(cstring text)
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
  { // Ddoc: '/++' '/**' '///'
    return token.kind == TOK.Comment && token.start[1] == token.start[2] &&
      // Exclude special cases: '/++/' and '/**/'
      (isLineComment(token) ? 1 : token.text.length > 4);
  }

  /// Returns the surrounding documentation comment tokens.
  /// Params:
  ///   node = The node to find doc comments for.
  ///   isDocComment = A function predicate that checks for doc comment tokens.
  /// Note: This function works correctly only if
  ///       the source text is syntactically correct.
  Token*[] getDocTokens(Node node,
    bool function(Token*) isDocComment = &isDDocComment)
  {
    Token*[] comments;
    auto isEnumMember = node.kind == NodeKind.EnumMemberDecl;
    // Get preceding comments.
    auto token = node.begin;
    // Scan backwards until we hit another declaration.
    while ((--token).kind)
      if (token.kind.In(TOK.LBrace, TOK.RBrace, TOK.Semicolon) ||
          (isEnumMember && token.kind == TOK.Comma))
        break;
      else if (token.kind == TOK.Comment)
        // Check that this comment doesn't belong to the previous declaration.
        if (token.prev.kind.In(TOK.Semicolon, TOK.RBrace, TOK.Comma))
          break;
        else if (isDocComment(token))
          comments ~= token; // Comments are appended in reverse order.
    comments.reverse; // Reverse the list when finished.
    // Get single comment to the right.
    token = node.end.next;
    if (token.kind == TOK.Comment && isDocComment(token))
      comments ~= token;
    else if (isEnumMember)
    {
      token = node.end.nextNWS;
      if (token.kind == TOK.Comma)
        if ((++token).kind == TOK.Comment && isDocComment(token))
          comments ~= token;
    }
    return comments;
  }

  bool isLineComment(Token* t)
  {
    assert(t.kind == TOK.Comment);
    return t.start[1] == '/';
  }

  /// Extracts the text body of the comment tokens.
  cstring getDDocText(Token*[] tokens)
  {
    if (tokens.length == 0)
      return null;
    char[] result;
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
  ///   comment = The string to be sanitized.
  ///   padding = '/', '+' or '*'
  cstring sanitize(char[] comment, char padding)
  {
    bool isNewline = true; // True when at the beginning of a new line.
    auto q = comment.ptr; // Writer.
    cchar* p = q; // Reader.
    auto end = p + comment.length;

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
  /// ditto
  cstring sanitize(cstring comment, char padding)
  {
    return sanitize(comment.dup, padding);
  }

  /// Unindents all lines in text by the maximum amount possible.
  /// Note: counts tabulators the same as single spaces.
  /// Returns: the unindented text or the original text.
  cstring unindentText(cstring text)
  {
    auto p = text.ptr, end = p + text.length;
    auto indent = size_t.max; // Start with the largest number.
    auto lbegin = p; // The beginning of a line.
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
    auto newText = text.dup;
    auto q = newText.ptr; // Writer.
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
      // Skip multiple newlines.
      while (p < end && *p == '\n')
        *q++ = *p++;
      lbegin = p;
    }
    newText.length = q - newText.ptr;
    return newText;
  }
}

/// Parses a DDoc comment string.
struct DDocParser
{
  cchar* p; /// Current character pointer.
  cchar* textEnd; /// Points one character past the end of the text.
  Section[] sections; /// Parsed sections.
  Section summary; /// Optional summary section.
  Section description; /// Optional description section.

  /// Parses the DDoc text into sections.
  /// All newlines in the text must be converted to '\n'.
  Section[] parse(cstring text)
  {
    if (!text.length)
      return null;
    p = text.ptr;
    textEnd = p + text.length;

    cchar* summaryBegin;
    cstring ident, nextIdent;
    cchar* bodyBegin, nextBodyBegin;

    while (p < textEnd && (isspace(*p) || *p == '\n'))
      p++;
    summaryBegin = p;

    if (findNextIdColon(ident, bodyBegin))
    { // Check if there's text before the explicit section.
      if (summaryBegin != ident.ptr)
        scanSummaryAndDescription(summaryBegin, ident.ptr);
      // Continue parsing.
      while (findNextIdColon(nextIdent, nextBodyBegin))
      {
        sections ~= new Section(ident, textBody(bodyBegin, nextIdent.ptr));
        ident = nextIdent;
        bodyBegin = nextBodyBegin;
      }
      // Add last section.
      sections ~= new Section(ident, textBody(bodyBegin, textEnd));
    }
    else // There are no explicit sections.
      scanSummaryAndDescription(summaryBegin, textEnd);
    return sections;
  }

  /// Separates the text between p and end
  /// into a summary and an optional description section.
  void scanSummaryAndDescription(cchar* p, cchar* end)
  {
    assert(p <= end);
    auto sectionBegin = p;
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
  static bool isCodeSection(cchar* p, cchar* end)
  {
    return p < end && *p == '-' && p+2 < end && p[1] == '-' && p[2] == '-';
  }

  /// Skips over a code section and sets p one character past it.
  ///
  /// Note: apparently DMD doesn't skip over code sections when
  /// parsing DDoc sections. However, from experience it seems
  /// to be a good idea to do that.
  /// Returns: true if a code section was skipped.
  static bool skipCodeSection(ref cchar* p, cchar* end)
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
  ///   ident = Set to the Identifier.
  ///   bodyBegin = Set to the beginning of the text body (whitespace skipped.)
  /// Returns: true if found.
  bool findNextIdColon(out cstring ident, out cchar* bodyBegin)
  {
    while (p < textEnd)
    {
      skipWhitespace();
      if (p is textEnd)
        break;
      if (skipCodeSection(p, textEnd))
        continue;
      assert(p < textEnd && (isascii(*p) || isLeadByte(*p)));
      auto id = scanIdentifier(p, textEnd);
      if (id && p < textEnd && *p == ':')
        if (!(++p < textEnd && *p == '/')) // Ignore links: http:// ftp:// etc.
        {
          ident = id;
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
  cstring name; /// The name of the section.
  cstring text; /// The text of the section.
  /// Constructs a Section object.
  this(cstring name, cstring text)
  {
    this.name = name;
    this.text = text;
  }

  /// Case-insensitively compares the section's name with name2.
  bool Is(cstring name2)
  {
    return String(name).ieql(name2);
  }

  /// Returns the section's text including its name.
  cstring wholeText()
  {
    if (name.length == 0)
      return text;
    return name ~ ": " ~ text;
  }
}

/// Represents a params section.
class ParamsSection : Section
{
  cstring[] paramNames; /// Parameter names.
  cstring[] paramDescs; /// Parameter descriptions.
  /// Constructs a ParamsSection object.
  this(cstring name, cstring text)
  {
    super(name, text);
    IdentValueParser parser;
    auto idvalues = parser.parse(text);
    this.paramNames = new cstring[idvalues.length];
    this.paramDescs = new cstring[idvalues.length];
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
  cstring[] macroNames; /// Macro names.
  cstring[] macroTexts; /// Macro texts.
  /// Constructs a MacrosSection object.
  this(cstring name, cstring text)
  {
    super(name, text);
    IdentValueParser parser;
    auto idvalues = parser.parse(text);
    this.macroNames = new cstring[idvalues.length];
    this.macroTexts = new cstring[idvalues.length];
    foreach (i, idvalue; idvalues)
    {
      this.macroNames[i] = idvalue.ident;
      this.macroTexts[i] = idvalue.value;
    }
  }
}
