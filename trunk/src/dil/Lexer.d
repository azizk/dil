/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Lexer;
import dil.Token;
import dil.Information;
import dil.Keywords;
import dil.Identifier;
import dil.Messages;
import dil.HtmlEntities;
import dil.Settings;
import tango.stdc.stdlib : strtof, strtod, strtold;
import tango.stdc.errno : errno, ERANGE;
import tango.stdc.time : time_t, time, ctime;
import tango.stdc.string : strlen;
import std.utf;
import std.uni;
import common;

const char[3] LS = \u2028;
const char[3] PS = \u2029;

const dchar LSd = 0x2028;
const dchar PSd = 0x2029;

const uint _Z_ = 26; /// Control+Z

class Lexer
{
  Token* head; /// The head of the doubly linked token list.
  Token* tail; /// The tail of the linked list. Set in scan().
  Token* token; /// Points to the current token in the token list.
  string text;
  char* p; /// Points to the current character in the source text.
  char* end; /// Points one character past the end of the source text.

  uint loc = 1; /// Actual line of code.

  uint loc_old; /// Store actual line number when #line token is parsed.
  uint loc_hline; /// Line number set by #line.

  char[] fileName;

  Information[] errors;

//   bool reportErrors;

  Identifier[string] idtable;

  this(string text, string fileName)
  {
    this.fileName = fileName;

    this.text = text;
    if (text[$-1] != 0)
    {
      this.text.length = this.text.length + 1;
      this.text[$-1] = 0;
    }

    this.p = this.text.ptr;
    this.end = this.p + this.text.length;
//     this.reportErrors = true;
    loadKeywords();

    this.head = new Token;
    this.head.type = TOK.HEAD;
    this.token = this.head;
    scanShebang();
  }

  ~this()
  {
    auto token = head.next;
    do
    {
      assert(token.type == TOK.EOF ? token == tail && token.next is null : 1);
      delete token.prev;
      token = token.next;
    } while (token !is null)
    delete tail;
  }

  void scanShebang()
  {
    if (*p == '#' && p[1] == '!')
    {
      Token* t = new Token;
      t.start = p;
      t.type = TOK.Shebang;
      ++p;
      while (1)
      {
        t.end = p;
        switch (*++p)
        {
        case '\r':
          if (p[1] == '\n')
            ++p;
        case '\n':
          ++p;
          ++loc;
          break;
        case 0, _Z_:
          break;
        default:
          if (*p & 128)
          {
            auto c = decodeUTF8();
            if (c == LSd || c == PSd)
              goto case '\n';
          }
          continue;
        }
        break; // Exit loop.
      }
      this.head.next = t;
      t.prev = this.head;
    }
  }

  void finalizeSpecialToken(ref Token t)
  {
    assert(t.srcText[0..2] == "__");
    switch (t.type)
    {
    case TOK.FILE:
      t.str = this.fileName;
      break;
    case TOK.LINE:
      t.uint_ = this.loc;
      break;
    case TOK.DATE,
         TOK.TIME,
         TOK.TIMESTAMP:
      time_t time_val;
      time(&time_val);
      char* str = ctime(&time_val);
      char[] time_str = str[0 .. strlen(str)];
      switch (t.type)
      {
      case TOK.DATE:
        time_str = time_str[4..11] ~ time_str[20..24] ~ \0; break;
      case TOK.TIME:
        time_str = time_str[11..19] ~ \0; break;
      case TOK.TIMESTAMP:
        time_str = time_str[0..24] ~ \0; break;
      default: assert(0);
      }
      t.str = time_str;
      break;
    case TOK.VENDOR:
      t.str = VENDOR;
      break;
    case TOK.VERSION:
      t.uint_ = VERSION_MAJOR*1000 + VERSION_MINOR;
      break;
    default:
      assert(0);
    }
  }

