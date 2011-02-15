/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.lexer.Lexer;

import dil.lexer.Token,
       dil.lexer.Funcs,
       dil.lexer.Keywords,
       dil.lexer.Identifier,
       dil.lexer.TokenSerializer,
       dil.lexer.Tables;
import dil.Diagnostics,
       dil.Messages,
       dil.HtmlEntities,
       dil.Version,
       dil.Unicode,
       dil.SourceText,
       dil.Time;
import dil.Float : Float;
import util.uni : isUniAlpha;
import util.mpfr : mpfr_t, mpfr_strtofr, mpfr_init;
import common;

import tango.core.Vararg;


/// The Lexer analyzes the characters of a source text and
/// produces a doubly-linked list of tokens.
class Lexer
{
  SourceText srcText; /// The source text.
  char* p;            /// Points to the current character in the source text.
  char* end;          /// Points one character past the end of the source text.

  Token* head;  /// The head of the doubly linked token list.
  Token* tail;  /// The tail of the linked list. Set in scan().
  Token* token; /// Points to the current token in the token list.
  LexerTables tables; /// Used to look up token values.

  // Members used for error messages:
  Diagnostics diag; /// For diagnostics.
  LexerError[] errors; /// List of errors.
  /// Always points to the first character of the current line.
  char* lineBegin;
  uint lineNum; /// Current, actual source text line number.
  uint inTokenString; /// > 0 if inside q{ }
  /// Holds the original file path and the modified one (by #line.)
  Token.HashLineInfo* hlinfo; /// Info set by "#line".

  /// Tokens from a *.dlx file.
  Token[] dlxTokens;


  static
  {
  const ushort chars_r = toUintE(`r"`); /// `r"` as a ushort.
  const ushort chars_x = toUintE(`x"`); /// `x"` as a ushort.
  const ushort chars_q = toUintE(`q"`); /// `q"` as a ushort.
  const ushort chars_q2 = toUintE(`q{`); /// `q{` as a ushort.
  const ushort chars_shebang = toUintE("#!"); /// `#!` as a ushort.
  const uint chars_line = toUintE("line"); /// `line` as a uint.
  }

  /// Constructs a Lexer object.
  /// Params:
  ///   srcText = The UTF-8 source code.
  ///   tables = Used to look up identifiers and token values.
  ///   diag = Used for collecting error messages.
  this(SourceText srcText, LexerTables tables, Diagnostics diag = null)
  {
    this.srcText = srcText;
    this.tables = tables;
    this.diag = diag;

    assert(text.length >= 4 && text[$-4..$] == SourceText.sentinelString,
      "source text has no sentinel character");
    this.p = text.ptr;
    this.end = this.p + text.length; // Point past the sentinel string.
    this.lineBegin = this.p;
    this.lineNum = 1;

    this.head = new Token;
    this.head.kind = TOK.HEAD;
    this.head.start = this.head.end = this.p;
    this.token = this.head;

    // Add a newline as the first token after the head.
    auto nl_tok = new Token;
    nl_tok.kind = TOK.Newline;
    nl_tok.setWhitespaceFlag();
    nl_tok.start = nl_tok.end = this.p;
    nl_tok.nlval = lookupNewline();
    // Link in.
    this.token.next = nl_tok;
    nl_tok.prev = this.token;
    this.token = nl_tok;

    if (*cast(ushort*)p == chars_shebang)
      scanShebang();
  }

  /// The destructor deletes the doubly-linked token list.
  ~this()
  {
    head.deleteList();
    head = tail = token = null;
  }

  /// Callback function to TokenSerializer.deserialize().
  bool dlxCallback(Token* t)
  {
    switch (t.kind)
    { // Some tokens need special handling:
    case TOK.Newline:
      assert(isNewlineEnd(t.end-1));
      ++lineNum;
      setLineBegin(t.end);
      t.setWhitespaceFlag();
      t.nlval = lookupNewline();
      break;
    case TOK.CharLiteral: // May have escape sequences.
      this.p = t.start;
      scanCharacterLiteral(*t);
      break;
    case TOK.String: // Escape sequences; token strings; etc.
      this.p = t.start;
      dchar c = *cast(ushort*)p;
      switch (c)
      {
      case chars_r:
        ++this.p, scanRawStringLiteral(*t); break;
      case chars_x:
        scanHexStringLiteral(*t); break;
      version(D2)
      {
      case chars_q:
        scanDelimitedStringLiteral(*t); break;
      case chars_q2:
        scanTokenStringLiteral(*t); break;
      }
      default:
      }
      switch (*p)
      {
      case '`':
        scanRawStringLiteral(*t); break;
      case '"':
        scanNormalStringLiteral(*t); break;
      version(D2)
      {}
      else { // Only in D1.
      case '\\':
        scanEscapeStringLiteral(*t); break;
      }
      default:
      }
      break;
    case TOK.Comment: // Just rescan for newlines.
      t.setWhitespaceFlag();
      if (t.isMultiline) // Mutliline tokens may have newlines.
        for (auto p = t.start, end = t.end; p < end;)
          if (scanNewline(p))
            lineNum++,
            setLineBegin(p);
          else
            ++p;
      break;
    case TOK.Int32, TOK.Int64, TOK.UInt32, TOK.UInt64:
      this.p = t.start;
      scanNumber(*t); // Complicated. Let the method handle this.
      break;
    case TOK.Float32, TOK.Float64, TOK.Float80,
         TOK.IFloat32, TOK.IFloat64, TOK.IFloat80:
      // The token is complete. What remains is to get its value.
      t.mpfloat = lookupFloat(copySansUnderscores(t.start, t.end));
      break;
    case TOK.HashLine:
      this.p = t.start;
      scanSpecialTokenSequence(*t); // Complicated. Let the method handle this.
      break;
    case TOK.Shebang, TOK.Empty: // Whitespace tokens.
      t.setWhitespaceFlag();
      break;
    default:
    }
    // Link the token into the list.
    this.token.next = t;
    t.prev = this.token;
    this.token = t;
    return true;
  }

  /// Loads the tokens from a dlx file.
  bool fromDLXFile(ubyte[] data)
  {
    this.dlxTokens = TokenSerializer.deserialize(
      data, this.text(), tables.idents, &dlxCallback);
    if (dlxTokens.length)
    {
      this.p = this.token.end;
      this.tail = this.token; // Set tail.
    }
    else
    { /// Function failed. Reset...
      this.p = this.text.ptr;
      this.lineBegin = this.p;
      this.lineNum = 1;
      if (*cast(ushort*)p == chars_shebang)
        scanShebang();
    }
    this.token = this.head.next; // Go to first newline token.
    return !!dlxTokens.length;
  }

  /// Returns the source text string.
  string text()
  {
    return srcText.data;
  }

  /// Returns the end pointer excluding the sentinel string.
  char* endX()
  {
    return this.end - SourceText.sentinelString.length;
  }

  /// Scans the whole source text until EOF is encountered.
  void scanAll()
  {
    while (nextToken() != TOK.EOF)
    {}
  }

  /// Returns the first token of the source text.
  /// This can be the EOF token.
  /// Structure: HEAD -> Newline -> First Token
  Token* firstToken()
  {
    return this.head.next.next;
  }

  /// The "shebang" may optionally appear once at the beginning of a file.
  /// $(BNF Shebang := "#!" AnyChar* EndOfLine)
  void scanShebang()
  {
    auto p = this.p;
    assert(*p == '#' && p[1] == '!');
    auto t = new Token;
    t.kind = TOK.Shebang;
    t.setWhitespaceFlag();
    t.start = p++;
    while (!isEndOfLine(++p))
      isascii(*p) || decodeUTF8(p);
    t.end = this.p = p;
    // Link it in.
    this.token.next = t;
    t.prev = this.token;
  }

  /// Sets the value of the special token.
  void finalizeSpecialToken(ref Token t)
  {
    assert(t.text[0..2] == "__");
    char[] str;
    switch (t.kind)
    {
    case TOK.FILE:
      str = errorFilePath().dup;
      break;
    case TOK.LINE:
      t.uint_ = this.errorLineNumber(this.lineNum);
      break;
    case TOK.DATE, TOK.TIME, TOK.TIMESTAMP:
      str = Time.toString();
      switch (t.kind)
      {
      case TOK.DATE:
        str = Time.month_day(str) ~ ' ' ~ Time.year(str); break;
      case TOK.TIME:
        str = Time.time(str); break;
      case TOK.TIMESTAMP:
        break; // str is the timestamp.
      default: assert(0);
      }
      break;
    case TOK.VENDOR:
      str = VENDOR.dup;
      break;
    case TOK.VERSION:
      t.uint_ = VERSION_MAJOR*1000 + VERSION_MINOR;
      break;
    default:
      assert(0);
    }
    if (str.length)
      t.strval = lookupString(str, 0);
  }

  private void setLineBegin(char* p)
  {
    // Check that we can look behind one character.
    assert((p-1) >= text.ptr && p < end);
    // Check that previous character is a newline.
    assert(isNewlineEnd(p - 1));
    this.lineBegin = p;
  }

  /// Scans the next token in the source text.
  ///
  /// Creates a new token if t.next is null and appends it to the list.
  private void scanNext(ref Token* t)
  {
    assert(t !is null);
    if (t.next) // Simply go to the next token if there is one.
      t = t.next;
    else if (t !is this.tail)
    { // Create a new token and pass it to the main scan() method.
      Token* new_t = new Token;
      scan(*new_t);
      new_t.prev = t; // Link the token in.
      t.next = new_t;
      t = new_t;
    }
  }

