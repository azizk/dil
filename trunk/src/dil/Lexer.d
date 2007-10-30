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
import dil.CompilerInfo;
import tango.stdc.stdlib : strtof, strtod, strtold;
import tango.stdc.errno : errno, ERANGE;
import tango.stdc.time : time_t, time, ctime;
import tango.stdc.string : strlen;
import std.utf;
import std.uni;
import common;

const char[3] LS = \u2028; /// Line separator.
const char[3] PS = \u2029; /// Paragraph separator.

const dchar LSd = 0x2028;
const dchar PSd = 0x2029;

/// U+FFFD = �. Used to replace invalid Unicode characters.
const dchar REPLACEMENT_CHAR = '\uFFFD';

const uint _Z_ = 26; /// Control+Z

class Lexer
{
  Token* head; /// The head of the doubly linked token list.
  Token* tail; /// The tail of the linked list. Set in scan().
  Token* token; /// Points to the current token in the token list.
  string text; /// The source text.
  char[] filePath; /// Path to the source file.
  char* p; /// Points to the current character in the source text.
  char* end; /// Points one character past the end of the source text.

  // Members used for error messages:
  Information[] errors;
  char* lineBegin; /// Always points to the beginning of the current line.
  uint loc = 1; /// Actual line of code.
  uint loc_hline; /// Line number set by #line.
  uint inTokenString; /// > 0 if inside q{ }
  Location errorLoc;

  Identifier[string] idtable;

  version(token2LocTable)
    /// Maps every token that starts a new line to a Location.
    Location[Token*] token2LocTable;

  this(string text, string filePath)
  {
    this.filePath = filePath;

    this.text = text;
    if (text.length == 0 || text[$-1] != 0)
    {
      this.text.length = this.text.length + 1;
      this.text[$-1] = 0;
    }

    this.p = this.text.ptr;
    this.end = this.p + this.text.length;
    this.lineBegin = this.p;
    this.errorLoc = new Location(filePath, 1, this.lineBegin, this.lineBegin);
    loadKeywords(this.idtable);

    this.head = new Token;
    this.head.type = TOK.HEAD;
    this.token = this.head;
    scanShebang();
  version(token2LocTable)
  {
    // Add first token to table.
    auto firstToken = this.head;
    peek(firstToken);
    token2LocTable[firstToken] = new Location(1, null);
  }
  }

  ~this()
  {
    auto token = head.next;
    while (token !is null)
    {
      assert(token.type == TOK.EOF ? token == tail && token.next is null : 1);
      delete token.prev;
      token = token.next;
    }
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
      assert(*p == '!');
      while (1)
      {
        t.end = ++p;
        switch (*p)
        {
        case '\r', '\n', 0, _Z_:
          break;
        case LS[0]:
          if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
            break;
        default:
          if (*p & 128)
            decodeUTF8();
          continue;
        }
        break; // Exit loop.
      }
      // Reset p. The newline will be scanned as whitespace in scan().
      p = t.end;
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
      t.str = this.errorLoc.filePath;
      break;
    case TOK.LINE:
      t.uint_ = this.errorLineNum(this.loc);
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

  void setLineBegin(char* p)
  {
    // Check that we can look behind one character.
    assert((p-1) >= text.ptr && p < end);
    // Check that previous character is a newline.
    assert(p[-1] == '\n' ||  p[-1] == '\r' ||
           p[-1] == LS[2] || p[-1] == PS[2]);
    this.lineBegin = p;
  }

  private void scanNext(bool rescan)(ref Token* t)
  {
    assert(t !is null);
    if (t.next)
    {
      t = t.next;
      static if (rescan == true)
        rescanNewlines(*t);
    }
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
    scanNext!(false)(t);
  }

  TOK nextToken()
  {
    scanNext!(true)(this.token);
    return this.token.type;
  }

  void rescanNewlines(ref Token t)
  {
    auto p = t.ws;
    auto end = t.start;

    if (p !is null)
    {
      assert(end !is null);
      // Scan preceding whitespace for newlines.
      do
      {
        switch (*p)
        {
        case '\r':
          if (p[1] == '\n')
            ++p;
        case '\n':
          ++loc;
          setLineBegin(p + 1);
          break;
        case LS[0]:
          assert(p+2 < end && p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]));
          ++p; ++p;
          ++loc;
          setLineBegin(p + 1);
          break;
        default:
          assert(isspace(*p));
        }
        ++p;
      } while (p < end)
    }

    if (t.type == TOK.String && t.start[0] != '\\' ||
        t.type == TOK.Comment && t.start[1] != '/')
    {
      // String literals and comments are the only tokens that can have
      // newlines.
      p = t.start;
      end = t.end;
      assert(p !is null && end !is null);
      do
      {
        switch (*p)
        {
        case '\r':
          if (p[1] == '\n')
            ++p;
        case '\n':
          ++loc;
          setLineBegin(p + 1);
          break;
        case LS[0]:
          if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
          {
            ++p; ++p;
            ++loc;
            setLineBegin(p + 1);
            break;
          }
        default:
        }
        ++p;
      } while (p < end)
    }
    else
    {
      if (t.type == TOK.HashLine)
        evaluateHashLine(t);

      assert(delegate() {
          p = t.start;
          end = t.end;
          while (p < end)
          {
            if (*p == '\n' || *p == '\r' ||
                (p+2) < end && *p == LS[0] && p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
              return false;
            ++p;
          }
          return true;
        }() == true, "Token '" ~ t.srcText ~ "' has unexpected newline."
      );
    }
  }

  struct LocState
  {
    char[] filePath;
    uint loc;
    uint loc_hline;
    char* lineBegin;
  }

  LocState getState()
  {
    LocState s;
    s.filePath = this.errorLoc.filePath;
    s.lineBegin = this.lineBegin;
    s.loc_hline = this.loc_hline;
    s.loc = this.loc;
    return s;
  }

