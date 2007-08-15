/++
  Author: Aziz Köksal
  License: GPL3
+/
module Lexer;
import Token;
import Information;
import Keywords;
import Identifier;
import Messages;
import HtmlEntities;
import std.stdio;
import std.utf;
import std.uni;
import std.c.stdlib;
import std.string;

const char[3] LS = \u2028;
const char[3] PS = \u2029;

const dchar LSd = 0x2028;
const dchar PSd = 0x2029;

const uint _Z_ = 26; /// Control+Z

class Lexer
{
  Token* head; /// The head of the doubly linked token list.
  Token* token; /// Points to the current token in the token list.
  string text;
  char* p; /// Points to the current character in the source text.
  char* end; /// Points one character past the end of the source text.

  uint loc = 1; /// line of code

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
  }

  public void scan(out Token t)
  in
  {
    assert(text.ptr <= p && p < end);
  }
  out
  {
    assert(text.ptr <= t.start && t.start < end);
    assert(text.ptr < t.end && t.end <= end, std.string.format(t.type));
  }
  body
  {
    uint c = *p;

    while (1)
    {
      t.start = p;

      if (c == 0 || c == _Z_)
      {
        assert(*p == 0 || *p == _Z_);
        t.type = TOK.EOF;
        t.end = p;
        assert(t.start == t.end);
        return;
      }

      if (c == '\n')
      {
        c = *++p;
        ++loc;
        continue;
      }
      else if (c == '\r')
      {
        c = *++p;
        if (c != '\n')
          ++loc;
        continue;
      }
      else if (c == LS[0] && p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
      {
        p += 3;
        c = *p;
        continue;
      }

      if (isidbeg(c))
      {
        if (c == 'r' && p[1] == '"' && ++p)
          return scanRawStringLiteral(t);
        if (c == 'x' && p[1] == '"')
          return scanHexStringLiteral(t);
      Lidentifier:
        do
        { c = *++p; }
        while (isident(c) || c & 128 && isUniAlpha(decodeUTF8()))

        t.end = p;

        string str = t.srcText;
        Identifier* id = str in idtable;

        if (!id)
        {
          idtable[str] = Identifier.Identifier(TOK.Identifier, str);
          id = str in idtable;
        }
        assert(id);
        t.type = id.type;
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
          ++p;
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
        scanSpecialToken();
        c = *p;
        continue;
      default:
      }

      if (c & 128 && isUniAlpha(decodeUTF8()))
        goto Lidentifier;
      c = *++p;
    }
  }

  void scanNormalStringLiteral(ref Token t)
  {
    assert(*p == '"');
    ++p;
    char[] buffer;
    t.type = TOK.String;
    while (1)
    {
      switch (*p)
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
        ++p;
        dchar d = scanEscapeSequence();
        if (d < 128)
          buffer ~= d;
        else
          encodeUTF8(buffer, d);
        continue;
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        ++p;
        ++loc;
        buffer ~= '\n'; // Convert EndOfLine to \n.
        continue;
      case 0, _Z_:
        error(MID.UnterminatedString);
        goto Lreturn;
      default:
        if (*p & 128)
        {
//           char* begin = p;
          dchar d = decodeUTF8();
          if (d == LSd || d == PSd)
            goto case '\n';

          // We don't copy per pointer because we might include
          // invalid, skipped utf-8 sequences. See decodeUTF8().
//           ++p;
//           buffer ~= begin[0 .. p - begin];
          ++p;
          encodeUTF8(buffer, d);
          continue;
        }
        // Copy ASCII character.
        buffer ~= *p++;
      }
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
      ++p;
      switch (*p)
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
        c = '\n'; // Convert '\r' and '\r\n' to '\n'
      case '\n':
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
      case LS[0]:
        if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
        {
          c = '\n';
          ++p; ++p;
          ++loc;
        }
        break;
      case 0, _Z_:
        if (delim == 'r')
          error(MID.UnterminatedRawString);
        else
          error(MID.UnterminatedBackQuoteString);
        goto Lreturn;
      default:
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

        if (c >= 128)
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

  dchar scanEscapeSequence()
  {
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
            ++p;
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
        error(MID.UndefinedEscapeSequence);
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
    case '_':
      ++p;
      goto LscanOct;
    default:
      if (isoctal(*p))
        goto LscanOct;
    }

    ulong_ = p[-1];
    isDecimal = true;
    goto Lfinalize;

  LscanInteger:
    isDecimal = true;
    while (1)
    {
      if (*++p == '_')
        continue;
      if (!isdigit(*p))
        break;
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

    switch (*p)
    {
    case '.':
      if (p[1] != '.')
        goto LscanHexReal;
      break;
    case 'L':
      if (p[1] != 'i')
        break;
    case 'i', 'p', 'P':
      goto LscanHexReal;
    default:
    }
    if (digits == 0)
      error(MID.NoDigitsInHexNumber);
    else if (digits > 16)
    {
      // Overflow: skip following digits.
      error(MID.OverflowHexNumber);
      while (ishexad(*++p)) {}
    }
    goto Lfinalize;
  LscanHexReal:
    return scanHexReal(t);

  LscanBin:
    assert(digits == 0);
    while (1)
    {
      if (*++p == '0')
      {
        ++digits;
        ulong_ *= 2;
      }
      if (*p == '1')
      {
        ++digits;
        ulong_ *= 2;
        ulong_ += *p - '0';
      }
      if (*p == '_')
        continue;
      break;
    }

    if (digits == 0)
      error(MID.NoDigitsInBinNumber);

    if (digits > 64)
      error(MID.OverflowBinaryNumber);
    assert((p[-1] == '0' || p[-1] == '1' || p[-1] == '_') && !(*p == '0' || *p == '1' || *p == '_'));
    goto Lfinalize;

  LscanOct:
    while (1)
    {
      if (*++p == '_')
        continue;
      if (!isoctal(*p))
        break;
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
        error(MID.FloatExponentDigitExpected);
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
    assert(*p == '.' || *p == 'i' || *p == 'p' || *p == 'P' || (*p == 'L' && p[1] == 'i'));
    MID mid;
    if (*p == '.')
      while (ishexad(*++p) || *p == '_') {}
    if (*p != 'p' && *p != 'P')
    {
      mid = MID.HexFloatExponentRequired;
      goto Lerr;
    }
    // Copy mantissa to a buffer ignoring underscores.
    char* end = p;
    p = t.start;
    char[] buffer;
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

    assert(p == end && (*p == 'p' || *p == 'P'));
    // Scan and copy the exponent.
    buffer ~= 'p';
    size_t bufflen = buffer.length;
    while (1)
    {
      if (*++p == '_')
        continue;
      if (isdigit(*p))
        buffer ~= *p;
      else
        break;
    }
    // When the buffer length hasn't changed, no digits were copied.
    if (bufflen == buffer.length) {
      mid = MID.HexFloatMissingExpDigits;
      goto Lerr;
    }
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
    if (getErrno == ERANGE)
      error(MID.OverflowFloatNumber);
    t.end = p;
  }

  /// Scan special token: #line Integer [Filespec] EndOfLine
  // TODO: Handle case like: #line 0 #line 2
  void scanSpecialToken()
  {
    assert(*p == '#');

    ++p;
    MID mid;
    Token* t;
    uint oldloc = this.loc, newloc;

    peek(t);
    if (!(this.loc == oldloc && p == t.start && t.type == TOK.Identifier && t.srcText == "line"))
    {
      this.loc = oldloc; // reset this.loc because we took a peek at the next token
      mid = MID.ExpectedIdentifierSTLine;
      goto Lerr;
    }
    p = t.end; // consume token

    peek(t);
    if (this.loc == oldloc && t.type == TOK.Int32)
    {
      newloc = t.uint_ - 1;
      p = t.end;
    }
    else
    {
      this.loc = oldloc;
      mid = MID.ExpectedNumberAfterSTLine;
      goto Lerr;
    }

    peek(t);
    if (this.loc != oldloc)
    {
      this.loc = oldloc;
      mid = MID.NewlineInSpecialToken;
      goto Lerr;
    }
    if (t.type == TOK.String)
    {
      if (*t.start != '"')
      {
        mid = MID.ExpectedNormalStringLiteral;
        goto Lerr;
      }
      fileName = t.srcText[1..$-1]; // contents of "..."
      p = t.end;
    }
    else if (t.type == TOK.Identifier && t.srcText == "__FILE__")
    {
      p = t.end;
    }
/+
    peek(t);
    if (this.loc == oldloc && t.type != TOK.EOF)
    {
      mid = MID.UnterminatedSpecialToken;
      goto Lerr;
    }
+/
    while (1)
    {
      switch (*p)
      {
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        ++p;
        break;
      case LS[0]:
        if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
        {
          p += 2;
          break;
        }
      case 0, _Z_:
        break;
      default:
        if (isspace(*p)) {
          ++p;
          continue;
        }
        mid = MID.UnterminatedSpecialToken;
        goto Lerr;
      }
      break;
    }

    this.loc = newloc;
    return;
  Lerr:
    error(mid);
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
      while (UTF8stride[*++p] != 0xFF) {}
      --p;
    }
    return d;
  }

  void loadKeywords()
  {
    foreach(k; keywords)
      idtable[k.str] = k;
  }
/+
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
    else if (t.type != TOK.EOF)
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

  void error(MID id, ...)
  {
//     if (reportErrors)
    errors ~= new Information(InfoType.Lexer, id, loc, arguments(_arguments, _argptr));
  }

  unittest
  {
    string sourceText = "unittest { }";
    auto lx = new Lexer(sourceText, null);

    Token next;
    lx.peek(next);
    assert(next == TOK.Unittest);
    lx.peek(next);
    assert(next == TOK.LBrace);
    lx.peek(next);
    assert(next == TOK.RBrace);
    lx.peek(next);
    assert(next == TOK.EOF);
    writefln("end of peek() unittest");
  }

  Token* getTokens()
  {
    while (nextToken() != TOK.EOF)
    {}
    return head;
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
  auto tokens = lx.getTokens();

  tokens = tokens[0..$-1]; // exclude TOK.EOF

  assert(tokens.length == toks.length );

  foreach (i, t; tokens)
    assert(t.srcText == toks[i], std.string.format("Lexed '%s' but expected '%s'", t.srcText, toks[i]));
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