  public void scan(out Token t)
  in
  {
    assert(text.ptr <= p && p < end);
  }
  out
  {
    assert(text.ptr <= t.start && t.start < end);
    assert(text.ptr < t.end && t.end <= end, Token.toString(t.type));
  }
  body
  {
    // Scan whitespace.
    auto pws = p;
    while (1)
    {
      switch (*p)
      {
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        ++p;
        ++loc;
        continue;
      case LS[0]:
        if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
        {
          p += 3;
          ++loc;
          continue;
        }
        // goto default;
      default:
        if (!isspace(*p))
          break;
        ++p;
        continue;
      }
      break; // Exit loop.
    }

    if (p != pws)
      t.ws = pws;

    // Scan token.
    uint c = *p;
    {
      t.start = p;

      if (c == 0 || c == _Z_)
      {
        assert(*p == 0 || *p == _Z_);
        t.type = TOK.EOF;
        t.end = p;
        tail = &t;
        assert(t.start == t.end);
        return;
      }

      if (isidbeg(c))
      {
        if (c == 'r' && p[1] == '"' && ++p)
          return scanRawStringLiteral(t);
        if (c == 'x' && p[1] == '"')
          return scanHexStringLiteral(t);
      version(D2)
      {
        if (c == 'q' && p[1] == '"')
          return scanDelimitedStringLiteral(t);
        if (c == 'q' && p[1] == '{')
          return scanTokenStringLiteral(t);
      }
      Lidentifier:
        do
        { c = *++p; }
        while (isident(c) || c & 128 && isUniAlpha(decodeUTF8()))

        t.end = p;

        string str = t.srcText;
        Identifier* id = str in idtable;

        if (!id)
        {
          idtable[str] = Identifier(TOK.Identifier, str);
          id = str in idtable;
        }
        assert(id);
        t.type = id.type;
        if (t.isSpecialToken)
          finalizeSpecialToken(t);
        return;
      }

      if (isdigit(c))
        return scanNumber(t);

      if (c == '/')
      {
        c = *++p;
        switch(c)
        {
        case '=':
          ++p;
          t.type = TOK.DivAssign;
          t.end = p;
          return;
        case '+':
          uint level = 1;
          while (1)
          {
            c = *++p;
          LswitchNC: // only jumped to from default case of next switch(c)
            switch (c)
            {
            case '\r':
              if (p[1] == '\n')
                ++p;
            case '\n':
              ++loc;
              continue;
            case 0, _Z_:
              error(MID.UnterminatedNestedComment);
              goto LreturnNC;
            default:
            }

            c <<= 8;
            c |= *++p;
            switch (c)
            {
            case 0x2F2B: // /+
              ++level;
              continue;
            case 0x2B2F: // +/
              if (--level == 0)
              {
                ++p;
              LreturnNC:
                t.type = TOK.Comment;
                t.end = p;
                return;
              }
              continue;
            case 0xE280: // LS[0..1] || PS[0..1]
              if (p[1] == LS[2] || p[1] == PS[2])
              {
                ++loc;
                ++p;
              }
              continue;
            default:
              c &= char.max;
              goto LswitchNC;
            }
          }
        case '*':
          while (1)
          {
            c = *++p;
          LswitchBC: // only jumped to from default case of next switch(c)
            switch (c)
            {
            case '\r':
              if (p[1] == '\n')
                ++p;
            case '\n':
              ++loc;
              continue;
            case 0, _Z_:
              error(MID.UnterminatedBlockComment);
              goto LreturnBC;
            default:
            }

            c <<= 8;
            c |= *++p;
            switch (c)
            {
            case 0x2A2F: // */
              ++p;
            LreturnBC:
              t.type = TOK.Comment;
              t.end = p;
              return;
            case 0xE280: // LS[0..1] || PS[0..1]
              if (p[1] == LS[2] || p[1] == PS[2])
              {
                ++loc;
                ++p;
              }
              continue;
            default:
              c &= char.max;
              goto LswitchBC;
            }
          }
          assert(0);
        case '/':
          while (1)
          {
            c = *++p;
            switch (c)
            {
            case '\r':
              if (p[1] == '\n')
                ++p;
            case '\n':
            case 0, _Z_:
              break;
            case LS[0]:
              if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
                break;
              continue;
            default:
              continue;
            }
            t.type = TOK.Comment;
            t.end = p;
            return;
          }
        default:
          t.type = TOK.Div;
          t.end = p;
          return;
        }
      }

      switch (c)
      {
      case '\'':
        return scanCharacterLiteral(t);
      case '`':
        return scanRawStringLiteral(t);
      case '"':
        return scanNormalStringLiteral(t);
      case '\\':
        char[] buffer;
        do
        {
          c = scanEscapeSequence();
          if (c < 128)
            buffer ~= c;
          else
            encodeUTF8(buffer, c);
        } while (*p == '\\')
        buffer ~= 0;
        t.type = TOK.String;
        t.str = buffer;
        t.end = p;
        return;
      case '>': /* >  >=  >>  >>=  >>>  >>>= */
        c = *++p;
        switch (c)
        {
        case '=':
          t.type = TOK.GreaterEqual;
          goto Lcommon;
        case '>':
          if (p[1] == '>')
          {
            ++p;
            if (p[1] == '=')
            { ++p;
              t.type = TOK.URShiftAssign;
            }
            else
              t.type = TOK.URShift;
          }
          else if (p[1] == '=')
          {
            ++p;
            t.type = TOK.RShiftAssign;
          }
          else
            t.type = TOK.RShift;
          goto Lcommon;
        default:
          t.type = TOK.Greater;
          goto Lcommon2;
        }
        assert(0);
      case '<': /* <  <=  <>  <>=  <<  <<= */
        c = *++p;
        switch (c)
        {
        case '=':
          t.type = TOK.LessEqual;
          goto Lcommon;
        case '<':
          if (p[1] == '=') {
            ++p;
            t.type = TOK.LShiftAssign;
          }
          else
            t.type = TOK.LShift;
          goto Lcommon;
        case '>':
          if (p[1] == '=') {
            ++p;
            t.type = TOK.LorEorG;
          }
          else
            t.type = TOK.LorG;
          goto Lcommon;
        default:
          t.type = TOK.Less;
          goto Lcommon2;
        }
        assert(0);
      case '!': /* !  !<  !>  !<=  !>=  !<>  !<>= */
        c = *++p;
        switch (c)
        {
        case '<':
          c = *++p;
          if (c == '>')
          {
            if (p[1] == '=') {
              ++p;
              t.type = TOK.Unordered;
            }
            else
              t.type = TOK.UorE;
          }
          else if (c == '=')
          {
            t.type = TOK.UorG;
          }
          else {
            t.type = TOK.UorGorE;
            goto Lcommon2;
          }
          goto Lcommon;
        case '>':
          if (p[1] == '=')
          {
            ++p;
            t.type = TOK.UorL;
          }
          else
            t.type = TOK.UorLorE;
          goto Lcommon;
        case '=':
          t.type = TOK.NotEqual;
          goto Lcommon;
        default:
          t.type = TOK.Not;
          goto Lcommon2;
        }
        assert(0);
      case '.': /* .  .[0-9]  ..  ... */
        if (p[1] == '.')
        {
          ++p;
          if (p[1] == '.') {
            ++p;
            t.type = TOK.Ellipses;
          }
          else
            t.type = TOK.Slice;
        }
        else if (isdigit(p[1]))
        {
          return scanReal(t);
        }
        else
          t.type = TOK.Dot;
        goto Lcommon;
      case '|': /* |  ||  |= */
        c = *++p;
        if (c == '=')
          t.type = TOK.OrAssign;
        else if (c == '|')
          t.type = TOK.OrLogical;
        else {
          t.type = TOK.OrBinary;
          goto Lcommon2;
        }
        goto Lcommon;
      case '&': /* &  &&  &= */
        c = *++p;
        if (c == '=')
          t.type = TOK.AndAssign;
        else if (c == '&')
          t.type = TOK.AndLogical;
        else {
          t.type = TOK.AndBinary;
          goto Lcommon2;
        }
        goto Lcommon;
      case '+': /* +  ++  += */
        c = *++p;
        if (c == '=')
          t.type = TOK.PlusAssign;
        else if (c == '+')
          t.type = TOK.PlusPlus;
        else {
          t.type = TOK.Plus;
          goto Lcommon2;
        }
        goto Lcommon;
      case '-': /* -  --  -= */
        c = *++p;
        if (c == '=')
          t.type = TOK.MinusAssign;
        else if (c == '-')
          t.type = TOK.MinusMinus;
        else {
          t.type = TOK.Minus;
          goto Lcommon2;
        }
        goto Lcommon;
      case '=': /* =  == */
        if (p[1] == '=') {
          ++p;
          t.type = TOK.Equal;
        }
        else
          t.type = TOK.Assign;
        goto Lcommon;
      case '~': /* ~  ~= */
         if (p[1] == '=') {
           ++p;
           t.type = TOK.CatAssign;
         }
         else
           t.type = TOK.Tilde;
         goto Lcommon;
      case '*': /* *  *= */
         if (p[1] == '=') {
           ++p;
           t.type = TOK.MulAssign;
         }
         else
           t.type = TOK.Mul;
         goto Lcommon;
      case '^': /* ^  ^= */
         if (p[1] == '=') {
           ++p;
           t.type = TOK.XorAssign;
         }
         else
           t.type = TOK.Xor;
         goto Lcommon;
      case '%': /* %  %= */
         if (p[1] == '=') {
           ++p;
           t.type = TOK.ModAssign;
         }
         else
           t.type = TOK.Mod;
         goto Lcommon;
      // Single character tokens:
      case '(':
        t.type = TOK.LParen;
        goto Lcommon;
      case ')':
        t.type = TOK.RParen;
        goto Lcommon;
      case '[':
        t.type = TOK.LBracket;
        goto Lcommon;
      case ']':
        t.type = TOK.RBracket;
        goto Lcommon;
      case '{':
        t.type = TOK.LBrace;
        goto Lcommon;
      case '}':
        t.type = TOK.RBrace;
        goto Lcommon;
      case ':':
        t.type = TOK.Colon;
        goto Lcommon;
      case ';':
        t.type = TOK.Semicolon;
        goto Lcommon;
      case '?':
        t.type = TOK.Question;
        goto Lcommon;
      case ',':
        t.type = TOK.Comma;
        goto Lcommon;
      case '$':
        t.type = TOK.Dollar;
      Lcommon:
        ++p;
      Lcommon2:
        t.end = p;
        return;
      case '#':
        return scanSpecialTokenSequence(t);
      default:
      }

      if (c & 128)
      {
        c = decodeUTF8();
        if (isUniAlpha(c))
          goto Lidentifier;
      }

      error(MID.IllegalCharacter, cast(dchar)c);

      ++p;
      t.type = TOK.Illegal;
      t.dchar_ = c;
      t.end = p;
      return;
    }
  }

