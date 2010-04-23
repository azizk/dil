/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.lexer.Lexer;

import dil.lexer.Token,
       dil.lexer.Keywords,
       dil.lexer.Identifier,
       dil.lexer.IdTable;
import dil.Diagnostics;
import dil.Messages;
import dil.HtmlEntities;
import dil.CompilerInfo;
import dil.Unicode;
import dil.SourceText;
import dil.Time;
import dil.Float : Float;
import util.uni : isUniAlpha;
import util.mpfr : mpfr_t, mpfr_strtofr, mpfr_init;
import common;

import tango.core.Vararg;

public import dil.lexer.Funcs;

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

  // Members used for error messages:
  Diagnostics diag;
  LexerError[] errors;
  /// Always points to the first character of the current line.
  char* lineBegin;
  uint lineNum = 1;   /// Current, actual source text line number.
  uint lineNum_hline; /// Line number set by #line.
  uint inTokenString; /// > 0 if inside q{ }
  /// Holds the original file path and the modified one (by #line.)
  NewlineData.FilePaths* filePaths;

  /// Constructs a Lexer object.
  /// Params:
  ///   srcText = the UTF-8 source code.
  ///   diag = used for collecting error messages.
  this(SourceText srcText, Diagnostics diag = null)
  {
    this.srcText = srcText;
    this.diag = diag;

    assert(text.length && text[$-1] == 0, "source text has no sentinel character");
    this.p = text.ptr;
    this.end = this.p + text.length;
    this.lineBegin = this.p;

    this.head = new Token;
    this.head.kind = TOK.HEAD;
    this.head.start = this.head.end = this.p;
    this.token = this.head;
    // Initialize this.filePaths.
    newFilePath(this.srcText.filePath);
    // Add a newline as the first token after the head.
    auto newline = new Token;
    newline.kind = TOK.Newline;
    newline.setWhitespaceFlag();
    newline.start = newline.end = this.p;
    newline.newline.filePaths = this.filePaths;
    newline.newline.oriLineNum = 1;
    newline.newline.setLineNum = 0;
    // Link in.
    this.token.next = newline;
    newline.prev = this.token;
    this.token = newline;
    scanShebang();
  }

  /// The destructor deletes the doubly-linked token list.
  ~this()
  {
    head.deleteList();
    head = tail = token = null;
  }

  char[] text()
  {
    return srcText.data;
  }

  /// The "shebang" may optionally appear once at the beginning of a file.
  /// $(BNF Shebang := "#!" AnyChar* EndOfLine)
  void scanShebang()
  {
    if (*p == '#' && p[1] == '!')
    {
      auto t = new Token;
      t.kind = TOK.Shebang;
      t.setWhitespaceFlag();
      t.start = p;
      ++p;
      while (!isEndOfLine(++p))
        isascii(*p) || decodeUTF8(p);
      t.end = p;
      this.token.next = t;
      t.prev = this.token;
    }
  }

  /// Sets the value of the special token.
  void finalizeSpecialToken(ref Token t)
  {
    assert(t.text[0..2] == "__");
    switch (t.kind)
    {
    case TOK.FILE:
      t.str = this.filePaths.setPath;
      break;
    case TOK.LINE:
      t.uint_ = this.errorLineNumber(this.lineNum);
      break;
    case TOK.DATE,
         TOK.TIME,
         TOK.TIMESTAMP:
      auto time_str = Time.toString();
      switch (t.kind)
      {
      case TOK.DATE:
        time_str = Time.month_day(time_str) ~ ' ' ~ Time.year(time_str); break;
      case TOK.TIME:
        time_str = Time.time(time_str); break;
      case TOK.TIMESTAMP:
        break; // time_str is the timestamp.
      default: assert(0);
      }
      time_str ~= '\0'; // Terminate with a zero.
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

  /// Sets a new file path.
  void newFilePath(char[] newPath)
  {
    auto paths = new NewlineData.FilePaths;
    paths.oriPath = this.srcText.filePath;
    paths.setPath = newPath;
    this.filePaths = paths;
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
    if (t.next)
      t = t.next;
    else if (t !is this.tail)
    {
      Token* new_t = new Token;
      scan(*new_t);
      new_t.prev = t;
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
    assert(text.ptr <= t.start && t.start < end, Token.toString(t.kind));
    assert(text.ptr <= t.end && t.end <= end, Token.toString(t.kind));
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
        assert(isNewlineEnd(p));
        ++p;
        ++lineNum;
        setLineBegin(p);
        kind = TOK.Newline;
        t.setWhitespaceFlag();
        auto nl = &t.newline;
        nl.filePaths = this.filePaths;
        nl.oriLineNum = lineNum;
        nl.setLineNum = lineNum_hline;
        goto Lreturn;
      default:
        if (isUnicodeNewline(p))
        {
          ++p; ++p;
          goto case '\n';
        }
      }
      assert(this.p == p);
      // Identifier or string literal.
      if (isidbeg(c))
      {
        if (c == 'r' && p[1] == '"')
          return ++this.p, scanRawStringLiteral(t);
        if (c == 'x' && p[1] == '"')
          return scanHexStringLiteral(t);
        version(D2)
        {
        if (c == 'q' && p[1] == '"')
          return scanDelimitedStringLiteral(t);
        if (c == 'q' && p[1] == '{')
          return scanTokenStringLiteral(t);
        }
        // Scan identifier.
      Lidentifier:
        do
        { c = *++p; }
        while (isident(c) || !isascii(c) && isUnicodeAlpha(p))
        t.end = this.p = p;

        auto id = IdTable.lookup(t.text);
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

      if (c == '/')
        switch(c = *++p)
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
          return (this.p = p), scanReal(t);
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
      case '=': /* =  == */
        if (p[1] == '=')
          ++p,
          kind = TOK.Equal;
        else
          kind = TOK.Assign;
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
        "(", "LParen",   ")", "RParen",
        "[", "LBracket", "]", "RBracket",
        "{", "LBrace",   "}", "RBrace",
        ":", "Colon",    ";", "Semicolon",
        "?", "Question", ",", "Comma",
        "$", "Dollar",   "@", "At"
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

      error(t.start, MID.IllegalCharacter, cast(dchar)c);

      p = this.p;
      ++p;
      kind = TOK.Illegal;
      t.setWhitespaceFlag();
      t.dchar_ = c;
      goto Lreturn;
    }

  Lcommon:
    ++p;
  Lreturn:
    t.kind = kind;
    t.end = this.p = p;
    return;
  }

  /// CTF: Casts a string literal to an integer.
  static uint toUint(char[] s)
  {
    assert(0 < s.length && s.length <= 4);
    int x = 0;
    for (int i = 0; i < s.length; i++)
      x = x << 8 | s[i];
    return x;
  }
  static assert(toUint("\xAA\xBB\xCC\xDD") == 0xAABBCCDD);

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
    return "case toUint(\""~str~"\"): kind = TOK."~kind~";"
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
    assert(text.ptr <= t.start && t.start < end, Token.toString(t.kind));
    assert(text.ptr <= t.end && t.end <= end, Token.toString(t.kind));
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
    mixin(cases(">>>=", "RShiftAssign", "!<>=", "Unordered"));
    default:
    }

    c >>>= 8;
  L3characters:
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
    case toUint(LS), toUint(PS):
      p += 2;
      goto Lnewline;
    default:
    }

    c >>>= 8;
  L2characters:
    assert(p == t.start);
    // 2 character tokens.
    switch (c)
    {
    case toUint("/+"):
      this.p = ++p; // Skip /
      return scanNestedComment(t);
    case toUint("/*"):
      this.p = ++p; // Skip /
      return scanBlockComment(t);
    case toUint("//"): // LineComment.
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
    case toUint("\r\n"):
      ++p;
      goto Lnewline;
    case toUint(`r"`):
      return (this.p = ++p), scanRawStringLiteral(t);
    case toUint(`x"`):
      return scanHexStringLiteral(t);
    version(D2)
    {
    case toUint(`q"`):
      return scanDelimitedStringLiteral(t);
    case toUint(`q{`):
      return scanTokenStringLiteral(t);
    }
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

    c >>>= 8;
  L1character:
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
        return (this.p = p), scanReal(t);
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

    // TODO: consider moving isidbeg() and isdigit() up.
    if (isidbeg(c))
    { // Scan an identifier.
    Lidentifier:
      do
      { c = *++p; }
      while (isident(c) || !isascii(c) && isUnicodeAlpha(p))
      t.end = this.p = p;

      auto id = IdTable.lookup(t.text);
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

    p = this.p;
    ++p;
    kind = TOK.Illegal;
    t.setWhitespaceFlag();
    t.dchar_ = c;
    goto Lreturn;

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
    auto nl = &t.newline;
    nl.filePaths = this.filePaths;
    nl.oriLineNum = lineNum;
    nl.setLineNum = lineNum_hline;
    t.kind = kind;
    t.end = this.p = p;
    return;
  }

  /// Scans a block comment.
  ///
  /// $(BNF BlockComment := "/*" AnyChar* "*/")
  void scanBlockComment(ref Token t)
  {
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
        else if (isEOF(*p))
        {
          error(tokenLineNum, tokenLineBegin, t.start, MID.UnterminatedBlockComment);
          break Loop;
        }
      }
    }
    t.kind = TOK.Comment;
    t.setWhitespaceFlag();
    t.end = p;
    return;
  }

  /// Scans a nested comment.
  ///
  /// $(BNF NestedComment := "/+" (AnyChar* | NestedComment) "+/")
  void scanNestedComment(ref Token t)
  {
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
        else if (isEOF(*p))
        {
          error(tokenLineNum, tokenLineBegin, t.start, MID.UnterminatedNestedComment);
          break Loop;
        }
      }
    }
    t.kind = TOK.Comment;
    t.setWhitespaceFlag();
    t.end = p;
    return;
  }

  /// Scans the postfix character of a string literal.
  ///
  /// $(BNF PostfixChar := "c" | "w" | "d")
  char scanPostfix()
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
      return 0;
    }
    assert(0);
  }

  /// Scans a normal string literal.
  ///
  /// $(BNF NormalStringLiteral := '"' AnyChar* '"')
  void scanNormalStringLiteral(ref Token t)
  {
    assert(*p == '"');
    auto tokenLineNum = lineNum;
    auto tokenLineBegin = lineBegin;
    t.kind = TOK.String;
    char[] buffer;
    uint c;
    while (1)
    {
      c = *++p;
      switch (c)
      {
      case '"':
        ++p;
        t.pf = scanPostfix();
      Lreturn:
        t.str = (buffer ~= '\0');
        t.end = p;
        return;
      case '\\':
        bool isBinary;
        c = scanEscapeSequence(isBinary);
        --p;
        if (isascii(c) || isBinary)
          buffer ~= c;
        else
          encodeUTF8(buffer, c);
        continue;
      case '\r':
        if (p[1] == '\n')
          ++p;
      case '\n':
        assert(isNewlineEnd(p));
        c = '\n'; // Convert Newline to \n.
        ++lineNum;
        setLineBegin(p+1);
        break;
      case 0, _Z_:
        error(tokenLineNum, tokenLineBegin, t.start, MID.UnterminatedString);
        goto Lreturn;
      default:
        if (!isascii(c))
        {
          c = decodeUTF8(p);
          if (isUnicodeNewlineChar(c))
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

  /// Scans an escape string literal.
  ///
  /// $(BNF EscapeStringLiteral := EscapeSequence+ )
  void scanEscapeStringLiteral(ref Token t)
  {
    assert(*p == '\\');
    char[] buffer;
    do
    {
      bool isBinary;
      auto c = scanEscapeSequence(isBinary);
      if (isascii(c) || isBinary)
        buffer ~= c;
      else
        encodeUTF8(buffer, c);
    } while (*p == '\\')
    buffer ~= 0;
    t.kind = TOK.String;
    t.str = buffer;
    t.end = p;
  }

  /// Scans a character literal.
  ///
  /// $(BNF CharLiteral := "'" AnyChar "'")
  void scanCharacterLiteral(ref Token t)
  {
    assert(*p == '\'');
    ++p;
    t.kind = TOK.CharLiteral;
    switch (*p)
    {
    case '\\':
      bool notused;
      t.dchar_ = scanEscapeSequence(notused);
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
    assert(*p == '`' || *p == '"' && p[-1] == 'r');
    auto tokenLineNum = lineNum;
    auto tokenLineBegin = lineBegin;
    t.kind = TOK.String;
    uint delim = *p;
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
        assert(isNewlineEnd(p));
        c = '\n'; // Convert Newline to '\n'.
        ++lineNum;
        setLineBegin(p+1);
        break;
      case '`':
      case '"':
        if (c == delim)
        {
          ++p;
          t.pf = scanPostfix();
        Lreturn:
          t.str = (buffer ~= '\0');
          t.end = p;
          return;
        }
        break;
      case 0, _Z_:
        error(tokenLineNum, tokenLineBegin, t.start,
          delim == 'r' ?
            MID.UnterminatedRawString : MID.UnterminatedBackQuoteString);
        goto Lreturn;
      default:
        if (!isascii(c))
        {
          c = decodeUTF8(p);
          if (isUnicodeNewlineChar(c))
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

  /// Scans a hexadecimal string literal.
  ///
  /// $(BNF HexStringLiteral := 'x"' (HexChar HexChar)* '"')
  void scanHexStringLiteral(ref Token t)
  {
    assert(p[0] == 'x' && p[1] == '"');
    t.kind = TOK.String;

    auto tokenLineNum = lineNum;
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
        if (n & 1)
          error(tokenLineNum, tokenLineBegin, t.start, MID.OddNumberOfDigitsInHexString);
        ++p;
        t.pf = scanPostfix();
      Lreturn:
        t.str = cast(string) (buffer ~= 0);
        t.end = p;
        return;
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
            buffer ~= h;
          }
          else
            h = cast(ubyte)c;
          ++n;
          continue;
        }
        else if (isspace(c))
          continue; // Skip spaces.
        else if (isEOF(c))
        {
          error(tokenLineNum, tokenLineBegin, t.start, MID.UnterminatedHexString);
          t.pf = 0;
          goto Lreturn;
        }
        else
        {
          auto errorAt = p;
          if (!isascii(c))
          {
            c = decodeUTF8(p);
            if (isUnicodeNewlineChar(c))
              goto case '\n';
          }
          error(errorAt, MID.NonHexCharInHexString, cast(dchar)c);
        }
      }
    }
    assert(0);
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
    assert(p[0] == 'q' && p[1] == '"');
    t.kind = TOK.String;

    auto tokenLineNum = lineNum;
    auto tokenLineBegin = lineBegin;

    char[] buffer;
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
      closing_delim = c + 2; // Get to closing counterpart. Feature of ASCII table.
      break;
    default:
      char* idbegin = p;
      if (scanNewline(p))
      {
        error(idbegin, MSG.DelimiterIsMissing);
        ++lineNum;
        setLineBegin(p);
        // closing_delim = '\n';
        goto Lerr;
      }

      c = *p;
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
      str_delim = idbegin[0..p-idbegin];
      // Scan a newline.
      if (scanNewline(p))
        ++lineNum,
        setLineBegin(p),
        --p; // Go back one because of "c = *++p;" in main loop.
      else
        error(p, MSG.NoNewlineAfterIdDelimiter, str_delim);
    }
    assert(closing_delim);

    if (isspace(closing_delim))
      error(p, MSG.DelimiterIsWhitespace);

    bool checkStringDelim(char* p)
    { // Returns true if p points to the closing string delimiter.
      assert(str_delim.length != 0, ""~*p);
      return buffer.length &&
        buffer[$-1] == '\n' && // Last copied character must be '\n'.
        end-p >= str_delim.length && // Check remaining length.
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
          encodeUTF8(buffer, c);
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
      buffer ~= c;
    }
  Lreturn: // Character delimiter.
    assert(c == closing_delim);
    assert(level == 0);
    ++p; // Skip closing delimiter.
  Lreturn2: // String delimiter.
    if (*p == '"')
      ++p, (t.pf = scanPostfix());
    else
      error(p, MSG.ExpectedDblQuoteAfterDelim,
        (str_delim.length || encodeUTF8(str_delim, closing_delim), str_delim));

  Lerr:
    t.str = (buffer ~= '\0');
    t.end = p;
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

    // A guard against changes to particular members:
    // this.lineNum_hline and this.errorPath
    ++inTokenString;

    uint lineNum = this.lineNum;
    uint level = 1;

    ++p; ++p; // Skip q{
    char* str_begin = p, str_end = void;
    // Set to true, if '\r', LS, PS, or multiline tokens are encountered.
    bool convertNewlines;

    auto prev_t = &t;
    Token* token;
  Loop:
    while (1)
    {
      token = new Token;
      scan(*token);
      // Save the tokens in a doubly linked list.
      // Could be useful for various tools.
      token.prev = prev_t;
      prev_t.next = token;
      prev_t = token;
      switch (token.kind)
      {
      case TOK.LBrace:
        ++level;
        break;
      case TOK.RBrace:
        if (--level == 0)
        {
          t.tok_str = t.next;
          t.next = null;
          break Loop;
        }
        break;
      case TOK.String, TOK.Comment:
        if (token.isMultiline())
          convertNewlines = true;
        break;
      case TOK.Newline:
        if (*token.start != '\n')
          convertNewlines = true;
        break;
      case TOK.EOF:
        error(tokenLineNum, tokenLineBegin, t.start,
          MSG.UnterminatedTokenString);
        t.tok_str = t.next;
        t.next = token;
        break Loop;
      default:
      }
    }

    assert(token.kind == TOK.RBrace || token.kind == TOK.EOF);
    assert(token.kind == TOK.RBrace && t.next is null ||
           token.kind == TOK.EOF && t.next !is null);

    // token is "}" or EOF.
    if (token.kind == TOK.EOF)
      str_end = t.end = token.start;
    else
    {
      str_end = p-1;
      t.pf = scanPostfix();
      t.end = p;
    }
    auto buffer = str_begin[0..str_end-str_begin+1]; // +1 for '\0'.
    // Convert newlines to '\n'.
    if (convertNewlines)
    { // Copy the string to the buffer and convert the newlines.
      buffer = new char[buffer.length];
      auto q = str_begin, s = buffer.ptr;
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
      buffer.length = s - buffer.ptr +1; // +1 for '\0'.
    }
    else // Just duplicate the string, no conversion needed.
      buffer = buffer.dup;
    buffer[$-1] = 0;
    t.str = buffer;

    --inTokenString;
  } // version(D2)
  }

  /// Scans an escape sequence.
  ///
  /// $(BNF
  ////EscapeSequence := "\\" (BinaryEsc | UnicodeEsc | CEsc | HTMLEsc)
  ////BinaryEsc := Octal{1,3} | "x" Hex{2}
  ////UnicodeEsc := "u" Hex{4} | "U" Hex{8}
  ////HTMLEsc := "&" AlphaNumerical+ ";"
  ////CEsc := "'" | '"' | "?" | "\\" | "a" | "b" | "f" | "n" | "r" | "t" | "v"
  ////)
  /// Params:
  ///   isBinary = set to true for octal and hexadecimal escapes.
  /// Returns: the escape value.
  dchar scanEscapeSequence(ref bool isBinary)
  out(result)
  { assert(isValidChar(result)); }
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
      isBinary = true;
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
              return c; // Return valid escape value.

            error(sequenceStart, MID.InvalidUnicodeEscapeSequence,
                  sequenceStart[0..p-sequenceStart]);
            break;
          }
          continue;
        }

        error(sequenceStart, MID.InsufficientHexDigits,
              sequenceStart[0..p-sequenceStart]);
        break;
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
        if (c > 0xFF)
          error(sequenceStart, MSG.InvalidOctalEscapeSequence,
                sequenceStart[0..p-sequenceStart]);
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
      else if (isEndOfLine(p))
        error(sequenceStart, MID.UndefinedEscapeSequence,
          isEOF(*p) ? `\EOF` : `\NewLine`);
      else
      {
        char[] str = `\`;
        if (isascii(c))
          str ~= *p;
        else
          encodeUTF8(str, decodeUTF8(p));
        ++p;
        // TODO: check for unprintable character?
        error(sequenceStart, MID.UndefinedEscapeSequence, str);
      }
    }
    return REPLACEMENT_CHAR; // Error: return replacement character.
  }

  /// Scans a number literal.
  ///
  /// $(BNF
  ////IntegerLiteral := (Dec | Hex | Bin | Oct) Suffix?
  ////Dec := ("0" | [1-9] [0-9_]*)
  ////Hex := "0" [xX] "_"* [0-9a-zA-Z] [0-9a-zA-Z_]*
  ////Bin := "0" [bB] "_"* [01] [01_]*
  ////Oct := "0" [0-7_]*
  ////Suffix := ("L" [uU]? | [uU] "L"?)
  ////)
  /// Invalid: "0b_", "0x_", "._" etc.
  void scanNumber(ref Token t)
  {
    ulong ulong_;
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
    switch (suffix)
    {
    case Suffix.None:
      if (ulong_ & 0x8000_0000_0000_0000)
      {
        if (isDecimal)
          error(t.start, MID.OverflowDecimalSign);
        t.kind = TOK.Uint64;
      }
      else if (ulong_ & 0xFFFF_FFFF_0000_0000)
        t.kind = TOK.Int64;
      else if (ulong_ & 0x8000_0000)
        t.kind = isDecimal ? TOK.Int64 : TOK.Uint32;
      else
        t.kind = TOK.Int32;
      break;
    case Suffix.Unsigned:
      if (ulong_ & 0xFFFF_FFFF_0000_0000)
        t.kind = TOK.Uint64;
      else
        t.kind = TOK.Uint32;
      break;
    case Suffix.Long:
      if (ulong_ & 0x8000_0000_0000_0000)
      {
        if (isDecimal)
          error(t.start, MID.OverflowDecimalSign);
        t.kind = TOK.Uint64;
      }
      else
        t.kind = TOK.Int64;
      break;
    case Suffix.Unsigned | Suffix.Long:
      t.kind = TOK.Uint64;
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
  ////DecFloat     := ([0-9] [0-9_]* "." [0-9_]* DecExponent?) |
  ////                "." [0-9] [0-9_]* DecExponent? |
  ////                [0-9] [0-9_]* DecExponent
  ////DecExponent  := [eE] [+-]? [0-9] [0-9_]*
  ////)
  void scanReal(ref Token t)
  {
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

    finalizeFloat(t, copySansUnderscores(t.start, p));
  }

  /// Scans a hexadecimal floating point number literal.
  /// $(BNF
  ////HexFloat := "0" [xX] (HexDigits "." HexDigits |
  ////                      "." [0-9a-fA-F] HexDigits? |
  ////                      HexDigits) HexExponent
  ////HexExponent := [pP] [+-]? [0-9] [0-9_]*
  ////)
  void scanHexReal(ref Token t)
  {
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

    finalizeFloat(t, copySansUnderscores(t.start, p));
    return;
  Lerr:
    t.kind = TOK.Float32;
    t.end = p;
    error(p, mid);
  }

  /// Sets the value of the token.
  /// Params:
  ///   t = receives the value.
  ///   buffer = the well-formed float string.
  void finalizeFloat(ref Token t, string buffer)
  {
    assert(buffer.length && buffer[$-1] == 0);
    // Finally check suffixes.
    TOK kind = void;
    if (*p == 'f' || *p == 'F')
      ++p, kind = TOK.Float32;
    else if (*p == 'L')
      ++p, kind = TOK.Float80;
    else
      kind = TOK.Float64;
    // Convert to multiprecision float.
    mpfr_t mpfloat;
    mpfr_init(&mpfloat);
    int res = mpfr_strtofr(&mpfloat, buffer.ptr, null, 0, Float.RND);
    // if (res == 0) // Exact precision.
    // else if (res < 0) // Lower precision.
    // {}
    // else /*if (res > 0)*/ // Higher precision.
    // {}
    if (*p == 'i')
    {
      ++p;
      kind += 3; // Switch to imaginary counterpart.
      assert(kind == TOK.Imaginary32 || kind == TOK.Imaginary64 ||
             kind == TOK.Imaginary80);
    }
    // TODO: test for overflow/underflow according to target platform.
    //       CompilationContext must be passed to Lexer for this.
    auto f = new Float(&mpfloat);
    if (f.isPInf())
      error(t.start, MID.OverflowFloatNumber);
    // else if (f.isNInf())
      // error(t.start, MSG.UnderflowFloatNumber);
    // else if (f.isNaN())
      // error(t.start, MSG.NaNFloat);
    t.mpfloat = f;
    t.kind = kind;
    t.end = p;
    return;
  }

  /// Scans a special token sequence.
  ///
  /// $(BNF SpecialTokenSequence := "#line" Integer Filespec? EndOfLine)
  void scanSpecialTokenSequence(ref Token t)
  {
    assert(*p == '#');
    t.kind = TOK.HashLine;
    t.setWhitespaceFlag();

    MID mid;
    char* errorAtColumn = p;
    char* tokenEnd = ++p;

    if (!(p[0] == 'l' && p[1] == 'i' && p[2] == 'n' && p[3] == 'e'))
    {
      mid = MID.ExpectedIdentifierSTLine;
      goto Lerr;
    }
    p += 3;
    tokenEnd = p + 1;

    // TODO: #line58"path/file" is legal. Require spaces?
    //       State.Space could be used for that purpose.
    enum State
    { /+Space,+/ Integer, Filespec, End }

    State state = State.Integer;

    while (!isEndOfLine(++p))
    {
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
        t.tokLineNum = new Token;
        scan(*t.tokLineNum);
        tokenEnd = p;
        if (t.tokLineNum.kind != TOK.Int32 && t.tokLineNum.kind != TOK.Uint32)
        {
          errorAtColumn = t.tokLineNum.start;
          mid = MID.ExpectedIntegerAfterSTLine;
          goto Lerr;
        }
        --p; // Go one back because scan() advanced p past the integer.
        state = State.Filespec;
      }
      else if (state == State.Filespec && *p == '"')
      { // MID.ExpectedFilespec is deprecated.
        // if (*p != '"')
        // {
        //   errorAtColumn = p;
        //   mid = MID.ExpectedFilespec;
        //   goto Lerr;
        // }
        t.tokLineFilespec = new Token;
        t.tokLineFilespec.start = p;
        t.tokLineFilespec.kind = TOK.Filespec;
        t.tokLineFilespec.setWhitespaceFlag();
        while (*++p != '"')
        {
          if (isEndOfLine(p))
          {
            errorAtColumn = t.tokLineFilespec.start;
            mid = MID.UnterminatedFilespec;
            t.tokLineFilespec.end = p;
            tokenEnd = p;
            goto Lerr;
          }
          isascii(*p) || decodeUTF8(p);
        }
        auto start = t.tokLineFilespec.start +1; // +1 skips '"'
        t.tokLineFilespec.str = start[0 .. p - start];
        t.tokLineFilespec.end = p + 1;
        tokenEnd = p + 1;
        state = State.End;
      }
      else/+ if (state == State.End)+/
      {
        mid = MID.UnterminatedSpecialToken;
        goto Lerr;
      }
    }
    assert(isEndOfLine(p));

    if (state == State.Integer)
    {
      errorAtColumn = p;
      mid = MID.ExpectedIntegerAfterSTLine;
      goto Lerr;
    }

    // Evaluate #line only when not in token string.
    if (!inTokenString && t.tokLineNum)
    {
      this.lineNum_hline = this.lineNum - t.tokLineNum.uint_ + 1;
      if (t.tokLineFilespec)
        newFilePath(t.tokLineFilespec.str);
    }
    p = tokenEnd;
    t.end = tokenEnd;

    return;
  Lerr:
    p = tokenEnd;
    t.end = tokenEnd;
    error(errorAtColumn, mid);
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
    return lineNum - this.lineNum_hline;
  }

  /// Forwards error parameters.
  void error(char* columnPos, char[] msg, ...)
  {
    error_(this.lineNum, this.lineBegin, columnPos, msg, _arguments, _argptr);
  }

  /// ditto
  void error(char* columnPos, MID mid, ...)
  {
    error_(this.lineNum, this.lineBegin, columnPos, GetMsg(mid), _arguments, _argptr);
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
  ///   lineNum = the line number.
  ///   lineBegin = points to the first character of the current line.
  ///   columnPos = points to the character where the error is located.
  ///   msg = the message.
  void error_(uint lineNum, char* lineBegin, char* columnPos, char[] msg,
              TypeInfo[] _arguments, va_list _argptr)
  {
    lineNum = this.errorLineNumber(lineNum);
    auto errorPath = this.filePaths.setPath;
    auto location = new Location(errorPath, lineNum, lineBegin, columnPos);
    msg = Format(_arguments, _argptr, msg);
    auto error = new LexerError(location, msg);
    errors ~= error;
    if (diag !is null)
      diag ~= error;
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

  /// Returns true if str is a valid D identifier.
  static bool isIdentifierString(char[] str)
  {
    if (str.length == 0 || isdigit(str[0]))
      return false;
    size_t idx;
    do
    {
      auto c = dil.Unicode.decode(str, idx);
      if (c == ERROR_CHAR || !(isident(c) || !isascii(c) && isUniAlpha(c)))
        return false;
    } while (idx < str.length)
    return true;
  }

  /// Returns true if str is a keyword or
  /// a special token (__FILE__, __LINE__ etc.)
  static bool isReservedIdentifier(char[] str)
  {
    if (str.length == 0)
      return false;
    auto id = IdTable.inStatic(str);
    if (id is null || id.kind == TOK.Identifier)
      return false; // str is not in the table or a normal identifier.
    return true;
  }

  /// Returns true if this is a valid identifier and if it's not reserved.
  static bool isValidUnreservedIdentifier(char[] str)
  {
    return isIdentifierString(str) && !isReservedIdentifier(str);
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

    // Decode
    if ((d & 0b1110_0000) == 0b1100_0000)
    { // 110xxxxx 10xxxxxx
      d &= 0b0001_1111;
      mixin(appendSixBits);
    }
    else if ((d & 0b1111_0000) == 0b1110_0000)
    { // 1110xxxx 10xxxxxx 10xxxxxx
      d &= 0b0000_1111;
      mixin(appendSixBits ~
            checkNextByte ~ appendSixBits);
    }
    else if ((d & 0b1111_1000) == 0b1111_0000)
    { // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
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
      while (p < (end-1) && isTrailByte(*p))
        ++p;
      --p;
      assert(!isTrailByte(p[1]));
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
    assert(isValidChar(d), "check if character is valid before calling encodeUTF8().");

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
    {
      if (decode(p, end) == ERROR_CHAR)
      {
        auto begin = p;
        // Skip trail-bytes.
        while (++p < end && isTrailByte(*p))
        {}
        return Lexer.formatBytes(begin, p);
      }
    }
    assert(p == end);
    return "";
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
    {"q\"d\n\nd\"", TOK.String},    {"q\"(())\"", TOK.String},
    {"q\"{{}}\"",   TOK.String},    {"q\"[[]]\"", TOK.String},
    {"q\"<<>>\"",   TOK.String},    {"q\"/__/\"", TOK.String},
    {"q{toks...}",  TOK.String},    {"q{({#line 0\n})}", TOK.String},
  ];
  pairs ~= pairs2;
  }
  else // D1
  {
  static Pair[] pairs2 = [
    {"\\n",  TOK.String},           {"\\u2028", TOK.String}
  ];
  pairs ~= pairs2;
  }

  char[] src;

  // Join all token texts into a single string.
  foreach (i, pair; pairs)
    if (pair.kind == TOK.Comment && pair.tokenText[1] == '/' || // Line comment.
        pair.kind == TOK.Shebang)
    {
      assert(pairs[i+1].kind == TOK.Newline); // Must be followed by a newline.
      src ~= pair.tokenText;
    }
    else
      src ~= pair.tokenText ~ " ";

  // Lex the constructed source text.
  auto lx = new Lexer(new SourceText("lexer_unittest", src));
  lx.scanAll();

  foreach (e; lx.errors)
    Stdout.formatln("{}({},{})L: {}", e.filePath, e.loc, e.col, e.getMsg);

  auto token = lx.firstToken();

  for (uint i; i < pairs.length && token.kind != TOK.EOF;
       ++i, (token = token.next))
    if (token.text != pairs[i].tokenText)
      assert(0, Format("Scanned '{0}' but expected '{1}'",
                       token.text, pairs[i].tokenText));
}

/// Tests the Lexer's peek() method.
unittest
{
  Stdout("Testing method Lexer.peek()\n");
  auto sourceText = new SourceText("", "unittest { }");
  auto lx = new Lexer(sourceText, null);

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

  lx = new Lexer(new SourceText("", ""));
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