  void restoreState(LocState s)
  {
    if (s.lineBegin == this.lineBegin)
      return;
    assert(s.loc != this.loc);
    this.errorLoc.setFilePath(s.filePath);
    this.lineBegin = s.lineBegin;
    this.loc = s.loc;
    this.loc_hline = s.loc_hline;
  }

  public void scan_(out Token t)
  in
  {
    assert(text.ptr <= p && p < end);
  }
  out
  {
    assert(text.ptr <= t.start && t.start < end, Token.toString(t.type));
    assert(text.ptr <= t.end && t.end <= end, Token.toString(t.type));
  }
  body
  {
    // Scan whitespace.
    auto pws = p;
    auto old_loc = this.loc;
    while (1)
    {
      switch (*p)
      {
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        assert(*p == '\n' || *p == '\r' || *p == LS[2] || *p == PS[2]);
        ++p;
        ++loc;
        setLineBegin(p);
        continue;
      case LS[0]:
        if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
        {
          ++p; ++p;
          goto case '\n';
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
    {
      t.ws = pws;
      if (old_loc != this.loc)
        version(token2LocTable)
          token2LocTable[&t] = new Location(loc, null);
    }

    // Scan token.
    uint c = *p;
    {
      t.start = p;

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
        if (t.type == TOK.Identifier)
          return;
        if (t.type == TOK.EOF)
        {
          t.type = TOK.EOF;
          t.end = p;
          tail = &t;
          assert(t.srcText == "__EOF__");
        }
        else if (t.isSpecialToken)
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
          return scanNestedComment(t);
        case '*':
          return scanBlockComment(t);
        case '/':
          while (1)
          {
            c = *++p;
            switch (c)
            {
            case '\r', '\n', 0, _Z_:
              break;
            case LS[0]:
              if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
                break;
            default:
              if (c & 128)
                decodeUTF8();
              continue;
            }
            break; // Exit loop.
          }
          t.type = TOK.Comment;
          t.end = p;
          return;
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

      // Check for EOF
      if (c == 0 || c == _Z_)
      {
        assert(*p == 0 || *p == _Z_);
        t.type = TOK.EOF;
        t.end = p;
        tail = &t;
        assert(t.start == t.end);
        return;
      }

      if (c & 128)
      {
        c = decodeUTF8();
        if (isUniAlpha(c))
          goto Lidentifier;
      }

      error(t.start, MID.IllegalCharacter, cast(dchar)c);

      ++p;
      t.type = TOK.Illegal;
      t.dchar_ = c;
      t.end = p;
      return;
    }
  }

  template toUint(char[] T)
  {
    static assert(0 < T.length && T.length <= 4);
    static if (T.length == 1)
      const uint toUint = T[0];
    else
      const uint toUint = (T[0] << ((T.length-1)*8)) | toUint!(T[1..$]);
  }
  static assert(toUint!("\xAA\xBB\xCC\xDD") == 0xAABBCCDD);

  // Can't use this yet due to a bug in DMD (bug id=1534).
  template case_(char[] str, TOK tok, char[] label)
  {
    const char[] case_ =
      `case `~toUint!(str).stringof~`:

         goto `~label~`;`;
  }

  template case_L4(char[] str, TOK tok)
  {
    const char[] case_L4 = case_!(str, tok, "Lcommon_4");
  }

  template case_L3(char[] str, TOK tok)
  {
    const char[] case_L3 = case_!(str, tok, "Lcommon_3");
  }

  template case_L2(char[] str, TOK tok)
  {
    const char[] case_L2 = case_!(str, tok, "Lcommon_2");
  }

  template case_L1(char[] str, TOK tok)
  {
    const char[] case_L3 = case_!(str, tok, "Lcommon");
  }

  public void scan(out Token t)
  in
  {
    assert(text.ptr <= p && p < end);
  }
  out
  {
    assert(text.ptr <= t.start && t.start < end, Token.toString(t.type));
    assert(text.ptr <= t.end && t.end <= end, Token.toString(t.type));
  }
  body
  {
    // Scan whitespace.
    auto pws = p;
    auto old_loc = this.loc;
    while (1)
    {
      switch (*p)
      {
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        assert(*p == '\n' || *p == '\r' || *p == LS[2] || *p == PS[2]);
        ++p;
        ++loc;
        setLineBegin(p);
        continue;
      case LS[0]:
        if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
        {
          ++p; ++p;
          goto case '\n';
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
    {
      t.ws = pws;
      if (old_loc != this.loc)
        version(token2LocTable)
          token2LocTable[&t] = new Location(loc, null);
    }

    // Scan token.
    t.start = p;

    uint c = *p;
    assert(end - p != 0);
    switch (end - p)
    {
    case 1:
      goto L1character;
    case 2:
      c <<= 8; c |= p[1];
      goto L2characters;
    case 3:
      c <<= 8; c |= p[1]; c <<= 8; c |= p[2];
      goto L3characters;
    default:
      version(BigEndian)
        c = *cast(uint*)p;
      else
      {
        c <<= 8; c |= p[1]; c <<= 8; c |= p[2]; c <<= 8; c |= p[3];
        /+
        c = *cast(uint*)p;
        asm
        {
          mov EDX, c;
          bswap EDX;
          mov c, EDX;
        }
        +/
      }
    }

    // 4 character tokens.
    switch (c)
    {
    case toUint!(">>>="):
      t.type = TOK.RShiftAssign;
      goto Lcommon_4;
    case toUint!("!<>="):
      t.type = TOK.Unordered;
    Lcommon_4:
      p += 4;
      t.end = p;
      return;
    default:
    }

    c >>>= 8;
  L3characters:
    assert(p == t.start);
    // 3 character tokens.
    switch (c)
    {
    case toUint!(">>="):
      t.type = TOK.RShiftAssign;
      goto Lcommon_3;
    case toUint!(">>>"):
      t.type = TOK.URShift;
      goto Lcommon_3;
    case toUint!("<>="):
      t.type = TOK.LorEorG;
      goto Lcommon_3;
    case toUint!("<<="):
      t.type = TOK.LShiftAssign;
      goto Lcommon_3;
    case toUint!("!<="):
      t.type = TOK.UorG;
      goto Lcommon_3;
    case toUint!("!>="):
      t.type = TOK.UorL;
      goto Lcommon_3;
    case toUint!("!<>"):
      t.type = TOK.UorE;
      goto Lcommon_3;
    case toUint!("..."):
      t.type = TOK.Ellipses;
    Lcommon_3:
      p += 3;
      t.end = p;
      return;
    default:
    }

    c >>>= 8;
  L2characters:
    assert(p == t.start);
    // 2 character tokens.
    switch (c)
    {
    case toUint!("/+"):
      ++p; // Skip /
      return scanNestedComment(t);
    case toUint!("/*"):
      ++p; // Skip /
      return scanBlockComment(t);
    case toUint!("//"):
      ++p; // Skip /
      assert(*p == '/');
      while (1)
      {
        c = *++p;
        switch (c)
        {
        case '\r', '\n', 0, _Z_:
          break;
        case LS[0]:
          if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
            break;
        default:
          if (c & 128)
            decodeUTF8();
          continue;
        }
        break; // Exit loop.
      }
      t.type = TOK.Comment;
      t.end = p;
      return;
    case toUint!(">="):
      t.type = TOK.GreaterEqual;
      goto Lcommon_2;
    case toUint!(">>"):
      t.type = TOK.RShift;
      goto Lcommon_2;
    case toUint!("<<"):
      t.type = TOK.LShift;
      goto Lcommon_2;
    case toUint!("<="):
      t.type = TOK.LessEqual;
      goto Lcommon_2;
    case toUint!("<>"):
      t.type = TOK.LorG;
      goto Lcommon_2;
    case toUint!("!<"):
      t.type = TOK.UorGorE;
      goto Lcommon_2;
    case toUint!("!>"):
      t.type = TOK.UorLorE;
      goto Lcommon_2;
    case toUint!("!="):
      t.type = TOK.NotEqual;
      goto Lcommon_2;
    case toUint!(".."):
      t.type = TOK.Slice;
      goto Lcommon_2;
    case toUint!("&&"):
      t.type = TOK.AndLogical;
      goto Lcommon_2;
    case toUint!("&="):
      t.type = TOK.AndAssign;
      goto Lcommon_2;
    case toUint!("||"):
      t.type = TOK.OrLogical;
      goto Lcommon_2;
    case toUint!("|="):
      t.type = TOK.OrAssign;
      goto Lcommon_2;
    case toUint!("++"):
      t.type = TOK.PlusPlus;
      goto Lcommon_2;
    case toUint!("+="):
      t.type = TOK.PlusAssign;
      goto Lcommon_2;
    case toUint!("--"):
      t.type = TOK.MinusMinus;
      goto Lcommon_2;
    case toUint!("-="):
      t.type = TOK.MinusAssign;
      goto Lcommon_2;
    case toUint!("=="):
      t.type = TOK.Equal;
      goto Lcommon_2;
    case toUint!("~="):
      t.type = TOK.CatAssign;
      goto Lcommon_2;
    case toUint!("*="):
      t.type = TOK.MulAssign;
      goto Lcommon_2;
    case toUint!("/="):
      t.type = TOK.DivAssign;
      goto Lcommon_2;
    case toUint!("^="):
      t.type = TOK.XorAssign;
      goto Lcommon_2;
    case toUint!("%="):
      t.type = TOK.ModAssign;
    Lcommon_2:
      p += 2;
      t.end = p;
      return;
    default:
    }

    c >>>= 8;
  L1character:
    assert(p == t.start);
    assert(*p == c, Format("p={0},c={1}", *p, cast(dchar)c));
    // 1 character tokens.
    // TODO: consider storing the token type in ptable.
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
    case '<':
      t.type = TOK.Greater;
      goto Lcommon;
    case '>':
      t.type = TOK.Less;
      goto Lcommon;
    case '^':
      t.type = TOK.Xor;
      goto Lcommon;
    case '!':
      t.type = TOK.Not;
      goto Lcommon;
    case '.':
      if (isdigit(p[1]))
        return scanReal(t);
      t.type = TOK.Dot;
      goto Lcommon;
    case '&':
      t.type = TOK.AndBinary;
      goto Lcommon;
    case '|':
      t.type = TOK.OrBinary;
      goto Lcommon;
    case '+':
      t.type = TOK.Plus;
      goto Lcommon;
    case '-':
      t.type = TOK.Minus;
      goto Lcommon;
    case '=':
      t.type = TOK.Assign;
      goto Lcommon;
    case '~':
      t.type = TOK.Tilde;
      goto Lcommon;
    case '*':
      t.type = TOK.Mul;
      goto Lcommon;
    case '/':
      t.type = TOK.Div;
      goto Lcommon;
    case '%':
      t.type = TOK.Mod;
      goto Lcommon;
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
      t.end = p;
      return;
    case '#':
      return scanSpecialTokenSequence(t);
    default:
    }

    assert(p == t.start);
    assert(*p == c);

    // TODO: consider moving isidbeg() and isdigit() up.
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
      if (t.type == TOK.Identifier)
        return;
      if (t.type == TOK.EOF)
      {
        t.type = TOK.EOF;
        t.end = p;
        tail = &t;
        assert(t.srcText == "__EOF__");
      }
      else if (t.isSpecialToken)
        finalizeSpecialToken(t);
      return;
    }

    if (isdigit(c))
      return scanNumber(t);

    // Check for EOF
    if (c == 0 || c == _Z_)
    {
      assert(*p == 0 || *p == _Z_, *p~"");
      t.type = TOK.EOF;
      t.end = p;
      tail = &t;
      assert(t.start == t.end);
      return;
    }

    if (c & 128)
    {
      c = decodeUTF8();
      if (isUniAlpha(c))
        goto Lidentifier;
    }

    error(t.start, MID.IllegalCharacter, cast(dchar)c);

    ++p;
    t.type = TOK.Illegal;
    t.dchar_ = c;
    t.end = p;
    return;
  }

  void scanBlockComment(ref Token t)
  {
    assert(p[-1] == '/' && *p == '*');
    auto tokenLineNum = loc;
    auto tokenLineBegin = lineBegin;
    uint c;
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
        assert(*p == '\n' || *p == '\r' || *p == LS[2] || *p == PS[2]);
        ++loc;
        setLineBegin(p+1);
        continue;
      case 0, _Z_:
        error(tokenLineNum, tokenLineBegin, t.start, MID.UnterminatedBlockComment);
        goto LreturnBC;
      default:
        if (c & 128)
        {
          c = decodeUTF8();
          if (c == LSd || c == PSd)
            goto case '\n';
          continue;
        }
      }

      c <<= 8;
      c |= *++p;
      switch (c)
      {
      case toUint!("*/"):
        ++p;
      LreturnBC:
        t.type = TOK.Comment;
        t.end = p;
        return;
      default:
        c &= char.max;
        goto LswitchBC;
      }
    }
    assert(0);
  }

  void scanNestedComment(ref Token t)
  {
    assert(p[-1] == '/' && *p == '+');
    auto tokenLineNum = loc;
    auto tokenLineBegin = lineBegin;
    uint level = 1;
    uint c;
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
        assert(*p == '\n' || *p == '\r' || *p == LS[2] || *p == PS[2]);
        ++loc;
        setLineBegin(p+1);
        continue;
      case 0, _Z_:
        error(tokenLineNum, tokenLineBegin, t.start, MID.UnterminatedNestedComment);
        goto LreturnNC;
      default:
        if (c & 128)
        {
          c = decodeUTF8();
          if (c == LSd || c == PSd)
            goto case '\n';
          continue;
        }
      }

      c <<= 8;
      c |= *++p;
      switch (c)
      {
      case toUint!("/+"):
        ++level;
        continue;
      case toUint!("+/"):
        if (--level == 0)
        {
          ++p;
        LreturnNC:
          t.type = TOK.Comment;
          t.end = p;
          return;
        }
        continue;
      default:
        c &= char.max;
        goto LswitchNC;
      }
    }
    assert(0);
  }

