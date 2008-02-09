/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.doc.Doc;

import dil.doc.Parser;
import dil.ast.Node;
import dil.lexer.Funcs;
import dil.Unicode;
import common;

import tango.text.Ascii : toLower;

class DDocComment
{
  Section[] sections; /// The sections of this comment.
  Section summary; /// Optional summary section.
  Section description; /// Optional description section.

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

  /// Returns: true if "ditto" is the only text in this comment.
  bool isDitto()
  {
    if (summary && sections.length == 1 &&
        toLower(strip(summary.text.dup)) == "ditto")
      return true;
    return false;
  }

//   MacrosSection[] getMacros()
//   {
//     MacrosSection[] macros;
//     foreach (section; sections)
//       if (section.Is("macros"))
//         macros ~= new MacrosSection(section.name, section.text);
//     return macros;
//   }
}

/// Returns a node's DDocComment.
DDocComment getDDocComment(Node node)
{
  DDocParser p;
  p.parse(getDDocText(getDocTokens(node)));
  if (p.sections.length)
    return new DDocComment(p.sections, p.summary, p.description);
  return null;
}

/// Strips leading and trailing whitespace characters.
/// Whitespace: ' ', '\t', '\v', '\f' and '\n'
char[] strip(char[] str)
{
  if (str.length == 0)
    return null;
  uint i;
  for (; i < str.length; i++)
    if (!isspace(str[i]) && str[i] != '\n')
      break;
  if (str.length == i)
    return null;
  str = str[i..$];
  assert(str.length);
  for (i = str.length; i; i--)
    if (!isspace(str[i-1]) && str[i-1] != '\n')
      break;
  return str[0..i];
}

/// Parses a DDoc comment string.
struct DDocParser
{
  char* p;
  char* textEnd;
  Section[] sections; /// Parsed sections.
  Section summary; /// Optional summary section.
  Section description; /// Optional description section.

  /// Parses the DDoc text into sections.
  Section[] parse(string text)
  {
    if (!text.length)
      return null;
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
      return sections;
    }

    assert(idBegin && idEnd);
    // Continue parsing.
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
    end--; // Decrement end, so we can look ahead one character.
    while (p < end && !(*p == '\n' && p[1] == '\n'))
      p++;
    end++;
    if (p+1 >= end)
      p = end;
    assert(p == end || (*p == '\n' && p[1] == '\n'));
    // The first paragraph is the summary.
    summary = new Section("", makeString(sectionBegin, p));
    sections ~= summary;
    // The rest is the description section.
    if (p < end)
    {
      skipWhitespace(p);
      sectionBegin = p;
      if (p < end)
      {
        description = new Section("", makeString(sectionBegin, end));
        sections ~= description;
      }
    }
  }

  void skipWhitespace(ref char* p)
  {
    while (p < textEnd && (isspace(*p) || *p == '\n'))
      p++;
  }

  /// Find next "Identifier:".
  /// Params:
  ///   idBegin = set to the first character of the Identifier
  ///   idEnd   = set to the colon following the Identifier
  /// Returns: true if found
  bool findNextIdColon(ref char* ref_idBegin, ref char* ref_idEnd)
  {
    while (p < textEnd)
    {
      skipWhitespace(p);
      if (p >= textEnd)
        break;
      assert(isascii(*p) || isLeadByte(*p));
      auto idBegin = p;
      if (isidbeg(*p) || isUnicodeAlpha(p, textEnd)) // IdStart
      {
        do // IdChar*
          p++;
        while (p < textEnd && (isident(*p) || isUnicodeAlpha(p, textEnd)))
        if (p < textEnd && *p == ':') // :
        {
          ref_idBegin = idBegin;
          ref_idEnd = p;
          return true;
        }
      }
      // Skip this line.
      while (p < textEnd && *p != '\n')
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

  bool Is(char[] name2)
  {
    return toLower(name.dup) == name2;
  }
}

class ParamsSection : Section
{
  string[] paramNames; /// Parameter names.
  string[] paramDescs; /// Parameter descriptions.
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

class MacrosSection : Section
{
  string[] macroNames; /// Macro names.
  string[] macroTexts; /// Macro texts.
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
  if (tokens.length == 0)
    return null;
  string result;
  foreach (token; tokens)
  {
    auto n = isLineComment(token) ? 0 : 2; // 0 for "//", 2 for "+/" and "*/".
    result ~= sanitize(token.srcText[3 .. $-n], token.start[1]);
    assert(token.next);
    if (token.next.kind == TOK.Newline)
      result ~= \n;
    else
      result ~= ' ';
  }
//   Stdout.formatln("→{}←", result);
  return result[0..$-1]; // Remove \n or ' '
}

/// Sanitizes a DDoc comment string.
/// Leading "commentChar"s are removed from the lines.
/// The various newline types are converted to '\n'.
/// Params:
///   comment = the string to be sanitized.
///   commentChar = '/', '+', or '*'
string sanitize(string comment, char commentChar)
{
  alias comment result;

  bool newline = true; // True when at the beginning of a new line.
  uint i, j;
  auto len = result.length;
  for (; i < len; i++, j++)
  {
    if (newline)
    { // Ignore commentChars at the beginning of each new line.
      newline = false;
      while (i < len && isspace(result[i]))
        i++;
      while (i < len && result[i] == commentChar)
        i++;
      if (i >= len)
        break;
    }
    // Check for Newline.
    switch (result[i])
    {
    case '\r':
      if (i+1 < len && result[i+1] == '\n')
        i++;
    case '\n':
      result[j] = '\n'; // Copy Newline as '\n'.
      newline = true;
      continue;
    default:
      if (!isascii(result[i]) && i+2 < len && isUnicodeNewline(result.ptr + i))
      {
        i += 2;
        goto case '\n';
      }
    }
    // Copy character.
    result[j] = result[i];
  }
  result.length = j; // Adjust length.
  // Lastly, strip trailing commentChars.
  if (!result.length)
    return null;
  i = result.length;
  for (; i && result[i-1] == commentChar; i--)
  {}
  result.length = i;
  return result;
}
