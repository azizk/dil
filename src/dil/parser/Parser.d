/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.parser.Parser;

import dil.lexer.Lexer,
       dil.lexer.IdTable,
       dil.lexer.Tables;
import dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Statements,
       dil.ast.Expressions,
       dil.ast.Types,
       dil.ast.Parameters;
import dil.i18n.Messages;
import dil.Diagnostics,
       dil.Enums,
       dil.SourceText,
       dil.Unicode;
import common;

/// The Parser produces a full parse tree by examining
/// the list of tokens provided by the Lexer.
class Parser
{
  Lexer lexer; /// Used to lex the source code.
  Token* token; /// Current non-whitespace token.
  Token* prevToken; /// Previous non-whitespace token.

  Diagnostics diag;     /// Collects error messages.
  ParserError[] errors; /// Array of parser error messages.

  ImportDecl[] imports; /// ImportDeclarations in the source text.

  /// Attributes are evaluated in the parsing phase.
  /// TODO: will be removed. SemanticPass1 takes care of attributes.
  LinkageType linkageType;
  Protection protection; /// ditto
  StorageClass storageClass; /// ditto
  uint alignSize; /// ditto


  private alias T = S2T; /// Used often in this class.
  private alias Type = TypeNode;

  /// Constructs a Parser object.
  /// Params:
  ///   srcText = The UTF-8 source code.
  ///   tables = For the Lexer.
  ///   diag = Used for collecting error messages.
  this(SourceText srcText, LexerTables tables, Diagnostics diag = null)
  {
    this.diag = diag ? diag : new Diagnostics();
    this.lexer = new Lexer(srcText, tables, diag);
  }

  /// Moves to the first non-whitespace token.
  protected void init()
  {
    lexer.scanAll();
    token = lexer.firstToken.prev;
    nT();
    prevToken = token;
  }

  /// Moves to the next token.
  void nT()
  {
    prevToken = token;
    do
      token++;
    while (token.isWhitespace); // Skip whitespace.
  }

  /// Starts the parser and returns the parsed Declarations.
  CompoundDecl start()
  {
    init();
    auto begin = token;
    auto decls = new CompoundDecl;
    if (tokenIs!"module")
      decls ~= parseModuleDecl();
    decls.addOptChildren(parseDeclarationDefinitions());
    set(decls, begin);
    return decls;
  }

  /// Starts the parser and returns the parsed Expression.
  Expression start2()
  {
    init();
    return parseExpression();
  }

  // Members related to the method tryToParse().
  uint trying; /// Greater than 0 if Parser is in tryToParse().
  uint errorCount; /// Used to track nr. of errors while being in tryToParse().

  /// This method executes the delegate parseMethod and when an error occurs
  /// the state of the lexer and parser is restored.
  /// Returns: The return value of parseMethod().
  RetType tryToParse(RetType)(RetType delegate() parseMethod, out bool success)
  {
    // Save members.
    auto oldToken     = this.token;
    auto oldPrevToken = this.prevToken;
    auto oldCount     = this.errorCount;

    ++trying;
    auto result = parseMethod();
    --trying;
    // Check if an error occurred.
    if (errorCount != oldCount)
    { // Restore members.
      token       = oldToken;
      prevToken   = oldPrevToken;
      errorCount  = oldCount;
    }
    else
      success = true;
    return result;
  }

  /// Causes the current call to tryToParse() to fail.
  void fail_tryToParse()
  {
    assert(trying);
    errorCount++;
  }

  /// Backtracks the Parser to the given token(s).
  void backtrackTo(Token* newtok, Token* newprev = null)
  {
    this.token = newtok;
    this.prevToken = newprev ? newprev : newtok.prevNWS();
  }

  /// Sets the begin and end tokens of a syntax tree node.
  Class set(Class)(Class node, Token* begin)
  {
    assert(node !is null);
    node.setTokens(begin, this.prevToken);
    return node;
  }

  /// Sets the begin and end tokens of a syntax tree node.
  Class set(Class)(Class node, Token* begin, Token* end)
  {
    assert(node !is null);
    node.setTokens(begin, end);
    return node;
  }

  /// Returns true if set() has been called on a node.
  static bool isNodeSet(const Node node)
  {
    assert(node !is null);
    return node.begin !is null && node.end !is null;
  }

  /// Returns true if the current token is of kind T!str.
  bool tokenIs(string str)()
  {
    return token.kind == T!str;
  }

  /// Returns true if the next token is of kind T!str.
  bool nextIs(string str)()
  {
    return peekNext() == T!str;
  }

  /// Returns the token kind of the next token.
  TOK peekNext()
  {
    Token* next = token;
    do
      lexer.peek(next);
    while (next.isWhitespace); // Skip whitespace
    return next.kind;
  }

  /// Returns the token that comes after t.
  Token* peekAfter(Token* t)
  {
    assert(t !is null);
    do
      lexer.peek(t);
    while (t.isWhitespace); // Skip whitespace
    return t;
  }

  /// Consumes the current token and returns it.
  Token* consume()()
  {
    return (nT(), prevToken);
  }

  /// Consumes the current token if its kind matches T!str and returns true.
  bool consumed(string str)()
  {
    return tokenIs!str ? (nT(), true) : false;
  }

  /// Consumes the current token if its kind matches T!str and returns it.
  Token* consumedToken(string str)()
  {
    return tokenIs!str ? (nT(), prevToken) : null;
  }

  /// Asserts that the current token is of kind T!str,
  /// and then moves to the next token.
  void skip(string str)()
  {
    assert(consumed!str, token.text);
  }

  /// Returns true if the token after the closing parenthesis
  /// matches the searched kind.
  /// Params:
  ///   kind = The token kind to test for.
  bool tokenAfterParenIs(TOK kind)
  {
    assert(tokenIs!"(");
    return skipParens(token, T!")").kind == kind;
  }

  /// Returns the token kind behind the closing bracket.
  TOK tokenAfterBracket(TOK closing)
  {
    assert(token.kind.Any!("[", "{"));
    return skipParens(token, closing).kind;
  }