  /// Advance t one token forward.
  void peek(ref Token* t)
  {
    scanNext(t);
  }

  /// Advance to the next token in the source text.
  TOK nextToken()
  {
    scanNext(this.token);
    return this.token.kind;
  }

  /// Returns true if p points to the last character of a Newline.
  bool isNewlineEnd(char* p)
  {
    if (*p == '\n' || *p == '\r')
      return true;
    if (*p == LS[2] || *p == PS[2])
      if ((p-2) >= text.ptr)
        if (p[-1] == LS[1] && p[-2] == LS[0])
          return true;
    return false;
  }

  alias Token.StringValue StringValue;
  alias Token.IntegerValue IntegerValue;
  alias Token.NewlineValue NewlineValue;

  /// Looks up a string value in the table.
  /// Params:
  ///   str = The string to be looked up, which is not zero-terminated.
  ///   pf = The postfix character.
  StringValue* lookupString(char[] str, char postfix)
  {
    auto hash = hashOf(str);
    auto psv = (hash + postfix) in tables.strvals;
    if (!psv)
    { // Insert a new string value into the table.
      auto sv = new StringValue;
      sv.str = lookupString(hash, str);
      sv.pf = postfix;
      tables.strvals[hash + postfix] = sv;
      return sv;
    }
    return *psv;
  }

  /// Looks up a string in the table.
  /// Params:
  ///   hash = The hash of str.
  ///   str = The string to be looked up, which is not zero-terminated.
  string lookupString(hash_t hash, string str)
  {
    auto pstr = hash in tables.strings;
    if (!pstr)
    { // Insert a new string into the table.
      auto new_str = str;
      if (text.ptr <= str.ptr && str.ptr < this.endX()) // Inside the text?
        new_str = new_str.dup; // A copy is needed.
      new_str ~= '\0'; // Terminate with a zero.
      tables.strings[hash] = new_str;
      return new_str;
    }
    return *pstr;
  }

  /// Calls lookupString(hash_t, string).
  string lookupString(string str)
  {
    return lookupString(hashOf(str), str);
  }

  /// Looks up a ulong in the table.
  /// Params:
  ///   num = The number value.
  IntegerValue* lookupUlong(ulong num)
  {
    auto pintval = num in tables.ulongs;
    if (!pintval)
    { // Insert a new IntegerValue into the table.
      auto iv = new IntegerValue;
      iv.ulong_ = num;
      tables.ulongs[num] = iv;
      return iv;
    }
    return *pintval;
  }

  /// Looks up a Float in the table.
  /// Params:
  ///   str = The zero-terminated string of the float number.
  Float lookupFloat(string str)
  {
    assert(str.length && str[$-1] == 0);
    auto hash = hashOf(str);
    auto pFloat = hash in tables.floats;
    if (!pFloat)
    { // Insert a new Float into the table.
      mpfr_t mpfloat;
      mpfr_init(&mpfloat);
      // Convert to multiprecision float.
      int res = mpfr_strtofr(&mpfloat, str.ptr, null, 0, Float.RND);
      // if (res == 0) // Exact precision.
      // else if (res < 0) // Lower precision.
      // {}
      // else /*if (res > 0)*/ // Higher precision.
      // {}
      auto f = new Float(&mpfloat);
      tables.floats[hash] = f;
      return f;
    }
    return *pFloat;
  }

  /// Looks up a newline value.
  NewlineValue* lookupNewline()
  {
    uint linnum = this.lineNum;
    if (hlinfo)
    { // Don't insert into the table, when '#line' tokens are in the text.
      // This could be optimised with another table.
      auto nl = new NewlineValue;
      nl.lineNum = linnum;
      auto hlinfo = nl.hlinfo = new Token.HashLineInfo;
      *hlinfo = *this.hlinfo;
      return nl;
    }

    auto newlines = tables.newlines;
    assert(linnum != 0);
    auto i = linnum - 1;
    if (i >= newlines.length)
      (tables.newlines.length = linnum),
      (newlines = tables.newlines);
    auto nl = newlines[i];
    if (!nl)
    { // Insert a new NewlineValue.
      newlines[i] = nl = new NewlineValue;
      nl.lineNum = linnum;
    }
    return nl;
  }


  /// The main method which recognizes the characters that make up a token.
  ///
  /// Complicated tokens are scanned in separate methods.
  public void scan(ref Token t)
  in
  {
    assert(text.ptr <= p && p < end);
  }
  out
  {
    assert(text.ptr <= t.start && t.start < end, t.kindAsString());
    assert(text.ptr <= t.end && t.end <= end, t.kindAsString());
    assert(t.kind != TOK.Invalid);
  }
  body
  {
    TOK kind; // The token kind that will be assigned to t.kind.
    char* p = this.p; // Incrementing a stack variable is faster.
    // Scan whitespace.
    if (isspace(*p))
    {
      t.ws = p;
      while (isspace(*++p))
      {}
    }

    // Scan a token.
    uint c = *p;
    {
      t.start = this.p = p;
      // Newline.
      switch (*p)
      {
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        goto Lnewline;
      default:
      }

      assert(this.p == p);
      // Identifier or string literal.
      if (isidbeg(c))
      {
        c = *cast(ushort*)p;
        if (c == chars_r)
          return ++this.p, scanRawStringLiteral(t);
        if (c == chars_x)
          return scanHexStringLiteral(t);
        version(D2)
        {
        if (c == chars_q)
          return scanDelimitedStringLiteral(t);
        if (c == chars_q2)
          return scanTokenStringLiteral(t);
        }

        // Scan identifier.
      Lidentifier:
        do
        { c = *++p; }
        while (isident(c) || !isascii(c) && isUnicodeAlpha(p))
        t.end = this.p = p;

        auto id = tables.lookupIdentifier(t.text);
        t.kind = kind = id.kind;
        t.ident = id;

        if (kind == TOK.Identifier || t.isKeyword)
          return;
        else if (t.isSpecialToken)
          finalizeSpecialToken(t);
        else if (kind == TOK.EOF)
        {
          tail = &t;
          assert(t.text == "__EOF__");
        }
        else
          assert(0, "unexpected token type: " ~ Token.toString(kind));
        return;
      }

      assert(this.p == p);
      if (isdigit(c))
        return scanNumber(t);

      // Check these characters early. They are very common.
      switch (c)
      {
      mixin(cases(
        ",", "Comma",
        ":", "Colon",    ";", "Semicolon",
        "(", "LParen",   ")", "RParen",
        "{", "LBrace",   "}", "RBrace",
        "[", "LBracket", "]", "RBracket"
      ));
      default:
      }

      if (c == '/')
        switch (c = *++p)
        {
        case '=':
          ++p;
          kind = TOK.DivAssign;
          goto Lreturn;
        case '+':
          return (this.p = p), scanNestedComment(t);
        case '*':
          return (this.p = p), scanBlockComment(t);
        case '/': // LineComment.
          while (!isEndOfLine(++p))
            isascii(*p) || decodeUTF8(p);
          kind = TOK.Comment;
          t.setWhitespaceFlag();
          goto Lreturn;
        default:
          kind = TOK.Div;
          goto Lreturn;
        }

      assert(this.p == p);
      switch (c)
      {
      case '=': /* =  == */
        if (p[1] == '=')
          ++p,
          kind = TOK.Equal;
        else
          kind = TOK.Assign;
        goto Lcommon;
      case '\'':
        return scanCharacterLiteral(t);
      case '`':
        return scanRawStringLiteral(t);
      case '"':
        return scanNormalStringLiteral(t);
      version(D2)
      {}
      else { // Only in D1.
      case '\\':
        return scanEscapeStringLiteral(t);
      }
      case '>': /* >  >=  >>  >>=  >>>  >>>= */
        c = *++p;
        switch (c)
        {
        case '=':
          kind = TOK.GreaterEqual;
          goto Lcommon;
        case '>':
          if (p[1] == '>')
          {
            ++p;
            if (p[1] == '=')
              ++p,
              kind = TOK.URShiftAssign;
            else
              kind = TOK.URShift;
          }
          else if (p[1] == '=')
            ++p,
            kind = TOK.RShiftAssign;
          else
            kind = TOK.RShift;
          goto Lcommon;
        default:
          kind = TOK.Greater;
          goto Lreturn;
        }
        assert(0);
      case '<': /* <  <=  <>  <>=  <<  <<= */
        c = *++p;
        switch (c)
        {
        case '=':
          kind = TOK.LessEqual;
          goto Lcommon;
        case '<':
          if (p[1] == '=')
            ++p,
            kind = TOK.LShiftAssign;
          else
            kind = TOK.LShift;
          goto Lcommon;
        case '>':
          if (p[1] == '=')
            ++p,
            kind = TOK.LorEorG;
          else
            kind = TOK.LorG;
          goto Lcommon;
        default:
          kind = TOK.Less;
          goto Lreturn;
        }
        assert(0);
      case '!': /* !  !<  !>  !<=  !>=  !<>  !<>= */
        c = *++p;
        switch (c)
        {
        case '<':
          c = *++p;
          if (c == '>')
            if (p[1] == '=')
              ++p,
              kind = TOK.Unordered;
            else
              kind = TOK.UorE;
          else if (c == '=')
            kind = TOK.UorG;
          else {
            kind = TOK.UorGorE;
            goto Lreturn;
          }
          goto Lcommon;
        case '>':
          if (p[1] == '=')
            ++p,
            kind = TOK.UorL;
          else
            kind = TOK.UorLorE;
          goto Lcommon;
        case '=':
          kind = TOK.NotEqual;
          goto Lcommon;
        default:
          kind = TOK.Not;
          goto Lreturn;
        }
        assert(0);
      case '.': /* .  .[0-9]  ..  ... */
        if (p[1] == '.')
          if ((++p)[1] == '.')
            ++p,
            kind = TOK.Ellipses;
          else
            kind = TOK.Slice;
        else if (isdigit(p[1]))
          return (this.p = p), scanFloat(t);
        else
          kind = TOK.Dot;
        goto Lcommon;
      case '|': /* |  ||  |= */
        c = *++p;
        if (c == '=')
          kind = TOK.OrAssign;
        else if (c == '|')
          kind = TOK.OrLogical;
        else {
          kind = TOK.OrBinary;
          goto Lreturn;
        }
        goto Lcommon;
      case '&': /* &  &&  &= */
        c = *++p;
        if (c == '=')
          kind = TOK.AndAssign;
        else if (c == '&')
          kind = TOK.AndLogical;
        else {
          kind = TOK.AndBinary;
          goto Lreturn;
        }
        goto Lcommon;
      case '+': /* +  ++  += */
        c = *++p;
        if (c == '=')
          kind = TOK.PlusAssign;
        else if (c == '+')
          kind = TOK.PlusPlus;
        else {
          kind = TOK.Plus;
          goto Lreturn;
        }
        goto Lcommon;
      case '-': /* -  --  -= */
        c = *++p;
        if (c == '=')
          kind = TOK.MinusAssign;
        else if (c == '-')
          kind = TOK.MinusMinus;
        else {
          kind = TOK.Minus;
          goto Lreturn;
        }
        goto Lcommon;
      case '~': /* ~  ~= */
        if (p[1] == '=')
          ++p,
          kind = TOK.CatAssign;
        else
          kind = TOK.Tilde;
        goto Lcommon;
      case '*': /* *  *= */
        if (p[1] == '=')
          ++p,
          kind = TOK.MulAssign;
        else
          kind = TOK.Mul;
        goto Lcommon;
      version(D2)
      {
      case '^': /* ^  ^=  ^^  ^^= */
        if (p[1] == '=')
          ++p,
          kind = TOK.XorAssign;
        else if (p[1] == '^')
        {
          ++p;
          if (p[1] == '=')
            ++p,
            kind = TOK.PowAssign;
          else
            kind = TOK.Pow;
        }
        else
          kind = TOK.Xor;
        goto Lcommon;
      } // end of version(D2)
      else
      {
      case '^': /* ^  ^= */
        if (p[1] == '=')
          ++p,
          kind = TOK.XorAssign;
        else
          kind = TOK.Xor;
        goto Lcommon;
      }
      case '%': /* %  %= */
        if (p[1] == '=')
          ++p,
          kind = TOK.ModAssign;
        else
          kind = TOK.Mod;
        goto Lcommon;
      // Single character tokens:
      mixin(cases(
        "@", "At",
        "$", "Dollar",
        "?", "Question"
      ));
      case '#':
        assert(this.p == p);
        return scanSpecialTokenSequence(t);
      default:
      }

      // Check for EOF
      if (isEOF(c))
      {
        assert(isEOF(*p), ""~*p);
        kind = TOK.EOF;
        tail = &t;
        assert(t.start == p);
        goto Lreturn;
      }

      assert(this.p == p);
      if (!isascii(c) && isUniAlpha(c = decodeUTF8(p)))
        goto Lidentifier;

      if (isUnicodeNewlineChar(c))
        goto Lnewline;

      error(t.start, MID.IllegalCharacter, cast(dchar)c);

      kind = TOK.Illegal;
      t.setWhitespaceFlag();
      t.dchar_ = c;
      goto Lcommon;
    }

  Lcommon:
    ++p;
  Lreturn:
    t.kind = kind;
    t.end = this.p = p;
    return;

  Lnewline:
    assert(isNewlineEnd(p));
    ++p;
    ++lineNum;
    setLineBegin(p);
    t.kind = TOK.Newline;
    t.setWhitespaceFlag();
    t.nlval = lookupNewline();
    t.end = this.p = p;
    return;
  }