  void scanNormalStringLiteral(ref Token t)
  {
    assert(*p == '"');
    char[] buffer;
    t.type = TOK.String;
    uint c;
    while (1)
    {
      c = *++p;
      switch (c)
      {
      case '"':
        ++p;
      Lreturn:
        buffer ~= 0;
        t.str = buffer;
        t.pf = scanPostfix();
        t.end = p;
        return;
      case '\\':
        c = scanEscapeSequence();
        --p;
        if (c & 128)
          encodeUTF8(buffer, c);
        else
          break;
        continue;
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        ++loc;
        c = '\n'; // Convert EndOfLine to \n.
        break;
      case 0, _Z_:
        error(MID.UnterminatedString);
        goto Lreturn;
      default:
        if (c & 128)
        {
//           char* begin = p;
          c = decodeUTF8();
          if (c == LSd || c == PSd)
            goto case '\n';

          // We don't copy per pointer because we might include
          // invalid, skipped utf-8 sequences. See decodeUTF8().
//           ++p;
//           buffer ~= begin[0 .. p - begin];
          encodeUTF8(buffer, c);
          continue;
        }
      }
      // Copy ASCII character.
      buffer ~= c;
    }
    assert(0);
  }

  void scanCharacterLiteral(ref Token t)
  {
    assert(*p == '\'');
    MID id = MID.UnterminatedCharacterLiteral;
    ++p;
    TOK type = TOK.CharLiteral;
    switch (*p)
    {
    case '\\':
      switch (p[1])
      {
      case 'u':
        type = TOK.WCharLiteral; break;
      case 'U':
        type = TOK.DCharLiteral; break;
      default:
      }
      t.dchar_ = scanEscapeSequence();
      break;
    case '\'':
      ++p;
      id = MID.EmptyCharacterLiteral;
    case '\n', '\r', 0, _Z_:
      goto Lerr;
    default:
      uint c = *p;
      if (c & 128)
      {
        c = decodeUTF8();
        if (c == LSd || c == PSd)
          goto Lerr;
        if (c <= 0xFFFF)
          type = TOK.WCharLiteral;
        else
          type = TOK.DCharLiteral;
      }
      t.dchar_ = c;
      ++p;
    }

    if (*p == '\'')
      ++p;
    else
    Lerr:
      error(id);
    t.type = type;
    t.end = p;
  }

  char scanPostfix()
  {
    switch (*p)
    {
    case 'c':
    case 'w':
    case 'd':
      return *p++;
    default:
      return 0;
    }
    assert(0);
  }

  void scanRawStringLiteral(ref Token t)
  {
    uint delim = *p;
    assert(delim == '`' || delim == '"' && p[-1] == 'r');
    t.type = TOK.String;
    char[] buffer;
    uint c;
    while (1)
    {
      c = *++p;
      switch (c)
      {
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        c = '\n'; // Convert EndOfLine ('\r','\r\n','\n',LS,PS) to '\n'
        ++loc;
        break;
      case '`':
      case '"':
        if (c == delim)
        {
          ++p;
          t.pf = scanPostfix();
        Lreturn:
          t.str = buffer ~ '\0';
          t.end = p;
          return;
        }
        break;
      case 0, _Z_:
        if (delim == 'r')
          error(MID.UnterminatedRawString);
        else
          error(MID.UnterminatedBackQuoteString);
        goto Lreturn;
      default:
        if (c & 128)
        {
          c = decodeUTF8();
          if (c == LSd || c == PSd)
            goto case '\n';
          encodeUTF8(buffer, c);
          continue;
        }
      }
      buffer ~= c; // copy character to buffer
    }
    assert(0);
  }