  /// Skips to the token behind the closing parenthesis token.
  /// Takes nesting into account.
  /// Params:
  ///   peek_token = Opening token to start from.
  ///   closing = Matching closing token kind.
  /// Returns: The token searched for, or the EOF token.
  Token* skipParens(Token* peek_token, TOK closing)
  {
    assert(peek_token !is null);
    size_t level = 1;
    TOK opening = peek_token.kind;
    while ((peek_token = peekAfter(peek_token)).kind != T!"EOF")
      if (peek_token.kind == opening)
        ++level;
      else
      if (peek_token.kind == closing && --level == 0) {
        peek_token = peekAfter(peek_token); // Closing token found.
        break;
      }
    return peek_token;
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                       Declaration parsing methods                       |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// $(BNF ModuleDecl := module ModuleType? Identifier ("." Identifier)* ";"
  ////ModuleType := "(" safe | system ")")
  Declaration parseModuleDecl()
  {
    auto begin = token;
    skip!"module";
    ModuleFQN moduleFQN;
    Token* typeId;
    version(D2)
    {
    if (consumed!"(")
    {
      typeId = requireIdentifier(MID.ExpectedModuleType);
      if (typeId && !typeId.ident.In(Ident.safe, Ident.system))
        error(typeId, MID.ExpectedModuleType);
      require2!")";
    }
    } // version(D2)
    do
      moduleFQN ~= requireIdentifier(MID.ExpectedModuleIdentifier);
    while (consumed!".");
    require2!";";
    return set(new ModuleDecl(typeId, moduleFQN), begin);
  }

  /// Parses DeclarationDefinitions until the end of file is hit.
  /// $(BNF DeclDefs := DeclDef*)
  Declaration[] parseDeclarationDefinitions()
  {
    Declaration[] decls;
    while (!tokenIs!"EOF")
      decls ~= parseDeclarationDefinition();
    return decls;
  }

  /// Parse the body of a template, class, interface, struct or union.
  /// $(BNF DeclDefsBlock := "{" DeclDefs? "}")
  CompoundDecl parseDeclarationDefinitionsBody()
  {
    // Save attributes.
    auto linkageType  = this.linkageType;
    auto protection   = this.protection;
    auto storageClass = this.storageClass;
    // Clear attributes.
    this.linkageType  = LinkageType.None;
    this.protection   = Protection.None;
    this.storageClass = StorageClass.None;

    // Parse body.
    auto decls = new CompoundDecl;
    auto brace = requireOpening!"{";
    while (!token.kind.Any!("}", "EOF"))
      decls ~= parseDeclarationDefinition();
    requireClosing!"}"(brace);
    set(decls, brace);

    // Restore original values.
    this.linkageType  = linkageType;
    this.protection   = protection;
    this.storageClass = storageClass;

    return decls;
  }

  /// Parses a DeclarationDefinition.
  ///
  /// $(BNF DeclDef := Attributes | AliasThisDecl | AliasDecl | TypedefDecl |
  ////  StaticCtorDecl | StaticDtorDecl | StaticIfDecl | StaticAssertDecl |
  ////  ImportDecl | EnumDecl | ClassDecl | InterfaceDecl | StructDecl |
  ////  UnionDecl | ConstructorDecl | DestructorDecl | InvariantDecl |
  ////  UnittestDecl | DebugDecl | VersionDecl | TemplateDecl | NewDecl |
  ////  DeleteDecl | MixinDecl | EmptyDecl | VariablesOrFunction
  ////TypedefDecl := typedef VariablesDecl)
  Declaration parseDeclarationDefinition()
  out(decl)
  { assert(isNodeSet(decl)); }
  body
  {
    auto begin = token;
    Declaration decl;
    switch (token.kind)
    {
    case T!"align", T!"pragma",
         // Protection attributes
         T!"export", T!"private", T!"package", T!"protected", T!"public",
         // Storage classes
         T!"extern", T!"deprecated", T!"override", T!"abstract",
         T!"synchronized", T!"auto", T!"scope", T!"final":
         //T!"static", T!"const"
    version(D2)
    { // T!"shared", T!"immutable", T!"inout"
    case T!"__gshared", T!"ref", T!"pure", T!"nothrow", T!"@":
    }
    case_parseAttributes:
      return parseAttributes();
    case T!"alias":
      decl = parseAliasDecl();
      break;
    case T!"typedef":
      nT();
      auto td = new TypedefDecl(parseAttributes(&decl));
      td.vardecl = decl;
      if (!decl.Is!(VariablesDecl))
        error(decl.begin, MID.TypedefExpectsVariable, decl.toText());
      decl = td;
      break;
    case T!"static":
      switch (peekNext())
      {
      case T!"import": goto case_Import;
      case T!"this":   decl = parseStaticCtorDecl();   break;
      case T!"~":      decl = parseStaticDtorDecl();   break;
      case T!"if":     decl = parseStaticIfDecl();     break;
      case T!"assert": decl = parseStaticAssertDecl(); break;
      default: goto case_parseAttributes;
      }
      break;
    case T!"import":
    case_Import:
      auto importDecl = parseImportDecl();
      imports ~= importDecl;
      // Handle specially. StorageClass mustn't be set.
      importDecl.setProtection(this.protection);
      return set(importDecl, begin);
    case T!"enum":
      version(D2)
      if (isEnumManifest())
        goto case_parseAttributes;
      decl = parseEnumDecl();
      break;
    case T!"class":
      decl = parseClassDecl();
      break;
    case T!"interface":
      decl = parseInterfaceDecl();
      break;
    case T!"struct", T!"union":
      decl = parseStructOrUnionDecl();
      break;
    case T!"this":
      if (nextIs!"(")
        decl = parseConstructorDecl();
      else
        goto case_Declaration;
      break;
    case T!"~":
      decl = parseDestructorDecl();
      break;
    version(D2)
    {
    case T!"const", T!"immutable", T!"inout", T!"shared":
      if (nextIs!"(")
        goto case_Declaration;
      goto case_parseAttributes;
    } // version(D2)
    else
    { // D1
    case T!"const":
      goto case_parseAttributes;
    }
    case T!"invariant":
      decl = parseInvariantDecl(); // invariant "(" ")"
      break;
    case T!"unittest":
      decl = parseUnittestDecl();
      break;
    case T!"debug":
      decl = parseDebugDecl();
      break;
    case T!"version":
      decl = parseVersionDecl();
      break;
    case T!"template":
      decl = parseTemplateDecl();
      break;
    case T!"new":
      decl = parseNewDecl();
      break;
    case T!"delete":
      decl = parseDeleteDecl();
      break;
    case T!"mixin":
      decl = parseMixin!(MixinDecl, Declaration)();
      break;
    case T!";":
      nT();
      decl = new EmptyDecl();
      break;
    // Declaration
    version(D2)
    {
    case T!"super"/*, T!"this"*/:
    }
    case T!"Identifier", T!".", T!"typeof":
    case_Declaration:
      return parseVariablesOrFunction(this.storageClass, this.protection,
                                      this.linkageType);
    default:
      if (token.isIntegralType)
        goto case_Declaration;
      else if (tokenIs!"module")
      {
        decl = parseModuleDecl();
        error(begin, MID.ModuleDeclarationNotFirst);
        return decl;
      }

      decl = new IllegalDecl();
      // Skip to next valid token.
      do
        nT();
      while (!token.isDeclDefStart() && !token.kind.Any!("}", "EOF"));
      auto text = begin.textSpan(this.prevToken);
      error(begin, MID.IllegalDeclaration, text);
    }
    decl.setProtection(this.protection);
    decl.setStorageClass(this.storageClass);
    assert(!isNodeSet(decl));
    set(decl, begin);
    return decl;
  }

  /// Parses a DeclarationsBlock.
  /// $(BNF DeclsBlock := ":" DeclDefs | "{" DeclDefs? "}" | DeclDef)
  Declaration parseDeclarationsBlock()
  {
    Declaration d;
    switch (token.kind)
    {
    case T!"{":
      auto brace = consume();
      auto decls = new CompoundDecl;
      while (!token.kind.Any!("}", "EOF"))
        decls ~= parseDeclarationDefinition();
      requireClosing!"}"(brace);
      d = set(decls, brace);
      break;
    case T!":":
      auto colon = consume();
      auto begin2 = token;
      auto decls = new CompoundDecl;
      while (!token.kind.Any!("}", "EOF"))
        decls ~= parseDeclarationDefinition();
      set(decls, begin2);
      d = set(new ColonBlockDecl(decls), colon);
      break;
    case T!";":
      error(MID.ExpectedNonEmptyDeclaration, token);
      // goto default;
    default:
      d = parseDeclarationDefinition();
    }
    assert(isNodeSet(d));
    return d;
  }

  /// $(BNF
  ////AliasDecl := alias Attributes
  ////AliasThisDecl := alias Identifier this ";"
  ////AliasesDecl := alias AliasName "=" Type ("," AliasName "=" Type)* ";"
  ////AliasName := this | Identifier)
  Declaration parseAliasDecl()
  {
    skip!"alias";
    version (D2)
    {
    if (tokenIs!"Identifier" && nextIs!"this")
    {
      auto ident = consume();
      skip!"this";
      require2!";";
      return new AliasThisDecl(ident);
    }
    else
    if (token.kind.Any!("this", "Identifier") && nextIs!"=")
    {
      Token*[] idents;
      TypeNode[] types;
      goto LenterLoop;

      while (consumed!",")
      {
        if (!token.kind.Any!("this", "Identifier"))
          error(token, MID.ExpectedAliasName, token.text);
      LenterLoop:
        idents ~= token;
        nT();
        require2!"=";
        types ~= parseType();
      }

      require2!";";
      return new AliasesDecl(idents, types);
    }
    } // version(D2)

    Declaration decl;
    auto ad = new AliasDecl(parseAttributes(&decl));
    ad.vardecl = decl;
    if (auto var = decl.Is!(VariablesDecl))
    {
      foreach (init; var.inits)
        if (init)
         error(init.begin.prevNWS(), MID.AliasHasInitializer);
    }
    else
      error(decl.begin, MID.AliasExpectsVariable, decl.toText());
    return ad;
  }

  /// Parses either a VariablesDecl or a FunctionDecl.
  ///
  /// $(BNF
  ////VariablesOrFunctionDecl :=
  ////  AutoDecl | VariablesDecl | FunctionDecl
  ////AutoDecl      := AutoVariables | AutoFunction
  ////AutoVariables := Name "=" Initializer MoreVariables* ";"
  ////AutoFunction  := Name TemplateParameterList? ParameterList FunctionBody
  ////VariablesDecl :=
  ////  BasicTypes Name DeclaratorSuffix? ("=" Initializer)? MoreVariables* ";"
  ////MoreVariables := "," Name ("=" Initializer)?
  ////FunctionDecl  :=
  ////  BasicTypes Name TemplateParameterList? ParameterList FunctionBody
  ////Name          := Identifier)
  /// Params:
  ///   stcs = Previously parsed storage classes.
  ///   protection = Previously parsed protection attribute.
  ///   linkType = Previously parsed linkage type.
  ///   testAutoDeclaration = Whether to check for an AutoDecl.
  Declaration parseVariablesOrFunction(
    StorageClass stcs = StorageClass.None,
    Protection protection = Protection.None,
    LinkageType linkType = LinkageType.None,
    bool testAutoDeclaration = false)
  {
    auto begin = token;
    Type type; // Variable or function type.
    Token* name; // Name of the variable or the function.

    Parameters params; // Function parameters.
    TemplateParameters tparams; // Function template parameters.
    Expression constraint; // Function template constraint.

    // Check for AutoDecl.
    if (testAutoDeclaration && tokenIs!"Identifier")
    {
      auto next_kind = peekNext();
      if (next_kind == T!"=")
      { // AutoVariables
        name = consume();
        goto LparseVariables;
      }
      else version(D2) if (next_kind == T!"(")
      { // Check for AutoFunction.
        auto peek_token = peekAfter(token); // Skip the Identifier.
        next_kind = skipParens(peek_token, T!")").kind; // Token after "("...")"
        if (next_kind == T!"(")
        { // TemplateParameterList ParameterList
          name = consume();
          assert(tokenIs!"(");
          goto LparseTPList; // Continue parsing templatized AutoFunction.
        }
        else
        if (next_kind.Any!("{", FunctionPostfix, "in", "out", "body"))
        { // ParameterList ("{" | FunctionPostfix | in | out | body)
          name = consume();
          assert(tokenIs!"(");
          goto LparseBeforeParams; // Continue parsing AutoFunction.
        }
      } // version(D2)
    }

    // VariableType or ReturnType
    type = parseBasicTypes();

    if (nextIs!"(")
    { // ReturnType FunctionName "(" ParameterList ")" FunctionBody
      name = requireIdentifier(MID.ExpectedFunctionName);
      if (!tokenIs!"(")
        nT(); // Skip non-identifier token.

    LparseBeforeTParams:
      assert(tokenIs!"(");
      if (tokenAfterParenIs(T!"("))
      LparseTPList: // "(" TemplateParameterList ")"
        tparams = parseTemplateParameterList();

    LparseBeforeParams: // "(" ParameterList ")"
      params = parseParameterList();

    LparseAfterParams:
      StorageClass postfix_stcs; // const | immutable | @property | ...
      version(D2)
      {
      params.postSTCs = postfix_stcs = parseFunctionPostfix();
      if (tparams) // if "(" ConstraintExpr ")"
        constraint = parseOptionalConstraint();
      } // version(D2)

      // FunctionBody
      auto funcBody = parseFunctionBody();
      auto fd = new FunctionDecl(type, name, params, funcBody, linkType);
      Declaration decl = fd;
      if (tparams)
      {
        decl =
          putInsideTemplateDeclaration(begin, name, fd, tparams, constraint);
        decl.setStorageClass(stcs);
        decl.setProtection(protection);
      }
      fd.setStorageClass(stcs | postfix_stcs); // Combine prefix/postfix stcs.
      fd.setProtection(protection);
      return set(decl, begin);
    }
    else
    { // Type VariableName DeclaratorSuffix
      name = requireIdentifier(MID.ExpectedVariableName);
      type = parseDeclaratorSuffix(type);
    }

  LparseVariables:
    // It's a variables declaration.
    Token*[] names = [name]; // One identifier has been parsed already.
    Expression[] values;
    goto LenterLoop; // Enter the loop and check for an initializer.
    while (consumed!",")
    {
      names ~= requireIdentifier(MID.ExpectedVariableName);
    LenterLoop:
      values ~= consumed!"=" ? parseInitializer() : null;
    }
    require2!";";
    auto d = new VariablesDecl(type, names, values, linkType);
    d.setStorageClass(stcs);
    d.setProtection(protection);
    return set(d, begin);
  }

  /// Parses a variable initializer.
  /// $(BNF Initializer        := VoidInitializer | NonVoidInitializer
  ////VoidInitializer    := void
  ////NonVoidInitializer :=
  ////  ArrayInitializer | StructInitializer | AssignExpr
  ////ArrayInitializer   := "[" ArrayInitElements? "]"
  ////ArrayInitElements  := ArrayInitElement ("," ArrayInitElement)* ","?
  ////ArrayInitElement   := (AssignExpr ":")? NonVoidInitializer
  ////StructInitializer  := "{" StructInitElements? "}"
  ////StructInitElements := StructInitElement ("," StructInitElement)* ","?
  ////StructInitElement  := (MemberName ":")? NonVoidInitializer
  ////MemberName         := Identifier)
  Expression parseInitializer()
  {
    if (tokenIs!"void" && peekNext().Any!(",", ";"))
      return set(new VoidInitExpr(), consume());
    return parseNonVoidInitializer();
  }

  /// Parses a NonVoidInitializer.
  /// $(BNF NonVoidInitializer :=
  ////  ArrayInitializer | StructInitializer | AssignExpr)
  Expression parseNonVoidInitializer()
  {
    auto begin = token;
    Expression init;
    switch (token.kind)
    {
    case T!"[":
      if (!tokenAfterBracket(T!"]").Any!(",", "]", "}", ";"))
        goto default; // Parse as an AssignExpr.
      // ArrayInitializer := "[" ArrayInitElements? "]"
      Expression[] keys, values;

      skip!"[";
      while (!tokenIs!"]")
      {
        Expression key;
        auto value = parseNonVoidInitializer();
        if (consumed!":")
          (key = value), // Switch roles.
          assert(!(key.Is!(ArrayInitExpr) || key.Is!(StructInitExpr))),
          value = parseNonVoidInitializer(); // Parse actual value.
        keys ~= key;
        values ~= value;
        if (!consumed!",")
          break;
      }
      requireClosing!"]"(begin);
      init = new ArrayInitExpr(keys, values);
      break;
    case T!"{":
      if (!tokenAfterBracket(T!"}").Any!(",", "]", "}", ";"))
        goto default; // Parse as an AssignExpr.
      // StructInitializer := "{" StructInitElements? "}"
      Token*[] idents;
      Expression[] values;

      skip!"{";
      while (!tokenIs!"}")
      { // Peek for colon to see if this is a member identifier.
        Token* ident;
        if (tokenIs!"Identifier" && nextIs!":")
          (ident = token),
          skip!"Identifier", skip!":";
        idents ~= ident;
        values ~= parseNonVoidInitializer();
        if (!consumed!",")
          break;
      }
      requireClosing!"}"(begin);
      init = new StructInitExpr(idents, values);
      break;
    default:
      return parseAssignExpr();
    }
    set(init, begin);
    return init;
  }

  /// Parses the body of a function.
  FuncBodyStmt parseFunctionBody()
  {
    auto begin = token;
    Statement funcBody, inBody, outBody;
    Token* outIdent;

    // Save the attributes.
    auto saved_stcs = this.storageClass;
    auto saved_prot = this.protection;
    auto saved_link = this.linkageType;
    // Clear attributes.
    this.storageClass = StorageClass.None;
    this.protection   = Protection.None;
    this.linkageType  = LinkageType.None;

  Loop:
    while (1)
      switch (token.kind)
      {
      case T!"{":
        funcBody = parseStatements();
        break Loop;
      case T!";":
        nT();
        break Loop;
      case T!"in":
        if (inBody)
          error(MID.InContract);
        nT();
        inBody = parseStatements();
        break;
      case T!"out":
        if (outBody)
          error(MID.OutContract);
        nT();
        if (consumed!"(")
          (outIdent = requireIdentifier(MID.ExpectedAnIdentifier)),
          require2!")";
        outBody = parseStatements();
        break;
      case T!"body":
        // if (!outBody || !inBody) // TODO:
        //   error2(MID.ExpectedInOutBody, token);
        nT();
        goto case T!"{";
      default:
        version (D2)
        {
        if (inBody || outBody)
          // In D2, having in or out contracts without a body is valid.
          break Loop;
        } // version (D2)
        error2(MID.ExpectedFunctionBody, token);
        break Loop;
      }

    // Restore the original attributes.
    this.storageClass = saved_stcs;
    this.protection = saved_prot;
    this.linkageType = saved_link;

    auto func = new FuncBodyStmt(funcBody, inBody, outBody, outIdent);
    return set(func, begin);
  }

  /// $(BNF FunctionPostfix :=
  ////  (const|immutable|inout|nothrow|shared|pure| "@" Identifier)*)
  StorageClass parseFunctionPostfix()
  {
    version(D2)
    {
    StorageClass stcs, stc;
    while (1)
    {
      switch (token.kind)
      {
      case T!"const":     stc = StorageClass.Const;     break;
      case T!"immutable": stc = StorageClass.Immutable; break;
      case T!"inout":     stc = StorageClass.Inout;     break;
      case T!"nothrow":   stc = StorageClass.Nothrow;   break;
      case T!"shared":    stc = StorageClass.Shared;    break;
      case T!"pure":      stc = StorageClass.Pure;      break;
      case T!"@":         stc = parseAtAttribute();     break;
      default:
        return stcs;
      }
      if (stcs & stc)
        error2(MID.RedundantStorageClass, token);
      stcs |= stc;
      nT();
    }
    return stcs;
    } // version(D2)
    assert(0);
  }

  /// A tuple of all the possible postfix tokens.
  alias FunctionPostfix = Tuple!("const", "immutable", "inout", "nothrow",
    "shared", "pure", "@");

  /// $(BNF ExternLinkageType := extern "(" LinkageType ")"
  ///LinkageType := "C" | "C" "++" | "D" | "Windows" | "Pascal" | "System")
  LinkageType parseExternLinkageType()
  {
    LinkageType linkageType;

    skip!"extern", skip!"(";

    if (consumed!")")
    { // extern "(" ")"
      error(MID.MissingLinkageType);
      return linkageType;
    }

    if (auto idtok = requireIdentifier(MID.ExpectedLinkageIdentifier))
      switch (idtok.ident.idKind)
      {
      case IDK.C:       linkageType = consumed!"++" ?
                                      LinkageType.Cpp :
                                      LinkageType.C;       break;
      case IDK.D:       linkageType = LinkageType.D;       break;
      case IDK.Windows: linkageType = LinkageType.Windows; break;
      case IDK.Pascal:  linkageType = LinkageType.Pascal;  break;
      case IDK.System:  linkageType = LinkageType.System;  break;
      default:
        error2(MID.UnrecognizedLinkageType, idtok);
      }
    require2!")";
    return linkageType;
  }

  /// Reports an error if a linkage type has already been parsed.
  void checkLinkageType(ref LinkageType prev_lt, LinkageType lt, Token* begin)
  {
    if (prev_lt == LinkageType.None)
      prev_lt = lt;
    else
      error(begin, MID.RedundantLinkageType, begin.textSpan(prevToken));
  }

  /// Returns a StorageClass when the next token is not a "(".
  StorageClass getSTC()
  {
    if (nextIs!"(")
      return StorageClass.None;
    auto k = token.kind;
    return k == T!"const" ? StorageClass.Const :
       k == T!"immutable" ? StorageClass.Immutable :
           k == T!"inout" ? StorageClass.Inout :
                            StorageClass.Shared;
  }

  /// Parses one or more attributes and a Declaration at the end.
  ///
  /// $(BNF
  ////Attributes :=
  ////  (StorageAttribute | AlignAttribute | PragmaAttribute | ProtAttribute)*
  ////  DeclsBlock
  ////StorageAttribute := extern | ExternLinkageType | override | abstract |
  ////  auto | synchronized | static | final | const | immutable | enum | scope
  ////AlignAttribute   := align ("(" Integer ")")?
  ////PragmaAttribute  := pragma "(" Identifier ("," ExpressionList)? ")"
  ////ProtAttribute    := private | public | package | protected | export)
  /// Params:
  ///   pDecl = Set to the non-attribute Declaration if non-null.
  Declaration parseAttributes(Declaration* pDecl = null)
  {
    StorageClass stcs, // Set to StorageClasses parsed in the loop.
      stc; // Current StorageClass in the loop.
    LinkageType linkageType; // Currently parsed LinkageType.
    Protection protection, // Set to the Protection parsed in the loop.
      prot; // Current Protection in the loop.
    uint alignSize; // Set to the AlignSize parsed in the loop.
    bool testAutoDecl; // Test for: auto Identifier "=" Expression

    // Allocate dummy declarations.
    scope emptyDecl = new EmptyDecl();
    // Function as the head of the attribute chain.
    scope AttributeDecl headAttr = new StorageClassDecl(STC.None, emptyDecl);

    AttributeDecl currentAttr = headAttr, prevAttr = headAttr;

    // Parse the attributes.
  Loop:
    while (1)
    {
      auto begin = token;
      switch (token.kind)
      {
      case T!"extern":
        if (nextIs!"(")
        {
          checkLinkageType(linkageType, parseExternLinkageType(), begin);
          currentAttr = new LinkageDecl(linkageType, emptyDecl);
          testAutoDecl = false;
          break;
        }
                             stc = StorageClass.Extern;       goto Lcommon;
      case T!"override":     stc = StorageClass.Override;     goto Lcommon;
      case T!"deprecated":   stc = StorageClass.Deprecated;   goto Lcommon;
      case T!"abstract":     stc = StorageClass.Abstract;     goto Lcommon;
      case T!"synchronized": stc = StorageClass.Synchronized; goto Lcommon;
      case T!"static":
        switch (peekNext())
        { // Avoid parsing static import, static this etc.
        case T!"import", T!"this", T!"~", T!"if", T!"assert":
          break Loop;
        default:
        }
                             stc = StorageClass.Static;       goto Lcommon;
      case T!"final":        stc = StorageClass.Final;        goto Lcommon;
      version(D2)
      {
      case T!"const", T!"immutable", T!"inout", T!"shared":
        if ((stc = getSTC()) == 0)
          break Loop;
        goto Lcommon;
      case T!"enum":
        if (!isEnumManifest())
          break Loop;
                             stc = StorageClass.Manifest;     goto Lcommon;
      case T!"ref":          stc = StorageClass.Ref;          goto Lcommon;
      case T!"pure":         stc = StorageClass.Pure;         goto Lcommon;
      case T!"nothrow":      stc = StorageClass.Nothrow;      goto Lcommon;
      case T!"__gshared":    stc = StorageClass.Gshared;      goto Lcommon;
      case T!"@":            stc = parseAtAttribute();        goto Lcommon;
      } // version(D2)
      else
      { // D1
      case T!"const":        stc = StorageClass.Const;        goto Lcommon;
      }
      case T!"auto":         stc = StorageClass.Auto;         goto Lcommon;
      case T!"scope":        stc = StorageClass.Scope;        goto Lcommon;
      Lcommon:
        if (stcs & stc) // Issue error if redundant.
          error2(MID.RedundantStorageClass, token);
        stcs |= stc;
        nT(); // Skip the storage class token.
        currentAttr = new StorageClassDecl(stc, emptyDecl);
        testAutoDecl = true;
        break;
      // Protection attributes:
      case T!"private":   prot = Protection.Private;   goto Lprot;
      case T!"package":   prot = Protection.Package;   goto Lprot;
      case T!"protected": prot = Protection.Protected; goto Lprot;
      case T!"public":    prot = Protection.Public;    goto Lprot;
      case T!"export":    prot = Protection.Export;    goto Lprot;
      Lprot:
        if (protection != Protection.None)
          error2(MID.RedundantProtection, token);
        protection = prot;
        nT();
        currentAttr = new ProtectionDecl(prot, emptyDecl);
        testAutoDecl = false;
        break;
      case T!"align":
        // align ("(" Integer ")")?
        Token* sizetok;
        alignSize = parseAlignAttribute(sizetok);
        // TODO: error msg for redundant align attributes.
        currentAttr = new AlignDecl(sizetok, emptyDecl);
        testAutoDecl = false;
        break;
      case T!"pragma":
        // Pragma := pragma "(" Identifier ("," ExpressionList)? ")"
        nT();
        auto paren = requireOpening!"(";
        auto ident = requireIdentifier(MID.ExpectedPragmaIdentifier);
        auto args = consumed!"," ? parseExpressionList() : null;
        requireClosing!")"(paren);
        currentAttr = new PragmaDecl(ident, args, emptyDecl);
        testAutoDecl = false;
        break;
      default:
        break Loop;
      }
      // NB: the 'end' member is not set to the end token of
      //   the declaration, which is parsed below.
      //   If necessary, this could be fixed by traversing
      //   the attributes at the end and calling set() there.
      set(currentAttr, begin);
      // Correct the child node and continue parsing attributes.
      prevAttr.setDecls(currentAttr);
      prevAttr = currentAttr; // Current becomes previous.
    }

    // Parse the declaration.
    Declaration decl;
    if (!linkageType)
      linkageType = this.linkageType;
    // Save attributes.
    auto outer_storageClass = this.storageClass;
    auto outer_linkageType = this.linkageType;
    auto outer_protection = this.protection;
    auto outer_alignSize = this.alignSize;
    // Set parsed values.
    stcs |= outer_storageClass; // Combine with outer stcs.
    this.storageClass = stcs;
    this.linkageType = linkageType;
    this.protection = protection;
    this.alignSize = alignSize;
    if (testAutoDecl && tokenIs!"Identifier") // "auto" Identifier "="
      decl = // This could be a normal Declaration or an AutoDeclaration
        parseVariablesOrFunction(stcs, protection, linkageType, true);
    else
    {
      if (prevAttr.Is!PragmaDecl && tokenIs!";")
        decl = parseDeclarationDefinition(); // Allow semicolon after pragma().
      else // Parse a block.
        decl = parseDeclarationsBlock();
    }
    // Restore outer values.
    this.storageClass = outer_storageClass;
    this.linkageType = outer_linkageType;
    this.protection = outer_protection;
    this.alignSize = outer_alignSize;
    if (pDecl)
      *pDecl = decl;

    assert(decl !is null && isNodeSet(decl));
    // Attach the declaration to the previously parsed attribute.
    prevAttr.setDecls(decl);
    // Return the first attribute declaration.
    return headAttr.decls;
  }

  /// $(BNF AlignAttribute := align ("(" Integer ")")?)
  uint parseAlignAttribute(out Token* sizetok)
  {
    skip!"align";
    uint size;
    if (consumed!"(")
    {
      if (tokenIs!"Int32")
        (sizetok = token), (size = token.int_), skip!"Int32";
      else
        expected!"Int32";
      require2!")";
    }
    return size;
  }

  /// $(BNF AtAttribute := "@" Identifier)
  StorageClass parseAtAttribute()
  {
    skip!"@";
    StorageClass stc;
    if (tokenIs!"Identifier")
      switch (token.ident.idKind)
      {
      case IDK.disable:  stc = StorageClass.Disable;  break;
      case IDK.property: stc = StorageClass.Property; break;
      case IDK.safe:     stc = StorageClass.Safe;     break;
      case IDK.system:   stc = StorageClass.System;   break;
      case IDK.trusted:  stc = StorageClass.Trusted;  break;
      default:
        error2(MID.UnrecognizedAttribute, token);
      }
    else
      error2(MID.ExpectedAttributeId, token);
    // Return without skipping the identifier.
    return stc;
  }

  /// $(BNF ImportDecl := static? import
  ////              ImportModule ("," ImportModule)*
  ////              (":" ImportBind ("," ImportBind)*)?
  ////              ";"
  ////ImportModule := (AliasName "=")? ModuleName
  ////ImportBind   := (AliasName "=")? BindName
  ////ModuleName   := Identifier ("." Identifier)*
  ////AliasName    := Identifier
  ////BindName     := Identifier)
  ImportDecl parseImportDecl()
  {
    bool isStatic = consumed!"static";
    skip!"import";

    ModuleFQN[] moduleFQNs;
    Token*[] moduleAliases;
    Token*[] bindNames;
    Token*[] bindAliases;

    do
    {
      ModuleFQN moduleFQN;
      Token* moduleAlias;
      // AliasName = ModuleName
      if (nextIs!"=")
      {
        moduleAlias = requireIdentifier(MID.ExpectedAliasModuleName);
        skip!"=";
      }
      // Identifier ("." Identifier)*
      do
        moduleFQN ~= requireIdentifier(MID.ExpectedModuleIdentifier);
      while (consumed!".");
      // Push identifiers.
      moduleFQNs ~= moduleFQN;
      moduleAliases ~= moduleAlias;
    } while (consumed!",");

    if (consumed!":")
    { // ImportBind := (BindAlias "=")? BindName
      // ":" ImportBind ("," ImportBind)*
      do
      {
        Token* bindAlias;
        // BindAlias = BindName
        if (nextIs!"=")
        {
          bindAlias = requireIdentifier(MID.ExpectedAliasImportName);
          skip!"=";
        }
        // Push identifiers.
        bindNames ~= requireIdentifier(MID.ExpectedImportName);
        bindAliases ~= bindAlias;
      } while (consumed!",");
    }
    require2!";";

    return new ImportDecl(moduleFQNs, moduleAliases, bindNames,
                                 bindAliases, isStatic);
  }

  /// Returns true if this is an enum manifest or
  /// false if it's a normal enum declaration.
  bool isEnumManifest()
  {
    version(D2)
    {
    assert(tokenIs!"enum");
    auto next = peekAfter(token);
    auto kind = next.kind;
    if (kind.Any!(":", "{"))
      return false; // Anonymous enum.
    else
    if (kind == T!"Identifier" && peekAfter(next).kind.Any!(":", "{", ";"))
      return false; // Named enum.
    return true; // Manifest enum.
    }
    assert(0);
  }

  /// $(BNF
  ////EnumDecl :=
  ////  enum Name? (":" BasicType)? EnumBody |
  ////  enum Name ";"
  ////EnumBody     := "{" EnumMembers "}"
  ////EnumMembers  := EnumMember ("," EnumMember)* ","?
  ////EnumMembers2 := Type? EnumMember ("," Type? EnumMember)* ","? # D2.0
  ////EnumMember   := Name ("=" AssignExpr)?)
  Declaration parseEnumDecl()
  {
    skip!"enum";

    EnumMemberDecl[] members;

    auto enumName = optionalIdentifier();
    auto baseType = consumed!":" ? parseBasicType() : null;

    if (enumName && consumed!";")
    {}
    else if (auto brace = consumedToken!"{")
    {
      while (!tokenIs!"}")
      {
        auto begin = token;
        Type type; // Optional member type.

        version(D2)
        if (!peekNext().Any!("=", ",", "}"))
          type = parseType();

        auto name = requireIdentifier(MID.ExpectedEnumMember);
        // "=" AssignExpr
        auto value = consumed!"=" ? parseAssignExpr() : null;
        auto member = new EnumMemberDecl(type, name, value);
        members ~= set(member, begin);

        if (!consumed!",")
          break;
      }
      requireClosing!"}"(brace);
    }
    else
      error2(MID.ExpectedEnumBody, token);

    return new EnumDecl(enumName, baseType, members);
  }

  /// Wraps a declaration inside a template declaration.
  /// Params:
  ///   begin = Begin token of decl.
  ///   name = Name of decl.
  ///   decl = The declaration to be wrapped.
  ///   tparams = The template parameters.
  ///   constraint = The constraint expression.
  TemplateDecl putInsideTemplateDeclaration(
    Token* begin,
    Token* name,
    Declaration decl,
    TemplateParameters tparams,
    Expression constraint)
  {
    set(decl, begin);
    auto cd = new CompoundDecl;
    cd ~= decl;
    set(cd, begin);
    decl.setStorageClass(this.storageClass);
    decl.setProtection(this.protection);
    return new TemplateDecl(name, tparams, constraint, cd);
  }

  /// $(BNF ClassDecl :=
  ////  class Name TemplateParameterList? (":" BaseClasses) ClassBody |
  ////  class Name ";"
  ////ClassBody := DeclDefsBlock)
  Declaration parseClassDecl()
  {
    auto begin = token;
    skip!"class";

    TemplateParameters tparams;
    Expression constraint;
    CompoundDecl decls;

    auto name = requireIdentifier(MID.ExpectedClassName);

    if (tokenIs!"(")
    {
      tparams = parseTemplateParameterList();
      version(D2) constraint = parseOptionalConstraint();
    }

    auto bases = consumed!":" ? parseBaseClasses() : null;

    version(D2)
    if (bases.length && tokenIs!"if")
    {
      if (constraint)
        error(MID.RedundantConstraint);
      constraint = parseOptionalConstraint();
    }

    if (bases.length || !consumed!";")
      if (tokenIs!"{")
        decls = parseDeclarationDefinitionsBody();
      else
        error2(MID.ExpectedClassBody, token);

    Declaration d = new ClassDecl(name, /+tparams, +/bases, decls);
    if (tparams)
      d = putInsideTemplateDeclaration(begin, name, d, tparams, constraint);
    return d;
  }

  /// $(BNF BaseClasses := BaseClass ("," BaseClass)*
  ////BaseClass   := Protection? BasicType
  ////Protection  := private | public | protected | package)
  BaseClassType[] parseBaseClasses()
  {
    BaseClassType[] bases;
    do
    {
      Protection prot;
      switch (token.kind)
      {
      case T!"Identifier", T!".", T!"typeof": goto LparseBasicType;
      case T!"private":   prot = Protection.Private;   break;
      case T!"protected": prot = Protection.Protected; break;
      case T!"package":   prot = Protection.Package;   break;
      case T!"public":    prot = Protection.Public;    break;
      default:
        error2(MID.ExpectedBaseClasses, token);
        return bases;
      }
      nT(); // Skip protection attribute.
    LparseBasicType:
      auto begin = token;
      auto type = parseBasicType();
      bases ~= set(new BaseClassType(prot, type), begin);
    } while (consumed!",");
    return bases;
  }

  /// $(BNF InterfaceDecl :=
  ////  interface Name TemplateParameterList? (":" BaseClasses) InterfaceBody |
  ////  interface Name ";"
  ////InterfaceBody := DeclDefsBlock)
  Declaration parseInterfaceDecl()
  {
    auto begin = token;
    skip!"interface";

    TemplateParameters tparams;
    Expression constraint;
    CompoundDecl decls;

    auto name = requireIdentifier(MID.ExpectedInterfaceName);

    if (tokenIs!"(")
    {
      tparams = parseTemplateParameterList();
      version(D2) constraint = parseOptionalConstraint();
    }

    auto bases = consumed!":" ? parseBaseClasses() : null;

    version(D2)
    if (bases.length && tokenIs!"if")
    {
      if (constraint)
        error(MID.RedundantConstraint);
      constraint = parseOptionalConstraint();
    }

    if (bases.length || !consumed!";")
      if (tokenIs!"{")
        decls = parseDeclarationDefinitionsBody();
      else
        error2(MID.ExpectedInterfaceBody, token);

    Declaration d = new InterfaceDecl(name, bases, decls);
    if (tparams)
      d = putInsideTemplateDeclaration(begin, name, d, tparams, constraint);
    return d;
  }

  /// $(BNF StructDecl :=
  ////  struct Name? TemplateParameterList? StructBody |
  ////  struct Name ";"
  ////StructBody := DeclDefsBlock
  ////UnionDecl  :=
  ////  union Name? TemplateParameterList? UnionBody |
  ////  union Name ";"
  ////UnionBody  := DeclDefsBlock)
  Declaration parseStructOrUnionDecl()
  {
    assert(token.kind.Any!("struct", "union"));
    auto begin = token;
    nT();

    TemplateParameters tparams;
    Expression constraint;
    CompoundDecl decls;

    auto name = optionalIdentifier();

    if (name && tokenIs!"(")
    {
      tparams = parseTemplateParameterList();
      version(D2) constraint = parseOptionalConstraint();
    }

    if (!name || !consumed!";")
      if (tokenIs!"{")
        decls = parseDeclarationDefinitionsBody();
      else
        error2(begin.kind == T!"struct" ?
               MID.ExpectedStructBody : MID.ExpectedUnionBody, token);

    Declaration d;
    if (begin.kind == T!"struct")
    {
      auto sd = new StructDecl(name, /+tparams, +/decls);
      sd.setAlignSize(this.alignSize);
      d = sd;
    }
    else
      d = new UnionDecl(name, /+tparams, +/decls);

    if (tparams)
      d = putInsideTemplateDeclaration(begin, name, d, tparams, constraint);
    return d;
  }

  /// $(BNF ConstructorDecl := this ParameterList FunctionBody)
  Declaration parseConstructorDecl()
  {
    version(D2)
    {
    auto begin = token;
    TemplateParameters tparams;
    Expression constraint;
    skip!"this";
    if (tokenIs!"(" && tokenAfterParenIs(T!"("))
      tparams = parseTemplateParameterList(); // "(" TemplateParameterList ")"
    Parameters parameters;
    if (!nextIs!"this")
      parameters = parseParameterList(); // "(" ParameterList ")"
    else // PostBlit := this "(" this ")"
    {
      auto paren = requireOpening!"(";
      parameters = new Parameters();
      auto this_ = consume();
      auto thisParam = new Parameter(STC.None, null, null, this_, null);
      parameters ~= set(thisParam, this_);
      requireClosing!")"(paren);
      set(parameters, paren);
    }
    parameters.postSTCs = parseFunctionPostfix();
    // FIXME: |= to storageClass?? Won't this affect other decls?
    this.storageClass |= parameters.postSTCs; // Combine with current stcs.
    if (tparams) // if "(" ConstraintExpr ")"
      constraint = parseOptionalConstraint();
    auto funcBody = parseFunctionBody();
    Declaration d = new ConstructorDecl(parameters, funcBody);
    if (tparams)
      d = putInsideTemplateDeclaration(begin, begin, d, tparams, constraint);
    return d;
    } // version(D2)
    else
    { // D1
    skip!"this";
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new ConstructorDecl(parameters, funcBody);
    }
  }

  /// $(BNF DestructorDecl := "~" this "(" ")" FunctionBody)
  Declaration parseDestructorDecl()
  {
    skip!"~";
    require2!"this";
    require2!"(";
    require2!")";
    auto funcBody = parseFunctionBody();
    return new DestructorDecl(funcBody);
  }

  /// $(BNF StaticCtorDecl := static this "(" ")" FunctionBody)
  Declaration parseStaticCtorDecl()
  {
    skip!"static";
    skip!"this";
    require2!"(";
    require2!")";
    auto funcBody = parseFunctionBody();
    return new StaticCtorDecl(funcBody);
  }

  /// $(BNF
  ////StaticDtorDecl := static "~" this "(" ")" FunctionBody)
  Declaration parseStaticDtorDecl()
  {
    skip!"static";
    skip!"~";
    require2!"this";
    require2!"(";
    require2!")";
    auto funcBody = parseFunctionBody();
    return new StaticDtorDecl(funcBody);
  }

  /// $(BNF InvariantDecl := invariant ("(" ")")? FunctionBody)
  Declaration parseInvariantDecl()
  {
    skip!"invariant";
    if (consumed!"(") // Optional "(" ")"
      require2!")";
    auto funcBody = parseFunctionBody();
    return new InvariantDecl(funcBody);
  }

  /// $(BNF UnittestDecl := unittest FunctionBody)
  Declaration parseUnittestDecl()
  {
    skip!"unittest";
    if (!tokenIs!"{")
      error2(MID.ExpectedUnittestBody, token);
    auto funcBody = parseFunctionBody();
    return new UnittestDecl(funcBody);
  }

  /// Parses an identifier or an integer. Reports an error otherwise.
  /// $(BNF IdentOrInt := Identifier | Integer)
  Token* parseIdentOrInt()
  {
    if (token.kind.Any!("Identifier", "Int32"))
      return consume();
    error2(MID.ExpectedIdentOrInt, token);
    return null;
  }

  /// $(BNF VersionCondition := unittest #*D2.0*# | IdentOrInt)
  Token* parseVersionCondition()
  {
    version(D2)
    if (token.kind.Any!("unittest", "assert"))
      return consume();
    return parseIdentOrInt();
  }

  /// $(BNF DebugDecl :=
  ////  debug "=" IdentOrInt ";" |
  ////  debug DebugCondition? DeclsBlock (else DeclsBlock)?
  ////DebugCondition := "(" IdentOrInt ")")
  Declaration parseDebugDecl()
  {
    skip!"debug";
    Token* spec, cond;
    Declaration decls, elseDecls;
    if (consumed!"=")
    { // debug "=" (Integer | Identifier) ";"
      spec = parseIdentOrInt();
      require2!";";
    }
    else
    {
      if (auto paren = consumedToken!"(")
      { // "(" Condition ")"
        cond = parseIdentOrInt();
        requireClosing!")"(paren);
      }
      decls = parseDeclarationsBlock(); // DeclsBlock
      if (consumed!"else") // else DeclsBlock
        elseDecls = parseDeclarationsBlock();
    }
    return new DebugDecl(spec, cond, decls, elseDecls);
  }

  /// $(BNF VersionDecl :=
  ////  version "=" IdentOrInt ";" |
  ////  version VCondition DeclsBlock (else DeclsBlock)?
  ////VCondition  := "(" VersionCondition ")")
  Declaration parseVersionDecl()
  {
    skip!"version";
    Token* spec, cond;
    Declaration decls, elseDecls;
    if (consumed!"=")
    { // version = (Integer | Identifier) ";"
      spec = parseIdentOrInt();
      require2!";";
    }
    else
    { // "(" Condition ")"
      auto paren = requireOpening!"(";
      cond = parseVersionCondition();
      requireClosing!")"(paren);
      decls = parseDeclarationsBlock(); // DeclsBlock
      if (consumed!"else") // else DeclsBlock
        elseDecls = parseDeclarationsBlock();
    }
    return new VersionDecl(spec, cond, decls, elseDecls);
  }

  /// $(BNF StaticIfDecl :=
  ////  static if "(" AssignExpr ")" DeclsBlock (else DeclsBlock)?)
  Declaration parseStaticIfDecl()
  {
    skip!"static";
    skip!"if";
    auto paren = requireOpening!"(";
    auto condition = parseAssignExpr();
    requireClosing!")"(paren);
    auto ifDecls = parseDeclarationsBlock();
    auto elseDecls = consumed!"else" ? parseDeclarationsBlock() : null;
    return new StaticIfDecl(condition, ifDecls, elseDecls);
  }

  /// $(BNF StaticAssertDecl :=
  ////  static assert "(" AssignExpr ("," Message)? ")" ";"
  ////Message          := AssignExpr)
  Declaration parseStaticAssertDecl()
  {
    skip!"static";
    skip!"assert";
    auto paren = requireOpening!"(";
    auto condition = parseAssignExpr();
    auto message = consumed!"," ? parseAssignExpr() : null;
    requireClosing!")"(paren);
    require2!";";
    return new StaticAssertDecl(condition, message);
  }

  /// $(BNF TemplateDecl :=
  ////  template Name TemplateParameterList Constraint? DeclDefsBlock)
  TemplateDecl parseTemplateDecl()
  {
    skip!"template";
    auto name = requireIdentifier(MID.ExpectedTemplateName);
    auto tparams = parseTemplateParameterList();
    auto constraint = parseOptionalConstraint();
    auto decls = parseDeclarationDefinitionsBody();
    return new TemplateDecl(name, tparams, constraint, decls);
  }

  /// $(BNF NewDecl := new ParameterList FunctionBody)
  Declaration parseNewDecl()
  {
    skip!"new";
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new NewDecl(parameters, funcBody);
  }

  /// $(BNF DeleteDecl := delete ParameterList FunctionBody)
  Declaration parseDeleteDecl()
  {
    skip!"delete";
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new DeleteDecl(parameters, funcBody);
  }

  /// Parses a MixinDecl or MixinStmt.
  /// $(BNF
  ////MixinDecl       := (MixinExpr | MixinTemplate | MixinTemplateId) ";"
  ////MixinExpr       := mixin "(" AssignExpr ")"
  ////MixinTemplate   := mixin TemplateDecl # D2
  ////MixinTemplateId := mixin TemplateIdentifier
  ////                   ("!" "(" TemplateArguments ")")? MixinIdentifier?)
  RetT parseMixin(Class, RetT = Class)()
  {
    static assert(is(Class == MixinDecl) || is(Class == MixinStmt));
    skip!"mixin";

    static if (is(Class == MixinDecl))
    {
    if (auto paren = consumedToken!"(")
    {
      auto e = parseAssignExpr();
      requireClosing!")"(paren);
      require2!";";
      return new MixinDecl(e);
    }
    else version(D2) if (tokenIs!"template")
    {
      auto d = parseTemplateDecl();
      d.isMixin = true;
      return d;
    } // version(D2)
    }

    auto e = parseIdentifiersExpr();
    auto mixinIdent = optionalIdentifier();
    require2!";";

    return new Class(e, mixinIdent);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                        Statement parsing methods                        |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// $(BNF Statements := "{" Statement* "}")
  CompoundStmt parseStatements()
  {
    auto brace = requireOpening!"{";
    auto statements = new CompoundStmt();
    while (!token.kind.Any!("}", "EOF"))
      statements ~= parseStatement();
    requireClosing!"}"(brace);
    return set(statements, brace);
  }

  /// Parses a Statement.
  Statement parseStatement()
  {
    auto begin = token;
    Statement s;
    Declaration d;

    if (token.isIntegralType)
    {
      d = parseVariablesOrFunction();
      goto LreturnDeclarationStmt;
    }

    switch (token.kind)
    {
    case T!"align":
      Token* sizetok;
      uint size = parseAlignAttribute(sizetok);
      // Restrict align attribute to structs in parsing phase.
      StructDecl structDecl;
      if (tokenIs!"struct")
      {
        auto begin2 = token;
        structDecl = parseStructOrUnionDecl().to!(StructDecl);
        structDecl.setAlignSize(size);
        set(structDecl, begin2);
      }
      else
        expected!"struct";

      d = structDecl ? cast(Declaration)structDecl : new CompoundDecl;
      d = new AlignDecl(sizetok, d);
      goto LreturnDeclarationStmt;

    case T!"extern", T!"const", T!"auto":
         //T!"final", T!"scope", T!"static":
    version(D2)
    {
    case T!"immutable", T!"inout", T!"pure", T!"shared", T!"__gshared",
         T!"ref", T!"nothrow", T!"@":
    }
      goto case_parseAttribute;

    case T!"Identifier":
      if (nextIs!":")
      {
        skip!"Identifier"; skip!":";
        s = new LabeledStmt(begin, parseNoScopeOrEmptyStmt());
        break;
      }
      goto case T!".";
    version(D2)
    {
    case T!"this", T!"super":
    }
    case T!".", T!"typeof":
      bool success;
      d = tryToParse({ return parseVariablesOrFunction(); }, success);
      if (success)
        goto LreturnDeclarationStmt; // Declaration
      else
        goto case_parseExpressionStmt; // Expression
    case T!"if":              s = parseIfStmt();            break;
    case T!"while":           s = parseWhileStmt();         break;
    case T!"do":              s = parseDoWhileStmt();       break;
    case T!"for":             s = parseForStmt();           break;
    case T!"foreach",
         T!"foreach_reverse": s = parseForeachStmt();       break;
    case T!"switch":          s = parseSwitchStmt();        break;
    case T!"case":            s = parseCaseStmt();          break;
    case T!"default":         s = parseDefaultStmt();       break;
    case T!"continue":        s = parseContinueStmt();      break;
    case T!"break":           s = parseBreakStmt();         break;
    case T!"return":          s = parseReturnStmt();        break;
    case T!"goto":            s = parseGotoStmt();          break;
    case T!"with":            s = parseWithStmt();          break;
    case T!"synchronized":    s = parseSynchronizedStmt();  break;
    case T!"try":             s = parseTryStmt();           break;
    case T!"throw":           s = parseThrowStmt();         break;
    case T!"volatile":        s = parseVolatileStmt();      break;
    case T!"asm":             s = parseAsmBlockStmt();      break;
    case T!"pragma":          s = parsePragmaStmt();        break;
    case T!"debug":           s = parseDebugStmt();         break;
    case T!"version":         s = parseVersionStmt();       break;
    case T!"{":               s = parseScopeStmt();         break;
    case T!";":         nT(); s = new EmptyStmt();          break;
    case_T_Scope:             s = parseScopeGuardStmt();    break;
    case_T_Mixin:             s = parseMixin!(MixinStmt)(); break;
    case_parseAttribute:      s = parseAttributeStmt();     break;
    case T!"scope":
      if (!nextIs!"(")
        goto case_parseAttribute;
      goto case_T_Scope;
    case T!"mixin":
      if (nextIs!"(")
        goto case_parseExpressionStmt; // Parse as expression.
      goto case_T_Mixin;
    case T!"final":
      version(D2)
      {
      if (nextIs!"switch")
        goto case T!"switch";
      }
      goto case_parseAttribute;
    case T!"static":
      switch (peekNext())
      {
      case T!"if":     s = parseStaticIfStmt();     break;
      case T!"assert": s = parseStaticAssertStmt(); break;
      default:         goto case_parseAttribute;
      }
      break;
    // DeclDef
    case T!"alias", T!"typedef":
      d = parseDeclarationDefinition();
      goto LreturnDeclarationStmt;
    case T!"enum":
      version(D2)
      if (isEnumManifest())
        goto case_parseAttribute;
      d = parseEnumDecl();
      goto LreturnDeclarationStmt;
    case T!"class":
      d = parseClassDecl();
      goto LreturnDeclarationStmt;
    case T!"import":
      version(D2)
      {
      if (!nextIs!"(")
      {
        d = parseImportDecl();
        goto LreturnDeclarationStmt;
      }
      }
      goto case_parseExpressionStmt;
    case T!"interface":
      d = parseInterfaceDecl();
      goto LreturnDeclarationStmt;
    case T!"struct", T!"union":
      d = parseStructOrUnionDecl();
      // goto LreturnDeclarationStmt;
    LreturnDeclarationStmt:
      set(d, begin);
      s = new DeclarationStmt(d);
      break;
    // Parse an ExpressionStmt:
    // Tokens that start a PrimaryExpr.
    // case T!"Identifier", T!".", T!"typeof":
    version(D1)
    {
    case T!"this":
    case T!"super":
    }
    case T!"null":
    case T!"true", T!"false":
    // case T!"$":
    case T!"Int32", T!"Int64", T!"UInt32", T!"UInt64":
    case T!"Float32", T!"Float64", T!"Float80",
         T!"IFloat32", T!"IFloat64", T!"IFloat80":
    case T!"Character":
    case T!"String":
    case T!"[":
    // case T!"{":
    case T!"function", T!"delegate":
    case T!"assert":
    // case T!"mixin":
    case T!"typeid":
    case T!"is":
    case T!"(":
    version(D2)
    {
    case T!"__traits":
    }
    // Tokens that can start a UnaryExpr:
    case T!"&", T!"++", T!"--", T!"*", T!"-",
         T!"+", T!"!", T!"~", T!"new", T!"delete", T!"cast":
    case_parseExpressionStmt:
      s = new ExpressionStmt(parseExpression());
      require2!";";
      break;
    default:
      if (token.isSpecialToken)
        goto case_parseExpressionStmt;

      if (!tokenIs!"$")
        // Assert that this isn't a valid expression.
        assert(delegate bool(){
            bool success;
            auto expression = tryToParse(&parseExpression, success);
            return success;
          }() == false, "Didn't expect valid expression."
        );

      // Report error: it's an illegal statement.
      s = new IllegalStmt();
      // Skip to next valid token.
      do
        nT();
      while (!token.isStatementStart() && !token.kind.Any!("}", "EOF"));
      auto text = begin.textSpan(this.prevToken);
      error(begin, MID.IllegalStatement, text);
    }
    assert(s !is null);
    set(s, begin);
    return s;
  }

  /// Parses a ScopeStmt.
  /// $(BNF ScopeStmt := NoScopeStmt)
  Statement parseScopeStmt()
  {
    auto s = parseNoScopeStmt();
    return set(new ScopeStmt(s), s.begin);
  }

  /// $(BNF
  ////NoScopeStmt := NonEmptyStmt | BlockStmt
  ////BlockStmt   := Statements)
  Statement parseNoScopeStmt()
  {
    if (tokenIs!"{")
      return parseStatements();
    else
    {
      if (tokenIs!";")
        error(MID.ExpectedNonEmptyStatement, token);
      return parseStatement();
    }
  }

  /// $(BNF NoScopeOrEmptyStmt := ";" | NoScopeStmt)
  Statement parseNoScopeOrEmptyStmt()
  {
    if (auto semicolon = consumedToken!";")
      return set(new EmptyStmt(), semicolon);
    else
      return parseNoScopeStmt();
  }

  /// $(BNF AttributeStmt := Attributes+
  ////  (VariableOrFunctionDecl | DeclDef)
  ////Attributes := extern | ExternLinkageType | auto | static |
  ////              final | const | immutable | enum | scope)
  Statement parseAttributeStmt()
  {
    StorageClass stcs, stc;
    LinkageType linkageType;
    bool testAutoDecl;

    // Allocate dummy declarations.
    scope emptyDecl = new EmptyDecl();
    // Function as the head of the attribute chain.
    scope AttributeDecl headAttr =
      new StorageClassDecl(StorageClass.None, emptyDecl);

    AttributeDecl currentAttr, prevAttr = headAttr;

    // Parse the attributes.
  Loop:
    while (1)
    {
      auto begin = token;
      switch (token.kind)
      {
      case T!"extern":
        if (nextIs!"(")
        {
          checkLinkageType(linkageType, parseExternLinkageType(), begin);
          currentAttr = new LinkageDecl(linkageType, emptyDecl);
          testAutoDecl = false;
          break;
        }
                          stc = StorageClass.Extern;   goto Lcommon;
      case T!"static":    stc = StorageClass.Static;   goto Lcommon;
      case T!"final":     stc = StorageClass.Final;    goto Lcommon;
      version(D2)
      {
      case T!"const", T!"immutable", T!"inout", T!"shared":
        if ((stc = getSTC()) == 0)
          break Loop;
        goto Lcommon;
      case T!"enum":
        if (!isEnumManifest())
          break Loop;
                          stc = StorageClass.Manifest; goto Lcommon;
      case T!"ref":       stc = StorageClass.Ref;      goto Lcommon;
      case T!"pure":      stc = StorageClass.Pure;     goto Lcommon;
      case T!"nothrow":   stc = StorageClass.Nothrow;  goto Lcommon;
      case T!"__gshared": stc = StorageClass.Gshared;  goto Lcommon;
      case T!"@":         stc = parseAtAttribute();    goto Lcommon;
      } // version(D2)
      else
      { // D1
      case T!"const":     stc = StorageClass.Const;    goto Lcommon;
      }
      case T!"auto":      stc = StorageClass.Auto;     goto Lcommon;
      case T!"scope":     stc = StorageClass.Scope;    goto Lcommon;
      Lcommon:
        if (stcs & stc) // Issue error if redundant.
          error2(MID.RedundantStorageClass, token);
        stcs |= stc;
        nT(); // Skip the storage class token.
        currentAttr = new StorageClassDecl(stc, emptyDecl);
        testAutoDecl = true;
        break;
      default:
        break Loop;
      }
      set(currentAttr, begin);
      // Correct the child node and continue parsing attributes.
      prevAttr.setDecls(currentAttr);
      prevAttr = currentAttr; // Current becomes previous.
    }

    // Parse the declaration.
    Declaration decl;
    assert(this.storageClass == StorageClass.None);
    assert(this.protection == Protection.None);
    assert(this.linkageType == LinkageType.None);
    if (token.kind.Any!("class", "interface", "struct", "union", "alias",
        "typedef", "enum"))
    {
      // Set current values.
      this.storageClass = stcs;
      this.linkageType = linkageType;
      // Parse a declaration.
      decl = parseDeclarationDefinition();
      // Clear values.
      this.storageClass = StorageClass.None;
      this.linkageType = LinkageType.None;
    }
    else
      decl =
        parseVariablesOrFunction(stcs, protection, linkageType, testAutoDecl);
    assert(decl !is null && isNodeSet(decl));
    // Attach the declaration to the previously parsed attribute.
    prevAttr.setDecls(decl);
    // Return the first attribute declaration. Wrap it in a Statement.
    return new DeclarationStmt(headAttr.decls);
  }

  /// $(BNF IfStmt    := if "(" Condition ")" ScopeStmt (else ScopeStmt)?
  ////Condition := AutoDecl | VariableDecl | Expression)
  Statement parseIfStmt()
  {
    skip!"if";
    auto paren = requireOpening!"(";

    Declaration variable;
    Expression condition;
    Type type;
    Token* name;
    auto begin = token; // For start of AutoDecl or normal Declaration.
    bool success;

    tryToParse({
      if (consumed!"auto") // auto Identifier = Expression
        name = requireIdentifier(MID.ExpectedVariableName);
      else // Declarator "=" Expression
        type = parseDeclarator(name);
      require!"=";
      return type;
    }, success);

    if (success)
    {
      auto init = parseExpression();
      variable = new VariablesDecl(type, [name], [init]);
      set(variable, begin);
    }
    else // Normal Expression.
      condition = parseExpression();

    requireClosing!")"(paren);
    auto ifBody = parseScopeStmt();
    auto elseBody = consumed!"else" ? parseScopeStmt() : null;
    return new IfStmt(variable, condition, ifBody, elseBody);
  }

  /// $(BNF WhileStmt := while "(" Expression ")" ScopeStmt)
  Statement parseWhileStmt()
  {
    skip!"while";
    auto paren = requireOpening!"(";
    auto condition = parseExpression();
    requireClosing!")"(paren);
    return new WhileStmt(condition, parseScopeStmt());
  }

  /// $(BNF DoWhileStmt := do ScopeStmt while "(" Expression ")")
  Statement parseDoWhileStmt()
  {
    skip!"do";
    auto doBody = parseScopeStmt();
    require!"while";
    auto paren = requireOpening!"(";
    auto condition = parseExpression();
    requireClosing!")"(paren);
    version(D2)
    require2!";";
    return new DoWhileStmt(condition, doBody);
  }

  /// $(BNF ForStmt :=
  ////  for "(" (NoScopeStmt | ";") Expression? ";" Expression? ")"
  ////    ScopeStmt)
  Statement parseForStmt()
  {
    skip!"for";
    auto paren = requireOpening!"(";
    auto init = !consumed!";" ? parseNoScopeStmt() : null;
    auto condition = !tokenIs!";" ? parseExpression() : null;
    require2!";";
    auto increment = !tokenIs!")" ? parseExpression() : null;
    requireClosing!")"(paren);
    auto forBody = parseScopeStmt();
    return new ForStmt(init, condition, increment, forBody);
  }

  /// $(BNF ForeachStmt :=
  ////  Foreach "(" ForeachVarList ";" Aggregate ")"
  ////    ScopeStmt
  ////Foreach        := foreach | foreach_reverse
  ////ForeachVarList := ForeachVar ("," ForeachVar)*
  ////ForeachVar     := ref? (Identifier | Declarator)
  ////RangeExpr2     := Expression ".." Expression # D2
  ////Aggregate      := RangeExpr2 | Expression)
  Statement parseForeachStmt()
  {
    assert(token.kind.Any!("foreach", "foreach_reverse"));
    auto kind = consume().kind;
    auto params = new Parameters;
    auto paren = requireOpening!"(";
    auto paramsBegin = token;
    do
    {
      auto paramBegin = token;
      StorageClass stcs, stc;
      Type type;
      Token* name, stctok;

    Lswitch:
      switch (token.kind)
      {
      version(D2)
      {
      case T!"const", T!"immutable", T!"inout", T!"shared":
        if ((stc = getSTC()) == 0)
          goto default;
        goto Lcommon;
      case T!"ref":
        stc = StorageClass.Ref;
      Lcommon:
        if (stcs & stc)
          error2(MID.RedundantStorageClass, token);
        stcs |= stc;
        stctok = token;
        nT();
        goto Lswitch;
      }
      version(D1)
      {
      case T!"inout", T!"ref":
        stcs = StorageClass.Ref;
        stctok = token;
        nT();
        // fall through
      }
      case T!"Identifier":
        if (peekNext().Any!(",", ";", ")"))
        { // (ref|const|...)? Identifier
          name = requireIdentifier(MID.ExpectedVariableName);
          break;
        }
        // fall through
      default: // (ref|const|...)? Declarator
        type = parseDeclarator(name);
      }

      params ~= set(new Parameter(stcs, stctok, type, name, null), paramBegin);
    } while (consumed!",");
    set(params, paramsBegin);

    require2!";";
    auto e = parseExpression();

    version(D2)
    if (auto op = consumedToken!"..") // Expression ".." Expression
      e = set(new RangeExpr(e, parseExpression(), op), e.begin);

    requireClosing!")"(paren);
    auto forBody = parseScopeStmt();
    return new ForeachStmt(kind, params, e, forBody);
  }

  /// $(BNF SwitchStmt := final? switch "(" Expression ")" ScopeStmt)
  Statement parseSwitchStmt()
  {
    bool isFinal = consumed!"final";
    skip!"switch";
    auto paren = requireOpening!"(";
    auto condition = parseExpression();
    requireClosing!")"(paren);
    auto switchBody = parseScopeStmt();
    return new SwitchStmt(condition, switchBody, isFinal);
  }

  /// Helper function for parsing the body of a default or case statement.
  /// $(BNF CaseOrDefaultBody := ScopeStmt*)
  Statement parseCaseOrDefaultBody()
  {
    // This function is similar to parseNoScopeStmt()
    auto begin = token;
    auto s = new CompoundStmt();
    while (!token.kind.Any!("case", "default", "}", "EOF"))
      s ~= parseStatement();
    if (begin is token) // Nothing consumed.
      begin = this.prevToken;
    set(s, begin);
    return set(new ScopeStmt(s), begin);
  }

  /// $(BNF CaseStmt := case ExpressionList ":" CaseOrDefaultBody |
  ////            case AssignExpr ":" ".." case AssignExpr ":" CaseOrDefaultBody)
  Statement parseCaseStmt()
  {
    skip!"case";
    auto values = parseExpressionList();
    require2!":";
    version(D2)
    if (consumed!"..")
    {
      if (values.length > 1)
        error(values[1].begin, MID.CaseRangeStartExpression);
      require!"case";
      Expression left = values[0], right = parseAssignExpr();
      require2!":";
      auto caseBody = parseCaseOrDefaultBody();
      return new CaseRangeStmt(left, right, caseBody);
    } // version(D2)
    auto caseBody = parseCaseOrDefaultBody();
    return new CaseStmt(values, caseBody);
  }

  /// $(BNF DefaultStmt := default ":" CaseOrDefaultBody)
  Statement parseDefaultStmt()
  {
    skip!"default";
    require2!":";
    auto defaultBody = parseCaseOrDefaultBody();
    return new DefaultStmt(defaultBody);
  }

  /// $(BNF ContinueStmt := continue Identifier? ";")
  Statement parseContinueStmt()
  {
    skip!"continue";
    auto ident = optionalIdentifier();
    require2!";";
    return new ContinueStmt(ident);
  }

  /// $(BNF BreakStmt := break Identifier? ";")
  Statement parseBreakStmt()
  {
    skip!"break";
    auto ident = optionalIdentifier();
    require2!";";
    return new BreakStmt(ident);
  }

  /// $(BNF ReturnStmt := return Expression? ";")
  Statement parseReturnStmt()
  {
    skip!"return";
    auto expr = !tokenIs!";" ? parseExpression() : null;
    require2!";";
    return new ReturnStmt(expr);
  }

  /// $(BNF
  ////GotoStmt := goto (case Expression? | default | Identifier) ";")
  Statement parseGotoStmt()
  {
    skip!"goto";
    auto ident = token;
    Expression caseExpr;
    switch (token.kind)
    {
    case T!"case":
      nT();
      if (tokenIs!";")
        break;
      caseExpr = parseExpression();
      break;
    case T!"default":
      nT();
      break;
    default:
      ident = requireIdentifier(MID.ExpectedAnIdentifier);
    }
    require2!";";
    return new GotoStmt(ident, caseExpr);
  }

  /// $(BNF WithStmt := with "(" Expression ")" ScopeStmt)
  Statement parseWithStmt()
  {
    skip!"with";
    auto paren = requireOpening!"(";
    auto expr = parseExpression();
    requireClosing!")"(paren);
    return new WithStmt(expr, parseScopeStmt());
  }

  /// $(BNF SynchronizedStmt := synchronized ("(" Expression ")")? ScopeStmt)
  Statement parseSynchronizedStmt()
  {
    skip!"synchronized";
    Expression expr;
    if (auto paren = consumedToken!"(")
    {
      expr = parseExpression();
      requireClosing!")"(paren);
    }
    return new SynchronizedStmt(expr, parseScopeStmt());
  }

  /// $(BNF TryStmt := try ScopeStmt CatchStmt* LastCatchStmt? FinallyStmt?
  ////CatchStmt     := catch "(" BasicType Identifier ")" NoScopeStmt
  ////LastCatchStmt := catch NoScopeStmt
  ////FinallyStmt   := finally NoScopeStmt)
  Statement parseTryStmt()
  {
    auto begin = token;
    skip!"try";

    auto tryBody = parseScopeStmt();
    CatchStmt[] catchBodies;
    FinallyStmt finBody;

    while (consumed!"catch")
    {
      auto catchBegin = prevToken;
      Parameter param;
      if (auto paren = consumedToken!"(")
      {
        auto paramBegin = token;
        Token* name;
        auto type = parseDeclaratorOptId(name);
        param = new Parameter(StorageClass.None, null, type, name, null);
        set(param, paramBegin);
        requireClosing!")"(paren);
      }
      catchBodies ~= set(new CatchStmt(param, parseNoScopeStmt()), catchBegin);
      if (param is null)
        break; // This is a LastCatch
    }

    if (auto t = consumedToken!"finally")
      finBody = set(new FinallyStmt(parseNoScopeStmt()), t);

    if (catchBodies is null && finBody is null)
      error(begin, MID.MissingCatchOrFinally);

    return new TryStmt(tryBody, catchBodies, finBody);
  }

  /// $(BNF ThrowStmt := throw Expression ";")
  Statement parseThrowStmt()
  {
    skip!"throw";
    auto expr = parseExpression();
    require2!";";
    return new ThrowStmt(expr);
  }

  /// $(BNF ScopeGuardStmt := scope "(" ScopeCondition ")" ScopeGuardBody
  ////ScopeCondition := "exit" | "success" | "failure"
  ////ScopeGuardBody := ScopeStmt | NoScopeStmt)
  Statement parseScopeGuardStmt()
  {
    skip!"scope";
    assert(tokenIs!"(");
    auto paren = consume();
    auto condition = requireIdentifier(MID.ExpectedScopeIdentifier);
    if (condition &&
        !condition.ident.In(Ident.exit, Ident.success, Ident.failure))
      error2(MID.InvalidScopeIdentifier, condition);
    requireClosing!")"(paren);
    auto scopeBody = tokenIs!"{" ? parseScopeStmt() : parseNoScopeStmt();
    return new ScopeGuardStmt(condition, scopeBody);
  }

  /// $(BNF VolatileStmt := volatile (ScopeStmt | NoScopeStmt))
  Statement parseVolatileStmt()
  {
    skip!"volatile";
    auto volatileBody = tokenIs!"{" ? parseScopeStmt() : parseNoScopeStmt();
    return new VolatileStmt(volatileBody);
  }

  /// $(BNF PragmaStmt :=
  ////  pragma "(" Identifier ("," ExpressionList)? ")" NoScopeStmt)
  Statement parsePragmaStmt()
  {
    skip!"pragma";
    auto paren = requireOpening!"(";
    auto name = requireIdentifier(MID.ExpectedPragmaIdentifier);
    auto args = consumed!"," ? parseExpressionList() : null;
    requireClosing!")"(paren);
    auto pragmaBody = parseNoScopeOrEmptyStmt();
    return new PragmaStmt(name, args, pragmaBody);
  }

  /// $(BNF StaticIfStmt :=
  ////  static if "(" Expression ")" NoScopeStmt (else NoScopeStmt)?)
  Statement parseStaticIfStmt()
  {
    skip!"static";
    skip!"if";
    auto paren = requireOpening!"(";
    auto condition = parseExpression();
    requireClosing!")"(paren);
    auto ifBody = parseNoScopeStmt();
    auto elseBody = consumed!"else" ? parseNoScopeStmt() : null;
    return new StaticIfStmt(condition, ifBody, elseBody);
  }

  /// $(BNF StaticAssertStmt :=
  ////  static assert "(" AssignExpr ("," Message)? ")" ";"
  ////Message := AssignExpr)
  Statement parseStaticAssertStmt()
  {
    skip!"static";
    skip!"assert";
    auto paren = requireOpening!"(";
    auto condition = parseAssignExpr();
    auto message = consumed!"," ? parseAssignExpr() : null;
    requireClosing!")"(paren);
    require2!";";
    return new StaticAssertStmt(condition, message);
  }

  /// $(BNF DebugStmt :=
  ////  debug DebugCondition? NoScopeStmt (else NoScopeStmt)?)
  Statement parseDebugStmt()
  {
    skip!"debug";
    Token* cond;
    if (auto paren = consumedToken!"(")
    { // ( Condition )
      cond = parseIdentOrInt();
      requireClosing!")"(paren);
    }
    auto debugBody = parseNoScopeStmt();
    auto elseBody = consumed!"else" ? parseNoScopeStmt() : null;
    return new DebugStmt(cond, debugBody, elseBody);
  }

  /// $(BNF VersionStmt :=
  ////  version VCondition NoScopeStmt (else NoScopeStmt)?)
  Statement parseVersionStmt()
  {
    skip!"version";
    auto paren = requireOpening!"(";
    auto cond = parseVersionCondition();
    requireClosing!")"(paren);
    auto versionBody = parseNoScopeStmt();
    auto elseBody = consumed!"else" ? parseNoScopeStmt() : null;
    return new VersionStmt(cond, versionBody, elseBody);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                        Assembler parsing methods                        |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// Parses an AsmBlockStmt.
  /// $(BNF AsmBlockStmt := asm "{" AsmStmt* "}")
  Statement parseAsmBlockStmt()
  {
    skip!"asm";
    auto brace = requireOpening!"{";
    auto ss = new CompoundStmt;
    while (!token.kind.Any!("}", "EOF"))
      ss ~= parseAsmStmt();
    requireClosing!"}"(brace);
    return new AsmBlockStmt(set(ss, brace));
  }

  /// $(BNF
  ////AsmStmt :=
  ////  OpcodeStmt | LabeledStmt | AsmAlignStmt | EmptyStmt
  ////OpcodeStmt   := Opcode Operands? ";"
  ////Opcode       := Identifier
  ////Operands     := AsmExpr ("," AsmExpr)*
  ////LabeledStmt  := Identifier ":" AsmStmt
  ////AsmAlignStmt := align Integer ";"
  ////EmptyStmt    := ";")
  Statement parseAsmStmt()
  {
    auto begin = token;
    Statement s;
    alias ident = begin;
    switch (token.kind)
    {
    case T!"in", T!"int", T!"out": // Keywords that are valid opcodes.
      nT();
      goto LparseOperands;
    case T!"Identifier":
      nT();
      if (consumed!":")
      { // Identifier ":" AsmStmt
        s = new LabeledStmt(ident, parseAsmStmt());
        break;
      }

      // JumpOpcode (short | (near | far) ptr)?
      if (Ident.isJumpOpcode(ident.ident.idKind))
        if (tokenIs!"short")
          nT();
        else if (tokenIs!"Identifier" && token.ident.In(Ident.near, Ident.far))
        {
          nT();
          if (tokenIs!"Identifier" && token.ident is Ident.ptr)
            skip!"Identifier";
          else
            error2(MID.ExpectedButFound, "ptr", token);
        }

      // TODO: Handle opcodes db, ds, di, dl, df, dd, de.
      //       They accept string operands.

    LparseOperands:
      // Opcode Operands? ";"
      Expression[] es;
      if (!tokenIs!";")
        do
          es ~= parseAsmExpr();
        while (consumed!",");
      require2!";";
      s = new AsmStmt(ident, es);
      break;
    case T!"align":
      // align Integer ";"
      nT();
      auto number = token;
      if (!consumed!"Int32")
        error2(MID.ExpectedIntegerAfterAlign, token);
      require2!";";
      s = new AsmAlignStmt(number);
      break;
    case T!";":
      s = new EmptyStmt();
      nT();
      break;
    default:
      s = new IllegalAsmStmt();
      // Skip to next valid token.
      do
        nT();
      while (!token.isAsmStatementStart() && !token.kind.Any!("}", "EOF"));
      auto text = begin.textSpan(this.prevToken);
      error(begin, MID.IllegalAsmStatement, text);
    }
    set(s, begin);
    return s;
  }

  /// $(BNF AsmExpr     := AsmCondExpr
  ////AsmCondExpr := AsmBinaryExpr ("?" AsmExpr ":" AsmExpr)?)
  Expression parseAsmExpr()
  {
    auto begin = token;
    auto e = parseAsmBinaryExpr();
    if (auto qtok = consumedToken!"?")
    {
      auto iftrue = parseAsmExpr();
      auto ctok = token; // ":"
      require!":";
      auto iffalse = parseAsmExpr();
      e = new CondExpr(e, iftrue, iffalse, qtok, ctok);
      set(e, begin);
    }
    // TODO: create AsmExpr that contains e?
    return e;
  }

  /// $(BNF AsmBinaryExpr := AsmOrOrExpr
  ////AsmOrOrExpr   := AsmAndAndExpr ("||" AsmAndAndExpr)*
  ////AsmAndAndExpr := AsmOrExpr  ("&&" AsmOrExpr)*
  ////AsmOrExpr     := AsmXorExpr ("|" AsmXorExpr)*
  ////AsmXorExpr    := AsmAndExpr ("^" AsmAndExpr)*
  ////AsmAndExpr    := AsmCmpExpr ("&" AsmCmpExpr)*
  ////AsmCmpExpr    := AsmShiftExpr (AsmCmpOp AsmShiftExpr)*
  ////AsmCmpOp      := "==" | "!=" | "<" | "<=" | ">" | ">="
  ////AsmShiftExpr  := AsmAddExpr (AsmShiftOp AsmAddExpr)*
  ////AsmShiftOp    := "<<" | ">>" | ">>>"
  ////AsmAddExpr    := AsmMulExpr (AsmAddOp AsmMulExpr)*
  ////AsmAddOp      := "+" | "-"
  ////AsmMulExpr    := AsmPostExpr (AsmMulOp AsmPostExpr)*
  ////AsmMulOp      := "*" | "/" | "%"
  ////)
  /// Params:
  ///   prevPrec = The precedence of the previous operator.
  Expression parseAsmBinaryExpr(PREC prevPrec = PREC.None)
  {
    auto begin = token;
    auto e = parseAsmPostExpr(); // Parse the left-hand side.

    NewBinaryExpr makeBinaryExpr = void;
    while (1)
    {
      auto operator = token;
      auto opPrec = parseBinaryOp(makeBinaryExpr, prevPrec);
      if (opPrec <= prevPrec) // Continue as long as the operators
        break;                // have higher precedence.
      if (prevToken.kind.Any!(/*"!", */"is", "in", "!<>=", "!<>", "!<=", "!<",
        "!>=", "!>", "<>=", "<>", "~", "^^"))
        // Use textSpan() for operators like "!is" and "!in".
        error(operator, MID.IllegalAsmBinaryOp, operator.textSpan(prevToken));
      auto rhs = parseAsmBinaryExpr(opPrec); // Parse the right-hand side.
      e = makeBinaryExpr(e, rhs, operator);
      set(e, begin);
    }
    return e;
  }

  /// $(BNF AsmPostExpr := AsmUnaryExpr ("[" AsmExpr "]")*)
  Expression parseAsmPostExpr()
  {
    Token* begin = token, bracket = void;
    auto e = parseAsmUnaryExpr();
    while ((bracket = consumedToken!"[") !is null)
    {
      e = new AsmPostBracketExpr(e, parseAsmExpr());
      requireClosing!"]"(bracket);
      set(e, begin);
    }
    return e;
  }

  /// $(BNF
  ////AsmUnaryExpr :=
  ////  AsmPrimaryExpr | AsmTypeExpr | AsmOffsetExpr | AsmSegExpr |
  ////  SignExpr | NotExpr | ComplementExpr
  ////AsmTypeExpr := TypePrefix "ptr" AsmExpr
  ////TypePrefix  := "byte" | "shor" | "int" | "float" | "double" | "real"
  ////               "near" | "far" | "word" | "dword" | "qword"
  ////AsmOffsetExpr  := "offset" AsmExpr
  ////AsmSegExpr     := "seg" AsmExpr
  ////SignExpr       := ("+" | "-") AsmUnaryExpr
  ////NotExpr        := "!" AsmUnaryExpr
  ////ComplementExpr := "~" AsmUnaryExpr
  ////)
  Expression parseAsmUnaryExpr()
  {
    auto begin = token;
    Expression e;
    switch (token.kind)
    {
    case T!"byte",  T!"short",  T!"int", T!"float", T!"double", T!"real":
      goto LAsmTypePrefix;
    case T!"Identifier":
      switch (token.ident.idKind)
      {
      case IDK.near, IDK.far,/* "byte",  "short",  "int",*/
           IDK.word, IDK.dword, IDK.qword/*, "float", "double", "real"*/:
      LAsmTypePrefix:
        nT();
        if (tokenIs!"Identifier" && token.ident is Ident.ptr)
          skip!"Identifier";
        else
          error2(MID.ExpectedButFound, "ptr", token);
        e = new AsmTypeExpr(begin, parseAsmExpr());
        break;
      case IDK.offsetof:
        nT();
        e = new AsmOffsetExpr(parseAsmExpr());
        break;
      case IDK.seg:
        nT();
        e = new AsmSegExpr(parseAsmExpr());
        break;
      default:
        goto LparseAsmPrimaryExpr;
      }
      break;
    case T!"-", T!"+":
      nT();
      e = new SignExpr(parseAsmUnaryExpr());
      break;
    case T!"!":
      nT();
      e = new NotExpr(parseAsmUnaryExpr());
      break;
    case T!"~":
      nT();
      e = new CompExpr(parseAsmUnaryExpr());
      break;
    default:
    LparseAsmPrimaryExpr:
      e = parseAsmPrimaryExpr();
      return e;
    }
    set(e, begin);
    return e;
  }

  /// $(BNF AsmPrimaryExpr :=
  ////  IntExpr | FloatExpr | DollarExpr |
  ////  AsmBracketExpr |AsmLocalSizeExpr | AsmRegisterExpr |
  ////  IdentifiersExpr
  ////IntExpr          := IntegerLiteral
  ////FloatExpr        := FloatLiteral
  ////DollarExpr       := "$"
  ////AsmBracketExpr   := "[" AsmExpr "]"
  ////AsmLocalSizeExpr := "__LOCAL_SIZE"
  ////AsmRegisterExpr  := ...)
  Expression parseAsmPrimaryExpr()
  {
    auto begin = token;
    Expression e;
    switch (token.kind)
    {
    case T!"Int32", T!"Int64", T!"UInt32", T!"UInt64":
      e = new IntExpr(token);
      nT();
      break;
    case T!"Float32", T!"Float64", T!"Float80",
         T!"IFloat32", T!"IFloat64", T!"IFloat80":
      e = new FloatExpr(token);
      nT();
      break;
    case T!"$":
      e = new DollarExpr();
      nT();
      break;
    case T!"[":
      // [ AsmExpr ]
      auto bracket = consume();
      e = parseAsmExpr();
      requireClosing!"]"(bracket);
      e = new AsmBracketExpr(e);
      break;
    case T!"Identifier":
      auto register = token;
      switch (register.ident.idKind)
      {
      // __LOCAL_SIZE
      case IDK.__LOCAL_SIZE:
        nT();
        e = new AsmLocalSizeExpr();
        break;
      // Register
      case IDK.ST:
        nT();
        Expression number; // (1) - (7)
        if (auto paren = consumedToken!"(")
          (number = parseAsmExpr()),
          requireClosing!")"(paren);
        e = new AsmRegisterExpr(register, number);
        break;
      case IDK.ES, IDK.CS, IDK.SS, IDK.DS, IDK.GS, IDK.FS:
        nT(); // Segment := XX (":" AsmExpr)?
        auto number = consumed!":" ? parseAsmExpr() : null;
        e = new AsmRegisterExpr(register, number);
        break;
      case IDK.AL, IDK.AH, IDK.AX, IDK.EAX,
           IDK.BL, IDK.BH, IDK.BX, IDK.EBX,
           IDK.CL, IDK.CH, IDK.CX, IDK.ECX,
           IDK.DL, IDK.DH, IDK.DX, IDK.EDX,
           IDK.BP, IDK.EBP, IDK.SP, IDK.ESP,
           IDK.DI, IDK.EDI, IDK.SI, IDK.ESI,
           IDK.CR0, IDK.CR2, IDK.CR3, IDK.CR4,
           IDK.DR0, IDK.DR1, IDK.DR2, IDK.DR3, IDK.DR6, IDK.DR7,
           IDK.TR3, IDK.TR4, IDK.TR5, IDK.TR6, IDK.TR7,
           IDK.MM0, IDK.MM1, IDK.MM2, IDK.MM3,
           IDK.MM4, IDK.MM5, IDK.MM6, IDK.MM7,
           IDK.XMM0, IDK.XMM1, IDK.XMM2, IDK.XMM3,
           IDK.XMM4, IDK.XMM5, IDK.XMM6, IDK.XMM7:
        nT();
        e = new AsmRegisterExpr(register);
        break;
      default:
        e = parseIdentifiersExpr();
      } // end of switch
      break;
    case T!".":
      e = parseIdentifiersExpr();
      break;
    default:
      error2(MID.ExpectedButFound, "Expression", token);
      nT();
      e = new IllegalExpr();
    }
    set(e, begin);
    return e;
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                       Expression parsing methods                        |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/


  /// Instantiates a function that returns a new binary expression.
  static Expression newBinaryExpr(E)(Expression l, Expression r, Token* op)
  {
    return new E(l, r, op);
  }
  /// The function signature of newBinaryExpr.
  alias NewBinaryExpr = Expression function(Expression, Expression, Token*);

  /// The root method for parsing an Expression.
  /// $(BNF Expression := CommaExpr
  ////CommaExpr := AssignExpr ("," AssignExpr)*)
  Expression parseExpression()
  {
    Token* begin = token, comma = void;
    auto e = parseAssignExpr();
    while ((comma = consumedToken!",") !is null)
      e = set(new CommaExpr(e, parseAssignExpr(), comma), begin);
    return e;
  }

  /// $(BNF AssignExpr := CondExpr (AssignOp AssignExpr)*
  ////AssignOp   := "=" | "<<=" | ">>=" | ">>>=" | "|=" | "&=" |
  ////              "+=" | "-=" | "/=" | "*=" | "%=" | "^=" | "~=" | "^^=")
  Expression parseAssignExpr()
  {
    auto begin = token;
    auto e = parseCondExpr();
    auto optok = token;
    NewBinaryExpr f = void;
    switch (optok.kind)
    {
    case T!"=":    f = &newBinaryExpr!(AssignExpr); goto Lcommon;
    case T!"<<=":  f = &newBinaryExpr!(LShiftAssignExpr); goto Lcommon;
    case T!">>=":  f = &newBinaryExpr!(RShiftAssignExpr); goto Lcommon;
    case T!">>>=": f = &newBinaryExpr!(URShiftAssignExpr); goto Lcommon;
    case T!"|=":   f = &newBinaryExpr!(OrAssignExpr); goto Lcommon;
    case T!"&=":   f = &newBinaryExpr!(AndAssignExpr); goto Lcommon;
    case T!"+=":   f = &newBinaryExpr!(PlusAssignExpr); goto Lcommon;
    case T!"-=":   f = &newBinaryExpr!(MinusAssignExpr); goto Lcommon;
    case T!"/=":   f = &newBinaryExpr!(DivAssignExpr); goto Lcommon;
    case T!"*=":   f = &newBinaryExpr!(MulAssignExpr); goto Lcommon;
    case T!"%=":   f = &newBinaryExpr!(ModAssignExpr); goto Lcommon;
    case T!"^=":   f = &newBinaryExpr!(XorAssignExpr); goto Lcommon;
    case T!"~=":   f = &newBinaryExpr!(CatAssignExpr); goto Lcommon;
    version(D2)
    {
    case T!"^^=":  f = &newBinaryExpr!(PowAssignExpr); goto Lcommon;
    }
    Lcommon:
      nT();
      // Parse the right-hand side and create the expression.
      e = f(e, parseAssignExpr(), optok);
      set(e, begin);
      break;
    default:
    }
    return e;
  }

  /// $(BNF CondExpr := BinaryExpr ("?" Expression ":" CondExpr)?)
  Expression parseCondExpr()
  {
    auto begin = token;
    auto e = parseBinaryExpr();
    if (auto qtok = consumedToken!"?")
    {
      auto iftrue = parseExpression();
      auto ctok = token; // ":"
      require!":";
      auto iffalse = parseCondExpr();
      e = new CondExpr(e, iftrue, iffalse, qtok, ctok);
      set(e, begin);
    }
    return e;
  }

  /// Enumeration of binary operator precedence values.
  enum PREC
  {
    None,  /// No precedence.
    OOr,   /// ||
    AAnd,  /// &&
    Or,    /// |
    Xor,   /// ^
    And,   /// &
    Cmp,   /// in !in is !is == != < > <= >= etc.
    Shift, /// << >> >>>
    Plus,  /// + - ~
    Mul,   /// * / %
    Pow,   /// ^^
  }

  /// Consumes the tokens of a binary operator.
  /// Params:
  ///   fn = Receives a function that creates the binary Expression.
  ///   prevPrec = The precedence value of the previous operator.
  /// Returns: The precedence value of the binary operator.
  ///   The higher the value the stronger the operator binds.
  PREC parseBinaryOp(out NewBinaryExpr fn, PREC prevPrec)
  {
    PREC p;
    NewBinaryExpr f;
    switch (token.kind)
    {
    case T!"!":
      auto next = peekNext();
      if (next == T!"is") // "!" is
        goto case T!"is";
      else version(D2) if (next == T!"in") // "!" in
        goto case T!"in";
      break; // Not a binary operator.
    case T!"||":  p = PREC.OOr;   f = &newBinaryExpr!(OrOrExpr); break;
    case T!"&&":  p = PREC.AAnd;  f = &newBinaryExpr!(AndAndExpr); break;
    case T!"|":   p = PREC.Or;    f = &newBinaryExpr!(OrExpr); break;
    case T!"^":   p = PREC.Xor;   f = &newBinaryExpr!(XorExpr); break;
    case T!"&":   p = PREC.And;   f = &newBinaryExpr!(AndExpr); break;
    case T!"is":  p = PREC.Cmp;   f = &newBinaryExpr!(IdentityExpr); break;
    case T!"in":  p = PREC.Cmp;   f = &newBinaryExpr!(InExpr); break;
    case T!"!=",
         T!"==":  p = PREC.Cmp;   f = &newBinaryExpr!(EqualExpr); break;
    case T!"<=", T!"<", T!">=", T!">", T!"!<>=", T!"!<>", T!"!<=", T!"!<",
         T!"!>=", T!"!>", T!"<>=", T!"<>":
                  p = PREC.Cmp;   f = &newBinaryExpr!(RelExpr); break;
    case T!"<<":  p = PREC.Shift; f = &newBinaryExpr!(LShiftExpr); break;
    case T!">>":  p = PREC.Shift; f = &newBinaryExpr!(RShiftExpr); break;
    case T!">>>": p = PREC.Shift; f = &newBinaryExpr!(URShiftExpr); break;
    case T!"+":   p = PREC.Plus;  f = &newBinaryExpr!(PlusExpr); break;
    case T!"-":   p = PREC.Plus;  f = &newBinaryExpr!(MinusExpr); break;
    case T!"~":   p = PREC.Plus;  f = &newBinaryExpr!(CatExpr); break;
    case T!"*":   p = PREC.Mul;   f = &newBinaryExpr!(MulExpr); break;
    case T!"/":   p = PREC.Mul;   f = &newBinaryExpr!(DivExpr); break;
    case T!"%":   p = PREC.Mul;   f = &newBinaryExpr!(ModExpr); break;
    version(D2)
    {
    case T!"^^":  p = PREC.Pow;   f = &newBinaryExpr!(PowExpr); break;
    }
    default:
    }
    if (p == prevPrec && p == PREC.Cmp)
      error(token, MID.CannotChainComparisonOps); // E.g.: a == b == c
    // Consume if we have a binary operator
    // and the precedence is greater than prevPrec.
    if (p > prevPrec)
    {
      assert(f !is null && p != PREC.None);
      fn = f;
      if (tokenIs!"!")
        nT(); // Consume "!" part.
      nT(); // Consume the binary operator.
    }
    return p;
  }

  /// Parses a binary operator expression.
  ///
  /// $(BNF BinaryExpr := OrOrExpr
  ////OrOrExpr   := AndAndExpr ("||" AndAndExpr)*
  ////AndAndExpr := OrExpr  ("&&" OrExpr)*
  ////OrExpr     := XorExpr ("|" XorExpr)*
  ////XorExpr    := AndExpr ("^" AndExpr)*
  ////AndExpr    := CmpExpr ("&" CmpExpr)*
  ////CmpExpr    := ShiftExpr (CmpOp ShiftExpr)?
  ////CmpOp      := "is" | "!" "is" | "in" | "==" | "!=" | "<" | "<=" | ">" |
  ////              ">=" | "!<>=" | "!<>" | "!<=" | "!<" |
  ////              "!>=" | "!>" | "<>=" | "<>"
  ////ShiftExpr  := AddExpr (ShiftOp AddExpr)*
  ////ShiftOp    := "<<" | ">>" | ">>>"
  ////AddExpr    := MulExpr (AddOp MulExpr)*
  ////AddOp      := "+" | "-" | "~"
  ////MulExpr    := PostExpr (MulOp PostExpr)*
  ////MulExpr2   := PowExpr  (MulOp PowExpr)* # D2
  ////MulOp      := "*" | "/" | "%"
  ////PowExpr    := PostExpr ("^^" PostExpr)* # D2
  ////)
  /// Params:
  ///   prevPrec = The precedence of the previous operator.
  /// Note: Uses the "precedence climbing" method as described here:
  /// $(LINK http://www.engr.mun.ca/~theo/Misc/exp_parsing.htm#climbing)
  Expression parseBinaryExpr(PREC prevPrec = PREC.None)
  {
    auto begin = token;
    auto e = parsePostExpr(); // Parse the left-hand side.

    NewBinaryExpr makeBinaryExpr = void;
    while (1)
    {
      auto operator = token;
      auto opPrec = parseBinaryOp(makeBinaryExpr, prevPrec);
      if (opPrec <= prevPrec) // Continue as long as the operators
        break;                // have higher precedence.
      auto rhs = parseBinaryExpr(opPrec); // Parse the right-hand side.
      e = makeBinaryExpr(e, rhs, operator);
      set(e, begin);
    }
    return e;
  }

  /// $(BNF PostExpr := UnaryExpr
  ////  (PostIdExpr | IncOrDecExpr | CallExpr | SliceExpr | IndexExpr)*
  ////PostIdExpr   := "." (NewExpr | IdentifierExpr)
  ////IncOrDecExpr := ("++" | "--")
  ////CallExpr     := "(" Arguments? ")"
  ////RangeExpr    := AssignExpr ".." AssignExpr
  ////SliceExpr    := "[" RangeExpr? "]")
  ////IndexExpr    := "[" ExpressionList "]")
  Expression parsePostExpr()
  {
    auto begin = token;
    auto e = parseUnaryExpr();
    while (1)
    {
      switch (token.kind)
      {
      case T!".":
        nT();
        e = tokenIs!"new" ? parseNewExpr(e) : parseIdentifierExpr(e);
        continue;
      case T!"++":
        e = new PostIncrExpr(e);
        break;
      case T!"--":
        e = new PostDecrExpr(e);
        break;
      case T!"(":
        e = new CallExpr(e, parseArguments());
        goto Lset;
      case T!"[":
        auto bracket = token;
        nT();
        // "[" "]" is the empty SliceExpr
        if (tokenIs!"]")
        {
          e = new SliceExpr(e, null);
          break;
        }
        auto e2 = parseAssignExpr();
        // "[" AssignExpr ".." AssignExpr "]"
        if (auto op = consumedToken!"..")
        {
          auto r = set(new RangeExpr(e2, parseAssignExpr(), op), e2.begin);
          e = new SliceExpr(e, r);
        }
        else
        { // "[" ExpressionList "]"
          auto index = [e2];
          if (consumed!",")
             index ~= parseExpressionList2(T!"]");
          e = new IndexExpr(e, index);
        }
        requireClosing!"]"(bracket);
        goto Lset;
      default:
        return e;
      }
      nT();
    Lset: // Jumped here to skip nT().
      set(e, begin);
    }
    assert(0);
  }

  /// $(BNF UnaryExpr := PrimaryExpr |
  ////  NewExpr | AddressExpr | PreIncrExpr |
  ////  PreDecrExpr | DerefExpr | SignExpr |
  ////  NotExpr | CompExpr | DeleteExpr |
  ////  CastExpr | TypeDotIdExpr
  ////AddressExpr   := "&" UnaryExpr
  ////PreIncrExpr   := "++" UnaryExpr
  ////PreDecrExpr   := "--" UnaryExpr
  ////DerefExpr     := "*" UnaryExpr
  ////SignExpr      := ("-" | "+") UnaryExpr
  ////NotExpr       := "!" UnaryExpr
  ////CompExpr      := "~" UnaryExpr
  ////DeleteExpr    := delete UnaryExpr
  ////CastExpr      := cast "(" Type? ")" UnaryExpr
  ////TypeDotIdExpr := "(" Type ")" "." Identifier
  ////TypeExpr      := Modifier Type)
  Expression parseUnaryExpr()
  {
    auto begin = token;
    Expression e;
    switch (token.kind)
    {
    case T!"&":
      nT();
      e = new AddressExpr(parseUnaryExpr());
      break;
    case T!"++":
      nT();
      e = new PreIncrExpr(parseUnaryExpr());
      break;
    case T!"--":
      nT();
      e = new PreDecrExpr(parseUnaryExpr());
      break;
    case T!"*":
      nT();
      e = new DerefExpr(parseUnaryExpr());
      break;
    case T!"-":
    case T!"+":
      nT();
      e = new SignExpr(parseUnaryExpr());
      break;
    case T!"!":
      nT();
      e = new NotExpr(parseUnaryExpr());
      break;
    case T!"~":
      nT();
      e = new CompExpr(parseUnaryExpr());
      break;
    case T!"new":
      e = parseNewExpr();
      return e;
    case T!"delete":
      nT();
      e = new DeleteExpr(parseUnaryExpr());
      break;
    case T!"cast":
      nT();
      auto paren = requireOpening!"(";
      Type type;
      switch (token.kind)
      {
      version(D2)
      {
      case T!")": // Mutable cast: cast "(" ")"
        break;
      case T!"const", T!"immutable", T!"inout", T!"shared":
        if (!nextIs!")")
          goto default; // ModParenType
        auto mod = consume();
        type = set(new ModifierType(mod), mod);
        break;
      } // version(D2)
      default:
       type = parseType();
      }
      requireClosing!")"(paren);
      e = new CastExpr(parseUnaryExpr(), type);
      break;
    case T!"(":
      if (!tokenAfterParenIs(T!"."))
        goto default;
      // "(" Type ")" "." Identifier
      bool success;
      auto type = tryToParse({
        skip!"(";
        auto type = parseType(); // Type
        require!")";
        require!".";
        return type;
      }, success);
      if (!success)
        goto default;
      auto ident = requireIdentifier(MID.ExpectedIdAfterTypeDot);
      e = new TypeDotIdExpr(type, ident);
      break;
    version(D2)
    {
    case T!"immutable", T!"const", T!"shared", T!"inout":
      e = new TypeExpr(parseType());
      break;
    }
    default:
      e = parsePrimaryExpr();
      return e;
    }
    assert(e !is null);
    set(e, begin);
    return e;
  }

  /// $(BNF IdentifiersExpr :=
  ////  ModuleScopeExpr? IdentifierExpr ("." IdentifierExpr)*
  ////ModuleScopeExpr := ".")
  Expression parseIdentifiersExpr()
  {
    Expression e;
    if (tokenIs!".")
      e = set(new ModuleScopeExpr(), token, token);
    else
      e = parseIdentifierExpr();
    while (consumed!".")
      e = parseIdentifierExpr(e);
    return e;
  }

  /// $(BNF IdentifierExpr   := Identifier | TemplateInstance
  ////TemplateInstance := Identifier "!" TemplateArgumentsOneOrMore)
  Expression parseIdentifierExpr(Expression next = null)
  {
    auto begin = token;
    auto ident = requireIdentifier(MID.ExpectedAnIdentifier);
    Expression e;
    // Peek to avoid parsing: "id !is Exp" or "id !in Exp"
    if (tokenIs!"!" && !peekNext().Any!("is", "in"))
    {
      skip!"!";
      // Identifier "!" "(" TemplateArguments? ")"
      // Identifier "!" TemplateArgumentSingle
      auto tparams = parseOneOrMoreTemplateArguments();
      e = new TmplInstanceExpr(ident, tparams, next);
    }
    else // Identifier
      e = new IdentifierExpr(ident, next);
    return set(e, begin);
  }

  /// $(BNF LambdaBody := AssignExpr)
  Expression parseLambdaExprBody()
  {
    skip!"=>";
    return parseAssignExpr();
  }

  /// $(BNF LambdaExpr := LambdaParams "=>" LambdaBody
  ////LambdaParams := Identifier | ParameterList ParamsPostfix)
  Expression parseSingleParamLambdaExpr()
  {
    auto begin = token;
    skip!"Identifier";
    auto params = set(new Parameters(), begin);
    auto param = new Parameter(StorageClass.None, null, null, begin, null);
    params ~= set(param, begin);
    auto fstmt = parseLambdaExprBody();
    return set(new LambdaExpr(params, fstmt), begin);
  }

  /// $(BNF PrimaryExpr := IdentifierExpr | ModuleScopeExpr |
  ////  LambdaExpr | TypeofExpr | ThisExpr | SuperExpr |
  ////  NullExpr | BoolExpr | DollarExpr | IntExpr | FloatExpr |
  ////  CharExpr | StringExpr | ArrayLiteralExpr | AArrayLiteralExpr |
  ////  FuncLiteralExpr | AssertExpr | MixinExpr | ImportExpr |
  ////  TypeidExpr | IsExpr | ParenExpr | TraitsExpr | TypeDotIdExpr |
  ////  SpecialTokenExpr
  ////TypeofExpr    := TypeofType
  ////ThisExpr      := this
  ////SuperExpr     := super
  ////NullExpr      := null
  ////BoolExpr      := true | false
  ////DollarExpr    := "$"
  ////IntExpr       := IntegerLiteral
  ////FloatExpr     := FloatLiteral
  ////CharExpr      := CharacterLiteral
  ////StringExpr    := StringLiteral+
  ////StringLiteral := NormalStringLiteral | EscapeStringLiteral |
  ////  RawStringLiteral | HexStringLiteral | DelimitedStringLiteral |
  ////  TokenStringLiteral
  ////ArrayLiteralExpr := "[" ExpressionList2 "]"
  ////AArrayLiteralExpr := "[" KeyValue ("," KeyValue)* ","? "]"
  ////KeyValue := (AssignExpr ":" AssignExpr)
  ////FuncLiteralExpr := (function | delegate)?
  ////  (ReturnType? ParameterList FunctionPostfix?)? "{" Statements "}"
  ////AssertExpr := assert "(" AssignExpr ("," AssignExpr)? ")"
  ////MixinExpr  := mixin "(" AssignExpr ")"
  ////ImportExpr := import "(" AssignExpr ")"
  ////TypeidExpr := typeid "(" Type ")"
  ////IsExpr := is "(" Declarator (Specialization TemplateParameterList2)? ")"
  ////Specialization := ((":" | "==") (SpecToken | Type))
  ////SpecToken := typedef | struct | union | class | interface | enum |
  ////  function | delegate | super | return |
  ////  const | immutable | inout | shared
  ////ParenExpr := "(" Expression ")"
  ////TraitsExpr := __traits "(" Identifier ("," TemplateArguments)? ")"
  ////TypeDotIdExpr := "(" Type ")" "." Identifier
  ////SpecialTokenExpr := SpecialToken)
  Expression parsePrimaryExpr()
  {
    auto begin = token;
    Expression e;
    switch (token.kind)
    {
    case T!"Identifier":
      e = nextIs!"=>" ? parseSingleParamLambdaExpr() : parseIdentifierExpr();
      return e;
    case T!"typeof":
      e = new TypeofExpr(parseTypeofType());
      break;
    case T!".":
      e = set(new ModuleScopeExpr(), begin, begin);
      nT();
      // parseIdentifiersExpr() isn't used; see case T!"." in parsePostExpr().
      e = parseIdentifierExpr(e);
      return e;
    case T!"this":
      e = new ThisExpr();
      goto LnT_and_return;
    case T!"super":
      e = new SuperExpr();
      goto LnT_and_return;
    case T!"null":
      e = new NullExpr();
      goto LnT_and_return;
    case T!"true", T!"false":
      e = new BoolExpr(token);
      goto LnT_and_return;
    case T!"$":
      e = new DollarExpr();
      goto LnT_and_return;
    case T!"Int32", T!"Int64", T!"UInt32", T!"UInt64":
      e = new IntExpr(token);
      goto LnT_and_return;
    case T!"Float32", T!"Float64", T!"Float80",
         T!"IFloat32", T!"IFloat64", T!"IFloat80":
      e = new FloatExpr(token);
      goto LnT_and_return;
    case T!"Character":
      e = new CharExpr(token);
      goto LnT_and_return;
    LnT_and_return:
      nT();
      assert(begin is prevToken);
      set(e, begin, begin);
      return e;
    case T!"String":
      auto str = token.strval.str;
      char postfix = token.strval.pf;
      nT();
      if (auto t = consumedToken!"String")
      { // Concatenate adjacent string literals.
        auto buffer = lexer.getBuffer();
        buffer ~= cast(cstring)str;
        do
        {
          if (auto pf = t.strval.pf) // If the string has a postfix char.
          {
            if (pf != postfix)
              error(t, MID.StringPostfixMismatch);
            postfix = pf;
          }
          buffer ~= cast(cstring)t.strval.str;
        } while((t = consumedToken!"String") !is null);
        str = cast(cbinstr)buffer[].dup; // Copy final string.
        lexer.setBuffer(buffer);
      }

      if (postfix)
      { // Check for UTF8 errors and if needed convert to UTF16 or UTF32.
        cbinstr function(cstring) conversionFunction =
          (postfix == 'c') ? x => cast(cbinstr)x :
          (postfix == 'w') ? x => cast(cbinstr)dil.Unicode.toUTF16(x) :
                             x => cast(cbinstr)dil.Unicode.toUTF32(x);
        if (!hasInvalidUTF8(str, begin))
          str = conversionFunction(cast(cstring)str);
      }

      // Did the value change due to conversion or multiple string literals?
      if (begin.strval.str !is str)
        str = lexer.lookupString(str); // Insert into table if so.

      e = new StringExpr(str, postfix);
      break;
    case T!"[":
      nT();
      Expression[] exprs;
      if (!tokenIs!"]")
        exprs = [parseAssignExpr()];
      if (consumed!":")
      { // "[" AssignExpr ":"
        Expression[] values;
        while (1)
        {
          values ~= parseAssignExpr();
          if (!consumed!"," || tokenIs!"]")
            break;
          exprs ~= parseAssignExpr(); // Keys
          require!":";
        }
        e = new AArrayLiteralExpr(exprs, values);
      }
      else
      { // "[" "]" | "[" AssignExpr
        if (consumed!",") // "," ExpressionList2
          exprs ~= parseExpressionList2(T!"]");
        e = new ArrayLiteralExpr(exprs);
      }
      requireClosing!"]"(begin);
      break;
    case T!"{":
      // DelegateLiteral := { Statements }
      e = new FuncLiteralExpr(parseFunctionBody());
      break;
    case T!"function", T!"delegate":
      // FunctionLiteral := ("function" | "delegate")
      //   ReturnType? "(" ArgumentList ")" FunctionPostfix? FunctionBody
      nT(); // Skip function or delegate keyword.
      Type returnType;
      Parameters parameters;
      if (!tokenIs!"{")
      {
        if (!tokenIs!"(") // Optional return type
          returnType = parseBasicTypes();
        parameters = parseParameterList();
        version(D2)
        parameters.postSTCs = parseFunctionPostfix();
      }
      auto funcBody = parseFunctionBody();
      e = new FuncLiteralExpr(begin, returnType, parameters, funcBody);
      break;
    case T!"assert":
      nT();
      require2!"(";
      e = parseAssignExpr();
      auto msg = consumed!"," ? parseAssignExpr() : null;
      require2!")";
      e = new AssertExpr(e, msg);
      break;
    case T!"mixin":
      nT();
      require2!"(";
      e = new MixinExpr(parseAssignExpr());
      require2!")";
      break;
    case T!"import":
      nT();
      require2!"(";
      e = new ImportExpr(parseAssignExpr());
      require2!")";
      break;
    case T!"typeid":
      nT();
      require2!"(";
      e = new TypeidExpr(parseType());
      require2!")";
      break;
    case T!"is":
      nT();
      auto paren = requireOpening!"(";

      Type specType;
      Token* ident; // optional Identifier
      Token* opTok, specTok;

      auto type = parseDeclaratorOptId(ident);

      if (token.kind.Any!(":", "=="))
      {
        opTok = token;
        nT();
        switch (token.kind)
        {
        case T!"typedef", T!"struct", T!"union", T!"class", T!"interface",
             T!"enum", T!"function", T!"delegate", T!"super", T!"return",
             T!"__argTypes", T!"__parameters":
        case_Const_Immutable_Inout_Shared: // D2
          specTok = token;
          nT();
          break;
        version(D2)
        {
        case T!"const", T!"immutable", T!"inout", T!"shared":
          if (peekNext().Any!(")", ","))
            goto case_Const_Immutable_Inout_Shared;
          goto default; // It's a type.
        } // version(D2)
        default:
          specType = parseType();
        }
      }

      TemplateParameters tparams;
      // "is" "(" DeclaratorOptId (":" | "==") TypeSpecialization ","
      //          TemplateParameterList ")"
      version(D2)
      if (specType && tokenIs!",")
        tparams = parseTemplateParameterList2();
      requireClosing!")"(paren);
      e = new IsExpr(type, ident, opTok, specTok, specType, tparams);
      break;
    case T!"(":
      auto kind = skipParens(token, T!")").kind;
      if (kind.Any!(FunctionPostfix, "{", "=>")) // E.g.: "(" int "a" ")" pure
      {
        auto parameters = parseParameterList(); // "(" ParameterList ")"
        parameters.postSTCs = parseFunctionPostfix(); // Optional attributes.
        FuncBodyStmt fstmt;
        if (tokenIs!"{") // "(" ... ")" "{" ...
          fstmt = parseFunctionBody();
        else if (tokenIs!"=>") // "(" ... ")" "=>" ...
        {
          e = new LambdaExpr(parameters, parseLambdaExprBody());
          break;
        }
        else
          error(token, MID.ExpectedFunctionBody, token.text);
        e = new FuncLiteralExpr(parameters, fstmt);
      }
      else
      { // "(" Expression ")"
        auto paren = token;
        skip!"(";
        e = parseExpression();
        requireClosing!")"(paren);
        e = new ParenExpr(e);
      }
      break;
    version(D2)
    {
    case T!"__traits":
      nT();
      auto paren = requireOpening!"(";
      auto ident = requireIdentifier(MID.ExpectedAnIdentifier);
      auto args = consumed!"," ? parseTemplateArguments2() : null;
      requireClosing!")"(paren);
      e = new TraitsExpr(ident, args);
      break;
    } // version(D2)
    default:
      if (token.isIntegralType)
      { // IntegralType . Identifier
        auto type = new IntegralType(token.kind);
        nT();
        set(type, begin);
        require2!".";
        auto ident = requireIdentifier(MID.ExpectedIdAfterTypeDot);
        e = new TypeDotIdExpr(type, ident);
      }
      else if (token.isSpecialToken)
        e = new SpecialTokenExpr(consume());
      else
      {
        error2(MID.ExpectedButFound, "Expression", token);
        nT();
        e = new IllegalExpr();
      }
    }
    set(e, begin);
    return e;
  }

  /// $(BNF NewExpr := NewAnonClassExpr | NewObjectExpr
  ////NewAnonClassExpr :=
  ////  new NewArguments? class NewArguments?
  ////  (SuperClass InterfaceClasses)? ClassBody
  ////NewObjectExpr := new NewArguments? Type (NewArguments | NewArray)?
  ////NewArguments  := "(" ArgumentList ")"
  ////NewArray      := "[" AssignExpr "]")
  /// Params:
  ///   frame = The frame or 'this' pointer expression.
  Expression parseNewExpr(Expression frame = null)
  {
    auto begin = token;
    skip!"new";

    Expression e;
    Expression[] ctorArguments;

    auto newArguments = tokenIs!"(" ?  parseArguments() : null;

    if (consumed!"class")
    { // NewAnonymousClassExpr
      if (tokenIs!"(")
        ctorArguments = parseArguments();
      auto bases = !tokenIs!"{" ? parseBaseClasses() : null;
      auto decls = parseDeclarationDefinitionsBody();
      e = new NewClassExpr(frame, newArguments, ctorArguments, bases, decls);
    }
    else
    { // NewObjectExpr
      auto type = parseType();

      if (type.Is!(ModifierType))
      { // Skip modifier types in the chain and search for an ArrayType.
        auto t = type;
        while ((t = t.next).Is!(ModifierType))
        {}
        if (auto at = t.Is!(ArrayType))
          if (at.isStatic() || at.isAssociative())
          {
            at.parent.setNext(at.next); // Link it out.
            at.setNext(type); // Make it the head type.
            type = at;
          }
      }

      // Don't parse arguments if an array type was parsed previously.
      auto arrayType = type.Is!(ArrayType);
      if (arrayType && arrayType.isStatic())
      {}
      else if (arrayType && arrayType.isAssociative())
      { // Backtrack to parse as a StaticArray.
        auto bracket = type.begin;
        backtrackTo(bracket);

        skip!"[";
        auto index = parseExpression();
        requireClosing!"]"(bracket);
        type = set(new ArrayType(type.next, index), bracket);
      }
      else if (tokenIs!"(") // NewArguments
        ctorArguments = parseArguments();
      e = new NewExpr(frame, newArguments, type, ctorArguments);
    }
    return set(e, begin);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                          Type parsing methods                           |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// Parses a Declarator with an optional Identifier.
  ///
  /// $(BNF DeclaratorOptId := Type (Identifier DeclaratorSuffix)?)
  /// Params:
  ///   ident = Receives the optional identifier of the declarator.
  Type parseDeclaratorOptId(ref Token* ident)
  {
    auto type = parseType();
    ident = optionalIdentifier();
    if (ident)
      type = parseDeclaratorSuffix(type);
    return type;
  }

  /// Parses a Declarator with an Identifier.
  ///
  /// $(BNF Declarator := Type Identifier DeclaratorSuffix)
  /// Params:
  ///   ident = Receives the identifier of the declarator.
  Type parseDeclarator(ref Token* ident)
  {
    auto type = parseDeclaratorOptId(ident);
    if (!ident)
      error2(MID.ExpectedDeclaratorIdentifier, token);
    return type;
  }

  /// Parses a full Type.
  ///
  /// $(BNF Type := ModAttrType | BasicTypes
  ////ModAttrType := Modifier Type
  ////Modifier := const | immutable | shared | inout)
  Type parseType()
  {
    version(D2)
    if (!nextIs!"(" && token.kind.Any!("const", "immutable", "inout", "shared"))
    {
      auto mod = consume();
      return set(new ModifierType(parseType(), mod, false), mod);
    }
    return parseBasicTypes();
  }

  /// Parses the basic types.
  ///
  /// $(BNF BasicTypes := BasicType BasicType2)
  Type parseBasicTypes()
  {
    return parseBasicType2(parseBasicType());
  }

  /// $(BNF IdentifierType := Identifier | TemplateInstance)
  Type parseIdentifierType(Type next = null)
  {
    auto begin = token;
    auto ident = requireIdentifier(MID.ExpectedAnIdentifier);
    auto t =  consumed!"!" ?
      new TmplInstanceType(next, ident, parseOneOrMoreTemplateArguments()) :
      new IdentifierType(next, ident);
    return set(t, begin);
  }

  /// $(BNF TypeofType   := typeof "(" Expression ")" | TypeofReturn
  ////TypeofReturn := typeof "(" return ")")
  Type parseTypeofType()
  {
    auto begin = token;
    skip!"typeof";
    auto paren = requireOpening!"(";
    version(D1)
    auto e = parseExpression();
    else
    auto e = consumed!"return" ? null : parseExpression();
    requireClosing!")"(paren);
    return set(new TypeofType(e), begin);
  }

  /// $(BNF QualifiedType :=
  //// (this | super | TypeofType | ModuleScopeType? IdentifierType)
  //// ("." IdentifierType)*)
  Type parseQualifiedType()
  {
    auto begin = token;
    Type type;

    if (tokenIs!".")
      type = set(new ModuleScopeType(), begin, begin);
    else if (tokenIs!"typeof")
      type = parseTypeofType();
    else if (token.kind.Any!("this", "super")) // D2
      type = set(new IdentifierType(null, consume()), begin, begin);
    else
      type = parseIdentifierType();

    while (consumed!".")
      type = parseIdentifierType(type);

    return type;
  }

  /// $(BNF BasicType := IntegralType | QualifiedType | ModParenType
  ////ModParenType := Modifier "(" Type ")")
  Type parseBasicType()
  {
    auto begin = token;
    Type t;

    if (token.isIntegralType)
    {
      t = new IntegralType(token.kind);
      nT();
    }
    else
    switch (token.kind)
    {
    version (D2)
    {
    case T!"this", T!"super":
    }
    case T!"Identifier", T!"typeof", T!".":
      t = parseQualifiedType();
      return t;
    version(D2)
    { // Modifier "(" Type ")"
    case T!"const", T!"immutable", T!"inout", T!"shared":
      auto kind = consume();
      auto paren = requireOpening!"(";
      t = parseType(); // Type
      requireClosing!")"(paren);
      t = new ModifierType(t, kind, true);
      break;
    } // version(D2)
    default:
      error2(MID.ExpectedButFound, "BasicType", token);
      t = new IllegalType();
      nT();
    }
    return set(t, begin);
  }

  /// $(BNF BasicType2   :=
  ////  (PointerType | ArrayType | FunctionType | DelegateType)*
  ////PointerType  := "*"
  ////FunctionType := function ParameterList
  ////DelegateType := delegate ParameterList)
  Type parseBasicType2(Type t)
  {
    while (1)
    {
      auto begin = token;
      switch (token.kind)
      {
      case T!"*":
        t = new PointerType(t);
        nT();
        break;
      case T!"[":
        t = parseArrayType(t);
        continue;
      case T!"function", T!"delegate":
        auto kind = consume().kind;
        auto parameters = parseParameterList();
        version(D2)
        parameters.postSTCs = parseFunctionPostfix();
        // TODO: add stcs to t.
        if (kind == T!"function")
          t = new FunctionType(t, parameters);
        else
          t = new DelegateType(t, parameters);
        break;
      default:
        return t;
      }
      set(t, begin);
    }
    assert(0);
  }

  /// Parses the array types after the declarator (C-style.) E.g.: int a[]
  ///
  /// $(BNF DeclaratorSuffix := ArrayType*)
  /// Returns: lhsType or a suffix type.
  /// Params:
  ///   lhsType = The type on the left-hand side.
  Type parseDeclaratorSuffix(Type lhsType)
  { // The Type chain should be as follows:
    // int[3]* Identifier [][1][2]
    //   <– <–.      ·start·–> -.
    //         `---------------´
    // Resulting chain: [][1][2]*[3]int
    auto result = lhsType; // Return lhsType if nothing else is parsed.
    if (tokenIs!"[")
    { // The previously parsed ArrayType.
      auto prevType = result = parseArrayType(lhsType);
      // Continue parsing ArrayTypes.
      while (tokenIs!"[")
      {
        auto arrayType = parseArrayType(lhsType);
        prevType.setNext(arrayType); // Make prevType point to this type.
        prevType = arrayType; // Current type becomes previous type.
      }
    }
    return result;
  }

  /// $(BNF ArrayType := "[" (Type | ArrayTypeIndex) "]"
  ////ArrayTypeIndex := AssignExpr (".." AssignExpr)?)
  Type parseArrayType(Type t)
  {
    auto begin = token;
    skip!"[";
    if (consumed!"]")
      t = new ArrayType(t);
    else
    {
      bool success;
      Type parseAAType()
      {
        auto type = parseType();
        require!"]";
        return type;
      }
      auto assocType = tryToParse(&parseAAType, success);
      if (success)
        t = new ArrayType(t, assocType);
      else
      {
        auto e = parseAssignExpr();
        auto e2 = consumed!".." ? parseAssignExpr() : null;
        requireClosing!"]"(begin);
        t = new ArrayType(t, e, e2);
      }
    }
    return set(t, begin);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                        Parameter parsing methods                        |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// Parses a list of AssignExpressions.
  /// $(BNF ExpressionList := AssignExpr ("," AssignExpr)*)
  Expression[] parseExpressionList()
  {
    Expression[] expressions;
    do
      expressions ~= parseAssignExpr();
    while (consumed!",");
    return expressions;
  }

  /// Parses an optional ExpressionList and allows a trailing comma.
  /// $(BNF ExpressionList2 := (ExpressionList ","?)? )
  Expression[] parseExpressionList2(TOK closing_tok)
  {
    Expression[] expressions;
    while (token.kind != closing_tok)
    {
      expressions ~= parseAssignExpr();
      if (!consumed!",")
        break;
    }
    return expressions;
  }

  /// Parses a list of Arguments.
  /// $(BNF Arguments := "(" ExpressionList2 ")")
  Expression[] parseArguments()
  {
    auto paren = token;
    skip!"(";
    auto args = !tokenIs!")" ? parseExpressionList2(T!")") : null;
    requireClosing!")"(paren);
    return args;
  }

  /// Parses a ParameterList.
  /// $(BNF ParameterList := "(" Parameters? ")"
  ////Parameters := Parameter ("," Parameter)* ","?
  ////Parameter  := StorageClasses? (Type Name? | Type? Name )
  ////              ("=" AssignExpr)?)
  Parameters parseParameterList()
  {
    auto paren = requireOpening!"(";
    auto params = new Parameters();

    Expression defValue; // Default value.

    while (!tokenIs!")")
    {
      auto paramBegin = token;
      StorageClass stcs, stc; // Storage classes.
      Token* stctok; // Token of the last storage class.
      Type type; // Type of the parameter.
      Token* name; // Name of the parameter.

      void pushParameter()
      { // Appends a new Parameter to the list.
        auto param = new Parameter(stcs, stctok, type, name, defValue);
        params ~= set(param, paramBegin);
      }

      if (consumed!"...")
        goto LvariadicParam; // Go to common code and leave the loop.

      while (1)
      { // Parse storage classes.
        switch (token.kind)
        {
        version(D2)
        {
        case T!"const", T!"immutable", T!"inout", T!"shared":
          if ((stc = getSTC) == 0)
            break;
          goto Lcommon;
        case T!"final":  stc = StorageClass.Final;  goto Lcommon;
        case T!"scope":  stc = StorageClass.Scope;  goto Lcommon;
        case T!"static": stc = StorageClass.Static; goto Lcommon;
        case T!"auto":   stc = StorageClass.Auto;   goto Lcommon;
        } // version(D2)
        case T!"in":     stc = StorageClass.In;     goto Lcommon;
        case T!"out":    stc = StorageClass.Out;    goto Lcommon;
        version (D1)
        {
        case T!"inout":
        }
        case T!"ref":    stc = StorageClass.Ref;    goto Lcommon;
        case T!"lazy":   stc = StorageClass.Lazy;   goto Lcommon;
        Lcommon:
          // Check for redundancy.
          if (stcs & stc)
            error2(MID.RedundantStorageClass, token);
          stcs |= stc;
          stctok = token;
          nT();
        version(D2)
          continue;
        else
          break; // In D1.0 the grammar only allows one storage class.
        default:
        }
        break; // Break out of inner loop.
      }
      type = parseDeclaratorOptId(name);

      if (consumed!"=")
        defValue = parseAssignExpr();
      else if (defValue !is null) // Parsed a defValue previously?
        error(name ? name : type.begin, // Position.
          MID.ExpectedParamDefValue,
          name ? name.text : ""); // Name.

      if (consumed!"...")
      {
        if (stcs & (StorageClass.Ref | StorageClass.Out))
          error(paramBegin, MID.IllegalVariadicParam);
      LvariadicParam:
        stcs |= StorageClass.Variadic;
        pushParameter();
        // TODO: allow trailing comma here? DMD doesn't...
        if (!tokenIs!")")
          error(token, MID.ParamsAfterVariadic);
        break;
      }
      // Add a non-variadic parameter to the list.
      pushParameter();

      if (!consumed!",")
        break;
    }
    requireClosing!")"(paren);
    return set(params, paren);
  }

  /// $(BNF TemplateArgumentsOneOrMore :=
  ////  TemplateArgumentList | TemplateArgumentSingle)
  TemplateArguments parseOneOrMoreTemplateArguments()
  {
    version(D2)
    if (!tokenIs!"(")
    { // Parse one TArg, but still put it in TemplateArguments.
      auto targs = new TemplateArguments;
      auto begin = token;
      bool success;
      // Don't parse a full Type. TODO: restrict further?
      auto typeArg = tryToParse(&parseBasicType, success);
      // Don't parse a full Expression. TODO: restrict further?
      targs ~= success ? typeArg : parsePrimaryExpr();
      return set(targs, begin);
    } // version(D2)
    return parseTemplateArguments();
  }

  /// $(BNF TemplateArgumentList := "(" TemplateArguments? ")")
  TemplateArguments parseTemplateArguments()
  {
    TemplateArguments targs;
    auto paren = requireOpening!"(";
    targs = !tokenIs!")" ? parseTemplateArguments_() : new TemplateArguments;
    requireClosing!")"(paren);
    return set(targs, paren);
  }

  /// $(BNF TemplateArgumentList2 := TemplateArguments (?= "$(RP)"))
  TemplateArguments parseTemplateArguments2()
  {
    version(D2)
    {
    TemplateArguments targs;
    if (!tokenIs!")")
      targs = parseTemplateArguments_();
    else
      error(token, MID.ExpectedTypeOrExpression);
    return targs;
    } // version(D2)
    else
    assert(0);
  }

  /// Used with method tryToParse().
  /// $(BNF TypeArgument := Type (?= "," | "$(RP)"))
  Type parseTypeArgument()
  {
    assert(trying);
    auto type = parseType();
    if (token.kind.Any!(",", ")"))
      return type;
    fail_tryToParse();
    return null;
  }

  /// $(BNF TemplateArguments := TemplateArgument ("," TemplateArgument)*
  ////TemplateArgument  := TypeArgument | AssignExpr)
  TemplateArguments parseTemplateArguments_()
  {
    auto begin = token;
    auto targs = new TemplateArguments;
    while (!tokenIs!")")
    {
      bool success;
      auto typeArgument = tryToParse(&parseTypeArgument, success);
      // TemplateArgument := Type | AssignExpr
      targs ~= success ? typeArgument : parseAssignExpr();
      if (!consumed!",")
        break;
    }
    set(targs, begin);
    return targs;
  }

  /// $(BNF Constraint := if "(" ConstraintExpr ")")
  Expression parseOptionalConstraint()
  {
    if (!consumed!"if")
      return null;
    auto paren = requireOpening!"(";
    auto e = parseExpression();
    requireClosing!")"(paren);
    return e;
  }

  /// $(BNF TemplateParameterList := "(" TemplateParameters? ")")
  TemplateParameters parseTemplateParameterList()
  {
    auto tparams = new TemplateParameters;
    auto paren = requireOpening!"(";
    if (!tokenIs!")")
      parseTemplateParameterList_(tparams);
    requireClosing!")"(paren);
    return set(tparams, paren);
  }

  /// $(BNF TemplateParameterList2 := "," TemplateParameters "$(RP)")
  TemplateParameters parseTemplateParameterList2()
  {
  version(D2)
  {
    skip!",";
    auto begin = token;
    auto tparams = new TemplateParameters;
    if (!tokenIs!")")
      parseTemplateParameterList_(tparams);
    else
      error(token, MID.ExpectedTemplateParameters);
    return set(tparams, begin);
  } // version(D2)
  else return null;
  }

  /// Parses template parameters.
  /// $(BNF TemplateParameters := TemplateParam ("," TemplateParam)*
  ////TemplateParam      :=
  ////  TemplateAliasParam | TemplateTypeParam | TemplateTupleParam |
  ////  TemplateValueParam | TemplateThisParam
  ////TemplateAliasParam := alias Identifier SpecOrDefaultType
  ////TemplateTypeParam  := Identifier SpecOrDefaultType
  ////TemplateTupleParam := Identifier "..."
  ////TemplateValueParam := Declarator SpecOrDefaultValue
  ////TemplateThisParam  := this Identifier SpecOrDefaultType # D2.0
  ////SpecOrDefaultType  := (":" Type)? ("=" Type)?
  ////SpecOrDefaultValue := (":" Value)? ("=" Value)?
  ////Value := CondExpr
  ////)
  void parseTemplateParameterList_(TemplateParameters tparams)
  {
    while (!tokenIs!")")
    {
      auto paramBegin = token;
      TemplateParam tp;
      Token* ident;
      Type specType, defType;

      void parseSpecAndOrDefaultType()
      {
        if (consumed!":")  // ":" SpecializationType
          specType = parseType();
        if (consumed!"=") // "=" DefaultType
          defType = parseType();
      }

      switch (token.kind)
      {
      case T!"alias": // TemplateAliasParam := "alias" Identifier
        nT();
        ident = requireIdentifier(MID.ExpectedAliasTemplateParam);
        Node spec, def;
        version(D2)
        {
        Node parseExpOrType()
        {
          bool success;
          auto typeArgument = tryToParse(&parseTypeArgument, success);
          return success ? typeArgument : parseCondExpr();
        }
        if (consumed!":")  // ":" Specialization
          spec = parseExpOrType();
        if (consumed!"=") // "=" Default
          def = parseExpOrType();
        } // version(D2)
        else
        { // D1
        parseSpecAndOrDefaultType();
        spec = specType;
        def = defType;
        }
        tp = new TemplateAliasParam(ident, spec, def);
        break;
      case T!"Identifier":
        ident = token;
        switch (peekNext())
        {
        case T!"...": // TemplateTupleParam := Identifier "..."
          skip!"Identifier"; skip!"...";
          if (tokenIs!",")
            error(MID.TemplateTupleParameter);
          tp = new TemplateTupleParam(ident);
          break;
        case T!",", T!")", T!":", T!"=": // TemplateTypeParam := Identifier
          skip!"Identifier";
          parseSpecAndOrDefaultType();
          tp = new TemplateTypeParam(ident, specType, defType);
          break;
        default: // TemplateValueParam := Declarator
          ident = null;
          goto LTemplateValueParam;
        }
        break;
      version(D2)
      {
      case T!"this": // TemplateThisParam := "this" TemplateTypeParam
        nT();
        ident = requireIdentifier(MID.ExpectedNameForThisTempParam);
        parseSpecAndOrDefaultType();
        tp = new TemplateThisParam(ident, specType, defType);
        break;
      } // version(D2)
      default:
      LTemplateValueParam:
        // TemplateValueParam := Declarator
        auto valueType = parseDeclarator(ident);
        // ":" SpecializationValue
        auto specValue = consumed!":" ? parseCondExpr() : null;
        // "=" DefaultValue
        auto defValue = consumed!"=" ? parseCondExpr() : null;
        tp = new TemplateValueParam(valueType, ident, specValue, defValue);
      }

      // Push template parameter.
      tparams ~= set(tp, paramBegin);

      if (!consumed!",")
        break;
    }
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                          Error handling methods                         |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// Returns the string of a token printable to the client.
  cstring getPrintable(Token* token)
  { // TODO: there are some other tokens that have to be handled, e.g. strings.
    return token.kind == T!"EOF" ? "EOF" : token.text;
  }

  alias expected = require;

  /// Requires a token of kind T!str.
  void require(string str)()
  {
    if (!consumed!str)
      error2(MID.ExpectedButFound, str, token);
  }

  /// Requires a token of kind tok. Uses the token end as the error location.
  void require2(string str)()
  {
    if (!consumed!str)
      error2_eL(MID.ExpectedButFound, str, token);
  }

  /// Parses an optional identifier.
  /// Returns: null or the identifier.
  Token* optionalIdentifier()
  {
    return tokenIs!"Identifier" ? consume() : null;
  }

  /// Reports an error if the current token is not an identifier.
  /// Params:
  ///   mid = The error message ID to be used.
  /// Returns: The identifier token or null.
  Token* requireIdentifier(MID mid)
  {
    auto idtok = consumedToken!"Identifier";
    if (!idtok)
      error(token, mid, token.text);
    return idtok;
  }

  /// Returns the opening bracket or the current token.
  Token* requireOpening(string str)()
  {
    static assert(str.In("{", "(", "["), "invalid bracket");
    if (consumed!str)
      return prevToken;
    require2!str;
    return token;
  }

  /// Reports an error if the closing counterpart of a token is not found.
  void requireClosing(string str)(Token* opening)
  {
    static assert(str.In("}", ")", "]"), "invalid bracket");
    assert(opening !is null);
    if (!consumed!str)
    {
      auto loc = opening.getErrorLocation(lexer.srcText.filePath);
      error(token, MID.ExpectedClosing,
        str, opening.text, loc.lineNum, loc.colNum,
        getPrintable(token));
    }
  }

  /// Returns true if the string str has an invalid UTF-8 sequence.
  bool hasInvalidUTF8(cbinstr str, Token* begin)
  {
    auto invalidUTF8Seq = Lexer.findInvalidUTF8Sequence(str);
    if (invalidUTF8Seq.length)
      error(begin, MID.InvalidUTF8SequenceInString, invalidUTF8Seq);
    return invalidUTF8Seq.length != 0;
  }

  /// Forwards error parameters.
  void error(Token* token, MID mid, ...)
  {
    error(_arguments, _argptr, token, false, mid);
  }
  /// ditto
  void error(MID mid, ...)
  {
    error(_arguments, _argptr, this.token, false, mid);
  }
  /// ditto
  void error_eL(MID mid, ...)
  {
    error(_arguments, _argptr, this.prevToken, true, mid);
  }

  /// ditto
  void error2(MID mid, Token* token)
  {
    error(mid, getPrintable(token));
  }
  /// ditto
  void error2(MID mid, string arg, Token* token)
  {
    error(mid, arg, getPrintable(token));
  }
  /// ditto
  void error2_eL(MID mid, string arg, Token* token)
  {
    error_eL(mid, arg, getPrintable(token));
  }

  /// Creates an error report and appends it to a list.
  /// Params:
  ///   token = Used to get the location of the error.
  ///   endLoc = Get the position of the token's end or start character?
  ///   formatMsg = The parser error message.
  void error(TypeInfo[] _arguments, va_list _argptr,
             Token* token, bool endLoc, cstring formatMsg)
  {
    if (trying)
    {
      errorCount++;
      return;
    }
    auto filePath = lexer.srcText.filePath;
    auto location = endLoc ?
      token.errorLocationOfEnd(filePath) :
      token.getErrorLocation(filePath);
    auto msg = diag.format(_arguments, _argptr, formatMsg);
    auto error = new ParserError(location, msg);
    errors ~= error;
    diag ~= error;
  }
  /// ditto
  void error(TypeInfo[] _arguments, va_list _argptr,
             Token* token, bool endLoc, MID mid)
  {
    error(_arguments, _argptr, token, endLoc, diag.bundle.msg(mid));
  }
}

/// Returns true if x is in a list of TOK values.
bool Any(Xs...)(TOK x)
{
  return In(x, S2T!Xs);
}