  /// CTF: Casts a string literal to an integer.
  static uint toUint(char[] s)
  {
    assert(s.length <= 4);
    uint x, i = s.length;
    if (i) x |= s[--i];
    if (i) x |= s[--i] << 8;
    if (i) x |= s[--i] << 16;
    if (i) x |= s[--i] << 24;
    return x;
  }
  static assert(toUint("\xAA\xBB\xCC\xDD") == 0xAABBCCDD);

  /// CTF: Like toUint(), but considers the endianness of the CPU.
  static uint toUintE(char[] s)
  {
    version(BigEndian)
    return toUint(s);
    else
    {
    assert(s.length <= 4);
    uint x, i = s.length;
    if (i) x |= s[--i] << 24;
    if (i) x |= s[--i] << 16;
    if (i) x |= s[--i] << 8;
    if (i) x |= s[--i];
    x >>>= (4 - s.length) * 8;
    return x;
    }
  }
  version(LittleEndian)
  static assert(toUintE("\xAA\xBB\xCC\xDD") == 0xDDCCBBAA);

  /// CTF: Constructs case statements. E.g.:
  /// ---
  //// // case_("<", "Less") ->
  /// case 60u:
  ///   kind = TOK.Less;
  ///   goto Lcommon;
  /// ---
  static char[] case_(char[] str, char[] kind)
  {
    char[] label_str = "Lcommon";
    if (str.length != 1) // Append length as a suffix.
      label_str ~= '0' + str.length;
    return "case toUintE(\""~str~"\"): kind = TOK."~kind~";"
             "goto "~label_str~";\n";
  }
  // pragma(msg, case_("<", "Less"));

  /// CTF: Maps a flat list to case_().
  static char[] cases(char[][] cs ...)
  {
    assert(cs.length % 2 == 0);
    char[] result;
    for (int i = 0; i < cs.length; i += 2)
      result ~= case_(cs[i], cs[i+1]);
    return result;
  }
  // pragma(msg, cases("<", "Less", ">", "Greater"));