  void scanNormalStringLiteral(ref Token t)
  {
    assert(*p == '"');
    auto tokenLineNum = loc;
    auto tokenLineBegin = lineBegin;
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
        if (c < 128)
          break;
        encodeUTF8(buffer, c);
        continue;
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        assert(*p == '\n' || *p == '\r' || *p == LS[2] || *p == PS[2]);
        ++loc;
        c = '\n'; // Convert EndOfLine to \n.
        setLineBegin(p+1);
        break;
      case 0, _Z_:
        error(tokenLineNum, tokenLineBegin, t.start, MID.UnterminatedString);
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
      assert(isascii(c));
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
    // fall through
    case '\n', '\r', 0, _Z_:
      goto Lerr;
    case LS[0]:
      if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
        goto Lerr;
    // fall through
    default:
      uint c = *p;
      if (c & 128)
      {
        c = decodeUTF8();
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
      error(t.start, id);
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
    auto tokenLineNum = loc;
    auto tokenLineBegin = lineBegin;
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
        assert(*p == '\n' || *p == '\r' || *p == LS[2] || *p == PS[2]);
        c = '\n'; // Convert EndOfLine ('\r','\r\n','\n',LS,PS) to '\n'
        ++loc;
        setLineBegin(p+1);
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
          error(tokenLineNum, tokenLineBegin, t.start, MID.UnterminatedRawString);
        else
          error(tokenLineNum, tokenLineBegin, t.start, MID.UnterminatedBackQuoteString);
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
      assert(isascii(c));
      buffer ~= c;
    }
    assert(0);
  }

