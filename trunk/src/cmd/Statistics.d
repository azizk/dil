/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.Statistics;
import dil.Token;
import dil.File;
import dil.Lexer;
import common;

struct Statistics
{
  uint whitespaceCount;
  uint wsTokenCount;
  uint keywordCount;
  uint identCount;
  uint numberCount;
  uint commentCount;
}

void execute(string fileName)
{
  auto sourceText = loadFile(fileName);
  auto lx = new Lexer(sourceText, fileName);

  auto token = lx.getTokens();

  Statistics stats;
  // Traverse linked list.
  while (token.type != TOK.EOF)
  {
    token = token.next;

    // Count whitespace characters
    if (token.ws)
    {
      // TODO: naive method doesn't account for \r\n, LS and PS.
      stats.whitespaceCount += token.start - token.ws;
    }

    switch (token.type)
    {
    case TOK.Identifier:
      stats.identCount++;
      break;
    case TOK.Comment:
      stats.commentCount++;
      break;
    case TOK.Int32, TOK.Int64, TOK.Uint32, TOK.Uint64,
         TOK.Float32, TOK.Float64, TOK.Float80,
         TOK.Imaginary32, TOK.Imaginary64, TOK.Imaginary80:
      stats.numberCount++;
      break;
    default:
      if (token.isKeyword)
        stats.keywordCount++;
    }

    if (token.isWhitespace)
      stats.wsTokenCount++;
  }
  Stdout.formatln(
    "Whitespace character count: {0}\n"
    "Whitespace token count: {1}\n"
    "Keyword count: {2}\n"
    "Identifier count: {3}\n"
    "Number count: {4}\n"
    "Comment count: {5}\n"
    "Lines of code: {6}",
    stats.whitespaceCount,
    stats.wsTokenCount,
    stats.keywordCount,
    stats.identCount,
    stats.numberCount,
    stats.commentCount,
    lx.loc);
}