  /// An alternative scan method.
  /// Profiling shows it's a bit slower.
  public void scan_(ref Token t)
  in
  {
    assert(text.ptr <= p && p < end);
  }
  out
  {
    assert(text.ptr <= t.start && t.start < end, t.kindAsString());
    assert(text.ptr <= t.end && t.end <= end, t.kindAsString());
    assert(t.kind != TOK.Invalid, String(t.start, t.end));
  }
  body
  {
    TOK kind; // The token kind that will be assigned to t.kind.
    char* p = this.p; // Incrementing a stack variable is faster.
    // Scan whitespace.
    if (isspace(*p))
    {
      t.ws = p;
      while (isspace(*++p))
      {}
    }

    // Scan a token.
    t.start = this.p = p;

    uint c = *p;

    assert(p == t.start);
    // Check for ids first, as they occur the most often in source codes.
    if (isidbeg(c))
    {
      c = *cast(ushort*)p;
      if (c == chars_r)
        return (this.p = ++p), scanRawStringLiteral(t);
      if (c == chars_x)
        return scanHexStringLiteral(t);
      version(D2)
      {
      if (c == chars_q)
        return scanDelimitedStringLiteral(t);
      if (c == chars_q2)
        return scanTokenStringLiteral(t);
      }

      // Scan an identifier.
    Lidentifier:
      do
      { c = *++p; }
      while (isident(c) || !isascii(c) && isUnicodeAlpha(p))
      t.end = this.p = p;

      auto id = tables.lookupIdentifier(t.text);
      t.kind = kind = id.kind;
      t.ident = id;

      if (kind == TOK.Identifier || t.isKeyword)
        return;
      else if (t.isSpecialToken)
        finalizeSpecialToken(t);
      else if (kind == TOK.EOF)
      {
        tail = &t;
        assert(t.text == "__EOF__");
      }
      else
        assert(0, "unexpected token type: " ~ Token.toString(kind));
      return;
    }

    if (isdigit(c))
      return scanNumber(t);


    // Thanks to the 4 zeros terminating the text,
    // it is possible to look ahead 4 characters.
    c = *cast(uint*)p;

    // 4 character tokens.
    switch (c)
    {
    mixin(cases(">>>=", "RShiftAssign", "!<>=", "Unordered"));
    default:
    }

    version(BigEndian)
    c >>>= 8;
    else
    c &= 0x00FFFFFF;
    assert(p == t.start);
    // 3 character tokens.
    switch (c)
    {
    mixin(cases(
      "<<=", "LShiftAssign", ">>=", "RShiftAssign",
      ">>>", "URShift",      "...", "Ellipses",
      "!<=", "UorG",         "!>=", "UorL",
      "!<>", "UorE",         "<>=", "LorEorG",
      "^^=", "PowAssign"
    ));
    case toUintE(LS), toUintE(PS):
      p += 2;
      goto Lnewline;
    default:
    }

    version(BigEndian)
    c >>>= 8;
    else
    c &= 0x0000FFFF;
    assert(p == t.start);
    // 2 character tokens.
    switch (c)
    {
    case toUintE("/+"):
      this.p = ++p; // Skip /
      return scanNestedComment(t);
    case toUintE("/*"):
      this.p = ++p; // Skip /
      return scanBlockComment(t);
    case toUintE("//"): // LineComment.
      ++p; // Skip /
      assert(*p == '/');
      while (!isEndOfLine(++p))
        isascii(*p) || decodeUTF8(p);
      kind = TOK.Comment;
      t.setWhitespaceFlag();
      goto Lreturn;
    mixin(cases(
      "<=", "LessEqual",  ">=", "GreaterEqual",
      "<<", "LShift",     ">>", "RShift",
      "==", "Equal",      "!=", "NotEqual",
      "!<", "UorGorE",    "!>", "UorLorE",
      "<>", "LorG",       "..", "Slice",
      "&&", "AndLogical", "&=", "AndAssign",
      "||", "OrLogical",  "|=", "OrAssign",
      "++", "PlusPlus",   "+=", "PlusAssign",
      "--", "MinusMinus", "-=", "MinusAssign",
      "*=", "MulAssign",  "/=", "DivAssign",
      "%=", "ModAssign",  "^=", "XorAssign",
      "~=", "CatAssign",  "^^", "Pow"
    ));
    case toUintE("\r\n"):
      ++p;
      goto Lnewline;
    default:
    }

    static TOK[127] char2tok = [
      '<':TOK.Greater,   '>':TOK.Less,     '^':TOK.Xor,    '!':TOK.Not,
      '&':TOK.AndBinary, '|':TOK.OrBinary, '+':TOK.Plus,   '-':TOK.Minus,
      '=':TOK.Assign,    '~':TOK.Tilde,    '*':TOK.Mul,    '/':TOK.Div,
      '%':TOK.Mod,       '(':TOK.LParen,   ')':TOK.RParen, '[':TOK.LBracket,
      ']':TOK.RBracket,  '{':TOK.LBrace,   '}':TOK.RBrace, ':':TOK.Colon,
      ';':TOK.Semicolon, '?':TOK.Question, ',':TOK.Comma,  '$':TOK.Dollar,
      '@':TOK.At
    ];

    version(BigEndian)
    c >>>= 8;
    else
    c &= 0x000000FF;
    assert(p == t.start);
    assert(*p == c, Format("p={0},c={1}", *p, cast(dchar)c));
    // 1 character tokens.
    // TODO: consider storing the token type in ptable.
    if (c < 127 && (kind = char2tok[c]) != 0)
      goto Lcommon;

    assert(this.p == p);
    switch (c)
    {
    case '\r', '\n':
      goto Lnewline;
    case '\'':
      return scanCharacterLiteral(t);
    case '`':
      return scanRawStringLiteral(t);
    case '"':
      return scanNormalStringLiteral(t);
    version(D2)
    {}
    else { // Only in D1.
    case '\\':
      return scanEscapeStringLiteral(t);
    }
    case '.':
      if (isdigit(p[1]))
        return (this.p = p), scanFloat(t);
      kind = TOK.Dot;
      ++p;
      goto Lreturn;
    case '#':
      assert(this.p == p);
      return scanSpecialTokenSequence(t);
    default:
    }

    assert(p == t.start);
    assert(*p == c);

    // Check for EOF
    if (isEOF(c))
    {
      assert(isEOF(*p), *p~"");
      kind = TOK.EOF;
      tail = &t;
      assert(t.start == p);
      goto Lreturn;
    }

    if (!isascii(c) && isUniAlpha(c = decodeUTF8(p)))
      goto Lidentifier;

    error(t.start, MID.IllegalCharacter, cast(dchar)c);

    kind = TOK.Illegal;
    t.setWhitespaceFlag();
    t.dchar_ = c;
    goto Lcommon;

  Lcommon4:
    ++p;
  Lcommon3:
    ++p;
  Lcommon2:
    ++p;
  Lcommon:
    ++p;
  Lreturn:
    t.kind = kind;
    t.end = this.p = p;
    return;

  Lnewline:
    assert(isNewlineEnd(p));
    ++p;
    ++lineNum;
    setLineBegin(p);
    kind = TOK.Newline;
    t.setWhitespaceFlag();
    t.nlval = lookupNewline();
    t.kind = kind;
    t.end = this.p = p;
    return;
  }

  /// Scans a block comment.
  ///
  /// $(BNF BlockComment := "/*" AnyChar* "*/")
  void scanBlockComment(ref Token t)
  {
    auto p = this.p;
    assert(p[-1] == '/' && *p == '*');
    auto tokenLineNum = lineNum;
    auto tokenLineBegin = lineBegin;
  Loop:
    while (1)
    {
      switch (*++p)
      {
      case '*':
        if (p[1] != '/')
          continue;
        p += 2;
        break Loop;
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        assert(isNewlineEnd(p));
        ++lineNum;
        setLineBegin(p+1);
        break;
      default:
        if (!isascii(*p))
        {
          if (isUnicodeNewlineChar(decodeUTF8(p)))
            goto case '\n';
        }
        else if (isEOF(*p)) {
          error(tokenLineNum, tokenLineBegin, t.start,
            MID.UnterminatedBlockComment);
          break Loop;
        }
      }
    }
    t.kind = TOK.Comment;
    t.setWhitespaceFlag();
    t.end = this.p = p;
    return;
  }

  /// Scans a nested comment.
  ///
  /// $(BNF NestedComment := "/+" (NestedComment | AnyChar)* "+/")
  void scanNestedComment(ref Token t)
  {
    auto p = this.p;
    assert(p[-1] == '/' && *p == '+');
    auto tokenLineNum = lineNum;
    auto tokenLineBegin = lineBegin;
    uint level = 1;
  Loop:
    while (1)
    {
      switch (*++p)
      {
      case '/':
        if (p[1] == '+')
          ++p, ++level;
        continue;
      case '+':
        if (p[1] != '/')
          continue;
        ++p;
        if (--level != 0)
          continue;
        ++p;
        break Loop;
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        assert(isNewlineEnd(p));
        ++lineNum;
        setLineBegin(p+1);
        break;
      default:
        if (!isascii(*p))
        {
          if (isUnicodeNewlineChar(decodeUTF8(p)))
            goto case '\n';
        }
        else if (isEOF(*p)) {
          error(tokenLineNum, tokenLineBegin, t.start,
            MID.UnterminatedNestedComment);
          break Loop;
        }
      }
    }
    t.kind = TOK.Comment;
    t.setWhitespaceFlag();
    t.end = this.p = p;
    return;
  }

  /// Scans the postfix character of a string literal.
  ///
  /// $(BNF PostfixChar := "c" | "w" | "d")
  static char scanPostfix(ref char* p)
  {
    assert(p[-1] == '"' || p[-1] == '`' ||
      { version(D2) return p[-1] == '}';
               else return 0; }()
    );
    switch (*p)
    {
    case 'c':
    case 'w':
    case 'd':
      return *p++;
    default:
    }
    return 0;
  }

  /// Scans a normal string literal.
  ///
  /// $(BNF NormalStringLiteral := '"' (EscapeSequence | AnyChar)* '"')
  void scanNormalStringLiteral(ref Token t)
  {
    auto p = this.p;
    assert(*p == '"');
    auto tokenLineNum = lineNum;
    auto tokenLineBegin = lineBegin;
    t.kind = TOK.String;
    char[] value;
    char* prev = ++p; // Skip '"'. prev is used to copy chunks to value.
    uint c;
  Loop:
    while (1)
      switch (c = *p)
      {
      case '"':
        break Loop;
      case '\\':
        if (prev != p) value ~= String(prev, p);
        bool isBinary;
        c = scanEscapeSequence(p, isBinary);
        prev = p;
        if (isascii(c) || isBinary)
          value ~= c;
        else
          encodeUTF8(value, c);
        break;
      case '\r':
        c = 0;
        if (p[1] == '\n')
          ++p, c = 1;
        // goto LconvertNewline;
      LconvertNewline:
        // Need to substract c to get to the start of the newline.
        value ~= String(prev, p-c + 1); // +1 is for '\n'.
        value[$-1] = '\n'; // Convert Newline to '\n'.
        prev = p+1;
      case '\n':
        assert(isNewlineEnd(p));
        ++lineNum;
        setLineBegin(++p);
        break;
      case 0, _Z_:
        error(tokenLineNum, tokenLineBegin, t.start, MID.UnterminatedString);
        goto Lerr;
      default:
        if (!isascii(c) && isUnicodeNewlineChar(c = decodeUTF8(p)))
        {
          c = 2;
          goto LconvertNewline;
        }
        ++p;
      }
    assert(*p == '"');
    auto str = String(prev, p);
    if (value.length)
      value ~= str; // Append previous string.
    else
      value = str; // A slice from the text.
    ++p; // Skip '"'.
    t.strval = lookupString(value, scanPostfix(p));
  Lerr:
    t.end = this.p = p;
    return;
  }

  /// Scans an escape string literal.
  ///
  /// $(BNF EscapeStringLiteral := EscapeSequence+ )
  void scanEscapeStringLiteral(ref Token t)
  {
    assert(*p == '\\');
    char[] value;
    do
    {
      bool isBinary;
      auto c = scanEscapeSequence(p, isBinary);
      if (isascii(c) || isBinary)
        value ~= c;
      else
        encodeUTF8(value, c);
    } while (*p == '\\')
    t.strval = lookupString(value, 0);
    t.kind = TOK.String;
    t.end = p;
  }

  /// Scans a character literal.
  ///
  /// $(BNF CharLiteral := "'" (EscapeSequence | AnyChar) "'")
  void scanCharacterLiteral(ref Token t)
  {
    assert(*p == '\'');
    ++p;
    t.kind = TOK.CharLiteral;
    switch (*p)
    {
    case '\\':
      bool notused;
      t.dchar_ = scanEscapeSequence(p, notused);
      break;
    case '\'':
      error(t.start, MID.EmptyCharacterLiteral);
      break;
    default:
      if (isEndOfLine(p))
        break;
      uint c = *p;
      if (!isascii(c))
        c = decodeUTF8(p);
      t.dchar_ = c;
      ++p;
    }

    if (*p == '\'')
      ++p;
    else
      error(t.start, MID.UnterminatedCharacterLiteral);
    t.end = p;
  }

