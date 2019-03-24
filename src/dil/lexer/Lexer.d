/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.lexer.Lexer;

import dil.lexer.Token,
       dil.lexer.Funcs,
       dil.lexer.Identifier,
       dil.lexer.IDsEnum,
       dil.lexer.TokenSerializer,
       dil.lexer.Tables;
import dil.i18n.Messages;
import dil.Diagnostics,
       dil.HtmlEntities,
       dil.ChunkAllocator,
       dil.Array,
       dil.Version,
       dil.Unicode,
       dil.SourceText,
       dil.Time,
       dil.String;
import dil.Float : Float;
import util.uni : isUniAlpha;
import common;

/// The Lexer analyzes the characters of a source text and
/// produces an array of tokens.
class Lexer
{
  cchar* p; /// Points to the current character in the source text.
  cchar* end; /// Points one character past the end of the source text.
  SourceText srcText; /// The source text.

  TokenArray tokens; /// Array of Tokens.
  LexerTables tables; /// Used to look up token values.
  CharArray buffer; /// A buffer for string values.
  ChunkAllocator allocator; /// Allocates memory for non-token structs.

  /// Groups line information.
  static struct LineLoc
  {
    cchar* p; /// Points to the first character of the current line.
    uint n; /// Actual source text line number.
  }
  LineLoc lineLoc; /// Current line.

  uint inTokenString; /// > 0 if inside q{ }
  /// Holds the original file path and the modified one (by #line.)
  Token.HashLineInfo* hlinfo; /// Info set by "#line".

  // Members used for error messages:
  Diagnostics diag; /// For diagnostics.
  LexerError[] errors; /// List of errors.
  // End of variable members.

  alias T = S2T; /// Converts, e.g., T!"+" to TOK.Plus.

  static
  {
  const ushort chars_r = castInt(`r"`); /// `r"` as a ushort.
  const ushort chars_x = castInt(`x"`); /// `x"` as a ushort.
  const ushort chars_q = castInt(`q"`); /// `q"` as a ushort.
  const ushort chars_q2 = castInt(`q{`); /// `q{` as a ushort.
  const ushort chars_shebang = castInt("#!"); /// `#!` as a ushort.
  const uint chars_line = castInt("line"); /// `line` as a uint.
  }

  /// Constructs a Lexer object.
  /// Params:
  ///   srcText = The UTF-8 source code.
  ///   tables = Used to look up identifiers and token values.
  ///   diag = Used for collecting error messages.
  this(SourceText srcText, LexerTables tables, Diagnostics diag = null)
  {
    version(gc_tokens)
    {}
    else
      this.allocator.initialize(PAGESIZE);
    this.srcText = srcText;
    this.tables = tables;
    this.diag = diag ? diag : new Diagnostics();
    assert(text.length >= 4 && text[$-4..$] == SourceText.sentinelString,
      "source text has no sentinel character");
    this.p = text.ptr;
    this.end = this.p + text.length; // Point past the sentinel string.
    this.lineLoc.p = this.p;
    this.lineLoc.n = 1;
  }

  ~this()
  {
    allocator.destroy();
  }

  /// Returns the next free token from the array.
  /// NB: The bytes are not zeroed out.
  Token* newToken()
  {
    if (tokens.rem == 0)
      tokens.growX1_5();
    return tokens.cur++;
  }

  /// Allocates memory for T.
  T* new_(T)()
  {
    version (gc_tokens) // Use to test GC instead of custom allocator.
      return new T;
    else
    {
      auto t = cast(T*)allocator.allocate(T.sizeof);
      *t = T.init;
      return t;
    }
  }

  /// Callback function to TokenSerializer.deserialize().
  bool dlxCallback(Token* t)
  {
    switch (t.kind)
    { // Some tokens need special handling:
    case T!"Newline":
      setLineBegin(t.end);
      t.nlval = lookupNewline();
      break;
    case T!"Character": // May have escape sequences.
      this.p = t.start;
      scanCharacter(t);
      break;
    case T!"String": // Escape sequences; token strings; etc.
      this.p = t.start;
      dchar c = *cast(ushort*)p;
      switch (c)
      {
      case chars_r:
        ++this.p, scanRawString(t); break;
      case chars_x:
        scanHexString(t); break;
      version(D2)
      {
      case chars_q:
        scanDelimitedString(t); break;
      case chars_q2:
        scanTokenString(t); break;
      }
      default:
      }
      switch (*p)
      {
      case '`':
        scanRawString(t); break;
      case '"':
        scanNormalString(t); break;
      version(D1)
      { // Only in D1.
      case '\\':
        scanEscapeString(t); break;
      }
      default:
      }
      break;
    case T!"Comment": // Just rescan for newlines.
      if (t.isMultiline) // Mutliline tokens may have newlines.
        for (auto p = t.start, end = t.end; p < end;)
          if (scanNewline(p))
            setLineBegin(p);
          else
            ++p;
      break;
    case T!"Int32", T!"Int64", T!"UInt32", T!"UInt64":
      this.p = t.start;
      scanNumber(t); // Complicated. Let the method handle this.
      break;
    case T!"Float32", T!"Float64", T!"Float80",
         T!"IFloat32", T!"IFloat64", T!"IFloat80":
      // The token is complete. What remains is to get its value.
      t.mpfloat = lookupFloat(copySansUnderscores(t.start, t.end));
      break;
    case T!"#line":
      this.p = t.start;
      scanSpecialTokenSequence(t); // Complicated. Let the method handle this.
      break;
    case T!"#!Shebang", T!"Empty": // Whitespace tokens.
      break;
    default:
    }
    return true;
  }

  /// Loads the tokens from a dlx file.
  bool fromDLXFile(ubyte[] data)
  {
    auto dlxTokens = TokenSerializer.deserialize(
      data, this.text(), tables.idents, &dlxCallback);
    if (dlxTokens.length)
    {
      alias ts = dlxTokens;
      ts[0] = Token.init; // NullToken
      ts[1].kind = T!"HEAD";
      ts[1].ws = null;
      ts[1].start = ts[1].end = this.text.ptr;
      ts[1].pvoid = null;
      ts[2].kind = T!"Newline";
      ts[2].ws = null;
      ts[2].start = ts[2].end = this.text.ptr;
      ts[2].nlval = lookupNewline();
      ts[$-1] = Token.init; // NullToken
      this.p = ts[$-2].end;
      tokens.ptr = ts.ptr;
      tokens.cur = tokens.end = ts.ptr + ts.length;
    }
    else
    { /// Function failed. Reset...
      this.p = this.text.ptr;
      this.lineLoc.p = this.p;
      this.lineLoc.n = 1;
    }
    return !!dlxTokens.length;
  }

  /// Acquires the current buffer.
  CharArray getBuffer()
  {
    auto buffer = this.buffer;
    this.buffer = buffer.init;
    return buffer;
  }

  /// Takes over buffer if its capacity is greater than the current one.
  void setBuffer(CharArray buffer)
  {
    buffer.len = 0;
    if (buffer.cap > this.buffer.cap)
      this.buffer = buffer;
  }

  /// Returns the source text string.
  cstring text()
  {
    return srcText.data;
  }

  /// Returns the end pointer excluding the sentinel string.
  cchar* endX()
  {
    return this.end - SourceText.sentinelString.length;
  }

  /// Returns the first token of the source text.
  /// This can be the EOF token.
  /// Structure: [NullToken, HEAD, Newline, FirstToken, ..., NullToken]
  Token* firstToken()
  {
    return tokens.ptr + 3;
  }

  /// Returns the list of tokens excluding special beginning and end tokens.
  Token[] tokenList()
  {
    return firstToken[0 .. tokens.len-4];
  }

  /// Returns the HEAD token.
  Token* head()
  {
    return tokens.ptr + 1;
  }

  /// Returns the EOF token.
  Token* lastToken()
  {
    return tokens.cur - 2;
  }

