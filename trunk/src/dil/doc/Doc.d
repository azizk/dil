/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.doc.Doc;

import dil.ast.Node;
import dil.lexer.Funcs;
import dil.Unicode;
import common;

class DDocComment
{
  Section[] sections;
  Section summary; /// Optional summary section.
  Section description; /// Optional description section.

  this(Section[] sections, Section summary, Section description)
  {
    this.sections = sections;
    this.summary = summary;
    this.description = description;
  }
}

struct DDocParser
{
  char* p;
  char* textEnd;
  Section[] sections;
  Section summary; /// Optional summary section.
  Section description; /// Optional description section.

  /// Parses the DDoc text into sections.
  Section[] parse(string text)
  {
    if (!text.length)
      return null;
    if (text[$-1] != '\0')
      text ~= '\0';
    p = text.ptr;
    textEnd = p + text.length;

    char* summaryBegin;
    char* idBegin, idEnd;
    char* nextIdBegin, nextIdEnd;

    skipWhitespace(p);
    summaryBegin = p;

    if (findNextIdColon(idBegin, idEnd))
    { // Check that this is not an explicit section.
      if (summaryBegin != idBegin)
        scanSummaryAndDescription(summaryBegin, idBegin);
    }
    else // There are no explicit sections.
    {
      scanSummaryAndDescription(summaryBegin, textEnd);
      return null;
    }

    assert(idBegin && idEnd);
    while (findNextIdColon(nextIdBegin, nextIdEnd))
    {
      sections ~= new Section(makeString(idBegin, idEnd), makeString(idEnd+1, nextIdBegin));
      idBegin = nextIdBegin;
      idEnd = nextIdEnd;
    }
    // Add last section.
    sections ~= new Section(makeString(idBegin, idEnd), makeString(idEnd+1, textEnd));
    return sections;
  }

  void scanSummaryAndDescription(char* p, char* end)
  {
    assert(p < end);
    char* sectionBegin = p;
    // Search for the end of the first paragraph.
    while (p < end && !(*p == '\n' && p[1] == '\n'))
      p++;
    // The first paragraph is the summary.
    summary = new Section("", makeString(sectionBegin, p));
    sections ~= summary;
    // The rest is the description section.
    if (p != end)
    {
      sectionBegin = p;
      skipWhitespace(p);
      if (p < end)
      {
        description = new Section("", makeString(sectionBegin, end));
        sections ~= description;
      }
    }
  }

  void skipWhitespace(ref char* p)
  {
    while (isspace(*p) || *p == '\n')
      p++;
  }

  /// Find next "Identifier:".
  /// Params:
  ///   p       = current character pointer
  ///   idBegin = set to the first character of the Identifier
  ///   idEnd   = set to the colon following the Identifier
  /// Returns: true if found
  bool findNextIdColon(ref char* ref_idBegin, ref char* ref_idEnd)
  {
    auto p = this.p;
    while (*p != '\0')
    {
      auto idBegin = p;
      assert(isascii(*p) || isLeadByte(*p));
      if (isidbeg(*p) || isUnicodeAlpha(p, textEnd)) // IdStart
      {
        do // IdChar*
          p++;
        while (isident(*p) || isUnicodeAlpha(p, textEnd))
        if (*p == ':') // :
        {
          ref_idBegin = idBegin;
          ref_idEnd = p;
          this.p = p;
          return true;
        }
      }
      else if (!isascii(*p))
      { // Skip UTF-8 sequences.
        while (!isascii(*++p))
        {}
        continue;
      }
      p++;
    }
    return false;
  }
}

class Section
{
  string name;
  string text;
  this(string name, string text)
  {
    this.name = name;
    this.text = text;
  }
}

char[] makeString(char* begin, char* end)
{
  return begin[0 .. end - begin];
}

bool isDoxygenComment(Token* token)
{ // Doxygen: '/+!' '/*!' '//!'
  return token.kind == TOK.Comment && token.start[2] == '!';
}

bool isDDocComment(Token* token)
{ // DDOC: '/++' '/**' '///'
  return token.kind == TOK.Comment && token.start[1] == token.start[2];
}

/++
  Returns the surrounding documentation comment tokens.
  Note: this function works correctly only if
        the source text is syntactically correct.
+/
Token*[] getDocTokens(Node node, bool function(Token*) isDocComment = &isDDocComment)
{
  Token*[] comments;
  auto isEnumMember = node.kind == NodeKind.EnumMemberDeclaration;
  // Get preceding comments.
  auto token = node.begin;
  // Scan backwards until we hit another declaration.
Loop:
  while (1)
  {
    token = token.prev;
    if (token.kind == TOK.LBrace ||
        token.kind == TOK.RBrace ||
        token.kind == TOK.Semicolon ||
        token.kind == TOK.HEAD ||
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
  string result;
  foreach (token; tokens)
  {
    auto n = isLineComment(token) ? 0 : 2; // 0 for "//", 2 for "+/" and "*/".
    result ~= sanitize(token.srcText[3 .. $-n], token.start[1]);
  }
  return result;
}

/// Sanitizes a DDoc comment string.
/// Leading "commentChar"s are removed from the lines.
/// The various newline types are converted to '\n'.
/// Params:
///   comment = the string to be sanitized.
///   commentChar = '/', '+', or '*'
string sanitize(string comment, char commentChar)
{
  string result = comment.dup ~ '\0';

  assert(result[$-1] == '\0');
  bool newline = true; // Indicates whether a newline has been encountered.
  uint i, j;
  for (; i < result.length; i++)
  {
    if (newline)
    { // Ignore commentChars at the beginning of each new line.
      newline = false;
      while (isspace(result[i]))
      { i++; }
      while (result[i] == commentChar)
      { i++; }
    }
    // Check for Newline.
    switch (result[i])
    {
    case '\r':
      if (result[i+1] == '\n')
        i++;
    case '\n':
      result[j++] = '\n'; // Copy Newline as '\n'.
      newline = true;
      continue;
    default:
      if (isUnicodeNewline(result.ptr + i))
      {
        i++; i++;
        goto case '\n';
      }
    }
    // Copy character.
    result[j++] = result[i];
  }
  result.length = j; // Adjust length.
  // Lastly, strip trailing commentChars.
  i = result.length - (1 + 1);
  while (i && result[i] == commentChar)
  { i--; }
  return result;
}
