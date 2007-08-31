/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.Statistics;
import dil.Token;
import dil.File;
import dil.Lexer;
import std.stdio;

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
  char* end = lx.text.ptr;

  Statistics stats;
  // Traverse linked list.
  while (token.type != TOK.EOF)
  {
    token = token.next;

    // Count whitespace characters
    if (end != token.start)
    {
      stats.whitespaceCount += token.start - end;
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

    end = token.end;
  }
  writefln("Whitespace character count: %s\n"
           "Whitespace token count: %s\n"
           "Keyword count: %s\n"
           "Identifier count: %s\n"
           "Number count: %s\n"
           "Comment count: %s\n"
           "Lines of code: %s",
           stats.whitespaceCount,
           stats.wsTokenCount,
           stats.keywordCount,
           stats.identCount,
           stats.numberCount,
           stats.commentCount,
           lx.loc);
}
