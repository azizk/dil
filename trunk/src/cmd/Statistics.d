/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.Statistics;

import dil.File;
import dil.lexer.Lexer;
import dil.lexer.Token;
import dil.parser.Parser;
import dil.ast.NodesEnum;
import cmd.ASTStats;
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
  uint[] tokensTable;   /// Table of counters for all token kinds.
  uint[] nodesTable;    /// Table of counters for all node kinds.

  static Statistics opCall(bool allocateTokensTable, bool allocateNodesTable = false)
  {
    Statistics s;
    if (allocateTokensTable)
      s.tokensTable = new uint[TOK.MAX];
    if (allocateNodesTable)
      s.nodesTable = new uint[classNames.length];
    return s;
  }

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
    foreach (i, count; s.tokensTable)
      this.tokensTable[i] += count;
    foreach (i, count; s.nodesTable)
      this.nodesTable[i] += count;
  }
}

void execute(string[] filePaths, bool printTokensTable, bool printNodesTable)
{
  Statistics[] stats;
  foreach (filePath; filePaths)
    stats ~= getStatistics(filePath, printTokensTable, printNodesTable);

  auto total = Statistics(printTokensTable, printNodesTable);

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
  {
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

  if (printTokensTable)
  {
    Stdout("Table of tokens:").newline;
    Stdout.formatln(" {,10} | {}", "Count", "Token kind");
    Stdout("-----------------------------").newline;
    foreach (i, count; total.tokensTable)
      Stdout.formatln(" {,10} | {}", count, Token.toString(cast(TOK)i));
    Stdout("// End of tokens table.").newline;
  }

  if(printNodesTable)
  {
    Stdout("Table of nodes:").newline;
    Stdout.formatln(" {,10} | {}", "Count", "Node kind");
    Stdout("-----------------------------").newline;
    foreach (i, count; total.nodesTable)
      Stdout.formatln(" {,10} | {}", count, classNames[i]);
    Stdout("// End of nodes table.").newline;
  }
}

Statistics getStatistics(string filePath, bool printTokensTable, bool printNodesTable)
{
  // Create a new record.
  auto stats = Statistics(printTokensTable);

  auto sourceText = loadFile(filePath);
  Parser parser;
  Lexer lx;
  if (printNodesTable)
  {
    parser = new Parser(sourceText, filePath);
    auto rootNode = parser.start();
    // Count nodes.
    stats.nodesTable = (new ASTStats).count(rootNode);
    lx = parser.lexer;
  }
  else
  {
    lx = new Lexer(sourceText, filePath);
    lx.scanAll();
  }

  auto token = lx.firstToken();

  // Count tokens.
  // Lexer creates HEAD + Newline, which are not in the source text.
  // No token left behind!
  stats.tokenCount = 2;
  stats.linesOfCode = lx.lineNum;
  if (printTokensTable)
  {
    stats.tokensTable[TOK.HEAD] = 1;
    stats.tokensTable[TOK.Newline] = 1;
  }
  // Traverse linked list.
  while (1)
  {
    stats.tokenCount += 1;

    if (printTokensTable)
      stats.tokensTable[token.type] += 1;

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