  /// Sets the value of the special token.
  void finalizeSpecialToken(Token* t)
  {
    assert(t.kind == T!"SpecialID" && t.text[0..2] == "__");
    cstring str;
    switch (t.ident.idKind)
    {
    case IDK.FILE:
      str = errorFilePath();
      break;
    case IDK.LINE:
      t.sizet_ = this.errorLineNumber(this.lineNum);
      break;
    case IDK.DATE, IDK.TIME, IDK.TIMESTAMP:
      str = Time.now();
      switch (t.kind)
      {
      case IDK.DATE:
        str = Time.month_day(str) ~ ' ' ~ Time.year(str); break;
      case IDK.TIME:
        str = Time.time(str); break;
      case IDK.TIMESTAMP:
        break; // str is the timestamp.
      default: assert(0);
      }
      break;
    case IDK.VENDOR:
      str = VENDOR;
      break;
    case IDK.VERSION:
      t.uint_ = VERSION_MAJOR*1000 + VERSION_MINOR;
      break;
    case IDK.EOF:
      assert(t.text == "__EOF__");
      t.kind = T!"EOF"; // Convert to EOF token, so that the Parser will stop.
      break;
    default:
      assert(0);
    }
    if (str.ptr)
      t.strval = lookupString(str, '\0');
  }

  /// Returns the current line number.
  size_t lineNum()
  {
    return lineLoc.n;
  }

  /// Sets the line pointer and increments the line number.
  private void setLineBegin(cchar* p)
  {
    assert(isNewlineEnd(p - 1));
    lineLoc.p = p;
    lineLoc.n++;
  }

  /// Returns true if p points to the last character of a Newline.
  bool isNewlineEnd(cchar* p)
  {
    assert(p >= text.ptr && p < end);
    return (*p).In('\n', '\r') || (p-=2) >= text.ptr && p[0..3].In(LS, PS);
  }

  /// Returns true if p points inside the source text.
  bool isInText(cchar* p)
  {
    return text.ptr <= p && p < end;
  }

  alias StringValue = Token.StringValue;
  alias IntegerValue = Token.IntegerValue;
  alias NewlineValue = Token.NewlineValue;

  /// Looks up a StringValue. Copies str if it's not a slice from the src text.
  StringValue* lookupString(cstring str, char postfix)
  {
    return tables.lookupString(str, postfix, !isInText(str.ptr));
  }

  /// Forwards to tables.lookupString().
  cbinstr lookupString(cbinstr bstr)
  {
    auto str = cast(cstring)bstr;
    return tables.lookupString(hashOf(str), str);
  }

  /// Looks up a Float in the table.
  /// Params:
  ///   str = The zero-terminated string of the float number.
  Float lookupFloat(cstring str)
  {
    assert(str.length && str[$-1] == 0);
    auto hash = hashOf(str);
    auto pFloat = hash in tables.floats;
    if (!pFloat)
    {
      int precision;
      auto f = new Float(precision, str);
      // if (precision == 0) // Exact precision.
      // {}
      // else if (precision < 0) // Lower precision.
      // {}
      // else /*if (precision > 0)*/ // Higher precision.
      // {}
      tables.floats[hash] = f;
      return f;
    }
    return *pFloat;
  }

  /// Looks up a newline value.
  NewlineValue* lookupNewline()
  {
    auto lineNum = this.lineNum;
    if (hlinfo)
    { // Don't insert into the table, when '#line' tokens are in the text.
      // This could be optimised with another table.
      auto nl = new_!(NewlineValue);
      nl.lineNum = lineNum;
      auto hlinfo = nl.hlinfo = new_!(Token.HashLineInfo);
      *hlinfo = *this.hlinfo;
      return nl;
    }
    return tables.lookupNewline(lineNum);
  }

  /// Advance t one token forward.
  void peek(ref Token* t)
  {
    t++;
    assert(tokens.ptr <= t && t < tokens.cur);
  }

  /// Scans the whole source text until EOF is encountered.
  void scanAll()
  { // The divisor 6 is an average measured by lexing large D projects.
    auto estimatedNrOfTokens = text.length / 6;
    tokens.cap = estimatedNrOfTokens;
    if (tokens.cap < 5)
      tokens.cap = 5; // Guarantee space for at least 5 tokens.
    auto first = newToken();
    *first = Token.init;
    auto head = newToken();
    head.kind = T!"HEAD";
    head.ws = null;
    head.start = head.end = this.p;
    head.pvoid = null;
    // Add a "virtual" newline as the first token after the head.
    auto newline = newToken();
    newline.kind = T!"Newline";
    newline.ws = null;
    newline.start = newline.end = this.p;
    newline.nlval = lookupNewline();
    // Scan optional shebang.
    if (*cast(ushort*)this.p == chars_shebang)
      scanShebang();
    // Main loop scanning the whole text.
    Token* t;
    do
      scan(t = newToken());
    while (t.kind != T!"EOF");
    // Add a terminating token, similar to 0 in C-like strings.
    auto last = newToken();
    *last = Token.init;

    auto toks = tokenList;
    foreach (x; toks)
    {}
  }

  /// The "shebang" may optionally appear once at the beginning of a file.
  /// $(BNF Shebang := "#!" AnyChar* EndOfLine)
  void scanShebang()
  {
    auto p = this.p;
    assert(p[0..2] == "#!");
    auto t = newToken();
    t.kind = T!"#!Shebang";
    t.start = p++;
    while (!isEndOfLine(++p))
      isascii(*p) || decodeUTF8(p);
    t.end = this.p = p;
    t.pvoid = null;
  }