  void scanHexStringLiteral(ref Token t)
  {
    assert(p[0] == 'x' && p[1] == '"');
    t.type = TOK.String;

    auto tokenLineNum = loc;
    auto tokenLineBegin = lineBegin;

    uint c;
    ubyte[] buffer;
    ubyte h; // hex number
    uint n; // number of hex digits

    ++p;
    assert(*p == '"');
    while (1)
    {
      c = *++p;
      switch (c)
      {
      case '"':
        ++p;
        if (n & 1)
          error(tokenLineNum, tokenLineBegin, t.start, MID.OddNumberOfDigitsInHexString);
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
        assert(*p == '\n' || *p == '\r' || *p == LS[2] || *p == PS[2]);
        ++loc;
        setLineBegin(p+1);
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
          continue; // Skip spaces.
        else if (c == LS[0] && p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
        {
          ++p; ++p;
          goto case '\n';
        }
        else if (c == 0 || c == _Z_)
        {
          error(tokenLineNum, tokenLineBegin, t.start, MID.UnterminatedHexString);
          t.pf = 0;
          goto Lreturn;
        }
        else
        {
          auto errorAt = p;
          if (c & 128)
            c = decodeUTF8();
          error(errorAt, MID.NonHexCharInHexString, cast(dchar)c);
        }
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

    auto tokenLineNum = loc;
    auto tokenLineBegin = lineBegin;

    char[] buffer;
    dchar opening_delim = 0, // 0 if no nested delimiter or '[', '(', '<', '{'
          closing_delim; // Will be ']', ')', '>', '},
                         // the first character of an identifier or
                         // any other Unicode/ASCII character.
    char[] str_delim; // Identifier delimiter.
    uint level = 1; // Counter for nestable delimiters.

    ++p; ++p; // Skip q"
    uint c = *p;
    switch (c)
    {
    case '(':
      opening_delim = c;
      closing_delim = ')'; // c + 1
      break;
    case '[', '<', '{':
      opening_delim = c;
      closing_delim = c + 2; // Get to closing counterpart. Feature of ASCII table.
      break;
    default:
      dchar scanNewline()
      {
        switch (*p)
        {
        case '\r':
          if (p[1] == '\n')
            ++p;
        case '\n':
          assert(*p == '\n' || *p == '\r' || *p == LS[2] || *p == PS[2]);
          ++p;
          ++loc;
          setLineBegin(p);
          return '\n';
        case LS[0]:
          if (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
          {
            ++p; ++p;
            goto case '\n';
          }
        default:
        }
        return 0;
      }

      // Skip leading newlines:
      while (scanNewline() != 0){}
      assert(*p != '\n' && *p != '\r' &&
             !(*p == LS[0] && p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2])));

      char* begin = p;
      c = *p;
      closing_delim = c;
      // TODO: Check for non-printable characters?
      if (c & 128)
      {
        closing_delim = decodeUTF8();
        if (!isUniAlpha(closing_delim))
          break; // Not an identifier.
      }
      else if (!isidbeg(c))
        break; // Not an identifier.

      // Parse Identifier + EndOfLine
      do
      { c = *++p; }
      while (isident(c) || c & 128 && isUniAlpha(decodeUTF8()))
      // Store identifier
      str_delim = begin[0..p-begin];
      // Scan newline
      if (scanNewline() == '\n')
        --p; // Go back one because of "c = *++p;" in main loop.
      else
      {
        // TODO: error(p, MID.ExpectedNewlineAfterIdentDelim);
      }
    }

    bool checkStringDelim(char* p)
    {
      assert(str_delim.length != 0);
      if (buffer[$-1] == '\n' && // Last character copied to buffer must be '\n'.
          end-p >= str_delim.length && // Check remaining length.
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
        assert(*p == '\n' || *p == '\r' || *p == LS[2] || *p == PS[2]);
        c = '\n'; // Convert EndOfLine ('\r','\r\n','\n',LS,PS) to '\n'
        ++loc;
        setLineBegin(p+1);
        break;
      case 0, _Z_:
        // TODO: error(tokenLineNum, tokenLineBegin, t.start, MID.UnterminatedDelimitedString);
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
            if (str_delim.length)
            {
              if (checkStringDelim(begin))
              {
                p = begin + str_delim.length;
                goto Lreturn2;
              }
            }
            else
            {
              assert(level == 1);
              --level;
              goto Lreturn;
            }
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
            if (str_delim.length)
            {
              if (checkStringDelim(p))
              {
                p += str_delim.length;
                goto Lreturn2;
              }
            }
            else if (--level == 0)
              goto Lreturn;
          }
        }
      }
      assert(isascii(c));
      buffer ~= c;
    }
  Lreturn: // Character delimiter.
    assert(c == closing_delim);
    assert(level == 0);
    ++p; // Skip closing delimiter.
  Lreturn2: // String delimiter.
    if (*p == '"')
      ++p;
    else
    {
      // TODO: error(p, MID.ExpectedDblQuoteAfterDelim, str_delim.length ? str_delim : closing_delim~"");
    }

    t.pf = scanPostfix();
  Lreturn3: // Error.
    t.str = buffer ~ '\0';
    t.end = p;
  }

