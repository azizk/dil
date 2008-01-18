/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.doc.Doc;

import dil.ast.Node;

bool isDoxygenComment(Token* token)
{ // Doxygen: '/+!' '/*!' '//!'
  return token.type == TOK.Comment && token.start[2] == '!';
}

bool isDDocComment(Token* token)
{ // DDOC: '/++' '/**' '///'
  return token.type == TOK.Comment && token.start[1] == token.start[2];
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
    if (token.type == TOK.LBrace ||
        token.type == TOK.RBrace ||
        token.type == TOK.Semicolon ||
        token.type == TOK.HEAD ||
        (node.kind == NodeKind.EnumMember && token.type == TOK.Comma))
      break;

    if (token.type == TOK.Comment)
    {
      // Check that this comment doesn't belong to the previous declaration.
      if (node.kind == NodeKind.EnumMember && token.type == TOK.Comma)
        break;
      switch (token.prev.type)
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
  if (token.type == TOK.Comment && isDocComment(token))
    comments ~= token;
  else if (node.kind == NodeKind.EnumMember)
  {
    token = node.end.nextNWS;
    if (token.type == TOK.Comma)
    {
      token = token.next;
      if (token.type == TOK.Comment && isDocComment(token))
        comments ~= token;
    }
  }
  return comments;
}