  /// Scans a raw string literal.
  ///
  /// $(BNF RawStringLiteral := 'r"' AnyChar* '"' | "`" AnyChar* "`")
  void scanRawStringLiteral(ref Token t)
  {
    auto p = this.p;
    assert(*p == '`' || *p == '"' && p[-1] == 'r');
    auto tokenLineNum = lineNum;
    auto tokenLineBegin = lineBegin;
    t.kind = TOK.String;
    uint delim = *p;
    char[] value;
    uint c;
  Loop:
    while (1)
    {
      c = *++p;
      switch (c)
      {
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        assert(isNewlineEnd(p));
        c = '\n'; // Convert Newline to '\n'.
        ++lineNum;
        setLineBegin(p+1);
        break;
      case '`':
      case '"':
        if (c == delim)
          break Loop;
        break;
      case 0, _Z_:
        error(tokenLineNum, tokenLineBegin, t.start,
          delim == '"' ?
            MID.UnterminatedRawString : MID.UnterminatedBackQuoteString);
        goto Lerr;
      default:
        if (!isascii(c))
        {
          if (isUnicodeNewlineChar(c = decodeUTF8(p)))
            goto case '\n';
          encodeUTF8(value, c);
          continue;
        }
      }
      assert(isascii(c));
      value ~= c;
    }
    assert(*p == '"' || *p == '`');
    ++p;
    t.strval = lookupString(value, scanPostfix(p));
  Lerr:
    t.end = this.p = p;
    return;
  }

  /// Scans a hexadecimal string literal.
  ///
  /// $(BNF HexStringLiteral := 'x"' (HexDigit HexDigit)* '"'
  ////HexDigit := [a-fA-F\d])
  void scanHexStringLiteral(ref Token t)
  {
    auto p = this.p;
    assert(p[0] == 'x' && p[1] == '"');
    t.kind = TOK.String;

    auto tokenLineNum = lineNum;
    auto tokenLineBegin = lineBegin;

    uint c;
    ubyte[] value;
    ubyte h; // hex number
    uint n; // number of hex digits

    ++p;
    assert(*p == '"');
  Loop:
    while (1)
    {
      c = *++p;
      switch (c)
      {
      case '"':
        break Loop;
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        assert(isNewlineEnd(p));
        ++lineNum;
        setLineBegin(p+1);
        continue;
      default:
        if (ishexad(c))
        {
          if (c <= '9')
            c -= '0';
          else
            c = (c|0x20) - 87; // ('a'-10) = 87

          if (n & 1)
          {
            h <<= 4;
            h |= c;
            value ~= h;
          }
          else
            h = cast(ubyte)c;
          ++n;
          continue;
        }
        else if (isspace(c))
          continue; // Skip spaces.
        else if (isEOF(c)) {
          error(tokenLineNum, tokenLineBegin, t.start,
            MID.UnterminatedHexString);
          goto Lerr;
        }
        else
        {
          auto errorAt = p;
          if (!isascii(c) && isUnicodeNewlineChar(c = decodeUTF8(p)))
            goto case '\n';
          error(errorAt, MID.NonHexCharInHexString, cast(dchar)c);
        }
      }
    }
    if (n & 1)
      error(tokenLineNum, tokenLineBegin, t.start,
        MID.OddNumberOfDigitsInHexString);
    ++p;
    t.strval = lookupString(cast(string)value, scanPostfix(p));
  Lerr:
    t.end = this.p = p;
    return;
  }