  void scanTokenStringLiteral(ref Token t)
  {
    assert(p[0] == 'q' && p[1] == '{');
    t.type = TOK.String;

    auto tokenLineNum = loc;
    auto tokenLineBegin = lineBegin;

    // A guard against changes to particular members:
    // this.loc_hline and this.errorLoc.filePath
    ++inTokenString;

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
        // TODO: error(tokenLineNum, tokenLineBegin, t.start, MID.UnterminatedTokenString);
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

    --inTokenString;
  }
} // version(D2)

  dchar scanEscapeSequence()
  out(result)
  { assert(isEncodable(result)); }
  body
  {
    assert(*p == '\\');

    auto sequenceStart = p; // Used for error reporting.

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
      assert(c == 0);
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
            if (isEncodable(c))
              return c; // Return valid escape value.

            error(sequenceStart, MID.InvalidUnicodeEscapeSequence, sequenceStart[0..p-sequenceStart]);
            break;
          }
          continue;
        }

        error(sequenceStart, MID.InsufficientHexDigits);
        break;
      }
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
        assert(c == 0);
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
        return c; // Return valid escape value.
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
            // Pass entity excluding '&' and ';'.
            c = entity2Unicode(begin[0..p - begin]);
            ++p; // Skip ;
            if (c != 0xFFFF)
              return c; // Return valid escape value.
            else
              error(sequenceStart, MID.UndefinedHTMLEntity, sequenceStart[0 .. p - sequenceStart]);
          }
          else
            error(sequenceStart, MID.UnterminatedHTMLEntity, sequenceStart[0 .. p - sequenceStart]);
        }
        else
          error(sequenceStart, MID.InvalidBeginHTMLEntity);
      }
      else if (*p == '\n' || *p == '\r' ||
               *p == LS[0] && p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
      {
        error(sequenceStart, MID.UndefinedEscapeSequence, r"\NewLine");
      }
      else if (*p == 0 || *p == _Z_)
      {
        error(sequenceStart, MID.UndefinedEscapeSequence, r"\EOF");
      }
      else
      {
        char[] str = `\`;
        if (*p & 128)
          encodeUTF8(str, decodeUTF8());
        else
          str ~= *p;
        ++p;
        // TODO: check for unprintable character?
        error(sequenceStart, MID.UndefinedEscapeSequence, str);
      }
    }
    return REPLACEMENT_CHAR; // Error: return replacement character.
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
      goto LscanBinary;
    case 'L':
      if (p[1] == 'i')
        goto LscanReal; // 0Li
      break; // 0L
    case '.':
      if (p[1] == '.')
        break; // 0..
      // 0.
    case 'i','f','F', // Imaginary and float literal suffixes.
         'e', 'E':    // Float exponent.
      goto LscanReal;
    default:
      if (*p == '_')
        goto LscanOctal; // 0_
      else if (isdigit(*p))
      {
        if (*p == '8' || *p == '9')
          goto Loctal_hasDecimalDigits; // 08 or 09
        else
          goto Loctal_enter_loop; // 0[0-7]
      }
    }

    // Number 0
    assert(p[-1] == '0');
    assert(*p != '_' && !isdigit(*p));
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
      error(t.start, MID.OverflowDecimalNumber);

    assert((isdigit(p[-1]) || p[-1] == '_') && !isdigit(*p) && *p != '_');
    goto Lfinalize;

  LscanHex:
    assert(digits == 0);
    assert(*p == 'x' || *p == 'X');
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

    assert(ishexad(p[-1]) || p[-1] == '_' || p[-1] == 'x' || p[-1] == 'X');
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

    if (digits == 0 || digits > 16)
      error(t.start, digits == 0 ? MID.NoDigitsInHexNumber : MID.OverflowHexNumber);

    goto Lfinalize;

  LscanBinary:
    assert(digits == 0);
    assert(*p == 'b' || *p == 'B');
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

    if (digits == 0 || digits > 64)
      error(t.start, digits == 0 ? MID.NoDigitsInBinNumber : MID.OverflowBinaryNumber);

    assert(p[-1] == '0' || p[-1] == '1' || p[-1] == '_' || p[-1] == 'b' || p[-1] == 'B', p[-1] ~ "");
    assert( !(*p == '0' || *p == '1' || *p == '_') );
    goto Lfinalize;

  LscanOctal:
    assert(*p == '_');
    while (1)
    {
      if (*++p == '_')
        continue;
      if (!isoctal(*p))
        break;
    Loctal_enter_loop:
      if (ulong_ < ulong.max/2 || (ulong_ == ulong.max/2 && *p <= '1'))
      {
        ulong_ *= 8;
        ulong_ += *p - '0';
        continue;
      }
      // Overflow: skip following digits.
      overflow = true;
      while (isoctal(*++p)) {}
      break;
    }

    bool hasDecimalDigits;
    if (isdigit(*p))
    {
    Loctal_hasDecimalDigits:
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
      error(t.start, MID.OctalNumberHasDecimals);

    if (overflow)
      error(t.start, MID.OverflowOctalNumber);
//     goto Lfinalize;

  Lfinalize:
    enum Suffix
    {
      None     = 0,
      Unsigned = 1,
      Long     = 2
    }

    // Scan optional suffix: L, Lu, LU, u, uL, U or UL.
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

    // Determine type of Integer.
    switch (suffix)
    {
    case Suffix.None:
      if (ulong_ & 0x8000_0000_0000_0000)
      {
        if (isDecimal)
          error(t.start, MID.OverflowDecimalSign);
        t.type = TOK.Uint64;
      }
      else if (ulong_ & 0xFFFF_FFFF_0000_0000)
        t.type = TOK.Int64;
      else if (ulong_ & 0x8000_0000)
        t.type = isDecimal ? TOK.Int64 : TOK.Uint32;
      else
        t.type = TOK.Int32;
      break;
    case Suffix.Unsigned:
      if (ulong_ & 0xFFFF_FFFF_0000_0000)
        t.type = TOK.Uint64;
      else
        t.type = TOK.Uint32;
      break;
    case Suffix.Long:
      if (ulong_ & 0x8000_0000_0000_0000)
      {
        if (isDecimal)
          error(t.start, MID.OverflowDecimalSign);
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
    {
      assert(p[1] != '.');
      // This function was called by scan() or scanNumber().
      while (isdigit(*++p) || *p == '_') {}
    }
    else
      // This function was called by scanNumber().
      assert(delegate ()
        {
          switch (*p)
          {
          case 'L':
            if (p[1] != 'i')
              return false;
          case 'i', 'f', 'F', 'e', 'E':
            return true;
          default:
          }
          return false;
        }()
      );

    // Scan exponent.
    if (*p == 'e' || *p == 'E')
    {
      ++p;
      if (*p == '-' || *p == '+')
        ++p;
      if (isdigit(*p))
        while (isdigit(*++p) || *p == '_') {}
      else
        error(t.start, MID.FloatExpMustStartWithDigit);
    }

    // Copy whole number and remove underscores from buffer.
    char[] buffer = t.start[0..p-t.start].dup;
    uint j;
    foreach (c; buffer)
      if (c != '_')
        buffer[j++] = c;
    buffer.length = j; // Adjust length.
    buffer ~= 0; // Terminate for C functions.

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
    ++p;
    if (*p == '+' || *p == '-')
      ++p;
    if (!isdigit(*p))
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
    error(t.start, mid);
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
      error(t.start, MID.OverflowFloatNumber);
    t.end = p;
  }

  /// Scan special token: #line Integer [Filespec] EndOfLine
  void scanSpecialTokenSequence(ref Token t)
  {
    assert(*p == '#');
    t.type = TOK.HashLine;

    MID mid;
    auto errorAtColumn = p;

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
      case LS[0]:
        if (!(p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2])))
          goto default;
      case '\r', '\n', 0, _Z_:
        break Loop;
      default:
        if (isspace(*p))
          continue;
        if (state == State.Integer)
        {
          if (!isdigit(*p))
          {
            errorAtColumn = p;
            mid = MID.ExpectedIntegerAfterSTLine;
            goto Lerr;
          }
          t.line_num = new Token;
          scan(*t.line_num);
          if (t.line_num.type != TOK.Int32 && t.line_num.type != TOK.Uint32)
          {
            errorAtColumn = t.line_num.start;
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
            errorAtColumn = p;
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
              errorAtColumn = t.line_filespec.start;
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
    assert(*p == '\r' || *p == '\n' || *p == 0 || *p == _Z_ ||
           *p == LS[0] && (p[1] == LS[1] && (p[2] == LS[2] || p[2] == PS[2]))
    );

    if (state == State.Integer)
    {
      errorAtColumn = p;
      mid = MID.ExpectedIntegerAfterSTLine;
      goto Lerr;
    }

    // Evaluate #line only when not in token string.
    if (!inTokenString)
      evaluateHashLine(t);
    t.end = p;

    return;
  Lerr:
    t.end = p;
    error(errorAtColumn, mid);
  }

  void evaluateHashLine(ref Token t)
  {
    assert(t.type == TOK.HashLine);
    if (t.line_num)
    {
      this.loc_hline = this.loc - t.line_num.uint_ + 1;
      if (t.line_filespec)
        this.errorLoc.setFilePath(t.line_filespec.str);
    }
  }

  /+
    Insert an empty dummy token before t.
    Useful in the parsing phase for representing a node in the AST
    that doesn't consume an actual token from the source text.
  +/
  Token* insertEmptyTokenBefore(Token* t)
  {
    assert(t !is null && t.prev !is null);
    assert(text.ptr <= t.start && t.start < end, Token.toString(t.type));
    assert(text.ptr <= t.end && t.end <= end, Token.toString(t.type));

    auto prev_t = t.prev;
    auto new_t = new Token;
    new_t.type = TOK.Empty;
    new_t.start = new_t.end = prev_t.end;
    // Link in new token.
    prev_t.next = new_t;
    new_t.prev = prev_t;
    new_t.next = t;
    t.prev = new_t;
    return new_t;
  }

  void updateErrorLoc(char* columnPos)
  {
    updateErrorLoc(this.loc, this.lineBegin, columnPos);
  }

  void updateErrorLoc(uint lineNum, char* lineBegin, char* columnPos)
  {
    errorLoc.set(this.errorLineNum(lineNum), lineBegin, columnPos);
  }

  uint errorLineNum(uint loc)
  {
    return loc - this.loc_hline;
  }

  void error(char* columnPos, MID mid, ...)
  {
    updateErrorLoc(columnPos);
    errors ~= new Information(InfoType.Lexer, mid, errorLoc.clone, Format(_arguments, _argptr, GetMsg(mid)));
  }

  void error(uint lineNum, char* lineBegin, char* columnPos, MID mid, ...)
  {
    updateErrorLoc(lineNum, lineBegin, columnPos);
    errors ~= new Information(InfoType.Lexer, mid, errorLoc.clone, Format(_arguments, _argptr, GetMsg(mid)));
  }

  Token* getTokens()
  {
    while (nextToken() != TOK.EOF)
    {}
    return head;
  }

  static void loadKeywords(ref Identifier[string] table)
  {
    foreach(k; keywords)
      table[k.str] = k;
  }

  static bool isNonReservedIdentifier(char[] ident)
  {
    if (ident.length == 0)
      return false;

    static Identifier[string] reserved_ids_table;
    if (reserved_ids_table is null)
      loadKeywords(reserved_ids_table);

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

  /++
    Returns true if d can be encoded as a UTF-8 sequence.
  +/
  bool isEncodable(dchar d)
  {
    return d < 0xD800 ||
          (d > 0xDFFF && d <= 0x10FFFF);
  }

  /++
    There are a total of 66 noncharacters.
    Returns true if this is one of them.
    See_also: Chapter 16.7 Noncharacters in Unicode 5.0
  +/
  bool isNoncharacter(dchar d)
  {
    return 0xFDD0 <= d && d <= 0xFDEF || // 32
           d <= 0x10FFFF && (d & 0xFFFF) >= 0xFFFE; // 34
  }

  /++
    Returns true if this character is not a noncharacter, not a surrogate
    code point and not higher than 0x10FFFF.
  +/
  bool isValidDecodedChar(dchar d)
  {
    return d < 0xD800 ||
          (d > 0xDFFF && d < 0xFDD0) ||
          (d > 0xFDEF && d <= 0x10FFFF && (d & 0xFFFF) < 0xFFFE);
  }

  /// Is this a trail byte of a UTF-8 sequence?
  bool isTrailByte(ubyte b)
  {
    return (b & 0xC0) == 0x80; // 10xx_xxxx
  }

  /// Is this a lead byte of a UTF-8 sequence?
  bool isLeadByte(ubyte b)
  {
    return (b & 0xC0) == 0xC0; // 11xx_xxxx
  }

  dchar decodeUTF8()
  {
    assert(!isascii(*p), "check for ASCII char before calling decodeUTF8().");
    char* p = this.p;
    dchar d = *p;

    ++p; // Move to second byte.
    // Error if second byte is not a trail byte.
    if (!isTrailByte(*p))
      goto Lerr2;

    // Check for overlong sequences.
    switch (d)
    {
    case 0xE0, // 11100000 100xxxxx
         0xF0, // 11110000 1000xxxx
         0xF8, // 11111000 10000xxx
         0xFC: // 11111100 100000xx
      if ((*p & d) == 0x80)
        goto Lerr;
    default:
      if ((d & 0xFE) == 0xC0) // 1100000x
        goto Lerr;
    }

    const char[] checkNextByte = "if (!isTrailByte(*++p))"
                                 "  goto Lerr2;";
    const char[] appendSixBits = "d = (d << 6) | *p & 0b0011_1111;";

    // Decode
    if ((d & 0b1110_0000) == 0b1100_0000)
    {
      // 110xxxxx 10xxxxxx
      d &= 0b0001_1111;
      mixin(appendSixBits);
    }
    else if ((d & 0b1111_0000) == 0b1110_0000)
    {
      // 1110xxxx 10xxxxxx 10xxxxxx
      d &= 0b0000_1111;
      mixin(appendSixBits ~
            checkNextByte ~ appendSixBits);
    }
    else if ((d & 0b1111_1000) == 0b1111_0000)
    {
      // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
      d &= 0b0000_0111;
      mixin(appendSixBits ~
            checkNextByte ~ appendSixBits ~
            checkNextByte ~ appendSixBits);
    }
    else
      // 5 and 6 byte UTF-8 sequences are not allowed yet.
      // 111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
      // 1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
      goto Lerr;

    assert(isTrailByte(*p));

    if (!isEncodable(d))
    {
    Lerr:
      // Three cases:
      // *) the UTF-8 sequence was successfully decoded but the resulting
      //    character is invalid.
      //    p points to last trail byte in the sequence.
      // *) the UTF-8 sequence is overlong.
      //    p points to second byte in the sequence.
      // *) the UTF-8 sequence has more than 4 bytes or starts with
      //    a trail byte.
      //    p points to second byte in the sequence.
      assert(isTrailByte(*p));
      // Move to next ASCII character or lead byte of a UTF-8 sequence.
      while (p < (end-1) && isTrailByte(*p))
        ++p;
      --p;
      assert(!isTrailByte(p[1]));
    Lerr2:
      d = REPLACEMENT_CHAR;
      error(this.p, MID.InvalidUTF8Sequence);
    }

    this.p = p;
    return d;
  }

  private void encodeUTF8(ref char[] str, dchar d)
  {
    char[6] b;
    assert(!isascii(d), "check for ASCII char before calling encodeUTF8().");
    assert(isEncodable(d), "check that 'd' is encodable before calling encodeUTF8().");

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
    /+ // There are no 5 and 6 byte UTF-8 sequences yet.
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
    +/
    else
     assert(0);
  }
}

unittest
{
  Stdout("Testing Lexer.\n");
  struct Pair
  {
    char[] token;
    TOK type;
  }
  static Pair[] pairs = [
    {"//çay\n", TOK.Comment},       {"&",       TOK.AndBinary},
    {"/*çağ*/", TOK.Comment},       {"&&",      TOK.AndLogical},
    {"/+çak+/", TOK.Comment},       {"&=",      TOK.AndAssign},
    {">",       TOK.Greater},       {"+",       TOK.Plus},
    {">=",      TOK.GreaterEqual},  {"++",      TOK.PlusPlus},
    {">>",      TOK.RShift},        {"+=",      TOK.PlusAssign},
    {">>=",     TOK.RShiftAssign},  {"-",       TOK.Minus},
    {">>>",     TOK.URShift},       {"--",      TOK.MinusMinus},
    {">>>=",    TOK.URShiftAssign}, {"-=",      TOK.MinusAssign},
    {"<",       TOK.Less},          {"=",       TOK.Assign},
    {"<=",      TOK.LessEqual},     {"==",      TOK.Equal},
    {"<>",      TOK.LorG},          {"~",       TOK.Tilde},
    {"<>=",     TOK.LorEorG},       {"~=",      TOK.CatAssign},
    {"<<",      TOK.LShift},        {"*",       TOK.Mul},
    {"<<=",     TOK.LShiftAssign},  {"*=",      TOK.MulAssign},
    {"!",       TOK.Not},           {"/",       TOK.Div},
    {"!=",      TOK.NotEqual},      {"/=",      TOK.DivAssign},
    {"!<",      TOK.UorGorE},       {"^",       TOK.Xor},
    {"!>",      TOK.UorLorE},       {"^=",      TOK.XorAssign},
    {"!<=",     TOK.UorG},          {"%",       TOK.Mod},
    {"!>=",     TOK.UorL},          {"%=",      TOK.ModAssign},
    {"!<>",     TOK.UorE},          {"(",       TOK.LParen},
    {"!<>=",    TOK.Unordered},     {")",       TOK.RParen},
    {".",       TOK.Dot},           {"[",       TOK.LBracket},
    {"..",      TOK.Slice},         {"]",       TOK.RBracket},
    {"...",     TOK.Ellipses},      {"{",       TOK.LBrace},
    {"|",       TOK.OrBinary},      {"}",       TOK.RBrace},
    {"||",      TOK.OrLogical},     {":",       TOK.Colon},
    {"|=",      TOK.OrAssign},      {";",       TOK.Semicolon},
    {"?",       TOK.Question},      {",",       TOK.Comma},
    {"$",       TOK.Dollar},        {"cam",     TOK.Identifier},
    {"çay",     TOK.Identifier},    {".0",      TOK.Float64},
    {"0",       TOK.Int32},
  ];

  char[] src;

  foreach (pair; pairs)
    src ~= pair.token ~ " ";

  assert(pairs[0].token == "//çay\n");
  // Remove \n after src has been constructed.
  // It won't be part of the scanned token string.
  pairs[0].token = "//çay";

  auto lx = new Lexer(src, "");
  auto token = lx.getTokens();

  uint i;
  assert(token == lx.head);
  token = token.next;
  do
  {
    assert(i < pairs.length);
    assert(token.srcText == pairs[i].token, Format("Scanned '{0}' but expected '{1}'", token.srcText, pairs[i].token));
    ++i;
    token = token.next;
  } while (token.type != TOK.EOF)
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
int isascii(uint c) { return c < 128; }

version(gen_ptable)
static this()
{
  alias ptable p;
  assert(p.length == 256);
  // Initialize character properties table.
  for (int i; i < p.length; ++i)
  {
    p[i] = 0; // Reset
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
  foreach (i, c; ptable)
  {
    array ~= Format((c>255?" 0x{0:x},":"{0,2},"), c) ~ (((i+1) % 16) ? "":"\n");
  }
  array[$-2..$] = "\n]";
  Stdout(array).newline;
}
