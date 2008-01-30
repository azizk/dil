/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.doc.Doc;

import dil.ast.Node;
import dil.lexer.Funcs;
import common;

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
Token*[] getDocComments(Node node, bool function(Token*) isDocComment = &isDDocComment)
{
  Token*[] comments;
  // Get preceding comments.
  auto token = node.begin;
  // Scan backwards until we hit another declaration.
  while (1)
  {
    token = token.prev;
    if (token.kind == TOK.LBrace ||
        token.kind == TOK.RBrace ||
        token.kind == TOK.Semicolon ||
        token.kind == TOK.HEAD ||
        (node.kind == NodeKind.EnumMemberDeclaration && token.kind == TOK.Comma))
      break;

    if (token.kind == TOK.Comment)
    {
      // Check that this comment doesn't belong to the previous declaration.
      if (node.kind == NodeKind.EnumMemberDeclaration && token.kind == TOK.Comma)
        break;
      switch (token.prev.kind)
      {
      case TOK.Semicolon, TOK.RBrace:
        break;
      default:
        if (isDocComment(token))
          comments ~= token;
      }
    }
  }
  // Get single comment to the right.
  token = node.end.next;
  if (token.kind == TOK.Comment && isDocComment(token))
    comments ~= token;
  else if (node.kind == NodeKind.EnumMemberDeclaration)
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

bool isspace(char c)
{
  return c == ' ' || c == '\t' || c == '\v' || c == '\f';
}

/// Sanitizes a DDoc comment string.
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