  /// Scans a delimited string literal.
  ///
  /// $(BNF
  ////DelimitedStringLiteral := 'q"' OpeningDelim AnyChar* MatchingDelim '"'
  ////OpeningDelim  := "[" | "(" | "{" | "&lt;" | Identifier EndOfLine
  ////MatchingDelim := "]" | ")" | "}" | "&gt;" | EndOfLine Identifier
  ////)
  void scanDelimitedStringLiteral(ref Token t)
  {
  version(D2)
  {
    auto p = this.p;
    assert(p[0] == 'q' && p[1] == '"');
    t.kind = TOK.String;

    auto tokenLineNum = lineNum;
    auto tokenLineBegin = lineBegin;

    char[] value;
    dchar nesting_delim, // '[', '(', '<', '{', or 0 if no nesting delimiter.
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
      nesting_delim = c;
      closing_delim = ')'; // c + 1
      break;
    case '[', '<', '{':
      nesting_delim = c;
      // Get to the closing counterpart. Feature of ASCII table.
      closing_delim = c + 2; // ']', '>' or '}'
      break;
    default:
      char* idbegin = p;
      if (scanNewline(p))
      {
        error(idbegin, MSG.DelimiterIsMissing);
        p = idbegin; // Reset and don't consume the newline.
        goto Lerr;
      }

      closing_delim = c;
      // TODO: Check for non-printable characters?
      if (!isascii(c))
      {
        closing_delim = decodeUTF8(p);
        if (!isUniAlpha(closing_delim))
          break; // Not an identifier.
      }
      else if (!isidbeg(c))
        break; // Not an identifier.

      // Scan: Identifier + EndOfLine
      do
      { c = *++p; }
      while (isident(c) || !isascii(c) && isUnicodeAlpha(p))
      // Store the identifier.
      str_delim = String(idbegin, p);
      // Scan a newline.
      if (scanNewline(p))
        ++lineNum,
        setLineBegin(p);
      else
        error(p, MSG.NoNewlineAfterIdDelimiter, str_delim);
      --p; // Go back one because of "c = *++p;" in main loop.
    }
    assert(closing_delim);

    if (isspace(closing_delim))
      error(p, MSG.DelimiterIsWhitespace);

    bool checkStringDelim(char* p)
    { // Returns true if p points to the closing string delimiter.
      assert(str_delim.length != 0, ""~*p);
      return lineBegin is p && // Must be at the beginning of a new line.
        this.endX()-p >= str_delim.length && // Check remaining length.
        p[0..str_delim.length] == str_delim; // Compare.
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
        assert(isNewlineEnd(p));
        c = '\n'; // Convert Newline to '\n'.
        ++lineNum;
        setLineBegin(p+1);
        break;
      case 0, _Z_:
        error(tokenLineNum, tokenLineBegin, t.start,
          MSG.UnterminatedDelimitedString);
        goto Lerr;
      default:
        if (!isascii(c))
        {
          auto begin = p;
          c = decodeUTF8(p);
          if (isUnicodeNewlineChar(c))
            goto case '\n';
          if (c == closing_delim)
            if (str_delim.length)
            { // Matched first character of the string delimiter.
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
          encodeUTF8(value, c);
          continue;
        }
        else
          if (c == nesting_delim)
            ++level;
          else if (c == closing_delim)
            if (str_delim.length)
            { // Matched first character of the string delimiter.
              if (checkStringDelim(p))
              {
                p += str_delim.length;
                goto Lreturn2;
              }
            }
            else if (--level == 0)
              goto Lreturn;
      }
      assert(isascii(c));
      value ~= c;
    }
  Lreturn: // Character delimiter.
    assert(c == closing_delim);
    assert(level == 0);
    ++p; // Skip closing delimiter.
  Lreturn2: // String delimiter.
    char postfix;
    if (*p == '"')
      postfix = scanPostfix((++p, p));
    else
      error(p, MSG.ExpectedDblQuoteAfterDelim,
        // Pass str_delim or encode and pass closing_delim as a string.
        (str_delim.length || encode(str_delim, closing_delim), str_delim));

    t.strval = lookupString(value, postfix);
  Lerr:
    t.end = this.p = p;
  } // version(D2)
  }

  /// Scans a token string literal.
  ///
  /// $(BNF TokenStringLiteral := "q{" Token* "}")
  void scanTokenStringLiteral(ref Token t)
  {
  version(D2)
  {
    assert(p[0] == 'q' && p[1] == '{');
    t.kind = TOK.String;

    auto tokenLineNum = lineNum;
    auto tokenLineBegin = lineBegin;

    // A guard against changes to 'this.hlinfo'.
    ++inTokenString;

    uint lineNum = this.lineNum;
    uint level = 1;

    ++p; ++p; // Skip q{
    char* str_begin = p, str_end = void;
    Token* inner_tokens; // The tokens inside this string.
    // Set to true, if '\r', LS, PS, or multiline tokens are encountered.
    bool convertNewlines;

    auto prev_t = &t;
    Token* new_t;
  Loop:
    while (1)
    {
      new_t = new Token;
      scan(*new_t);
      // Save the tokens in a doubly linked list.
      // Could be useful for various tools.
      new_t.prev = prev_t;
      prev_t.next = new_t;
      prev_t = new_t;
      switch (new_t.kind)
      {
      case TOK.LBrace:
        ++level;
        break;
      case TOK.RBrace:
        if (--level == 0)
        {
          inner_tokens = t.next;
          t.next = null;
          break Loop;
        }
        break;
      case TOK.String, TOK.Comment:
        if (new_t.isMultiline())
          convertNewlines = true;
        break;
      case TOK.Newline:
        if (*new_t.start != '\n')
          convertNewlines = true;
        break;
      case TOK.EOF:
        error(tokenLineNum, tokenLineBegin, t.start,
          MSG.UnterminatedTokenString);
        inner_tokens = t.next;
        t.next = new_t;
        break Loop;
      default:
      }
    }
    assert(new_t.kind == TOK.RBrace || new_t.kind == TOK.EOF);
    assert(new_t.kind == TOK.RBrace && t.next is null ||
           new_t.kind == TOK.EOF && t.next !is null);

    char postfix;
    // new_t is "}" or EOF.
    if (new_t.kind == TOK.EOF)
      str_end = t.end = new_t.start;
    else
    {
      str_end = p-1;
      postfix = scanPostfix(p);
      t.end = p;
    }

    auto value = String(str_begin, str_end);
    // Convert newlines to '\n'.
    if (convertNewlines)
    { // Copy the value and convert the newlines.
      value = new char[value.length];
      auto q = str_begin, s = value.ptr;
      for (; q < str_end; ++q)
        switch (*q)
        {
        case '\r':
          if (q[1] == '\n')
            ++q;
        case '\n':
          assert(isNewlineEnd(q));
          *s++ = '\n'; // Convert Newline to '\n'.
          break;
        default:
          if (isUnicodeNewline(q))
          {
            ++q; ++q;
            goto case '\n';
          }
          *s++ = *q; // Copy current character.
        }
      value.length = s - value.ptr;
    }

    auto strval = new StringValue;
    strval.str = lookupString(value);
    strval.pf = postfix;
    strval.tok_str = inner_tokens;
    t.strval = strval;

    --inTokenString;
  } // version(D2)
  }

  /// Scans an escape sequence.
  ///
  /// $(BNF
  ////EscapeSequence := "\\" (BinaryEsc | UnicodeEsc | CEsc | HTMLEsc)
  ////BinaryEsc := Octal{1,3} | "x" Hex{2}
  ////UnicodeEsc := "u" Hex{4} | "U" Hex{8}
  ////CEsc := "'" | '"' | "?" | "\\" | "a" | "b" | "f" | "n" | "r" | "t" | "v"
  ////HTMLEsc := "&" EntityName ";"
  ////EntityName := [a-zA-Z] [a-zA-Z\d]*
  ////)
  /// Params:
  ///   ref_p = Used to scan the sequence.
  ///   isBinary = Set to true for octal and hexadecimal escapes.
  /// Returns: The escape value.
  dchar scanEscapeSequence(ref char* ref_p, ref bool isBinary)
  out(result)
  { assert(isValidChar(result)); }
  body
  {
    auto p = ref_p;
    assert(*p == '\\');
    // Used for error reporting.
    MID mid;
    char[] err_msg, err_arg;

    ++p; // Skip '\\'.
    uint c = char2ev(*p); // Table lookup.
    if (c)
    {
      ++p;
      goto Lreturn;
    }

    uint digits = void;

    switch (*p)
    {
    case 'x':
      isBinary = true;
      digits = 2;
    case_Unicode:
      assert(c == 0);
      assert(digits == 2 || digits == 4 || digits == 8);
      while (1)
      {
        ++p;
        if (ishexad(*p))
        {
          c *= 16;
          if (*p <= '9')
            c += *p - '0';
          else
            c += (*p|0x20) - 87; // ('a'-10) = 87

          if (--digits == 0)
          {
            ++p;
            if (isValidChar(c))
              goto Lreturn; // Return valid escape value.

            mid = MID.InvalidUnicodeEscapeSequence;
            goto Lerr;
          }
          continue;
        }

        mid = MID.InsufficientHexDigits;
        goto Lerr;
      }
      break;
    case 'u':
      digits = 4;
      goto case_Unicode;
    case 'U':
      digits = 8;
      goto case_Unicode;
    default:
      if (isoctal(*p))
      {
        isBinary = true;
        assert(c == 0);
        c += *p++ - '0';
        if (!isoctal(*p))
          goto Lreturn;
        c = c * 8 + *p++ - '0';
        if (!isoctal(*p))
          goto Lreturn;
        c = c * 8 + *p++ - '0';
        if (c <= 0xFF)
          goto Lreturn;

        err_msg = MSG.InvalidOctalEscapeSequence;
        goto Lerr2;
      }
      else if (*p == '&')
      {
        if (isalpha(*++p))
        {
          auto begin = p;
          while (isalnum(*++p))
          {}

          if (*p == ';')
          { // Pass entity excluding '&' and ';'.
            c = entity2Unicode(String(begin, p));
            ++p; // Skip ;
            if (c)
              goto Lreturn; // Return valid escape value.
            else
              mid = MID.UndefinedHTMLEntity;
          }
          else
            mid = MID.UnterminatedHTMLEntity;
        }
        else
          mid = MID.InvalidBeginHTMLEntity;
      }
      else if (isEndOfLine(p))
        (mid = MID.UndefinedEscapeSequence),
        (err_arg = isEOF(*p) ? `\EOF` : `\NewLine`);
      else
      {
        err_arg = `\`;
        // TODO: check for non-printable character?
        if (isascii(*p))
          err_arg ~= *p;
        else
          encodeUTF8(err_arg, decodeUTF8(p));
        ++p;
        mid = MID.UndefinedEscapeSequence;
      }
      goto Lerr;
    }

  Lreturn:
    ref_p = p;
    return c;

  Lerr:
    err_msg = GetMsg(mid);
  Lerr2:
    if (!err_arg.length)
      err_arg = String(ref_p, p);
    error(ref_p, err_msg, err_arg);
    ref_p = p; // Is at the beginning of the sequence. Update now.
    return REPLACEMENT_CHAR; // Error: return replacement character.
  }

  /// Scans a number literal.
  ///
  /// $(BNF
  ////IntegerLiteral := (Dec | Hex | Bin | Oct) Suffix?
  ////Dec := "0" | [1-9] [\d_]*
  ////Hex := "0" [xX] "_"* HexDigits
  ////Bin := "0" [bB] "_"* [01] [01_]*
  ////Oct := "0" [0-7_]*
  ////Suffix := "L" [uU]? | [uU] "L"?
  ////)
  /// Invalid: "0b_", "0x_", "._" etc.
  void scanNumber(ref Token t)
  {
    auto p = this.p;
    ulong ulong_; // The integer value.
    bool overflow;
    bool isDecimal;
    size_t digits;

    if (*p != '0')
      goto LscanInteger;
    ++p; // Skip zero.
    // Check for xX bB ...
    switch (*p)
    {
    case 'x','X':
      goto LscanHex;
    case 'b','B':
      goto LscanBinary;
    case 'L':
      if (p[1] == 'i')
        goto LscanFloat; // 0Li
      break; // 0L
    case '.':
      if (p[1] == '.')
        break; // 0..
      // 0.
    case 'i','f','F', // Imaginary and float literal suffixes.
         'e', 'E':    // Float exponent.
      goto LscanFloat;
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
        goto LscanFloat;
      break;
    case 'L':
      if (p[1] != 'i')
        break;
    case 'i', 'f', 'F', 'e', 'E':
      goto LscanFloat;
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
      else
        ulong_ += (*p|0x20) - 87; // ('a'-10) = 87
    }

    assert(ishexad(p[-1]) || p[-1] == '_' || p[-1] == 'x' || p[-1] == 'X');
    assert(!ishexad(*p) && *p != '_');

    switch (*p)
    {
    case '.':
      if (p[1] == '.')
        break;
    case 'p', 'P':
      this.p = p;
      return scanHexFloat(t);
    default:
    }

    if (digits == 0 || digits > 16)
      error(t.start,
        digits == 0 ? MID.NoDigitsInHexNumber : MID.OverflowHexNumber);

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
      error(t.start,
        digits == 0 ? MID.NoDigitsInBinNumber : MID.OverflowBinaryNumber);

    assert(p[-1] == '0' || p[-1] == '1' || p[-1] == '_' ||
           p[-1] == 'b' || p[-1] == 'B', p[-1] ~ "");
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
        goto LscanFloat;
      break;
    case 'L':
      if (p[1] != 'i')
        break;
    case 'i', 'f', 'F', 'e', 'E':
      goto LscanFloat;
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
  Loop:
    while (1)
      switch (*p)
      {
      case 'L':
        if (suffix & Suffix.Long)
          break Loop;
        suffix |= Suffix.Long;
        ++p;
        continue;
      case 'u', 'U':
        if (suffix & Suffix.Unsigned)
          break Loop;
        suffix |= Suffix.Unsigned;
        ++p;
        continue;
      default:
        break Loop;
      }

    // Determine type of Integer.
    TOK kind;
    switch (suffix)
    {
    case Suffix.None:
      if (ulong_ & 0x8000_0000_0000_0000)
      {
        if (isDecimal)
          error(t.start, MID.OverflowDecimalSign);
        kind = TOK.UInt64;
      }
      else if (ulong_ & 0xFFFF_FFFF_0000_0000)
        kind = TOK.Int64;
      else if (ulong_ & 0x8000_0000)
        kind = isDecimal ? TOK.Int64 : TOK.UInt32;
      else
        kind = TOK.Int32;
      break;
    case Suffix.Unsigned:
      if (ulong_ & 0xFFFF_FFFF_0000_0000)
        kind = TOK.UInt64;
      else
        kind = TOK.UInt32;
      break;
    case Suffix.Long:
      if (ulong_ & 0x8000_0000_0000_0000)
      {
        if (isDecimal)
          error(t.start, MID.OverflowDecimalSign);
        kind = TOK.UInt64;
      }
      else
        kind = TOK.Int64;
      break;
    case Suffix.Unsigned | Suffix.Long:
      kind = TOK.UInt64;
      break;
    default:
      assert(0);
    }
    t.kind = kind;
    if (kind == TOK.Int64 || kind == TOK.UInt64)
    {
      version(X86_64)
      t.intval.ulong_ = ulong_;
      else
      t.intval = lookupUlong(ulong_);
    }
    else
      t.uint_ = cast(uint)ulong_;
    t.end = this.p = p;
    return;
  LscanFloat:
    this.p = p;
    scanFloat(t);
    return;
  }

  /// Returns a zero-terminated copy of the string where all
  /// underscores are removed.
  static char[] copySansUnderscores(char* begin, char* end)
  {
    assert(begin && begin < end);
    auto str = new char[end-begin+1]; // +1 for '\0'.
    auto p = begin, s = str.ptr;
    for (; p < end; ++p)
      if (*p != '_')
        *s++ = *p;
    *s = 0;
    str.length = s - str.ptr +1; // Adjust length.
    return str;
  }

  /// Scans a floating point number literal.
  ///
  /// $(BNF
  ////FloatLiteral := Float [fFL]? i?
  ////Float        := DecFloat | HexFloat
  ////DecFloat     := (DecDigits "." "_"* DecDigits? DecExponent?) |
  ////                ("." DecDigits DecExponent?)
  ////                (DecDigits DecExponent)
  ////DecExponent  := [eE] [+-]? DecDigits
  ////DecDigits    := \d [\d_]*
  ////)
  void scanFloat(ref Token t)
  {
    auto p = this.p;
    if (*p == '.')
    {
      assert(p[1] != '.');
      // This function was called by scan() or scanNumber().
      while (isdigit(*++p) || *p == '_') {}
    }
    else // This function was called by scanNumber().
      assert(delegate () {
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
        error(p, MID.FloatExpMustStartWithDigit);
    }

    this.p = p;
    finalizeFloat(t, copySansUnderscores(t.start, p));
  }

  /// Scans a hexadecimal floating point number literal.
  /// $(BNF
  ////HexFloat := "0" [xX] (HexDigits? "." HexDigits | HexDigits) HexExponent
  ////HexExponent := [pP] [+-]? DecDigits
  ////HexDigits := [a-fA-F\d] [a-fA-F\d_]*
  ////)
  void scanHexFloat(ref Token t)
  {
    auto p = this.p;
    assert(*p == '.' || *p == 'p' || *p == 'P');
    MID mid = MID.HexFloatExponentRequired;
    if (*p == '.')
      while (ishexad(*++p) || *p == '_') {}
    // Decimal exponent is required.
    if (*p != 'p' && *p != 'P')
      goto Lerr;
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

    this.p = p;
    finalizeFloat(t, copySansUnderscores(t.start, p));
    return;
  Lerr:
    t.kind = TOK.Float32;
    t.end = this.p = p;
    error(p, mid);
  }

  /// Sets the value of the token.
  /// Params:
  ///   t = Receives the value.
  ///   float_string = The well-formed float number string.
  void finalizeFloat(ref Token t, string float_string)
  {
    auto p = this.p;
    assert(float_string.length && float_string[$-1] == 0);
    // Finally check suffixes.
    TOK kind = void;
    if (*p == 'f' || *p == 'F')
      ++p, kind = TOK.Float32;
    else if (*p == 'L')
      ++p, kind = TOK.Float80;
    else
      kind = TOK.Float64;

    if (*p == 'i')
    {
      ++p;
      kind += 3; // Switch to imaginary counterpart.
      assert(kind == TOK.IFloat32 || kind == TOK.IFloat64 ||
             kind == TOK.IFloat80);
    }
    // TODO: test for overflow/underflow according to target platform.
    //       CompilationContext must be passed to Lexer for this.
    auto f = lookupFloat(float_string);
    if (f.isPInf())
      error(t.start, MID.OverflowFloatNumber);
    // else if (f.isNInf())
      // error(t.start, MSG.UnderflowFloatNumber);
    // else if (f.isNaN())
      // error(t.start, MSG.NaNFloat);
    t.mpfloat = f;
    t.kind = kind;
    t.end = this.p = p;
    return;
  }

  /// Scans a special token sequence.
  ///
  /// $(BNF SpecialTokenSequence := "#line" Integer Filespec? EndOfLine)
  void scanSpecialTokenSequence(ref Token t)
  {
    auto p = this.p;
    assert(*p == '#');

    auto hlval = new Token.HashLineValue;

    MID mid;
    char* errorAtColumn = p;
    char* tokenEnd = ++p;

    if (*cast(uint*)p != chars_line)
    {
      mid = MID.ExpectedIdentifierSTLine;
      goto Lerr;
    }

    p += 4;
    tokenEnd = p;

    // TODO: #line58"path/file" is legal. Require spaces?
    //       State.Space could be used for that purpose.
    enum State
    { /+Space,+/ Integer, OptionalFilespec, End }

    State state = State.Integer;

    while (!isEndOfLine(p))
    {
      if (isspace(*p))
      {}
      else if (state == State.Integer)
      {
        if (!isdigit(*p))
        {
          errorAtColumn = p;
          mid = MID.ExpectedIntegerAfterSTLine;
          goto Lerr;
        }
        auto newtok = new Token;
        hlval.lineNum = newtok;
        this.p = p;
        scan(*newtok);
        tokenEnd = p = this.p;
        if (newtok.kind != TOK.Int32 && newtok.kind != TOK.UInt32)
        {
          errorAtColumn = newtok.start;
          mid = MID.ExpectedIntegerAfterSTLine;
          goto Lerr;
        }
        state = State.OptionalFilespec;
        continue;
      }
      else if (state == State.OptionalFilespec && *p == '"')
      {
        auto fs = hlval.filespec = new Token;
        fs.start = p;
        fs.kind = TOK.Filespec;
        fs.setWhitespaceFlag();
        // Skip until closing '"'.
        while (*++p != '"' && !isEndOfLine(p))
          isascii(*p) || decodeUTF8(p);
        if (*p != '"')
        { // Error.
          errorAtColumn = fs.start;
          mid = MID.UnterminatedFilespec;
          fs.end = p;
          tokenEnd = p;
          goto Lerr;
        }
        auto start = fs.start +1; // +1 skips '"'
        auto strval = new StringValue;
        strval.str = String(start, p); // No need to zero-terminate.
        fs.strval = strval;
        fs.end = tokenEnd = ++p;
        state = State.End;
        continue;
      }
      else/+ if (state == State.End)+/
      {
        errorAtColumn = tokenEnd;
        mid = MID.UnterminatedSpecialToken;
        goto Lerr;
      }
      ++p;
    }
    assert(isEndOfLine(p));

    if (state == State.Integer)
    {
      errorAtColumn = p;
      mid = MID.ExpectedIntegerAfterSTLine;
      goto Lerr;
    }

    // Evaluate #line only when not in token string.
    if (!inTokenString && hlval.lineNum)
    {
      if (!hlinfo)
      {
        hlinfo = new Token.HashLineInfo;
        hlinfo.path = srcText.filePath;
      }
      hlinfo.setLineNum(this.lineNum, hlval.lineNum.uint_);
      if (hlval.filespec)
        hlinfo.path = hlval.filespec.strval.str;
    }

    if (0) // Only issue an error if jumped here.
    Lerr:
      error(errorAtColumn, mid);

    t.kind = TOK.HashLine;
    t.setWhitespaceFlag();
    t.hlval = hlval;
    t.end = this.p = tokenEnd;
    return;
  }

  /// Inserts an empty dummy token (TOK.Empty) before t.
  ///
  /// Useful in the parsing phase for representing a node in the AST
  /// that doesn't consume an actual token from the source text.
  Token* insertEmptyTokenBefore(Token* t)
  {
    assert(t !is null && t.prev !is null);
    assert(text.ptr <= t.start && t.start < end, Token.toString(t.kind));
    assert(text.ptr <= t.end && t.end <= end, Token.toString(t.kind));

    auto prev_t = t.prev;
    auto new_t = new Token;
    new_t.kind = TOK.Empty;
    new_t.start = new_t.end = prev_t.end;
    // Link in new token.
    prev_t.next = new_t;
    new_t.prev = prev_t;
    new_t.next = t;
    t.prev = new_t;
    return new_t;
  }

  /// Returns the error line number.
  uint errorLineNumber(uint lineNum)
  {
    if (hlinfo)
      lineNum -= hlinfo.lineNum;
    return lineNum;
  }

  /// Returns the file path for error messages.
  string errorFilePath()
  {
    return hlinfo ? hlinfo.path : srcText.filePath;
  }

  /// Forwards error parameters.
  void error(char* columnPos, char[] msg, ...)
  {
    error_(this.lineNum, this.lineBegin, columnPos, msg, _arguments, _argptr);
  }

  /// ditto
  void error(char* columnPos, MID mid, ...)
  {
    error_(this.lineNum, this.lineBegin, columnPos,
      GetMsg(mid), _arguments, _argptr);
  }

  /// ditto
  void error(uint lineNum, char* lineBegin, char* columnPos, MID mid, ...)
  {
    error_(lineNum, lineBegin, columnPos, GetMsg(mid), _arguments, _argptr);
  }

  /// ditto
  void error(uint lineNum, char* lineBegin, char* columnPos, char[] msg, ...)
  {
    error_(lineNum, lineBegin, columnPos, msg, _arguments, _argptr);
  }

  /// Creates an error report and appends it to a list.
  /// Params:
  ///   lineNum = The line number.
  ///   lineBegin = Points to the first character of the current line.
  ///   columnPos = Points to the character where the error is located.
  ///   msg = The error message.
  void error_(uint lineNum, char* lineBegin, char* columnPos, char[] msg,
              TypeInfo[] _arguments, va_list _argptr)
  {
    lineNum = this.errorLineNumber(lineNum);
    auto errorPath = errorFilePath();
    auto location = new Location(errorPath, lineNum, lineBegin, columnPos);
    msg = Format(_arguments, _argptr, msg);
    auto error = new LexerError(location, msg);
    errors ~= error;
    if (diag !is null)
      diag ~= error;
  }

  /// Returns true if the current character to be decoded is
  /// a Unicode alpha character.
  /// Params:
  ///   ref_p = Is set to the last trail byte if true is returned.
  static bool isUnicodeAlpha(ref char* ref_p)
  {
    char* p = ref_p;
    assert(!isascii(*p),
      "check for ASCII char before calling isUnicodeAlpha().");
    dchar d = *p;
    ++p; // Move to second byte.
    // Error if second byte is not a trail byte.
    if (!isTrailByte(*p))
      return false;
    // Check for overlong sequences.
    switch (d)
    {
    case 0xE0, 0xF0, 0xF8, 0xFC:
      if ((*p & d) == 0x80)
        return false;
    default:
      if ((d & 0xFE) == 0xC0) // 1100000x
        return false;
    }
    const char[] checkNextByte = "if (!isTrailByte(*++p))"
                                 "  return false;";
    const char[] appendSixBits = "d = (d << 6) | *p & 0b0011_1111;";
    // Decode
    if ((d & 0b1110_0000) == 0b1100_0000)
    {
      d &= 0b0001_1111;
      mixin(appendSixBits);
    }
    else if ((d & 0b1111_0000) == 0b1110_0000)
    {
      d &= 0b0000_1111;
      mixin(appendSixBits ~
            checkNextByte ~ appendSixBits);
    }
    else if ((d & 0b1111_1000) == 0b1111_0000)
    {
      d &= 0b0000_0111;
      mixin(appendSixBits ~
            checkNextByte ~ appendSixBits ~
            checkNextByte ~ appendSixBits);
    }
    else
      return false;

    assert(isTrailByte(*p));
    if (!isValidChar(d) || !isUniAlpha(d))
      return false;
    // Only advance pointer if this is a Unicode alpha character.
    ref_p = p;
    return true;
  }

  /// Decodes the next UTF-8 sequence.
  ///
  /// Params:
  ///   ref_p = Set to the last trail byte.
  dchar decodeUTF8(ref char* ref_p)
  {
    char* p = ref_p;
    assert(!isascii(*p), "check for ASCII char before calling decodeUTF8().");
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

    // See how many bytes need to be decoded.
    if ((d & 0b1110_0000) == 0b1100_0000)
    { // 110xxxxx 10xxxxxx
      d &= 0b0001_1111;
      goto L2Bytes;
    }
    else if ((d & 0b1111_0000) == 0b1110_0000)
    { // 1110xxxx 10xxxxxx 10xxxxxx
      d &= 0b0000_1111;
      goto L3Bytes;
    }
    else if ((d & 0b1111_1000) == 0b1111_0000)
    { // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
      d &= 0b0000_0111;
      goto L4Bytes;
    }
    else
      // 5 and 6 byte UTF-8 sequences are not allowed yet.
      // 111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
      // 1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
      goto Lerr;

    // Decode the bytes now.
  L4Bytes:
    mixin(appendSixBits);
    mixin(checkNextByte);
  L3Bytes:
    mixin(appendSixBits);
    mixin(checkNextByte);
  L2Bytes:
    mixin(appendSixBits);

    assert(isTrailByte(*p));

    if (!isValidChar(d))
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
      while (*p && !isValidLead(*p))
        ++p;
      --p;
      assert(!isTrailByte(p[1]) && p < this.endX());
    Lerr2:
      d = REPLACEMENT_CHAR;
      error(ref_p, MID.InvalidUTF8Sequence, formatBytes(ref_p, p));
    }
    // Advance the pointer and return.
    ref_p = p;
    return d;
  }

  /// Encodes the character d and appends it to str.
  static void encodeUTF8(ref char[] str, dchar d)
  {
    assert(!isascii(d), "check for ASCII char before calling encodeUTF8().");
    assert(isValidChar(d),
      "check if character is valid before calling encodeUTF8().");

    char[6] b = void;
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

  /// Formats the bytes between start and end (excluding end.)
  /// Returns: e.g.: "abc" -> "\x61\x62\x63"
  static char[] formatBytes(char* start, char* end)
  {
    const formatLen = 4; // `\xXX`.length
    const H = "0123456789ABCDEF"; // Hex numerals.
    auto strLen = end-start;
    char[] result = new char[strLen*formatLen]; // Allocate space.
    char* p = result.ptr;
    foreach (c; start[0..strLen])
      (*p++ = '\\'), (*p++ = 'x'), (*p++ = H[c>>4]), (*p++ = H[c&0x0F]);
    assert(p is result.ptr+result.length);
    return result;
  }

  /// Searches for an invalid UTF-8 sequence in str.
  /// Returns: a formatted string of the invalid sequence (e.g. "\xC0\x80").
  static string findInvalidUTF8Sequence(string str)
  {
    char* p = str.ptr, end = p + str.length;
    while (p < end)
      if (decode(p, end) == ERROR_CHAR)
      {
        auto begin = p;
        // Skip trail-bytes.
        while (++p < end && !isValidLead(*p))
        {}
        return Lexer.formatBytes(begin, p);
      }
    assert(p == end);
    return null;
  }
}

/// Tests the lexer with a list of tokens.
unittest
{
  Stdout("Testing Lexer.\n");
  struct Pair
  {
    char[] tokenText;
    TOK kind;
  }
  static Pair[] pairs = [
    {"#!äöüß",  TOK.Shebang},       {"\n",      TOK.Newline},
    {"//çay",   TOK.Comment},       {"\n",      TOK.Newline},
                                    {"&",       TOK.AndBinary},
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
    {"0",       TOK.Int32},         {"\n",      TOK.Newline},
    {"\r",      TOK.Newline},       {"\r\n",    TOK.Newline},
    {"\u2028",  TOK.Newline},       {"\u2029",  TOK.Newline},
    {"'c'",     TOK.Char},          {`'\''`,    TOK.Char},
    {`"dblq"`,  TOK.String},        {"`raw`",   TOK.String},
    {`r"aw"`,   TOK.String},        {`x"0123456789abcdef"`, TOK.String},
  ];

  version(D2)
  {
  static Pair[] pairs2 = [
    {"@",       TOK.At},
    {"^^",      TOK.Pow},
    {"^^=",     TOK.PowAssign},
    {"q\"ⱷ\n\nⱷ\"", TOK.String},    {`q"(())"`, TOK.String},
    {`q"{{}}"`,     TOK.String},    {`q"[[]]"`, TOK.String},
    {`q"<<>>"`,     TOK.String},    {`q"/__/"`, TOK.String},
    {`q"∆⟵✻⟶∆"`,    TOK.String},    {`q"\⣯⣻\"`, TOK.String},
    {"q{toks...}",  TOK.String},    {"q{({#line 0\n})}", TOK.String},
    {"q\"HDOC\nq\"***\"\nHDOC\"", TOK.String},
    {"q\"ȨÖF\nq{***}\nȨÖF\"",   TOK.String},
    {`q{q"<>"q"()"q"[]"q"{}"q"//"q"\\"q{}}`,  TOK.String},
  ];
  }
  else // D1
  {
  static Pair[] pairs2 = [
    {"\\n",  TOK.String},           {"\\u2028", TOK.String}
  ];
  }
  pairs ~= pairs2;

  char[] src; // The source text to be scanned.

  // Join all token texts into a single string.
  foreach (i, pair; pairs)
    if (pair.kind == TOK.Comment &&
        pair.tokenText[1] == '/' || // Line comment.
        pair.kind == TOK.Shebang)
    {
      assert(pairs[i+1].kind == TOK.Newline); // Must be followed by a newline.
      src ~= pair.tokenText;
    }
    else
      src ~= pair.tokenText ~ " ";

  // Lex the constructed source text.
  auto tables = new LexerTables();
  auto lx = new Lexer(new SourceText("lexer_unittest", src), tables);
  lx.scanAll();

  foreach (e; lx.errors)
    Stdout.formatln("{}({},{})L: {}", e.filePath, e.loc, e.col, e.getMsg);

  auto token = lx.firstToken();

  for (uint i; i < pairs.length && token.kind != TOK.EOF;
       ++i, (token = token.next))
    if (token.text != pairs[i].tokenText)
      assert(0, Format("Scanned ‘{0}’ but expected ‘{1}’",
                       token.text, pairs[i].tokenText));
}

/// Tests the Lexer's peek() method.
unittest
{
  Stdout("Testing method Lexer.peek()\n");
  auto tables = new LexerTables();
  auto sourceText = new SourceText("", "unittest { }");
  auto lx = new Lexer(sourceText, tables);

  auto next = lx.head;
  lx.peek(next);
  assert(next.kind == TOK.Newline);
  lx.peek(next);
  assert(next.kind == TOK.Unittest);
  lx.peek(next);
  assert(next.kind == TOK.LBrace);
  lx.peek(next);
  assert(next.kind == TOK.RBrace);
  lx.peek(next);
  assert(next.kind == TOK.EOF);

  lx = new Lexer(new SourceText("", ""), tables);
  next = lx.head;
  lx.peek(next);
  assert(next.kind == TOK.Newline);
  lx.peek(next);
  assert(next.kind == TOK.EOF);
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