  void scanHexStringLiteral(ref Token t)
  {
    assert(p[0] == 'x' && p[1] == '"');
    t.type = TOK.String;

    uint c;
    ubyte[] buffer;
    ubyte h; // hex number
    uint n; // number of hex digits

    ++p;
    while (1)
    {
      c = *++p;
      switch (c)
      {
      case '"':
        ++p;
        if (n & 1)
          error(MID.OddNumberOfDigitsInHexString);
        t.pf = scanPostfix();
      Lreturn:
        buffer ~= 0;
        t.str = cast(string) buffer;
        t.end = p;
        return;
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        ++loc;
        continue;
      default:
        if (ishexad(c))
        {
          if (c <= '9')
            c -= '0';
          else if (c <= 'F')
            c -= 'A' - 10;
          else
            c -= 'a' - 10;

          if (n & 1)
          {
            h <<= 4;
            h |= c;
            buffer ~= h;
          }
          else
            h = cast(ubyte)c;
          ++n;
          continue;
        }
        else if (isspace(c))
          continue;

        if (c & 128)
        {
          c = decodeUTF8();
          if (c == LSd || c == PSd)
          {
            ++p; ++p;
            ++loc;
            continue;
          }
        }
        else if (c == 0 || c == _Z_)
        {
          error(MID.UnterminatedHexString);
          t.pf = 0;
          goto Lreturn;
        }
        error(MID.NonHexCharInHexString, cast(dchar)c);
      }
    }
    assert(0);
  }

version(D2)
{
  void scanDelimitedStringLiteral(ref Token t)
  {
    assert(p[0] == 'q' && p[1] == '"');
    t.type = TOK.String;

    char[] buffer;
    dchar opening_delim, // 0 if no nested delimiter or '[', '(', '<', '{'
          closing_delim; // Will be ']', ')', '>', '}', any other character
                         // or the first, decoded character of an identifier.
    char[] str_delim; // Identifier delimiter
    uint level = 1;

    ++p; ++p; // Skip q"
    uint c = *p;
    switch (c)
    {
    case '(':
      opening_delim = c;
      closing_delim = ')'; // *p + 1
      break;
    case '[', '<', '{':
      opening_delim = c;
      closing_delim = c + 2; // Get to closing counterpart. Feature of ASCII table.
      break;
    default:
      char* begin = p;
      closing_delim = c;
      // TODO: What to do about newlines? Skip or accept as delimiter?
      // TODO: Check for non-printable characters?
      if (c & 128)
      {
        closing_delim = decodeUTF8();
        if (!isUniAlpha(c))
          break;
      }
      else if (!isidbeg(c))
        break;
      // Parse identifier + newline
      do
      { c = *++p; }
      while (isident(c) || c & 128 && isUniAlpha(decodeUTF8()))
      // Store identifier
      str_delim = begin[0..p-begin];
      // Scan newline
      switch (*p)
      {
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        ++loc;
        break;
      case LS[0]:
        if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
        {
          ++p; ++p;
          ++loc;
          break;
        }
        // goto default;
      default:
        // TODO: error(MID.ExpectedNewlineAfterIdentDelim);
      }
    }

    bool checkStringDelim(char* p)
    {
      assert(str_delim.length != 0);
      if (end-p >= str_delim.length && // Check remaining length.
          p[0..str_delim.length] == str_delim) // Compare.
        return true;
      return false;
    }

    while (1)
    {
      c = *++p;
      switch (c)
      {
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        c = '\n'; // Convert EndOfLine ('\r','\r\n','\n',LS,PS) to '\n'
        ++loc;
        break;
      case 0, _Z_:
//         error(MID.UnterminatedDelimitedString);
        goto Lreturn3;
      default:
        if (c & 128)
        {
          auto begin = p;
          c = decodeUTF8();
          if (c == LSd || c == PSd)
            goto case '\n';
          if (c == closing_delim)
          {
            if (str_delim.length && checkStringDelim(begin))
            {
              p = begin + str_delim.length;
              goto Lreturn2;
            }
            assert(level == 1);
            --level;
            goto Lreturn;
          }
          encodeUTF8(buffer, c);
          continue;
        }
        else
        {
          if (c == opening_delim)
            ++level;
          else if (c == closing_delim)
          {
            if (str_delim.length && checkStringDelim(p))
            {
              p += str_delim.length;
              goto Lreturn2;
            }
            if (--level == 0)
              goto Lreturn;
          }
        }
      }
      buffer ~= c; // copy character to buffer
    }
  Lreturn:
    assert(*p == closing_delim);
    assert(level == 0);
    ++p; // Skip closing delimiter.
  Lreturn2:
    if (*p == '"')
      ++p;
    // else
    // TODO: error(MID.ExpectedDblQuoteAfterDelim, str_delim.length ? str_delim : p[-1]);

    t.pf = scanPostfix();
  Lreturn3:
    t.str = buffer ~ '\0';
    t.end = p;
  }

  void scanTokenStringLiteral(ref Token t)
  {
    assert(p[0] == 'q' && p[1] == '{');
    t.type = TOK.String;
    // Copy members that might be changed by subsequent tokens. Like #line for example.
    auto loc_old = this.loc_old;
    auto loc_hline = this.loc_hline;
    auto filePath = this.fileName;

    uint loc = this.loc;
    uint level = 1;

    ++p; ++p; // Skip q{

    auto prev_t = &t;
    Token* token;
    while (1)
    {
      token = new Token;
      scan(*token);
      // Save the tokens in a doubly linked list.
      // Could be useful for various tools.
      token.prev = prev_t;
      prev_t.next = token;
      prev_t = token;
      switch (token.type)
      {
      case TOK.LBrace:
        ++level;
        continue;
      case TOK.RBrace:
        if (--level == 0)
        {
          t.tok_str = t.next;
          t.next = null;
          break;
        }
        continue;
      case TOK.EOF:
        // TODO: error(MID.UnterminatedTokenString);
        t.tok_str = t.next;
        t.next = token;
        break;
      default:
        continue;
      }
      break; // Exit loop.
    }

    assert(token.type == TOK.RBrace || token.type == TOK.EOF);
    assert(token.type == TOK.RBrace && t.next is null ||
           token.type == TOK.EOF && t.next !is null);

    char[] buffer;
    // token points to } or EOF
    if (token.type == TOK.EOF)
    {
      t.end = token.start;
      buffer = t.srcText[2..$].dup ~ '\0';
    }
    else
    {
      // Assign to buffer before scanPostfix().
      t.end = p;
      buffer = t.srcText[2..$-1].dup ~ '\0';
      t.pf = scanPostfix();
      t.end = p;
    }
    // Convert EndOfLines to '\n'
    if (loc != this.loc)
    {
      assert(buffer[$-1] == '\0');
      uint i, j;
      for (; i < buffer.length; ++i)
        switch (buffer[i])
        {
        case '\r':
          if (buffer[i+1] == '\n')
            ++i;
        case '\n':
          buffer[j++] = '\n';
          break;
        case LS[0]:
          auto b = buffer[i..$];
          if (b[1] == LS[1] && (b[2] == LS[2] || b[2] == PS[2]))
          {
            ++i; ++i;
            goto case '\n';
          }
          // goto default;
        default:
          buffer[j++] = buffer[i]; // Copy character
        }
      buffer.length = j; // Adjust length
    }
    assert(buffer[$-1] == '\0');
    t.str = buffer;

    // Restore possibly changed members.
    this.loc_old = loc_old;
    this.loc_hline = loc_hline;
    this.fileName = filePath;
  }
}

