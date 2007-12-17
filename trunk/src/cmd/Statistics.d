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
  uint whitespaceCount; /// Counter for whitespace characters.
  uint wsTokenCount;    /// Counter for all whitespace tokens.
  uint keywordCount;    /// Counter for keywords.
  uint identCount;      /// Counter for identifier.
  uint numberCount;     /// Counter for number literals.
  uint commentCount;    /// Counter for comments.
  uint tokenCount;      /// Counter for all tokens produced by the Lexer.
  uint linesOfCode;     /// Number of lines.

  void opAddAssign(Statistics s)
  {
    this.whitespaceCount += s.whitespaceCount;
    this.wsTokenCount    += s.wsTokenCount;
    this.keywordCount    += s.keywordCount;
    this.identCount      += s.identCount;
    this.numberCount     += s.numberCount;
    this.commentCount    += s.commentCount;
    this.tokenCount      += s.tokenCount;
    this.linesOfCode     += s.linesOfCode;
  }
}

void execute(string[] filePaths)
{
  Statistics[] stats;
  foreach (filePath; filePaths)
    stats ~= getStatistics(filePath);

  Statistics total;

  foreach (i, ref stat; stats)
  {
    total += stat;
    Stdout.formatln(
      "----\n"
      "File: {}\n"
      "Whitespace character count: {}\n"
      "Whitespace token count: {}\n"
      "Keyword count: {}\n"
      "Identifier count: {}\n"
      "Number count: {}\n"
      "Comment count: {}\n"
      "All tokens count: {}\n"
      "Lines of code: {}",
      filePaths[i],
      stat.whitespaceCount,
      stat.wsTokenCount,
      stat.keywordCount,
      stat.identCount,
      stat.numberCount,
      stat.commentCount,
      stat.tokenCount,
      stat.linesOfCode
    );
  }

  if (filePaths.length > 1)
    Stdout.formatln(
      "--------------------------------------------------------------------------------\n"
      "Total of {} files:\n"
      "Whitespace character count: {}\n"
      "Whitespace token count: {}\n"
      "Keyword count: {}\n"
      "Identifier count: {}\n"
      "Number count: {}\n"
      "Comment count: {}\n"
      "All tokens count: {}\n"
      "Lines of code: {}",
      filePaths.length,
      total.whitespaceCount,
      total.wsTokenCount,
      total.keywordCount,
      total.identCount,
      total.numberCount,
      total.commentCount,
      total.tokenCount,
      total.linesOfCode
    );
}

Statistics getStatistics(string filePath)
{
  auto sourceText = loadFile(filePath);
  auto lx = new Lexer(sourceText, filePath);
  lx.scanAll();
  auto token = lx.firstToken();

  Statistics stats;
  // Lexer creates HEAD + Newline, which are not in the source text.
  // No token left behind!
  stats.tokenCount = 2;
  stats.linesOfCode = lx.lineNum;
  // Traverse linked list.
  while (1)
  {
    stats.tokenCount += 1;
    // Count whitespace characters
    if (token.ws !is null)
      stats.whitespaceCount += token.start - token.ws;

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
    case TOK.Newline:
      break;
    default:
      if (token.isKeyword)
        stats.keywordCount++;
      else if (token.isWhitespace)
        stats.wsTokenCount++;
    }

    if (token.next is null)
      break;
    token = token.next;
  }
  assert(token.type == TOK.EOF);
  return stats;
}