  /// The main method which recognizes the characters that make up a token.
  ///
  /// Complicated tokens are scanned in separate methods.
  public void scan(Token* t)
  in
  {
    assert(text.ptr <= p && p < end);
  }
  out
  {
    assert(text.ptr <= t.start && t.start < end, t.kind.toString);
    assert(text.ptr <= t.end && t.end <= end, t.kind.toString);
    assert(t.kind != T!"Invalid", t.text);
  }
  body
  {
    TOK kind; // The token kind that will be assigned to t.kind.
    auto p = this.p; // Incrementing a stack variable is faster.
    // Scan whitespace.
    if (isspace(*p))
    {
      t.ws = p;
      while (isspace(*++p))
      {}
    }
    else
      t.ws = null;
    t.pvoid = null;

    // Scan the text of the token.
    dchar c = *p;
    {
      t.start = this.p = p;

      // Identifier or string literal.
      if (isidbeg(c))
      {
        c = *cast(ushort*)p;
        if (c == chars_r)
          return ++this.p, scanRawString(t);
        if (c == chars_x)
          return scanHexString(t);
        version(D2)
        {
        if (c == chars_q)
          return scanDelimitedString(t);
        if (c == chars_q2)
          return scanTokenString(t);
        }

        // Scan identifier.
      Lidentifier:
        do
        { c = *++p; }
        while (isident(c) || !isascii(c) && scanUnicodeAlpha(p));
        t.end = this.p = p;

        auto id = tables.lookupIdentifier(t.text);
        t.kind = id.kind;
        t.ident = id;
        assert(t.isKeyword || id.kind.In(T!"SpecialID", T!"Identifier"));

        if (kind == T!"SpecialID")
          finalizeSpecialToken(t);
        return;
      }

      /// Advances p if p[1] equals x.
      bool next(cchar x)
      {
        return p[1] == x ? (++p, 1) : 0;
      }

      // Newline.
      if (*p == '\n' || *p == '\r' && (next('\n'), true))
        goto Lnewline;

      assert(this.p == p);
      if (isdigit(c))
        return scanNumber(t);

      switch (c)
      {
      // Cases are sorted roughly according to times of occurrence.
      mixin(cases(",", "(", ")", ";", "{", "}", "[", "]", ":"));
      case '.': /* .  .[0-9]  ..  ... */
        if (next('.'))
          kind = next('.') ? T!"..." : T!"..";
        else if (isdigit(p[1]))
          return (this.p = p), scanFloat(t);
        else
          kind = T!".";
        goto Lcommon;
      case '=': /* =  ==  => */
        kind = next('=') ? T!"==" : (next('>') ? T!"=>" : T!"=");
        goto Lcommon;
      case '`':
        return scanRawString(t);
      case '"':
        return scanNormalString(t);
      version(D1)
      { // Only in D1.
      case '\\':
        return scanEscapeString(t);
      }
      case '\'':
        return scanCharacter(t);
      case '/':
        switch (*++p)
        {
        case '=':
          kind = T!"/=";
          goto Lcommon;
        case '+':
          return (this.p = p), scanNestedComment(t);
        case '*':
          return (this.p = p), scanBlockComment(t);
        case '/': // LineComment.
          while (!isEndOfLine(++p))
            isascii(*p) || decodeUTF8(p);
          kind = T!"Comment";
          goto Lreturn;
        default:
          kind = T!"/";
          goto Lreturn;
        }
        assert(0);
      case '>': /* >  >=  >>  >>=  >>>  >>>= */
        switch (*++p)
        {
        case '=':
          kind = T!">=";
          goto Lcommon;
        case '>':
          if (next('>'))
            kind = next('=') ? T!">>>=" : T!">>>";
          else
            kind = next('=') ? T!">>=" : T!">>";
          goto Lcommon;
        default:
          kind = T!">";
          goto Lreturn;
        }
        assert(0);
      case '<': /* <  <=  <>  <>=  <<  <<= */
        switch (*++p)
        {
        case '=':
          kind = T!"<=";
          goto Lcommon;
        case '<':
          kind = next('=') ? T!"<<=" : T!"<<";
          goto Lcommon;
        case '>':
          kind = next('=') ? T!"<>=" : T!"<>";
          goto Lcommon;
        default:
          kind = T!"<";
          goto Lreturn;
        }
        assert(0);
      case '!': /* !  !<  !>  !<=  !>=  !<>  !<>= */
        switch (*++p)
        {
        case '<':
          if (next('>'))
            kind = next('=') ? T!"!<>=" : T!"!<>";
          else
            kind = next('=') ? T!"!<=" : T!"!<";
          goto Lcommon;
        case '>':
          kind = next('=') ? T!"!>=" : T!"!>";
          goto Lcommon;
        case '=':
          kind = T!"!=";
          goto Lcommon;
        default:
          kind = T!"!";
          goto Lreturn;
        }
        assert(0);
      case '|': /* |  ||  |= */
        kind = next('=') ? T!"|=" : (next('|') ? T!"||" : T!"|");
        goto Lcommon;
      case '&': /* &  &&  &= */
        kind = next('=') ? T!"&=" : (next('&') ? T!"&&" : T!"&");
        goto Lcommon;
      case '+': /* +  ++  += */
        kind = next('=') ? T!"+=" : (next('+') ? T!"++" : T!"+");
        goto Lcommon;
      case '-': /* -  --  -= */
        kind = next('=') ? T!"-=" : (next('-') ? T!"--" : T!"-");
        goto Lcommon;
      case '~': /* ~  ~= */
        kind = next('=') ? T!"~=" : T!"~";
        goto Lcommon;
      case '*': /* *  *= */
        kind = next('=') ? T!"*=" : T!"*";
        goto Lcommon;
      version(D2)
      {
      case '^': /* ^  ^=  ^^  ^^= */
        if (next('='))
          kind = T!"^=";
        else if (next('^'))
          kind = next('=') ? T!"^^=" : T!"^^";
        else
          kind = T!"^";
        goto Lcommon;
      } // end of version(D2)
      else
      {
      case '^': /* ^  ^= */
        kind = next('=') ? T!"^=" : T!"^";
        goto Lcommon;
      }
      case '%': /* %  %= */
        kind = next('=') ? T!"%=" : T!"%";
        goto Lcommon;
      // Single character tokens:
      mixin(cases("@","$","?"));
      case '#':
        assert(this.p == p);
        return scanSpecialTokenSequence(t);
      default:
      }

      // Check for EOF
      if (isEOF(c))
      {
        assert(isEOF(*p), ""~*p);
        kind = T!"EOF";
        assert(t.start == p);
        goto Lreturn;
      }

      assert(this.p == p);
      if (!isascii(c) && isUniAlpha(c = decodeUTF8(p)))
        goto Lidentifier;

      if (isUnicodeNewlineChar(c))
        goto Lnewline;

      error(t.start, MID.IllegalCharacter, cast(dchar)c);

      kind = T!"Illegal";
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
    setLineBegin(++p);
    t.kind = T!"Newline";
    t.nlval = lookupNewline();
    t.end = this.p = p;
    return;
  }

  /// Generates case statements for token strings.
  /// ---
  //// // case_("<") ->
  /// case 60u:
  ///   kind = T!"<";
  ///   goto Lcommon;
  /// ---
  static char[] cases(string[] strs...)
  {
    char[] result;
    foreach (str; strs)
    {
      char[] label_str = "Lcommon".dup;
      if (str.length != 1) // Append length as a suffix.
        label_str ~= '0' + cast(char)str.length;
      result ~= `case castInt("`~str~`"): kind = T!"`~str~`"; `~
                "goto "~label_str~";\n";
    }
    return result;
  }
  //pragma(msg, cases("<", ">"));

  /// An alternative scan method.
  /// Profiling shows it's a bit slower.
  public void scan_(Token* t)
  in
  {
    assert(text.ptr <= p && p < end);
  }
  out
  {
    assert(text.ptr <= t.start && t.start < end, t.kind.toString);
    assert(text.ptr <= t.end && t.end <= end, t.kind.toString);
    assert(t.kind != T!"Invalid", t.text);
  }
  body
  {
    TOK kind; // The token kind that will be assigned to t.kind.
    auto p = this.p; // Incrementing a stack variable is faster.
    // Scan whitespace.
    if (isspace(*p))
    {
      t.ws = p;
      while (isspace(*++p))
      {}
    }
    else
      t.ws = null;
    t.pvoid = null;

    // Scan a token.
    t.start = this.p = p;

    uint c = *p;

    assert(p == t.start);
    // Check for ids first, as they occur the most often in source codes.
    if (isidbeg(c))
    {
      c = *cast(ushort*)p;
      if (c == chars_r)
        return (this.p = ++p), scanRawString(t);
      if (c == chars_x)
        return scanHexString(t);
      version(D2)
      {
      if (c == chars_q)
        return scanDelimitedString(t);
      if (c == chars_q2)
        return scanTokenString(t);
      }

      // Scan an identifier.
    Lidentifier:
      do
      { c = *++p; }
      while (isident(c) || !isascii(c) && scanUnicodeAlpha(p));
      t.end = this.p = p;

      auto id = tables.lookupIdentifier(t.text);
      t.kind = id.kind;
      t.ident = id;
      assert(t.isKeyword || id.kind.In(T!"SpecialID", T!"Identifier"));

      if (kind == T!"SpecialID")
        finalizeSpecialToken(t);
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
    mixin(cases(">>>=", "!<>="));
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
    mixin(cases("<<=", ">>=", ">>>", "...",
      "!<=", "!>=", "!<>", "<>=", "^^="));
    case castInt(LS), castInt(PS):
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
    case castInt("/+"):
      this.p = ++p; // Skip /
      return scanNestedComment(t);
    case castInt("/*"):
      this.p = ++p; // Skip /
      return scanBlockComment(t);
    case castInt("//"): // LineComment.
      ++p; // Skip /
      assert(*p == '/');
      while (!isEndOfLine(++p))
        isascii(*p) || decodeUTF8(p);
      kind = T!"Comment";
      goto Lreturn;
    mixin(cases("<=", ">=", "<<", ">>", "==", "=>", "!=", "!<", "!>", "<>",
      "..", "&&", "&=", "||", "|=", "++", "+=", "--", "-=", "*=", "/=", "%=",
      "^=", "~=", "^^"));
    case castInt("\r\n"):
      ++p;
      goto Lnewline;
    default:
    }

    static TOK[127] char2TOK = [
      '<': T!"<", '>': T!">", '^': T!"^", '!': T!"!",
      '&': T!"&", '|': T!"|", '+': T!"+", '-': T!"-",
      '=': T!"=", '~': T!"~", '*': T!"*", '/': T!"/",
      '%': T!"%", '(': T!"(", ')': T!")", '[': T!"[",
      ']': T!"]", '{': T!"{", '}': T!"}", ':': T!":",
      ';': T!";", '?': T!"?", ',': T!",", '$': T!"$",
      '@': T!"@"
    ];

    version(BigEndian)
    c >>>= 8;
    else
    c &= 0x000000FF;
    assert(p == t.start);
    assert(*p == c, Format("p={0},c={1}", *p, cast(dchar)c));
    // 1 character tokens.
    // TODO: consider storing the token type in ptable.
    if (c < 127 && (kind = char2TOK[c]) != 0)
      goto Lcommon;

    assert(this.p == p);
    switch (c)
    {
    case '\r', '\n':
      goto Lnewline;
    case '\'':
      return scanCharacter(t);
    case '`':
      return scanRawString(t);
    case '"':
      return scanNormalString(t);
    version(D2)
    {}
    else { // Only in D1.
    case '\\':
      return scanEscapeString(t);
    }
    case '.':
      if (isdigit(p[1]))
        return (this.p = p), scanFloat(t);
      kind = T!".";
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
      kind = T!"EOF";
      assert(t.start == p);
      goto Lreturn;
    }

    if (!isascii(c) && isUniAlpha(c = decodeUTF8(p)))
      goto Lidentifier;

    error(t.start, MID.IllegalCharacter, cast(dchar)c);

    kind = T!"Illegal";
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
    setLineBegin(++p);
    t.kind = T!"Newline";
    t.nlval = lookupNewline();
    t.end = this.p = p;
    return;
  }

  /// Scans a block comment.
  ///
  /// $(BNF BlockComment := "/*" AnyChar* "*/")
  void scanBlockComment(Token* t)
  {
    auto p = this.p;
    assert((p-1)[0..2] == "/*");
    auto tokenLine = this.lineLoc;
  Loop:
    while (1)
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
        goto case;
      case '\n':
        setLineBegin(p+1);
        break;
      default:
        if (!isascii(*p))
        {
          if (isUnicodeNewlineChar(decodeUTF8(p)))
            goto case '\n';
        }
        else if (isEOF(*p)) {
          error(tokenLine, t.start, MID.UnterminatedBlockComment);
          break Loop;
        }
      }
    t.kind = T!"Comment";
    t.end = this.p = p;
    return;
  }