  dchar scanEscapeSequence()
  {
    assert(*p == '\\');
    ++p;
    uint c = char2ev(*p);
    if (c)
    {
      ++p;
      return c;
    }
    uint digits = 2;

    switch (*p)
    {
    case 'x':
      c = 0;
      while (1)
      {
        ++p;
        if (ishexad(*p))
        {
          c *= 16;
          if (*p <= '9')
            c += *p - '0';
          else if (*p <= 'F')
            c += *p - 'A' + 10;
          else
            c += *p - 'a' + 10;

          if (!--digits)
          {
            ++p;
            break;
          }
        }
        else
        {
          error(MID.InsufficientHexDigits);
          break;
        }
      }
      if (!isValidDchar(c))
        error(MID.InvalidUnicodeCharacter);
      break;
    case 'u':
      digits = 4;
      goto case 'x';
    case 'U':
      digits = 8;
      goto case 'x';
    default:
      if (isoctal(*p))
      {
        c = 0;
        c += *p - '0';
        ++p;
        if (!isoctal(*p))
          return c;
        c *= 8;
        c += *p - '0';
        ++p;
        if (!isoctal(*p))
          return c;
        c *= 8;
        c += *p - '0';
        ++p;
      }
      else if(*p == '&')
      {
        if (isalpha(*++p))
        {
          auto begin = p;
          while (isalnum(*++p))
          {}

          if (*p == ';')
          {
            c = entity2Unicode(begin[0..p - begin]);
            ++p; // Skip ;
            if (c == 0xFFFF)
              error(MID.UndefinedHTMLEntity, (begin-1)[0..p-(begin-1)]);
          }
          else
            error(MID.UnterminatedHTMLEntity);
        }
        else
          error(MID.InvalidBeginHTMLEntity);
      }
      else
      {
        dchar d = *p;
        char[] str = `\`;
        if (d & 128)
          encodeUTF8(str, decodeUTF8());
        else
          str ~= d;
        ++p;
        // TODO: check for unprintable character?
        error(MID.UndefinedEscapeSequence, str);
      }
    }

    return c;
  }

  /*
    IntegerLiteral:= (Dec|Hex|Bin|Oct)Suffix?
    Dec:= (0|[1-9][0-9_]*)
    Hex:= 0[xX] HexDigits
    Bin:= 0[bB][01_]+
    Oct:= 0[0-7_]+
    Suffix:= (L[uU]?|[uU]L?)
    HexDigits:= [0-9a-zA-Z_]+

    Invalid: "0b_", "0x_", "._"
  */
  void scanNumber(ref Token t)
  {
    ulong ulong_;
    bool overflow;
    bool isDecimal;
    size_t digits;

    if (*p != '0')
      goto LscanInteger;
    ++p; // skip zero
    // check for xX bB ...
    switch (*p)
    {
    case 'x','X':
      goto LscanHex;
    case 'b','B':
      goto LscanBin;
    case 'L':
      if (p[1] == 'i')
        goto LscanReal;
    case '.':
      if (p[1] == '.')
        break;
    case 'i','f','F', 'e', 'E': // Imaginary and float literal suffix
      goto LscanReal;
    default:
      if (*p == '_' || isoctal(*p))
        goto LscanOct;
    }

    // Number 0
    assert(p[-1] == '0');
    assert(ulong_ == 0);
    isDecimal = true;
    goto Lfinalize;

  LscanInteger:
    assert(*p != 0 && isdigit(*p));
    isDecimal = true;
    goto Lenter_loop_int;
    while (1)
    {
      if (*++p == '_')
        continue;
      if (!isdigit(*p))
        break;
    Lenter_loop_int:
      if (ulong_ < ulong.max/10 || (ulong_ == ulong.max/10 && *p <= '5'))
      {
        ulong_ *= 10;
        ulong_ += *p - '0';
        continue;
      }
      // Overflow: skip following digits.
      overflow = true;
      while (isdigit(*++p)) {}
      break;
    }

    // The number could be a float, so check overflow below.
    switch (*p)
    {
    case '.':
      if (p[1] != '.')
        goto LscanReal;
      break;
    case 'L':
      if (p[1] != 'i')
        break;
    case 'i', 'f', 'F', 'e', 'E':
      goto LscanReal;
    default:
    }

    if (overflow)
      error(MID.OverflowDecimalNumber);

    assert((isdigit(p[-1]) || p[-1] == '_') && !isdigit(*p) && *p != '_');
    goto Lfinalize;

  LscanHex:
    assert(digits == 0);
    assert(*p == 'x');
    while (1)
    {
      if (*++p == '_')
        continue;
      if (!ishexad(*p))
        break;
      ++digits;
      ulong_ *= 16;
      if (*p <= '9')
        ulong_ += *p - '0';
      else if (*p <= 'F')
        ulong_ += *p - 'A' + 10;
      else
        ulong_ += *p - 'a' + 10;
    }

    assert(ishexad(p[-1]) || p[-1] == '_' || p[-1] == 'x');
    assert(!ishexad(*p) && *p != '_');

    switch (*p)
    {
    case '.':
      if (p[1] == '.')
        break;
    case 'p', 'P':
      return scanHexReal(t);
    default:
    }

    if (digits == 0)
      error(MID.NoDigitsInHexNumber);
    else if (digits > 16)
      error(MID.OverflowHexNumber);

    goto Lfinalize;

  LscanBin:
    assert(digits == 0);
    assert(*p == 'b');
    while (1)
    {
      if (*++p == '0')
      {
        ++digits;
        ulong_ *= 2;
      }
      else if (*p == '1')
      {
        ++digits;
        ulong_ *= 2;
        ulong_ += *p - '0';
      }
      else if (*p == '_')
        continue; 
      else
        break;
    }

    if (digits == 0)
      error(MID.NoDigitsInBinNumber);
    else if (digits > 64)
      error(MID.OverflowBinaryNumber);

    assert(p[-1] == '0' || p[-1] == '1' || p[-1] == '_', p[-1] ~ "");
    assert( !(*p == '0' || *p == '1' || *p == '_') );
    goto Lfinalize;

  LscanOct:
    assert(*p == '_' || isoctal(*p));
    if (*p != '_')
      goto Lenter_loop_oct;
    while (1)
    {
      if (*++p == '_')
        continue;
      if (!isoctal(*p))
        break;
    Lenter_loop_oct:
      if (ulong_ < ulong.max/2 || (ulong_ == ulong.max/2 && *p <= '1'))
      {
        ulong_ *= 8;
        ulong_ += *p - '0';
        ++p;
        continue;
      }
      // Overflow: skip following digits.
      overflow = true;
      while (isdigit(*++p)) {}
      break;
    }

    bool hasDecimalDigits;
    if (isdigit(*p))
    {
      hasDecimalDigits = true;
      while (isdigit(*++p)) {}
    }

    // The number could be a float, so check errors below.
    switch (*p)
    {
    case '.':
      if (p[1] != '.')
        goto LscanReal;
      break;
    case 'L':
      if (p[1] != 'i')
        break;
    case 'i', 'f', 'F', 'e', 'E':
      goto LscanReal;
    default:
    }

    if (hasDecimalDigits)
      error(MID.OctalNumberHasDecimals);
    if (overflow)
      error(MID.OverflowOctalNumber);
//     goto Lfinalize;

  Lfinalize:
    enum Suffix
    {
      None     = 0,
      Unsigned = 1,
      Long     = 2
    }

    Suffix suffix;
    while (1)
    {
      switch (*p)
      {
      case 'L':
        if (suffix & Suffix.Long)
          break;
        suffix |= Suffix.Long;
        ++p;
        continue;
      case 'u', 'U':
        if (suffix & Suffix.Unsigned)
          break;
        suffix |= Suffix.Unsigned;
        ++p;
        continue;
      default:
        break;
      }
      break;
    }

    switch (suffix)
    {
    case Suffix.None:
      if (ulong_ & 0x8000000000000000)
      {
        if (isDecimal)
          error(MID.OverflowDecimalSign);
        t.type = TOK.Uint64;
      }
      else if (ulong_ & 0xFFFFFFFF00000000)
        t.type = TOK.Int64;
      else if (ulong_ & 0x80000000)
        t.type = isDecimal ? TOK.Int64 : TOK.Uint32;
      else
        t.type = TOK.Int32;
      break;
    case Suffix.Unsigned:
      if (ulong_ & 0xFFFFFFFF00000000)
        t.type = TOK.Uint64;
      else
        t.type = TOK.Uint32;
      break;
    case Suffix.Long:
      if (ulong_ & 0x8000000000000000)
      {
        if (isDecimal)
          error(MID.OverflowDecimalSign);
        t.type = TOK.Uint64;
      }
      else
        t.type = TOK.Int64;
      break;
    case Suffix.Unsigned | Suffix.Long:
      t.type = TOK.Uint64;
      break;
    default:
      assert(0);
    }
    t.ulong_ = ulong_;
    t.end = p;
    return;
  LscanReal:
    scanReal(t);
    return;
  }

  /*
    FloatLiteral:= Float[fFL]?i?
    Float:= DecFloat | HexFloat
    DecFloat:= ([0-9][0-9_]*[.][0-9_]*DecExponent?) | [.][0-9][0-9_]*DecExponent? | [0-9][0-9_]*DecExponent
    DecExponent:= [eE][+-]?[0-9][0-9_]*
    HexFloat:= 0[xX](HexDigits[.]HexDigits | [.][0-9a-zA-Z]HexDigits? | HexDigits)HexExponent
    HexExponent:= [pP][+-]?[0-9][0-9_]*
  */
  void scanReal(ref Token t)
  {
    if (*p == '.')
      // This function was called by scan() or scanNumber().
      while (isdigit(*++p) || *p == '_') {}
    else
    {
      // This function was called by scanNumber().
      debug switch (*p)
      {
      case 'L':
        if (p[1] != 'i')
          assert(0);
      case 'i', 'f', 'F', 'e', 'E': break;
      default: assert(0);
      }
    }

    // Scan exponent.
    if (*p == 'e' || *p == 'E')
    {
      ++p;
      if (*p == '-' || *p == '+')
        ++p;
      if (!isdigit(*p))
        error(MID.FloatExpMustStartWithDigit);
      else
        while (isdigit(*++p) || *p == '_') {}
    }

    // Copy string to buffer ignoring underscores.
    char[] buffer;
    char* end = p;
    p = t.start;
    do
    {
      if (*p == '_')
      {
        ++p;
        continue;
      }
      buffer ~= *p;
      ++p;
    } while (p != end)
    buffer ~= 0;
    finalizeFloat(t, buffer);
  }

  void scanHexReal(ref Token t)
  {
    assert(*p == '.' || *p == 'p' || *p == 'P');
    MID mid;
    if (*p == '.')
      while (ishexad(*++p) || *p == '_')
      {}
    // Decimal exponent is required.
    if (*p != 'p' && *p != 'P')
    {
      mid = MID.HexFloatExponentRequired;
      goto Lerr;
    }
    // Scan exponent
    assert(*p == 'p' || *p == 'P');
    if (!isdigit(*++p))
    {
      mid = MID.HexFloatExpMustStartWithDigit;
      goto Lerr;
    }
    while (isdigit(*++p) || *p == '_')
    {}
    // Copy whole number and remove underscores from buffer.
    char[] buffer = t.start[0..p-t.start].dup;
    uint j;
    foreach (c; buffer)
      if (c != '_')
        buffer[j++] = c;
    buffer.length = j; // Adjust length.
    buffer ~= 0; // Terminate for C functions.
    finalizeFloat(t, buffer);
    return;
  Lerr:
    t.type = TOK.Float32;
    t.end = p;
    error(mid);
  }

  void finalizeFloat(ref Token t, string buffer)
  {
    assert(buffer[$-1] == 0);
    // Float number is well-formed. Check suffixes and do conversion.
    switch (*p)
    {
    case 'f', 'F':
      t.type = TOK.Float32;
      t.float_ = strtof(buffer.ptr, null);
      ++p;
      break;
    case 'L':
      t.type = TOK.Float80;
      t.real_ = strtold(buffer.ptr, null);
      ++p;
      break;
    default:
      t.type = TOK.Float64;
      t.double_ = strtod(buffer.ptr, null);
      break;
    }
    if (*p == 'i')
    {
      ++p;
      t.type += 3; // Switch to imaginary counterpart.
    }
    if (errno() == ERANGE)
      error(MID.OverflowFloatNumber);
    t.end = p;
  }

  /// Scan special token: #line Integer [Filespec] EndOfLine
  void scanSpecialTokenSequence(ref Token t)
  {
    assert(*p == '#');

    t.type = TOK.HashLine;

    MID mid;

    ++p;
    if (p[0] != 'l' || p[1] != 'i' || p[2] != 'n' || p[3] != 'e')
    {
      mid = MID.ExpectedIdentifierSTLine;
      goto Lerr;
    }
    p += 3;

    // TODO: #line58"path/file" is legal. Require spaces?
    //       State.Space could be used for that purpose.
    enum State
    { /+Space,+/ Integer, Filespec, End }

    State state = State.Integer;

  Loop:
    while (1)
    {
      switch (*++p)
      {
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n', 0, _Z_:
        break Loop;
      case LS[0]:
        if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
        {
          ++p; ++p;
          break Loop;
        }
        goto default;
      default:
        if (isspace(*p))
          continue;
        if (state == State.Integer)
        {
          if (!isdigit(*p))
          {
            mid = MID.ExpectedIntegerAfterSTLine;
            goto Lerr;
          }
          t.line_num = new Token;
          scan(*t.line_num);
          if (t.line_num.type != TOK.Int32 && t.line_num.type != TOK.Uint32)
          {
            mid = MID.ExpectedIntegerAfterSTLine;
            goto Lerr;
          }
          --p; // Go one back because scan() advanced p past the integer.
          state = State.Filespec;
        }
        else if (state == State.Filespec)
        {
          if (*p != '"')
          {
            mid = MID.ExpectedFilespec;
            goto Lerr;
          }
          t.line_filespec = new Token;
          t.line_filespec.start = p;
          t.line_filespec.type = TOK.Filespec;
          while (1)
          {
            switch (*++p)
            {
            case '"':
              break;
            case LS[0]:
              if (!(p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2])))
                goto default;
            case '\r', '\n', 0, _Z_:
              mid = MID.UnterminatedFilespec;
              t.line_filespec.end = p;
              goto Lerr;
            default:
              if (*p & 128)
                decodeUTF8();
              continue;
            }
            break; // Exit loop.
          }
          auto start = t.line_filespec.start +1; // +1 skips '"'
          t.line_filespec.str = start[0 .. p - start];
          t.line_filespec.end = p + 1;
          state = State.End;
        }
        else/+ if (state == State.End)+/
        {
          mid = MID.UnterminatedSpecialToken;
          goto Lerr;
        }
      }
    }

    if (state == State.Integer)
    {
      mid = MID.ExpectedIntegerAfterSTLine;
      goto Lerr;
    }

    this.loc_old = this.loc;
    this.loc_hline = t.line_num.uint_ - 1;
    if (t.line_filespec)
      this.fileName = t.line_filespec.str;
    t.end = p;

    return;
  Lerr:
    t.end = p;
    error(mid);
  }

  uint errorLoc()
  {
    // ∆loc + line_num_of(#line)
    return this.loc - this.loc_old + this.loc_hline;
  }

  dchar decodeUTF8()
  {
    assert(*p & 128, "check for ASCII char before calling decodeUTF8().");
    size_t idx;
    dchar d;
    try
    {
      d = std.utf.decode(p[0 .. end-p], idx);
      p += idx -1;
    }
    catch (UtfException e)
    {
      error(MID.InvalidUTF8Sequence);
      // Skip to next valid utf-8 sequence
      while (p < end && UTF8stride[*++p] != 0xFF) {}
      --p;
      assert(p < end);
    }
    return d;
  }

  void loadKeywords()
  {
    foreach(k; keywords)
      idtable[k.str] = k;
  }
/+ // Not needed anymore because tokens are stored in a linked list.
  struct State
  {
    Lexer lexer;
    Token token;
    char* scanPointer;
    int loc;
    string fileName;
    size_t errorLen;
    static State opCall(Lexer lx)
    {
      State s;
      s.lexer = lx;
      s.token = lx.token;
      s.scanPointer = lx.p;
      s.loc = lx.loc;
      s.fileName = lx.fileName;
      s.errorLen = lx.errors.length;
      return s;
    }
    void restore()
    {
      lexer.p = scanPointer;
      lexer.token = token;
      lexer.loc = loc;
      lexer.fileName = fileName;
      lexer.errors = lexer.errors[0..errorLen];
    }
  }

  State getState()
  {
    return State(this);
  }
+/

  private void scanNext(ref Token* t)
  {
    assert(t !is null);
    if (t.next)
      t = t.next;
    else if (t != this.tail)
    {
      Token* new_t = new Token;
      scan(*new_t);
      new_t.prev = t;
      t.next = new_t;
      t = new_t;
    }
  }

  void peek(ref Token* t)
  {
    scanNext(t);
  }

  TOK nextToken()
  {
    scanNext(this.token);
    return this.token.type;
  }

  void error(MID mid, ...)
  {
//     if (reportErrors)
    errors ~= new Information(InfoType.Lexer, mid, this.errorLoc, Format(_arguments, _argptr, GetMsg(mid)));
  }

  unittest
  {
    Stdout("Testing method Lexer.peek()\n");
    string sourceText = "unittest { }";
    auto lx = new Lexer(sourceText, null);

    Token* next = lx.head;
    lx.peek(next);
    assert(next.type == TOK.Unittest);
    lx.peek(next);
    assert(next.type == TOK.LBrace);
    lx.peek(next);
    assert(next.type == TOK.RBrace);
    lx.peek(next);
    assert(next.type == TOK.EOF);
  }

  Token* getTokens()
  {
    while (nextToken() != TOK.EOF)
    {}
    return head;
  }

  static bool isNonReservedIdentifier(char[] ident)
  {
    if (ident.length == 0)
      return false;

    static Identifier[string] reserved_ids_table;
    if (reserved_ids_table is null)
      foreach(k; keywords)
        reserved_ids_table[k.str] = k;

    size_t idx = 1; // Index to the 2nd character in ident.
    dchar isFirstCharUniAlpha()
    {
      idx = 0;
      // NB: decode() could throw an Exception which would be
      // caught by the next try-catch-block.
      return isUniAlpha(std.utf.decode(ident, idx));
    }

    try
    {
      if (isidbeg(ident[0]) ||
          ident[0] & 128 && isFirstCharUniAlpha())
      {
        foreach (dchar c; ident[idx..$])
          if (!isident(c) && !isUniAlpha(c))
            return false;
      }
    }
    catch (Exception)
      return false;

    return !(ident in reserved_ids_table);
  }

  private void encodeUTF8(inout char[] str, dchar d)
  {
    char[6] b;
    assert(d > 0x7F, "check for ASCII char before calling encodeUTF8().");
    if (d < 0x800)
    {
      b[0] = 0xC0 | (d >> 6);
      b[1] = 0x80 | (d & 0x3F);
      str ~= b[0..2];
    }
    else if (d < 0x10000)
    {
      b[0] = 0xE0 | (d >> 12);
      b[1] = 0x80 | ((d >> 6) & 0x3F);
      b[2] = 0x80 | (d & 0x3F);
      str ~= b[0..3];
    }
    else if (d < 0x200000)
    {
      b[0] = 0xF0 | (d >> 18);
      b[1] = 0x80 | ((d >> 12) & 0x3F);
      b[2] = 0x80 | ((d >> 6) & 0x3F);
      b[3] = 0x80 | (d & 0x3F);
      str ~= b[0..4];
    }
    else if (d < 0x4000000)
    {
      b[0] = 0xF8 | (d >> 24);
      b[1] = 0x80 | ((d >> 18) & 0x3F);
      b[2] = 0x80 | ((d >> 12) & 0x3F);
      b[3] = 0x80 | ((d >> 6) & 0x3F);
      b[4] = 0x80 | (d & 0x3F);
      str ~= b[0..5];
    }
    else if (d < 0x80000000)
    {
      b[0] = 0xFC | (d >> 30);
      b[1] = 0x80 | ((d >> 24) & 0x3F);
      b[2] = 0x80 | ((d >> 18) & 0x3F);
      b[3] = 0x80 | ((d >> 12) & 0x3F);
      b[4] = 0x80 | ((d >> 6) & 0x3F);
      b[5] = 0x80 | (d & 0x3F);
      str ~= b[0..6];
    }
    else
      error(MID.InvalidUnicodeCharacter);
  }
}

unittest
{
  Stdout("Testing Lexer.\n");
  string[] toks = [
    ">",    ">=", ">>",  ">>=", ">>>", ">>>=", "<",   "<=",  "<>",
    "<>=",  "<<", "<<=", "!",   "!<",  "!>",   "!<=", "!>=", "!<>",
    "!<>=", ".",  "..",  "...", "&",   "&&",   "&=",  "+",   "++",
    "+=",   "-",  "--",  "-=",  "=",   "==",   "~",   "~=",  "*",
    "*=",   "/",  "/=",  "^",   "^=",  "%",    "%=",  "(",   ")",
    "[",    "]",  "{",   "}",   ":",   ";",    "?",   ",",   "$"
  ];

  char[] src;

  foreach (op; toks)
    src ~= op ~ " ";

  auto lx = new Lexer(src, "");
  auto token = lx.getTokens();

  uint i;
  assert(token == lx.head);
  token = token.next;
  do
  {
    assert(i < toks.length);
    assert(token.srcText == toks[i], Format("Scanned '{0}' but expected '{1}'", token.srcText, toks[i]));
    ++i;
    token = token.next;
  } while (token.type != TOK.EOF)
}

unittest
{
  // Numbers unittest
  // 0L 0ULi 0_L 0_UL 0x0U 0x0p2 0_Fi 0_e2 0_F 0_i
  // 0u 0U 0uL 0UL 0L 0LU 0Lu
  // 0Li 0f 0F 0fi 0Fi 0i
  // 0b_1_LU 0b1000u
  // 0x232Lu
}

/// ASCII character properties table.
static const int ptable[256] = [
 0, 0, 0, 0, 0, 0, 0, 0, 0,32, 0,32,32, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
32, 0, 0x2200, 0, 0, 0, 0, 0x2700, 0, 0, 0, 0, 0, 0, 0, 0,
 7, 7, 7, 7, 7, 7, 7, 7, 6, 6, 0, 0, 0, 0, 0, 0x3f00,
 0,12,12,12,12,12,12, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0x5c00, 0, 0,16,
 0, 0x70c, 0x80c,12,12,12, 0xc0c, 8, 8, 8, 8, 8, 8, 8, 0xa08, 8,
 8, 8, 0xd08, 8, 0x908, 8, 0xb08, 8, 8, 8, 8, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
];

enum CProperty
{
       Octal = 1,
       Digit = 1<<1,
         Hex = 1<<2,
       Alpha = 1<<3,
  Underscore = 1<<4,
  Whitespace = 1<<5
}

const uint EVMask = 0xFF00; // Bit mask for escape value

private alias CProperty CP;
int isoctal(char c) { return ptable[c] & CP.Octal; }
int isdigit(char c) { return ptable[c] & CP.Digit; }
int ishexad(char c) { return ptable[c] & CP.Hex; }
int isalpha(char c) { return ptable[c] & CP.Alpha; }
int isalnum(char c) { return ptable[c] & (CP.Alpha | CP.Digit); }
int isidbeg(char c) { return ptable[c] & (CP.Alpha | CP.Underscore); }
int isident(char c) { return ptable[c] & (CP.Alpha | CP.Underscore | CP.Digit); }
int isspace(char c) { return ptable[c] & CP.Whitespace; }
int char2ev(char c) { return ptable[c] >> 8; /*(ptable[c] & EVMask) >> 8;*/ }

version(gen_ptable)
static this()
{
  alias ptable p;
  // Initialize character properties table.
  for (int i; i < p.length; ++i)
  {
    p[i] = 0;
    if ('0' <= i && i <= '7')
      p[i] |= CP.Octal;
    if ('0' <= i && i <= '9')
      p[i] |= CP.Digit;
    if (isdigit(i) || 'a' <= i && i <= 'f' || 'A' <= i && i <= 'F')
      p[i] |= CP.Hex;
    if ('a' <= i && i <= 'z' || 'A' <= i && i <= 'Z')
      p[i] |= CP.Alpha;
    if (i == '_')
      p[i] |= CP.Underscore;
    if (i == ' ' || i == '\t' || i == '\v' || i == '\f')
      p[i] |= CP.Whitespace;
  }
  // Store escape sequence values in second byte.
  assert(CProperty.max <= ubyte.max, "character property flags and escape value byte overlap.");
  p['\''] |= 39 << 8;
  p['"'] |= 34 << 8;
  p['?'] |= 63 << 8;
  p['\\'] |= 92 << 8;
  p['a'] |= 7 << 8;
  p['b'] |= 8 << 8;
  p['f'] |= 12 << 8;
  p['n'] |= 10 << 8;
  p['r'] |= 13 << 8;
  p['t'] |= 9 << 8;
  p['v'] |= 11 << 8;
  // Print a formatted array literal.
  char[] array = "[\n";
  for (int i; i < p.length; ++i)
  {
    int c = p[i];
    array ~= std.string.format(c>255?" 0x%x,":"%2d,", c, ((i+1) % 16) ? "":"\n");
  }
  array[$-2..$] = "\n]";
  writefln(array);
}