  /// Scans a nested comment.
  ///
  /// $(BNF NestedComment := "/+" (NestedComment | AnyChar)* "+/")
  void scanNestedComment(Token* t)
  {
    auto p = this.p;
    assert((p-1)[0..2] == "/+");
    auto tokenLine = this.lineLoc;
    uint level = 1;
  Loop:
    while (1)
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
        goto case;
      case '\n':
        setLineBegin(p+1);
        break;
      default:
        if (!isascii(*p))
        {
          if (isUnicodeNewlineChar(decodeUTF8(p)))
            goto case '\n';
        }
        else if (isEOF(*p)) {
          error(tokenLine, t.start, MID.UnterminatedNestedComment);
          break Loop;
        }
      }
    t.kind = T!"Comment";
    t.end = this.p = p;
    return;
  }

  /// Scans the postfix character of a string literal.
  ///
  /// $(BNF PostfixChar := "c" | "w" | "d")
  static char scanPostfix(ref cchar* p)
  {
    assert(p[-1].In('"', '`', '}'));
    return (*p).In('c', 'w', 'd') ? *p++ : '\0';
  }

  /// Scans a normal string literal.
  ///
  /// $(BNF NormalStringLiteral := '"' (EscapeSequence | AnyChar)* '"')
  void scanNormalString(Token* t)
  {
    auto p = this.p;
    assert(*p == '"');
    auto tokenLine = this.lineLoc;
    t.kind = T!"String";
    auto value = getBuffer();
    auto prev = ++p; // Skip '"'. prev is used to copy chunks to value.
    cchar* prev2;

    while (*p != '"')
      switch (*p)
      {
      case '\\':
        if (prev != p) value ~= slice(prev, p);
        bool isBinary;
        auto c = scanEscapeSequence(p, isBinary);
        if (isascii(c) || isBinary)
          value ~= cast(char)c;
        else
          encodeUTF8(value, c);
        prev = p;
        break;
      case '\r':
        prev2 = p;
        if (p[1] == '\n')
          ++p;
      LconvertNewline:
        value ~= slice(prev, prev2 + 1); // +1 is for '\n'.
        *(value.cur-1) = '\n'; // Convert Newline to '\n'.
        prev = p+1;
        goto case;
      case '\n':
        setLineBegin(++p);
        break;
      case 0, _Z_:
        error(tokenLine, t.start, MID.UnterminatedString);
        goto Lerror;
      default:
        if (!isascii(*p) && isUnicodeNewlineChar(decodeUTF8(p)))
        {
          prev2 = p - 2;
          goto LconvertNewline;
        }
        ++p;
      }
    assert(*p == '"');

    {
    auto finalString = slice(prev, p);
    if (value.len)
      finalString = ((value ~= finalString), value[]); // Append previous string.
    ++p; // Skip '"'.
    t.strval = lookupString(finalString, scanPostfix(p));
    }
  Lerror:
    t.end = this.p = p;
    setBuffer(value);
    return;
  }

  /// Scans an escape string literal.
  ///
  /// $(BNF EscapeStringLiteral := EscapeSequence+ )
  void scanEscapeString(Token* t)
  {
    version(D1)
    {
    assert(*p == '\\');
    auto value = getBuffer();
    do
    {
      bool isBinary;
      auto c = scanEscapeSequence(p, isBinary);
      if (isascii(c) || isBinary)
        value ~= cast(char)c;
      else
        encodeUTF8(value, c);
    } while (*p == '\\');
    t.strval = lookupString(value, '\0');
    t.kind = T!"String";
    t.end = p;
    setBuffer(value);
    }
  }

  /// Scans a character literal.
  ///
  /// $(BNF CharacterLiteral := "'" (EscapeSequence | AnyChar) "'")
  void scanCharacter(Token* t)
  {
    assert(*p == '\'');
    t.kind = T!"Character";
    switch (*++p)
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
      t.dchar_ = isascii(*p) ? *p : decodeUTF8(p);
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
  void scanRawString(Token* t)
  {
    auto p = this.p;
    assert(*p == '`' || (p-1)[0..2] == `r"`);
    auto tokenLine = this.lineLoc;
    t.kind = T!"String";
    uint delim = *p;
    auto value = getBuffer();
    auto prev = ++p;
    cchar* prev2;

    while (*p != delim)
      switch (*p)
      {
      case '\r':
        prev2 = p;
        if (p[1] == '\n')
          ++p;
      LconvertNewline:
        value ~= slice(prev, prev2 + 1);
        *(value.cur-1) = '\n'; // Convert Newline to '\n'.
        prev = p+1;
        goto case;
      case '\n':
        setLineBegin(++p);
        break;
      case 0, _Z_:
        error(tokenLine, t.start, (delim == '"' ?
          MID.UnterminatedRawString : MID.UnterminatedBackQuoteString));
        goto Lerror;
      default:
        if (!isascii(*p) && isUnicodeNewlineChar(decodeUTF8(p)))
        {
          prev2 = p - 2;
          goto LconvertNewline;
        }
        ++p;
      }
    assert((*p).In('"', '`'));

    {
    auto finalString = slice(prev, p);
    if (value.len)
      finalString = ((value ~= finalString), value[]); // Append previous string.
    ++p; // Skip '"' or '`'.
    t.strval = lookupString(finalString, scanPostfix(p));
    }
  Lerror:
    t.end = this.p = p;
    setBuffer(value);
    return;
  }

  /// Scans a hexadecimal string literal.
  ///
  /// $(BNF HexStringLiteral := 'x"' (HexDigit HexDigit)* '"'
  ////HexDigit := [a-fA-F\d])
  void scanHexString(Token* t)
  {
    auto p = this.p;
    assert(p[0..2] == `x"`);
    t.kind = T!"String";

    auto tokenLine = this.lineLoc;

    auto value = getBuffer();
    ubyte h; // Current hex number.
    bool odd; // True if one hex digit has been scanned previously.

    ++p;
    assert(*p == '"');
    while (*++p != '"')
      switch (*p)
      {
      case '\r':
        if (p[1] == '\n')
          ++p;
        goto case;
      case '\n':
        setLineBegin(p+1);
        continue;
      default:
        dchar c = *p;
        if (hex2val(c))
        {
          if (odd)
            value ~= cast(ubyte)(h << 4 | c);
          else
            h = cast(ubyte)c;
          odd = !odd;
        }
        else if (isspace(c))
          continue; // Skip spaces.
        else if (isEOF(c)) {
          error(tokenLine, t.start, MID.UnterminatedHexString);
          goto Lerror;
        }
        else
        {
          auto errorAt = p;
          if (!isascii(c) && isUnicodeNewlineChar(c = decodeUTF8(p)))
            goto case '\n';
          error(errorAt, MID.NonHexCharInHexString, cast(dchar)c);
        }
      }
    if (odd)
      error(tokenLine, t.start, MID.OddNumberOfDigitsInHexString);
    ++p;
    t.strval = lookupString(value[], scanPostfix(p));
  Lerror:
    t.end = this.p = p;
    setBuffer(value);
    return;
  }

  /// Scans a delimited string literal.
  ///
  /// $(BNF
  ////DelimitedStringLiteral := 'q"' OpeningDelim AnyChar* MatchingDelim '"'
  ////OpeningDelim  := "[" | "(" | "{" | "&lt;" | Identifier EndOfLine
  ////MatchingDelim := "]" | ")" | "}" | "&gt;" | EndOfLine Identifier
  ////)
  void scanDelimitedString(Token* t)
  {
  version(D2)
  {
    auto p = this.p;
    assert(p[0..2] == `q"`);
    t.kind = T!"String";

    auto tokenLine = this.lineLoc;

    auto value = getBuffer();
    dchar nesting_delim, // '[', '(', '<', '{', or 0 if no nesting delimiter.
          closing_delim; // Will be ']', ')', '>', '},
                         // the first character of an identifier or
                         // any other Unicode/ASCII character.
    cstring str_delim; // Identifier delimiter.
    uint level = 1; // Counter for nestable delimiters.

    ++p; ++p; // Skip q"
    auto prev = p;
    cchar* prev2;
    dchar c = *p;
    // Scan the delimiter.
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
      if (isNewline(p))
      {
        error(p, MID.DelimiterIsMissing);
        goto Lerror;
      }

      auto idbegin = p;
      closing_delim = isascii(c) ? c : decodeUTF8(p);

      if (isidbeg(closing_delim) || isUniAlpha(closing_delim))
      { // Scan: Identifier Newline
        do
        { c = *++p; }
        while (isident(c) || !isascii(c) && scanUnicodeAlpha(p));
        str_delim = slice(idbegin, p); // Scanned identifier delimiter.
        if (scanNewline(p))
          setLineBegin(p);
        else
          error(p, MID.NoNewlineAfterIdDelimiter, str_delim);
        --p; // Go back one because of "c = *++p;" in main loop.
      }
    }
    assert(closing_delim);

    if (isspace(closing_delim))
      error(p, MID.DelimiterIsWhitespace);

    bool checkStringDelim(cchar* p)
    { // Returns true if p points to the closing string delimiter.
      assert(str_delim.length != 0, ""~*p);
      return this.lineLoc.p is p && // Must be at the beginning of a new line.
        this.endX()-p >= str_delim.length && // Check remaining length.
        p[0..str_delim.length] == str_delim; // Compare.
    }

    // Scan the contents of the string.
    while (1)
      switch (c = *++p)
      {
      case '\r':
        prev2 = p;
        if (p[1] == '\n')
          ++p;
      LconvertNewline:
        value ~= slice(prev, prev2 + 1); // +1 is for '\n'.
        *(value.cur-1) = '\n'; // Convert Newline to '\n'.
        prev = p+1;
        goto case;
      case '\n':
        setLineBegin(p+1);
        break;
      case 0, _Z_:
        error(tokenLine, t.start, MID.UnterminatedDelimitedString);
        goto Lerror;
      default:
        prev2 = p;
        if (!isascii(c))
        { // Unicode branch.
          c = decodeUTF8(p);
          if (isUnicodeNewlineChar(c))
            goto LconvertNewline;
          if (c == closing_delim)
            if (str_delim.length)
            { // Matched first character of the string delimiter.
              if (checkStringDelim(prev2))
              {
                p = prev2 + str_delim.length;
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
        else // ASCII branch.
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
  Lreturn: // Character delimiter.
    assert(c == closing_delim);
    assert(level == 0);
    ++p; // Skip closing delimiter.
  Lreturn2: // String delimiter.
    {
    auto finalString = slice(prev, prev2);
    if (value.len)
      finalString = ((value ~= finalString), value[]); // Append previous string.

    char postfix;
    if (*p == '"')
      postfix = scanPostfix(++p);
    else
    { // Pass str_delim or encode and pass closing_delim as a string.
      if (!str_delim.length)
      {
        char[] tmp;
        encode(tmp, closing_delim);
        str_delim = tmp;
      }
      error(p, MID.ExpectedDblQuoteAfterDelim, str_delim);
    }
    t.strval = lookupString(finalString, postfix);
    }
  Lerror:
    t.end = this.p = p;
    setBuffer(value);
  } // version(D2)
  }

  /// Scans a token string literal.
  ///
  /// $(BNF TokenStringLiteral := "q{" Token* "}")
  void scanTokenString(Token* t)
  {
  version(D2)
  {
    assert(p[0..2] == `q{`);
    t.kind = T!"String";

    auto tokenLine = this.lineLoc;

    ++inTokenString; // A guard against changes to 'this.hlinfo'.

    ++p; ++p; // Skip q{
    cchar* str_begin = p, str_end; // Inner string.
    TokenArray innerTokens; // The tokens inside this string.
    innerTokens.cap = 1;
    // Set to true, if '\r', LS, PS, or multiline tokens are encountered.
    bool convertNewlines;

    Token* new_t;
    uint level = 1; // Current nesting level of curly braces.
  Loop:
    while (1)
    {
      if (innerTokens.rem == 0)
        innerTokens.growX1_5();
      scan(new_t = innerTokens.cur++);
      switch (new_t.kind)
      {
      case T!"{":
        ++level;
        break;
      case T!"}":
        if (--level == 0)
          break Loop;
        break;
      case T!"String", T!"Comment":
        if (new_t.isMultiline())
          convertNewlines = true;
        break;
      case T!"Newline":
        if (*new_t.start != '\n')
          convertNewlines = true;
        break;
      case T!"EOF":
        error(tokenLine, t.start, MID.UnterminatedTokenString);
        this.p = new_t.ws ? new_t.ws : new_t.start; // Reset.
        break Loop;
      default:
      }
    }
    assert(new_t.kind.In(T!"}", T!"EOF"));

    char postfix;
    if (new_t.kind == T!"EOF")
      str_end = t.end = p;
    else
    {
      str_end = p-1;
      postfix = scanPostfix(p);
      t.end = p;
    }
    *new_t = Token.init; // Terminate with a "0-token".

    auto value = slice(str_begin, str_end);
    // Convert newlines to '\n'.
    if (convertNewlines)
    { // Copy the value and convert the newlines.
      auto tmp = getBuffer();
      tmp.len = value.length;
      auto q = str_begin; // Reader.
      auto s = tmp.ptr; // Writer.
      for (; q < str_end; ++q)
        switch (*q)
        {
        case '\r':
          if (q[1] == '\n')
            ++q;
          goto case;
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
      tmp.len = s - tmp.ptr;
      value = tmp[];
      setBuffer(tmp);
    }

    auto strval = new_!(StringValue);
    strval.str = lookupString(cast(cbinstr)value);
    strval.pf = postfix;
    strval.tokens = innerTokens.ptr;
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
  dchar scanEscapeSequence(ref cchar* ref_p, out bool isBinary)
  out(result)
  { assert(isValidChar(result)); }
  body
  {
    auto p = ref_p;
    assert(*p == '\\');
    // Used for error reporting.
    MID mid;
    cstring err_arg;

    ++p; // Skip '\\'.
    dchar c = char2ev(*p); // Table lookup.
    if (c)
    {
      ++p;
      goto Lreturn;
    }

    switch (*p)
    {
    uint loopCounter;

    case 'x':
      isBinary = true;
      loopCounter = 1;
    case_Unicode:
      assert(c == 0 && loopCounter.In(1, 2, 4));
      mid = MID.InsufficientHexDigits;
      while (loopCounter--)
      { // Decode two hex digits.
        dchar x = *++p;
        if (!hex2val(x))
          goto Lerror; // Not a hexdigit.
        c = c << 4 | x;
        x = *++p;
        if (!hex2val(x))
          goto Lerror;
        c = c << 4 | x;
      }
      ++p;
      if (!isValidChar(c))
      {
        mid = MID.InvalidUnicodeEscapeSequence;
        goto Lerror;
      }
      break;
    case 'u':
      loopCounter = 2;
      goto case_Unicode;
    case 'U':
      loopCounter = 4;
      goto case_Unicode;
    default:
      size_t x = *p - '0';
      if (x < 8)
      { // Octal sequence.
        isBinary = true;
        assert(c == 0);
        c = x;
        if ((x = *++p - '0') >= 8)
          break;
        c = c * 8 + x;
        if ((x = *++p - '0') >= 8)
          break;
        c = c * 8 + x;
        ++p;
        if (c <= 0xFF)
          break;
        mid = MID.InvalidOctalEscapeSequence;
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
            c = entity2Unicode(slice(begin, p));
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
      else if (isEndOfLine(p)) {
        mid = MID.UndefinedEscapeSequence;
        err_arg = isEOF(*p) ? `\EOF` : `\NewLine`;
      }
      else
      {
        auto tmp = "\\".dup;
        // TODO: check for non-printable character?
        encode(tmp, isascii(*p) ? *p : decodeUTF8(p));
        err_arg = tmp;
        ++p;
        mid = MID.UndefinedEscapeSequence;
      }
      goto Lerror;
    }

  Lreturn:
    ref_p = p;
    return c;

  Lerror:
    if (!err_arg.length)
      err_arg = slice(ref_p, p);
    error(ref_p, mid, err_arg);
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
  void scanNumber(Token* t)
  {
    assert(isdigit(*p));
    auto p = this.p;
    ulong ulong_; // The integer value.
    bool overflow; // True if an overflow was detected.
    bool isDecimal; // True for Dec literals.
    bool hasDecimalDigits; // To check for 8s and 9s in octal numbers.
    size_t digits; // Used to detect overflow in hex/bin numbers.
    size_t x; // Current digit value.

    bool isfloat(char c)
    { // True if the decimal point '.' is not followed by:
      return c != '.' && !isidbeg(c) && isascii(c);
    }

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
      if (!isfloat(p[1]))
        break;
      goto LscanFloat; // 0.[0-9]
    case 'i','f','F', // Imaginary and float literal suffixes.
         'e', 'E':    // Float exponent.
      goto LscanFloat;
    default:
      if (*p == '_')
        goto LscanOctal; // 0_
      else if ((x = *p - '0') < 10)
        if (x > 7)
          goto Loctal_hasDecimalDigits; // 08 or 09
        else
          goto Loctal_scannedFirstDigit; // 0[0-7]
    }

    // Number 0
    assert(p[-1] == '0' && !isdigi_(*p) && ulong_ == 0);
    isDecimal = true;
    goto Lfinalize;

  LscanInteger:
    assert(*p != '0' && isdigit(*p));
    isDecimal = true;
    for (; 1; ++p)
      if ((x = *p - '0') < 10)
      {
        if (ulong_ < ulong.max/10 || (ulong_ == ulong.max/10 && x < 6))
          ulong_ = ulong_ * 10 + x;
        else
        { // Overflow: skip following digits.
          overflow = true;
          while (isdigit(*++p))
          {}
          break;
        }
      }
      else if (*p != '_')
        break;

    // The number could be a float, so check overflow below.
    switch (*p)
    {
    case '.':
      if (isfloat(p[1]))
        goto LscanFloat;
      break;
    case 'L':
      if (p[1] != 'i')
        break;
      goto LscanFloat;
    case 'i', 'f', 'F', 'e', 'E':
      goto LscanFloat;
    default:
    }

    if (overflow)
      error(t.start, MID.OverflowDecimalNumber);

    assert(isdigi_(p[-1]) && !isdigi_(*p));
    goto Lfinalize;

  LscanHex:
    assert(digits == 0);
    assert((*p).In('x', 'X'));
    while (1)
    {
      x = *++p;
      if (hex2val(x))
      {
        ulong_ = ulong_ << 4 | x;
        ++digits;
      }
      else if (*p != '_')
        break;
    }

    assert((ishexa_(p[-1]) || p[-1].In('x', 'X')) && !ishexa_(*p));

    switch (*p)
    {
    case '.':
      if (!isfloat(p[1]))
        break;
      goto case;
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
    assert((*p).In('b', 'B'));
    while (1)
      if ((x = *++p - '0') < 2)
      {
        ++digits;
        ulong_ = ulong_ * 2 + x;
      }
      else if (*p != '_')
        break;

    if (digits == 0 || digits > 64)
      error(t.start,
        digits == 0 ? MID.NoDigitsInBinNumber : MID.OverflowBinaryNumber);

    assert(p[-1].In('0', '1', '_', 'b', 'B'), p[-1] ~ "");
    assert(!(*p).In('0', '1', '_'));
    goto Lfinalize;

  LscanOctal:
    assert(*p == '_');
    while (1)
      if ((x = *++p - '0') < 8)
      {
        if (ulong_ < ulong.max/2 || (ulong_ == ulong.max/2 && x < 2))
        Loctal_scannedFirstDigit:
          ulong_ = ulong_ * 8 + x;
        else
        { // Overflow: skip following digits.
          overflow = true;
          while (isoctal(*++p))
          {}
          break;
        }
      }
      else if (*p != '_')
        break;

    if (isdigit(*p))
    {
    Loctal_hasDecimalDigits:
      hasDecimalDigits = true;
      while (isdigit(*++p))
      {}
    }

    // The number could be a float, so check errors below.
    switch (*p)
    {
    case '.':
      if (isfloat(p[1]))
        goto LscanFloat;
      break;
    case 'L':
      if (p[1] != 'i')
        break;
      goto LscanFloat;
    case 'i', 'f', 'F', 'e', 'E':
      goto LscanFloat;
    default:
    }

    version(D2)
    {
    if (ulong_ >= 8 || hasDecimalDigits)
      error(t.start, MID.OctalNumbersDeprecated);
    }
    else
    {
    if (hasDecimalDigits)
      error(t.start, MID.OctalNumberHasDecimals);
    if (overflow)
      error(t.start, MID.OverflowOctalNumber);
    }
    //goto Lfinalize;

  Lfinalize:
    {
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
        kind = T!"UInt64";
      }
      else if (ulong_ & 0xFFFF_FFFF_0000_0000)
        kind = T!"Int64";
      else if (ulong_ & 0x8000_0000)
        kind = isDecimal ? T!"Int64" : T!"UInt32";
      else
        kind = T!"Int32";
      break;
    case Suffix.Unsigned:
      if (ulong_ & 0xFFFF_FFFF_0000_0000)
        kind = T!"UInt64";
      else
        kind = T!"UInt32";
      break;
    case Suffix.Long:
      if (ulong_ & 0x8000_0000_0000_0000)
      {
        if (isDecimal)
          error(t.start, MID.OverflowDecimalSign);
        kind = T!"UInt64";
      }
      else
        kind = T!"Int64";
      break;
    case Suffix.Unsigned | Suffix.Long:
      kind = T!"UInt64";
      break;
    default:
      assert(0);
    }

    t.kind = kind;
    if (kind == T!"Int64" || kind == T!"UInt64")
    {
      version(X86_64)
      t.intval.ulong_ = ulong_;
      else
      t.intval = tables.lookupUlong(ulong_);
    }
    else
      t.uint_ = cast(uint)ulong_;
    t.end = this.p = p;
    return;
    }

  LscanFloat:
    this.p = p;
    scanFloat(t);
    return;
  }

  /// Returns a zero-terminated copy of the string where all
  /// underscores are removed.
  static char[] copySansUnderscores(cchar* begin, cchar* end)
  {
    auto s = String(begin, end + 1).dup;
    s[Neg(1)] = 0;
    return s.sub('_', "")[];
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
  void scanFloat(Token* t)
  {
    auto p = this.p;
    if (*p == '.')
    {
      assert(p[1] != '.');
      // This function was called by scan() or scanNumber().
      while (isdigi_(*++p))
      {}
    }
    else // This function was called by scanNumber().
      assert((*p).In('i', 'f', 'F', 'e', 'E') || p[0..2] == "Li");

    // Scan exponent.
    if (*p == 'e' || *p == 'E')
    {
      ++p;
      if (*p == '-' || *p == '+')
        ++p;
      if (isdigit(*p))
        while (isdigi_(*++p))
        {}
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
  void scanHexFloat(Token* t)
  {
    auto p = this.p;
    assert((*p).In('.', 'p', 'P'));
    MID mid = MID.HexFloatExponentRequired;
    if (*p == '.')
      while (ishexa_(*++p))
      {}
    // Decimal exponent is required.
    if (*p != 'p' && *p != 'P')
      goto Lerror;
    // Scan exponent
    assert((*p).In('p', 'P'));
    ++p;
    if (*p == '+' || *p == '-')
      ++p;
    if (!isdigit(*p))
    {
      mid = MID.HexFloatExpMustStartWithDigit;
      goto Lerror;
    }
    while (isdigi_(*++p))
    {}

    this.p = p;
    finalizeFloat(t, copySansUnderscores(t.start, p));
    return;
  Lerror:
    t.kind = T!"Float32";
    t.end = this.p = p;
    error(p, mid);
  }

  /// Sets the value of the token.
  /// Params:
  ///   t = Receives the value.
  ///   float_string = The well-formed float number string.
  void finalizeFloat(Token* t, cstring float_string)
  {
    auto p = this.p;
    assert(float_string.length && float_string[$-1] == 0);
    // Finally check suffixes.
    TOK kind = void;
    if (*p == 'f' || *p == 'F')
      ++p, kind = T!"Float32";
    else if (*p == 'L')
      ++p, kind = T!"Float80";
    else
      kind = T!"Float64";

    if (*p == 'i')
    {
      ++p;
      kind += 3; // Switch to imaginary counterpart.
      assert(kind.In(T!"IFloat32", T!"IFloat64", T!"IFloat80"));
    }
    // TODO: test for overflow/underflow according to target platform.
    //       CompilationContext must be passed to Lexer for this.
    auto f = lookupFloat(float_string);
    if (f.isPInf())
      error(t.start, MID.OverflowFloatNumber);
    // else if (f.isNInf())
      // error(t.start, MID.UnderflowFloatNumber);
    // else if (f.isNaN())
      // error(t.start, MID.NaNFloat);
    t.mpfloat = f;
    t.kind = kind;
    t.end = this.p = p;
    return;
  }

  /// Scans a special token sequence.
  ///
  /// $(BNF SpecialTokenSequence := "#line" Integer Filespec? EndOfLine)
  void scanSpecialTokenSequence(Token* t)
  {
    auto p = this.p;
    assert(*p == '#');

    auto hlval = new_!(Token.HashLineValue);

    MID mid;
    cchar* errorAtColumn = p;
    cchar* tokenEnd = ++p;

    if (*cast(uint*)p != chars_line)
    {
      mid = MID.ExpectedIdentifierSTLine;
      goto Lerror;
    }

    { // Start of scanning code block.
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
          goto Lerror;
        }
        auto newtok = new_!(Token);
        hlval.lineNum = newtok;
        this.p = p;
        scan(newtok);
        tokenEnd = p = this.p;
        if (newtok.kind != T!"Int32" && newtok.kind != T!"UInt32")
        {
          errorAtColumn = newtok.start;
          mid = MID.ExpectedIntegerAfterSTLine;
          goto Lerror;
        }
        state = State.OptionalFilespec;
        continue;
      }
      else if (state == State.OptionalFilespec && *p == '"')
      {
        auto fs = hlval.filespec = new_!(Token);
        fs.start = p;
        fs.kind = T!"Filespec";
        // Skip until closing '"'.
        while (*++p != '"' && !isEndOfLine(p))
          isascii(*p) || decodeUTF8(p);
        if (*p != '"')
        { // Error.
          errorAtColumn = fs.start;
          mid = MID.UnterminatedFilespec;
          fs.end = p;
          tokenEnd = p;
          goto Lerror;
        }
        auto str = slice(fs.start + 1, p); // Get string excluding "".
        fs.strval = lookupString(str, '\0');
        fs.end = tokenEnd = ++p;
        state = State.End;
        continue;
      }
      else/+ if (state == State.End)+/
      {
        errorAtColumn = tokenEnd;
        mid = MID.UnterminatedSpecialToken;
        goto Lerror;
      }
      ++p;
    }
    assert(isEndOfLine(p));

    if (state == State.Integer)
    {
      errorAtColumn = p;
      mid = MID.ExpectedIntegerAfterSTLine;
      goto Lerror;
    }
    } // End of scanning code block.

    // Evaluate #line only when not in token string.
    if (!inTokenString && hlval.lineNum)
    {
      if (!hlinfo)
      {
        hlinfo = new_!(Token.HashLineInfo);
        hlinfo.path = srcText.filePath;
      }
      hlinfo.setLineNum(this.lineNum, hlval.lineNum.sizet_);
      if (hlval.filespec)
        hlinfo.path = cast(cstring)hlval.filespec.strval.str;
    }

    if (0) // Only issue an error if jumped here.
    Lerror:
      error(errorAtColumn, mid);

    t.kind = TOK.HashLine;
    t.hlval = hlval;
    t.end = this.p = tokenEnd;
    return;
  }

  /// Returns the error line number.
  size_t errorLineNumber(size_t lineNum)
  {
    if (hlinfo)
      lineNum -= hlinfo.lineNum;
    return lineNum;
  }

  /// Returns the file path for error messages.
  cstring errorFilePath()
  {
    return hlinfo ? hlinfo.path : srcText.filePath;
  }

  /// Forwards error parameters.
  void error(cchar* columnPos, MID mid, ...)
  {
    error(_arguments, _argptr, this.lineLoc, columnPos, diag.bundle.msg(mid));
  }

  /// ditto
  void error(LineLoc line, cchar* columnPos, MID mid, ...)
  {
    error(_arguments, _argptr, line, columnPos, diag.bundle.msg(mid));
  }

  /// Creates an error report and appends it to a list.
  /// Params:
  ///   line = The line number and pointer to the first character of a line.
  ///   columnPos = Points to the character where the error is located.
  ///   msg = The error message.
  void error(TypeInfo[] _arguments, va_list _argptr,
    LineLoc line, cchar* columnPos, cstring msg)
  {
    line.n = this.errorLineNumber(line.n);
    auto errorPath = errorFilePath();
    auto location = new Location(errorPath, line.n, line.p, columnPos);
    msg = diag.format(_arguments, _argptr, msg);
    auto error = new LexerError(location, msg);
    errors ~= error;
    diag ~= error;
  }

  /// Returns true if the current character to be decoded is
  /// a Unicode alpha character.
  /// Params:
  ///   ref_p = Is set to the last trail byte if true is returned.
  static bool scanUnicodeAlpha(ref cchar* ref_p)
  {
    auto p = ref_p;
    assert(!isascii(*p),
      "check for ASCII char before calling scanUnicodeAlpha().");
    dchar d = *p;
    ++p; // Move to second byte.
    // Error if second byte is not a trail byte.
    if (!isTrailByte(*p))
      return false;
    // Check for overlong sequences.
    if (d.In(0xE0, 0xF0, 0xF8, 0xFC) && (*p & d) == 0x80 ||
        (d & 0xFE) == 0xC0) // 1100000x
      return false;
    const string checkNextByte = "if (!isTrailByte(*++p))" ~
                                 "  return false;";
    const string appendSixBits = "d = (d << 6) | *p & 0b0011_1111;";
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
  dchar decodeUTF8(ref cchar* ref_p)
  {
    auto p = ref_p;
    assert(!isascii(*p), "check for ASCII char before calling decodeUTF8().");
    dchar d = *p;

    ++p; // Move to second byte.
    // Error if second byte is not a trail byte.
    if (!isTrailByte(*p))
      goto Lerror2;

    // Check for overlong sequences.
    if (d.In(0xE0, 0xF0, 0xF8, 0xFC) && (*p & d) == 0x80 ||
        (d & 0xFE) == 0xC0) // 1100000x
      goto Lerror;

    enum checkNextByte = "if (!isTrailByte(*++p))" ~
                         "  goto Lerror2;";
    enum appendSixBits = "d = (d << 6) | *p & 0b0011_1111;";

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
      goto Lerror;

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
    Lerror:
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
    Lerror2:
      d = REPLACEMENT_CHAR;
      error(ref_p, MID.InvalidUTF8Sequence, formatBytes(ref_p, p));
    }
    // Advance the pointer and return.
    ref_p = p;
    return d;
  }

  /// Encodes the character d and appends it to str.
  static void encodeUTF8(ref CharArray str, dchar d)
  {
    assert(!isascii(d), "check for ASCII char before calling encodeUTF8().");
    assert(isValidChar(d), "cannot encode invalid char in encodeUTF8().");

    auto count = d < 0x800 ? 2 : (d < 0x10000 ? 3 : 4);
    if (count > str.rem) // Not enough space?
      str.rem = count;
    auto p = str.cur;
    str.cur += count;
    if (d < 0x800)
    {
      p[0] = 0xC0 | cast(char)(d >> 6);
      p[1] = 0x80 | (d & 0x3F);
    }
    else if (d < 0x10000)
    {
      p[0] = 0xE0 | cast(char)(d >> 12);
      p[1] = 0x80 | ((d >> 6) & 0x3F);
      p[2] = 0x80 | (d & 0x3F);
    }
    else if (d < 0x200000)
    {
      p[0] = 0xF0 | (d >> 18);
      p[1] = 0x80 | ((d >> 12) & 0x3F);
      p[2] = 0x80 | ((d >> 6) & 0x3F);
      p[3] = 0x80 | (d & 0x3F);
    }
    else
     assert(0);
  }

  /// Formats the bytes between start and end (excluding end.)
  /// Returns: e.g.: "abc" -> "\x61\x62\x63"
  static cstring formatBytes(cchar* start, cchar* end)
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
  static cstring findInvalidUTF8Sequence(cbinstr bstr)
  {
    auto str = cast(cstring)bstr;
    auto p = str.ptr, end = p + str.length;
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
} // End of Lexer

/// Tests the lexer with a list of tokens.
void testLexer()
{
  scope msg = new UnittestMsg("Testing class Lexer.");
  struct Pair
  {
    string tokenText;
    TOK kind;
  }
  static Pair[] pairs = [
    {"#!äöüß",  TOK.Shebang},       {"\n",      TOK.Newline},
    {"//çay",   TOK.Comment},       {"\n",      TOK.Newline},
                                    {"&",       TOK.Amp},
    {"/*çağ*/", TOK.Comment},       {"&&",      TOK.Amp2},
    {"/+çak+/", TOK.Comment},       {"&=",      TOK.AmpEql},
    {">",       TOK.Greater},       {"+",       TOK.Plus},
    {">=",      TOK.GreaterEql},    {"++",      TOK.Plus2},
    {">>",      TOK.Greater2},      {"+=",      TOK.PlusEql},
    {">>=",     TOK.Greater2Eql},   {"-",       TOK.Minus},
    {">>>",     TOK.Greater3},      {"--",      TOK.Minus2},
    {">>>=",    TOK.Greater3Eql},   {"-=",      TOK.MinusEql},
    {"<",       TOK.Less},          {"=",       TOK.Equal},
    {"<=",      TOK.LessEql},       {"==",      TOK.Equal2},
    {"<>",      TOK.LorG},          {"~",       TOK.Tilde},
    {"<>=",     TOK.LorEorG},       {"~=",      TOK.TildeEql},
    {"<<",      TOK.Less2},         {"*",       TOK.Star},
    {"<<=",     TOK.Less2Eql},      {"*=",      TOK.StarEql},
    {"!",       TOK.Exclaim},       {"/",       TOK.Slash},
    {"!=",      TOK.ExclaimEql},    {"/=",      TOK.SlashEql},
    {"!<",      TOK.UorGorE},       {"^",       TOK.Caret},
    {"!>",      TOK.UorLorE},       {"^=",      TOK.CaretEql},
    {"!<=",     TOK.UorG},          {"%",       TOK.Percent},
    {"!>=",     TOK.UorL},          {"%=",      TOK.PercentEql},
    {"!<>",     TOK.UorE},          {"(",       TOK.LParen},
    {"!<>=",    TOK.Unordered},     {")",       TOK.RParen},
    {".",       TOK.Dot},           {"[",       TOK.LBracket},
    {"..",      TOK.Dot2},          {"]",       TOK.RBracket},
    {"...",     TOK.Dot3},          {"{",       TOK.LBrace},
    {"|",       TOK.Pipe},          {"}",       TOK.RBrace},
    {"||",      TOK.Pipe2},         {":",       TOK.Colon},
    {"|=",      TOK.PipeEql},       {";",       TOK.Semicolon},
    {"?",       TOK.Question},      {",",       TOK.Comma},
    {"$",       TOK.Dollar},        {"cam",     TOK.Identifier},
    {"çay",     TOK.Identifier},    {".0",      TOK.Float64},
    {"0",       TOK.Int32},         {"\n",      TOK.Newline},
    {"\r",      TOK.Newline},       {"\r\n",    TOK.Newline},
    {"\u2028",  TOK.Newline},       {"\u2029",  TOK.Newline},
    {"'c'",     TOK.Character},     {`'\''`,    TOK.Character},
    {`"dblq"`,  TOK.String},        {"`raw`",   TOK.String},
    {`r"aw"`,   TOK.String},        {`x"0123456789abcdef"`, TOK.String},
  ];

  version(D2)
  {
  static Pair[] pairs2 = [
    {"@",       TOK.At},
    {"^^",      TOK.Caret2},
    {"^^=",     TOK.Caret2Eql},
    {"=>",      TOK.EqlGreater},
    {"q\"ⱷ\n\nⱷ\"", TOK.String},    {`q"(())"`, TOK.String},
    {`q"{{}}"`,     TOK.String},    {`q"[[]]"`, TOK.String},
    {`q"<<>>"`,     TOK.String},    {`q"/__/"`, TOK.String},
    {`q"∆⟵✻⟶∆"`, TOK.String},    {`q"\⣯⣻\"`, TOK.String},
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

  auto token = lx.firstToken, last = lx.lastToken;

  for (size_t i; i < pairs.length && token < last; ++i, ++token)
    if (token.text != pairs[i].tokenText)
      assert(0, Format("Scanned ‘{0}’ but expected ‘{1}’",
                       escapeNonPrintable(token.text), pairs[i].tokenText));
}

/// Tests the Lexer's peek() method.
void testLexerPeek()
{
  scope msg = new UnittestMsg("Testing method Lexer.peek()");
  auto tables = new LexerTables();
  auto sourceText = new SourceText("", "unittest { }");
  auto lx = new Lexer(sourceText, tables);
  lx.scanAll();

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
  lx.scanAll();
  next = lx.head;
  lx.peek(next);
  assert(next.kind == TOK.Newline);
  lx.peek(next);
  assert(next.kind == TOK.EOF);
}

void testLexerNumbers()
{
  // Numbers unittest
  // 0L 0ULi 0_L 0_UL 0x0U 0x0p2 0_Fi 0_e2 0_F 0_i
  // 0u 0U 0uL 0UL 0L 0LU 0Lu
  // 0Li 0f 0F 0fi 0Fi 0i
  // 0b_1_LU 0b1000u
  // 0x232Lu
}
