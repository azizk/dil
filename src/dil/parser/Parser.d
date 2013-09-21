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

import tango.core.Vararg;

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
    if (diag is null)
      diag = new Diagnostics();
    this.diag = diag;
    this.lexer = new Lexer(srcText, tables, diag);
  }

  /// Moves to the first token.
  protected void init()
  {
    nT();
    prevToken = token;
  }

  /// Moves to the next token.
  void nT()
  {
    prevToken = token;
    do
    {
      lexer.nextToken();
      token = lexer.token;
    } while (token.isWhitespace); // Skip whitespace
  }

  /// Starts the parser and returns the parsed Declarations.
  CompoundDecl start()
  {
    init();
    auto begin = token;
    auto decls = new CompoundDecl;
    if (tokenIs(T!"module"))
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
      lexer.token = oldToken;
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

  /// Backtracks the Parser and the Lexer to the given token(s).
  void backtrackTo(Token* newtok, Token* newprev = null)
  {
    this.lexer.token = this.token = newtok;
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

  /// Returns true if the current token is of a certain kind.
  bool tokenIs()(TOK kind)
  {
    return token.kind == kind;
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

  /// Consumes the current token if its kind matches k and returns true.
  bool consumed()(TOK k) // Templatized, so it's inlined.
  {
    return tokenIs(k) ? (nT(), true) : false;
  }

  /// Consumes the current token if its kind matches k and returns it.
  Token* consumedToken()(TOK k) // Templatized, so it's inlined.
  {
    return tokenIs(k) ? (nT(), prevToken) : null;
  }

  /// Asserts that the current token is of kind expectedKind,
  /// and then moves to the next token.
  void skip()(TOK expectedKind)
  {
    assert(tokenIs(expectedKind) /+|| *(int*).init+/, token.text);
    nT();
  }

  /// Returns true if the token after the closing parenthesis
  /// matches the searched kind.
  /// Params:
  ///   kind = The token kind to test for.
  bool tokenAfterParenIs(TOK kind)
  {
    assert(tokenIs(T!"("));
    return skipParens(token, T!")").kind == kind;
  }

  /// Returns the token kind behind the closing bracket.
  TOK tokenAfterBracket(TOK closing)
  {
    assert(tokenIs(T!"[") || tokenIs(T!"{"));
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
    skip(T!"module");
    ModuleFQN moduleFQN;
    Token* typeId;
    version(D2)
    {
    if (consumed(T!"("))
    {
      typeId = requireIdentifier(MID.ExpectedModuleType);
      auto ident = typeId ? typeId.ident : null;
      if (ident && ident !is Ident.safe && ident !is Ident.system)
        error(typeId, MID.ExpectedModuleType);
      require2(T!")");
    }
    } // version(D2)
    do
      moduleFQN ~= requireIdentifier(MID.ExpectedModuleIdentifier);
    while (consumed(T!"."));
    require2(T!";");
    return set(new ModuleDecl(typeId, moduleFQN), begin);
  }

  /// Parses DeclarationDefinitions until the end of file is hit.
  /// $(BNF DeclDefs := DeclDef*)
  Declaration[] parseDeclarationDefinitions()
  {
    Declaration[] decls;
    while (!tokenIs(T!"EOF"))
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
    auto begin = token;
    auto decls = new CompoundDecl;
    require(T!"{");
    while (!tokenIs(T!"}") && !tokenIs(T!"EOF"))
      decls ~= parseDeclarationDefinition();
    requireClosing(T!"}", begin);
    set(decls, begin);

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
    case T!"align",
         T!"pragma",
         // Protection attributes
         T!"export",
         T!"private",
         T!"package",
         T!"protected",
         T!"public",
         // Storage classes
         T!"extern",
         T!"deprecated",
         T!"override",
         T!"abstract",
         T!"synchronized",
         T!"auto",
         T!"scope",
         //T!"static",
         //T!"const",
         T!"final":
    version(D2)
    {
    case //T!"shared",
         T!"__gshared",
         //T!"immutable",
         //T!"inout",
         T!"ref",
         T!"pure",
         T!"nothrow",
         T!"__thread",
         T!"@":
    } // version(D2)
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
      case T!"import":
        goto case_Import;
      case T!"this":
        decl = parseStaticCtorDecl();
        break;
      case T!"~":
        decl = parseStaticDtorDecl();
        break;
      case T!"if":
        decl = parseStaticIfDecl();
        break;
      case T!"assert":
        decl = parseStaticAssertDecl();
        break;
      default:
        goto case_parseAttributes;
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
      if (peekNext() == T!"(")
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
      if (peekNext() == T!"(")
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
    //case T!"this":
    case T!"super":
    }
    case T!"Identifier", T!".", T!"typeof":
    case_Declaration:
      return parseVariablesOrFunction(this.storageClass, this.protection,
                                      this.linkageType);
    default:
      if (token.isIntegralType)
        goto case_Declaration;
      else if (tokenIs(T!"module"))
      {
        decl = parseModuleDecl();
        error(begin, MID.ModuleDeclarationNotFirst);
        return decl;
      }

      decl = new IllegalDecl();
      // Skip to next valid token.
      do
        nT();
      while (!token.isDeclDefStart() &&
             !tokenIs(T!"}") &&
             !tokenIs(T!"EOF"));
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
  Declaration parseDeclarationsBlock(/+bool noColon = false+/)
  {
    Declaration d;
    switch (token.kind)
    {
    case T!"{":
      auto begin = token;
      nT();
      auto decls = new CompoundDecl;
      while (!tokenIs(T!"}") && !tokenIs(T!"EOF"))
        decls ~= parseDeclarationDefinition();
      requireClosing(T!"}", begin);
      d = set(decls, begin);
      break;
    case T!":":
      // if (noColon == true)
      //   goto default;
      auto begin = token;
      nT();
      auto begin2 = token;
      auto decls = new CompoundDecl;
      while (!tokenIs(T!"}") && !tokenIs(T!"EOF"))
        decls ~= parseDeclarationDefinition();
      set(decls, begin2);
      d = set(new ColonBlockDecl(decls), begin);
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

  // Declaration parseDeclarationsBlockNoColon()
  // {
  //   return parseDeclarationsBlock(true);
  // }

  /// $(BNF
  ////AliasDecl := alias Attributes
  ////AliasThisDecl := alias Identifier this ";"
  ////AliasesDecl := alias AliasName "=" Type ("," AliasName "=" Type)* ";"
  ////AliasName := this | Identifier)
  Declaration parseAliasDecl()
  {
    skip(T!"alias");
    version (D2)
    {
    if (tokenIs(T!"Identifier") && peekNext() == T!"this")
    {
      auto ident = token;
      skip(T!"Identifier");
      skip(T!"this");
      require2(T!";");
      return new AliasThisDecl(ident);
    }
    else
    if ((tokenIs(T!"this") || tokenIs(T!"Identifier")) && peekNext() == T!"=")
    {
      Token*[] idents;
      TypeNode[] types;
      goto LenterLoop;

      while (consumed(T!","))
      {
        if (!(tokenIs(T!"this") || tokenIs(T!"Identifier")))
          error(token, MID.ExpectedAliasName, token.text);
      LenterLoop:
        idents ~= token;
        nT();
        require2(T!"=");
        types ~= parseType();
      }

      require2(T!";");
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
    if (testAutoDeclaration && tokenIs(T!"Identifier"))
    {
      auto next_kind = peekNext();
      if (next_kind == T!"=")
      { // AutoVariables
        name = token;
        skip(T!"Identifier");
        goto LparseVariables;
      }
      else version(D2) if (next_kind == T!"(")
      { // Check for AutoFunction.
        auto peek_token = peekAfter(token); // Skip the Identifier.
        peek_token = skipParens(peek_token, T!")");
        next_kind = peek_token.kind; // Token after "(" ... ")"
        if (next_kind == T!"(")
        { // TemplateParameterList ParameterList
          name = token;
          skip(T!"Identifier");
          assert(tokenIs(T!"("));
          goto LparseTPList; // Continue parsing templatized AutoFunction.
        }
        else
        if (next_kind == T!"{" || isFunctionPostfix(peek_token) ||
            next_kind == T!"in" || next_kind == T!"out" || next_kind == T!"body")
        { // ParameterList ("{" | FunctionPostfix | in | out | body)
          name = token;
          skip(T!"Identifier");
          assert(tokenIs(T!"("));
          goto LparseBeforeParams; // Continue parsing AutoFunction.
        }
      } // version(D2)
    }

    // VariableType or ReturnType
    type = parseBasicTypes();

    if (peekNext() == T!"(")
    { // ReturnType FunctionName "(" ParameterList ")" FunctionBody
      name = requireIdentifier(MID.ExpectedFunctionName);
      if (!tokenIs(T!"("))
        nT(); // Skip non-identifier token.

    LparseBeforeTParams:
      assert(tokenIs(T!"("));
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
    while (consumed(T!","))
    {
      names ~= requireIdentifier(MID.ExpectedVariableName);
    LenterLoop:
      values ~= consumed(T!"=") ? parseInitializer() : null;
    }
    require2(T!";");
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
    if (tokenIs(T!"void"))
    {
      auto next = peekNext();
      if (next == T!"," || next == T!";")
        return skip(T!"void"), set(new VoidInitExpr(), prevToken);
    }
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
      auto after_bracket = tokenAfterBracket(T!"]");
      if (after_bracket != T!"," && after_bracket != T!"]" &&
          after_bracket != T!"}" && after_bracket != T!";")
        goto default; // Parse as an AssignExpr.
      // ArrayInitializer := "[" ArrayInitElements? "]"
      Expression[] keys, values;

      skip(T!"[");
      while (!tokenIs(T!"]"))
      {
        Expression key;
        auto value = parseNonVoidInitializer();
        if (consumed(T!":"))
          (key = value), // Switch roles.
          assert(!(key.Is!(ArrayInitExpr) || key.Is!(StructInitExpr))),
          value = parseNonVoidInitializer(); // Parse actual value.
        keys ~= key;
        values ~= value;
        if (!consumed(T!","))
          break;
      }
      requireClosing(T!"]", begin);
      init = new ArrayInitExpr(keys, values);
      break;
    case T!"{":
      auto after_bracket = tokenAfterBracket(T!"}");
      if (after_bracket != T!"," && after_bracket != T!"}" &&
          after_bracket != T!"]" && after_bracket != T!";")
        goto default; // Parse as an AssignExpr.
      // StructInitializer := "{" StructInitElements? "}"
      Token*[] idents;
      Expression[] values;

      skip(T!"{");
      while (!tokenIs(T!"}"))
      { // Peek for colon to see if this is a member identifier.
        Token* ident;
        if (tokenIs(T!"Identifier") && peekNext() == T!":")
          (ident = token),
          skip(T!"Identifier"), skip(T!":"); // Identifier ":"
        idents ~= ident;
        values ~= parseNonVoidInitializer();
        if (!consumed(T!","))
          break;
      }
      requireClosing(T!"}", begin);
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
        if (consumed(T!"("))
          (outIdent = requireIdentifier(MID.ExpectedAnIdentifier)),
          require2(T!")");
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

  /// Returns true if t points to a postfix attribute.
  bool isFunctionPostfix(Token* t)
  {
    switch (t.kind)
    {
    case T!"const", T!"immutable", T!"inout", T!"nothrow", T!"shared",
         T!"pure", T!"@":
      return true;
    default:
    }
    return false;
  }

  /// $(BNF ExternLinkageType := extern "(" LinkageType ")"
  ///LinkageType := "C" | "C" "++" | "D" | "Windows" | "Pascal" | "System")
  LinkageType parseExternLinkageType()
  {
    LinkageType linkageType;

    skip(T!"extern"), skip(T!"("); // extern "("

    if (consumed(T!")"))
    { // extern "(" ")"
      error(MID.MissingLinkageType);
      return linkageType;
    }

    auto idtok = requireIdentifier(MID.ExpectedLinkageIdentifier);

    switch (idtok.ident.idKind)
    {
    case IDK.C:       linkageType = consumed(T!"++") ?
                                    LinkageType.Cpp :
                                    LinkageType.C;       break;
    case IDK.D:       linkageType = LinkageType.D;       break;
    case IDK.Windows: linkageType = LinkageType.Windows; break;
    case IDK.Pascal:  linkageType = LinkageType.Pascal;  break;
    case IDK.System:  linkageType = LinkageType.System;  break;
    case IDK.Empty:   break; // Avoid reporting another error below.
    default:
      assert(idtok);
      error2(MID.UnrecognizedLinkageType, idtok);
    }
    require2(T!")");
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
        if (peekNext() == T!"(")
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
        if (peekNext() == T!"(")
          break Loop;
                             stc = tokenIs(T!"const") ? StorageClass.Const :
                               tokenIs(T!"immutable") ? StorageClass.Immutable :
                                   tokenIs(T!"inout") ? StorageClass.Inout :
                                                        StorageClass.Shared;
        goto Lcommon;
      case T!"enum":
        if (!isEnumManifest())
          break Loop;
                             stc = StorageClass.Manifest;     goto Lcommon;
      case T!"ref":          stc = StorageClass.Ref;          goto Lcommon;
      case T!"pure":         stc = StorageClass.Pure;         goto Lcommon;
      case T!"nothrow":      stc = StorageClass.Nothrow;      goto Lcommon;
      case T!"__gshared":    stc = StorageClass.Gshared;      goto Lcommon;
      case T!"__thread":     stc = StorageClass.Thread;       goto Lcommon;
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

      // Non-StorageClass attributes:
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
        Token* ident;

        auto leftParen = token;
        require2(T!"(");
        ident = requireIdentifier(MID.ExpectedPragmaIdentifier);
        auto args = consumed(T!",") ? parseExpressionList() : null;
        requireClosing(T!")", leftParen);

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
    if (testAutoDecl && tokenIs(T!"Identifier")) // "auto" Identifier "="
      decl = // This could be a normal Declaration or an AutoDeclaration
        parseVariablesOrFunction(stcs, protection, linkageType, true);
    else
    {
      if (prevAttr.Is!PragmaDecl && tokenIs(T!";"))
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
    skip(T!"align");
    uint size;
    if (consumed(T!"("))
    {
      if (tokenIs(T!"Int32"))
        (sizetok = token), (size = token.int_), skip(T!"Int32");
      else
        expected(T!"Int32");
      require2(T!")");
    }
    return size;
  }

  /// $(BNF AtAttribute := "@" Identifier)
  StorageClass parseAtAttribute()
  {
    skip(T!"@");
    auto idtok = tokenIs(T!"Identifier") ?
      token : requireIdentifier(MID.ExpectedAttributeId);
    StorageClass stc;
    switch (idtok.ident.idKind)
    {
    case IDK.disable:  stc = StorageClass.Disable;  break;
    case IDK.property: stc = StorageClass.Property; break;
    case IDK.safe:     stc = StorageClass.Safe;     break;
    case IDK.system:   stc = StorageClass.System;   break;
    case IDK.trusted:  stc = StorageClass.Trusted;  break;
    case IDK.Empty: break; // No Id. Avoid another error below.
    default:
      assert(idtok);
      error2(MID.UnrecognizedAttribute, idtok);
    }
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
    bool isStatic = consumed(T!"static");
    skip(T!"import");

    ModuleFQN[] moduleFQNs;
    Token*[] moduleAliases;
    Token*[] bindNames;
    Token*[] bindAliases;

    do
    {
      ModuleFQN moduleFQN;
      Token* moduleAlias;
      // AliasName = ModuleName
      if (peekNext() == T!"=")
      {
        moduleAlias = requireIdentifier(MID.ExpectedAliasModuleName);
        skip(T!"=");
      }
      // Identifier ("." Identifier)*
      do
        moduleFQN ~= requireIdentifier(MID.ExpectedModuleIdentifier);
      while (consumed(T!"."));
      // Push identifiers.
      moduleFQNs ~= moduleFQN;
      moduleAliases ~= moduleAlias;
    } while (consumed(T!","));

    if (consumed(T!":"))
    { // ImportBind := (BindAlias "=")? BindName
      // ":" ImportBind ("," ImportBind)*
      do
      {
        Token* bindAlias;
        // BindAlias = BindName
        if (peekNext() == T!"=")
        {
          bindAlias = requireIdentifier(MID.ExpectedAliasImportName);
          skip(T!"=");
        }
        // Push identifiers.
        bindNames ~= requireIdentifier(MID.ExpectedImportName);
        bindAliases ~= bindAlias;
      } while (consumed(T!","));
    }
    require2(T!";");

    return new ImportDecl(moduleFQNs, moduleAliases, bindNames,
                                 bindAliases, isStatic);
  }

  /// Returns true if this is an enum manifest or
  /// false if it's a normal enum declaration.
  bool isEnumManifest()
  {
    version(D2)
    {
    assert(tokenIs(T!"enum"));
    auto next = peekAfter(token);
    auto kind = next.kind;
    if (kind == T!":" || kind == T!"{")
      return false; // Anonymous enum.
    else if (kind == T!"Identifier")
    {
      kind = peekAfter(next).kind;
      if (kind == T!":" || kind == T!"{" || kind == T!";")
        return false; // Named enum.
    }
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
    skip(T!"enum");

    Token* enumName;
    Type baseType;
    EnumMemberDecl[] members;

    enumName = optionalIdentifier();

    if (consumed(T!":"))
      baseType = parseBasicType();

    if (enumName && consumed(T!";"))
    {}
    else if (auto leftBrace = consumedToken(T!"{"))
    {
      while (!tokenIs(T!"}"))
      {
        Token* begin = token,
               name; // Name of the enum member.
        Type type; // Optional member type.
        Expression value; // Optional value.

        version(D2)
        {
        auto kind = peekNext();
        if (kind != T!"=" && kind != T!"," && kind != T!"}")
          type = parseType();
        }

        name = requireIdentifier(MID.ExpectedEnumMember);

        if (consumed(T!"=")) // "=" AssignExpr
          value = parseAssignExpr();

        auto member = new EnumMemberDecl(type, name, value);
        members ~= set(member, begin);

        if (!consumed(T!","))
          break;
      }
      requireClosing(T!"}", leftBrace);
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
    skip(T!"class");

    Token* name;
    TemplateParameters tparams;
    Expression constraint;
    BaseClassType[] bases;
    CompoundDecl decls;

    name = requireIdentifier(MID.ExpectedClassName);

    if (tokenIs(T!"("))
    {
      tparams = parseTemplateParameterList();
      version(D2) constraint = parseOptionalConstraint();
    }

    if (consumed(T!":"))
      bases = parseBaseClasses();

    if (bases.length == 0 && consumed(T!";"))
    {}
    else if (tokenIs(T!"{"))
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
    } while (consumed(T!","));
    return bases;
  }

  /// $(BNF InterfaceDecl :=
  ////  interface Name TemplateParameterList? (":" BaseClasses) InterfaceBody |
  ////  interface Name ";"
  ////InterfaceBody := DeclDefsBlock)
  Declaration parseInterfaceDecl()
  {
    auto begin = token;
    skip(T!"interface");

    Token* name;
    TemplateParameters tparams;
    Expression constraint;
    BaseClassType[] bases;
    CompoundDecl decls;

    name = requireIdentifier(MID.ExpectedInterfaceName);

    if (tokenIs(T!"("))
    {
      tparams = parseTemplateParameterList();
      version(D2) constraint = parseOptionalConstraint();
    }

    if (consumed(T!":"))
      bases = parseBaseClasses();

    if (bases.length == 0 && consumed(T!";"))
    {}
    else if (tokenIs(T!"{"))
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
    assert(tokenIs(T!"struct") || tokenIs(T!"union"));
    auto begin = token;
    nT();

    Token* name;
    TemplateParameters tparams;
    Expression constraint;
    CompoundDecl decls;

    name = optionalIdentifier();

    if (name && tokenIs(T!"("))
    {
      tparams = parseTemplateParameterList();
      version(D2) constraint = parseOptionalConstraint();
    }

    if (name && consumed(T!";"))
    {}
    else if (tokenIs(T!"{"))
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
    skip(T!"this");
    if (tokenIs(T!"(") && tokenAfterParenIs(T!"("))
      tparams = parseTemplateParameterList(); // "(" TemplateParameterList ")"
    Parameters parameters;
    if (peekNext() != T!"this")
      parameters = parseParameterList(); // "(" ParameterList ")"
    else // TODO: Create own class PostBlit?: this "(" this ")"
    {
      auto begin2 = token;
      parameters = new Parameters();
      require2(T!"(");
      auto this_ = token;
      auto thisParam = new Parameter(STC.None, null, null, this_, null);
      skip(T!"this");
      parameters ~= set(thisParam, this_);
      require2(T!")");
      set(parameters, begin2);
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
    skip(T!"this");
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new ConstructorDecl(parameters, funcBody);
    }
  }

  /// $(BNF DestructorDecl := "~" this "(" ")" FunctionBody)
  Declaration parseDestructorDecl()
  {
    skip(T!"~");
    require2(T!"this");
    require2(T!"(");
    require2(T!")");
    auto funcBody = parseFunctionBody();
    return new DestructorDecl(funcBody);
  }

  /// $(BNF StaticCtorDecl := static this "(" ")" FunctionBody)
  Declaration parseStaticCtorDecl()
  {
    skip(T!"static");
    skip(T!"this");
    require2(T!"(");
    require2(T!")");
    auto funcBody = parseFunctionBody();
    return new StaticCtorDecl(funcBody);
  }

  /// $(BNF
  ////StaticDtorDecl := static "~" this "(" ")" FunctionBody)
  Declaration parseStaticDtorDecl()
  {
    skip(T!"static");
    skip(T!"~");
    require2(T!"this");
    require2(T!"(");
    require2(T!")");
    auto funcBody = parseFunctionBody();
    return new StaticDtorDecl(funcBody);
  }

  /// $(BNF InvariantDecl := invariant ("(" ")")? FunctionBody)
  Declaration parseInvariantDecl()
  {
    skip(T!"invariant");
    // Optional () for getting ready porting to D 2.0
    if (consumed(T!"("))
      require2(T!")");
    auto funcBody = parseFunctionBody();
    return new InvariantDecl(funcBody);
  }

  /// $(BNF UnittestDecl := unittest FunctionBody)
  Declaration parseUnittestDecl()
  {
    skip(T!"unittest");
    if (!tokenIs(T!"{"))
      error2(MID.ExpectedUnittestBody, token);
    auto funcBody = parseFunctionBody();
    return new UnittestDecl(funcBody);
  }

  /// Parses an identifier or an integer. Reports an error otherwise.
  /// $(BNF IdentOrInt := Identifier | Integer)
  Token* parseIdentOrInt()
  {
    if (consumed(T!"Identifier") || consumed(T!"Int32"))
      return this.prevToken;
    error2(MID.ExpectedIdentOrInt, token);
    return null;
  }

  /// $(BNF VersionCondition := unittest #*D2.0*# | IdentOrInt)
  Token* parseVersionCondition()
  {
    version(D2)
    if (auto t = consumedToken(T!"unittest"))
      return t;
    return parseIdentOrInt();
  }

  /// $(BNF DebugDecl :=
  ////  debug "=" IdentOrInt ";" |
  ////  debug DebugCondition? DeclsBlock (else DeclsBlock)?
  ////DebugCondition := "(" IdentOrInt ")")
  Declaration parseDebugDecl()
  {
    skip(T!"debug");

    Token* spec;
    Token* cond;
    Declaration decls, elseDecls;

    if (consumed(T!"="))
    { // debug = Integer ;
      // debug = Identifier ;
      spec = parseIdentOrInt();
      require2(T!";");
    }
    else
    { // "(" Condition ")"
      if (consumed(T!"("))
      {
        cond = parseIdentOrInt();
        require2(T!")");
      }
      // debug DeclsBlock
      // debug ( Condition ) DeclsBlock
      decls = parseDeclarationsBlock();
      // else DeclsBlock
      if (consumed(T!"else"))
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
    skip(T!"version");

    Token* spec;
    Token* cond;
    Declaration decls, elseDecls;

    if (consumed(T!"="))
    { // version = Integer ;
      // version = Identifier ;
      spec = parseIdentOrInt();
      require2(T!";");
    }
    else
    { // ( Condition )
      require2(T!"(");
      cond = parseVersionCondition();
      require2(T!")");
      // version ( Condition ) DeclsBlock
      decls = parseDeclarationsBlock();
      // else DeclsBlock
      if (consumed(T!"else"))
        elseDecls = parseDeclarationsBlock();
    }

    return new VersionDecl(spec, cond, decls, elseDecls);
  }

  /// $(BNF StaticIfDecl :=
  ////  static if "(" AssignExpr ")" DeclsBlock (else DeclsBlock)?)
  Declaration parseStaticIfDecl()
  {
    skip(T!"static");
    skip(T!"if");

    Expression condition;
    Declaration ifDecls, elseDecls;

    auto leftParen = token;
    require2(T!"(");
    condition = parseAssignExpr();
    requireClosing(T!")", leftParen);

    ifDecls = parseDeclarationsBlock();

    if (consumed(T!"else"))
      elseDecls = parseDeclarationsBlock();

    return new StaticIfDecl(condition, ifDecls, elseDecls);
  }

  /// $(BNF StaticAssertDecl :=
  ////  static assert "(" AssignExpr ("," Message)? ")" ";"
  ////Message          := AssignExpr)
  Declaration parseStaticAssertDecl()
  {
    skip(T!"static");
    skip(T!"assert");
    Expression condition, message;
    auto leftParen = token;
    require2(T!"(");
    condition = parseAssignExpr();
    if (consumed(T!","))
      message = parseAssignExpr();
    requireClosing(T!")", leftParen);
    require2(T!";");
    return new StaticAssertDecl(condition, message);
  }

  /// $(BNF TemplateDecl :=
  ////  template Name TemplateParameterList Constraint? DeclDefsBlock)
  TemplateDecl parseTemplateDecl()
  {
    skip(T!"template");
    auto name = requireIdentifier(MID.ExpectedTemplateName);
    auto tparams = parseTemplateParameterList();
    auto constraint = parseOptionalConstraint();
    auto decls = parseDeclarationDefinitionsBody();
    return new TemplateDecl(name, tparams, constraint, decls);
  }

  /// $(BNF NewDecl := new ParameterList FunctionBody)
  Declaration parseNewDecl()
  {
    skip(T!"new");
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new NewDecl(parameters, funcBody);
  }

  /// $(BNF DeleteDecl := delete ParameterList FunctionBody)
  Declaration parseDeleteDecl()
  {
    skip(T!"delete");
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
    skip(T!"mixin");

    static if (is(Class == MixinDecl))
    {
    if (consumed(T!"("))
    {
      auto leftParen = token;
      auto e = parseAssignExpr();
      requireClosing(T!")", leftParen);
      require2(T!";");
      return new MixinDecl(e);
    }
    else version(D2) if (tokenIs(T!"template"))
    {
      auto d = parseTemplateDecl();
      d.isMixin = true;
      return d;
    } // version(D2)
    }

    auto e = parseIdentifiersExpr();
    auto mixinIdent = optionalIdentifier();
    require2(T!";");

    return new Class(e, mixinIdent);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                        Statement parsing methods                        |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// $(BNF Statements := "{" Statement* "}")
  CompoundStmt parseStatements()
  {
    auto begin = token;
    require(T!"{");
    auto statements = new CompoundStmt();
    while (!tokenIs(T!"}") && !tokenIs(T!"EOF"))
      statements ~= parseStatement();
    requireClosing(T!"}", begin);
    return set(statements, begin);
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
      if (tokenIs(T!"struct"))
      {
        auto begin2 = token;
        structDecl = parseStructOrUnionDecl().to!(StructDecl);
        structDecl.setAlignSize(size);
        set(structDecl, begin2);
      }
      else
        expected(T!"struct");

      d = structDecl ? cast(Declaration)structDecl : new CompoundDecl;
      d = new AlignDecl(sizetok, d);
      goto LreturnDeclarationStmt;

    case T!"extern", T!"const", T!"auto":
         //T!"final", T!"scope", T!"static":
    version(D2)
    {
    case T!"immutable", T!"inout", T!"pure", T!"shared", T!"__gshared",
         T!"ref", T!"nothrow", T!"__thread", T!"@":
    }
      goto case_parseAttribute;

    case T!"Identifier":
      if (peekNext() == T!":")
      {
        skip(T!"Identifier"); skip(T!":");
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
      if (peekNext() != T!"(")
        goto case_parseAttribute;
      goto case_T_Scope;
    case T!"mixin":
      if (peekNext() == T!"(")
        goto case_parseExpressionStmt; // Parse as expression.
      goto case_T_Mixin;
    case T!"final":
      version(D2)
      {
      if (peekNext() == T!"switch")
        goto case T!"switch";
      }
      goto case_parseAttribute;
    case T!"static":
      switch (peekNext())
      {
      case T!"if":     s = parseStaticIfStmt();     break;
      case T!"assert": s = parseStaticAssertStmt(); break;
      default:       goto case_parseAttribute;
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
      if (peekNext() != T!"(")
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
      require2(T!";");
      break;
    default:
      if (token.isSpecialToken)
        goto case_parseExpressionStmt;

      if (!tokenIs(T!"$"))
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
      while (!token.isStatementStart() &&
             !tokenIs(T!"}") &&
             !tokenIs(T!"EOF"));
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
    Statement s;
    if (tokenIs(T!"{"))
      s = parseStatements();
    else
    {
      if (tokenIs(T!";"))
        error(MID.ExpectedNonEmptyStatement, token);
      s = parseStatement();
    }
    return s;
  }

  /// $(BNF NoScopeOrEmptyStmt := ";" | NoScopeStmt)
  Statement parseNoScopeOrEmptyStmt()
  {
    if (auto semicolon = consumedToken(T!";"))
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
        if (peekNext() == T!"(")
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
        if (peekNext() == T!"(")
          break Loop;
                          stc = tokenIs(T!"const") ? StorageClass.Const :
                            tokenIs(T!"immutable") ? StorageClass.Immutable :
                                tokenIs(T!"inout") ? StorageClass.Inout :
                                                     StorageClass.Shared;
        goto Lcommon;
      case T!"enum":
        if (!isEnumManifest())
          break Loop;
                          stc = StorageClass.Manifest; goto Lcommon;
      case T!"ref":       stc = StorageClass.Ref;      goto Lcommon;
      case T!"pure":      stc = StorageClass.Pure;     goto Lcommon;
      case T!"nothrow":   stc = StorageClass.Nothrow;  goto Lcommon;
      case T!"__gshared": stc = StorageClass.Gshared;  goto Lcommon;
      case T!"__thread":  stc = StorageClass.Thread;   goto Lcommon;
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
    switch (token.kind)
    {
    case T!"class", T!"interface", T!"struct", T!"union",
         T!"alias", T!"typedef", T!"enum":
      // Set current values.
      this.storageClass = stcs;
      this.linkageType = linkageType;
      // Parse a declaration.
      decl = parseDeclarationDefinition();
      // Clear values.
      this.storageClass = StorageClass.None;
      this.linkageType = LinkageType.None;
      break;
    case T!"template": // TODO:
      // error2("templates are not allowed in functions", token);
      //break;
    default:
      decl =
        parseVariablesOrFunction(stcs, protection, linkageType, testAutoDecl);
    }
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
    skip(T!"if");

    Declaration variable;
    Expression condition;
    Statement ifBody, elseBody;

    auto leftParen = token;
    require2(T!"(");

    Type type;
    Token* name;
    auto begin = token; // For start of AutoDecl or normal Declaration.
    bool success;

    tryToParse({
      if (consumed(T!"auto")) // auto Identifier = Expression
        name = requireIdentifier(MID.ExpectedVariableName);
      else // Declarator "=" Expression
        type = parseDeclarator(name);
      require(T!"=");
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

    requireClosing(T!")", leftParen);
    ifBody = parseScopeStmt();
    if (consumed(T!"else"))
      elseBody = parseScopeStmt();
    return new IfStmt(variable, condition, ifBody, elseBody);
  }

  /// $(BNF WhileStmt := while "(" Expression ")" ScopeStmt)
  Statement parseWhileStmt()
  {
    skip(T!"while");
    auto leftParen = token;
    require2(T!"(");
    auto condition = parseExpression();
    requireClosing(T!")", leftParen);
    return new WhileStmt(condition, parseScopeStmt());
  }

  /// $(BNF DoWhileStmt := do ScopeStmt while "(" Expression ")")
  Statement parseDoWhileStmt()
  {
    skip(T!"do");
    auto doBody = parseScopeStmt();
    require(T!"while");
    auto leftParen = token;
    require2(T!"(");
    auto condition = parseExpression();
    requireClosing(T!")", leftParen);
    version(D2)
    require2(T!";");
    return new DoWhileStmt(condition, doBody);
  }

  /// $(BNF ForStmt :=
  ////  for "(" (NoScopeStmt | ";") Expression? ";" Expression? ")"
  ////    ScopeStmt)
  Statement parseForStmt()
  {
    skip(T!"for");

    Statement init, forBody;
    Expression condition, increment;

    auto leftParen = token;
    require2(T!"(");
    if (!consumed(T!";"))
      init = parseNoScopeStmt();
    if (!tokenIs(T!";"))
      condition = parseExpression();
    require2(T!";");
    if (!tokenIs(T!")"))
      increment = parseExpression();
    requireClosing(T!")", leftParen);
    forBody = parseScopeStmt();
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
    assert(tokenIs(T!"foreach") || tokenIs(T!"foreach_reverse"));
    TOK tok = token.kind;
    nT();

    auto params = new Parameters;
    Expression e; // Expression or RangeExpr

    auto leftParen = token;
    require2(T!"(");
    auto paramsBegin = token;
    do
    {
      auto paramBegin = token;
      StorageClass stc;
      Type type;
      Token* name, stctok;

      switch (token.kind)
      {
      version(D1)
      {
      case T!"inout":
      }
      case T!"ref":
        stc = StorageClass.Ref;
        stctok = token;
        nT();
        // fall through
      case T!"Identifier":
        auto next = peekNext();
        if (next == T!"," || next == T!";" || next == T!")")
        { // (ref|inout)? Identifier
          name = requireIdentifier(MID.ExpectedVariableName);
          break;
        }
        // fall through
      default: // (ref|inout)? Declarator
        type = parseDeclarator(name);
      }

      params ~= set(new Parameter(stc, stctok, type, name, null), paramBegin);
    } while (consumed(T!","));
    set(params, paramsBegin);

    require2(T!";");
    e = parseExpression();

    version(D2)
    if (auto op = consumedToken(T!"..")) // Expression ".." Expression
      e = set(new RangeExpr(e, parseExpression(), op), e.begin);

    requireClosing(T!")", leftParen);
    auto forBody = parseScopeStmt();
    return new ForeachStmt(tok, params, e, forBody);
  }

  /// $(BNF SwitchStmt := final? switch "(" Expression ")" ScopeStmt)
  Statement parseSwitchStmt()
  {
    bool isFinal = consumed(T!"final");
    skip(T!"switch");
    auto leftParen = token;
    require2(T!"(");
    auto condition = parseExpression();
    requireClosing(T!")", leftParen);
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
    while (!tokenIs(T!"case")   && !tokenIs(T!"default") &&
           !tokenIs(T!"}") && !tokenIs(T!"EOF"))
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
    skip(T!"case");
    auto values = parseExpressionList();
    require2(T!":");
    version(D2)
    if (consumed(T!"..")) // ".."
    {
      if (values.length > 1)
        error(values[1].begin, MID.CaseRangeStartExpression);
      require(T!"case");
      Expression left = values[0], right = parseAssignExpr();
      require2(T!":");
      auto caseBody = parseCaseOrDefaultBody();
      return new CaseRangeStmt(left, right, caseBody);
    } // version(D2)
    auto caseBody = parseCaseOrDefaultBody();
    return new CaseStmt(values, caseBody);
  }

  /// $(BNF DefaultStmt := default ":" CaseOrDefaultBody)
  Statement parseDefaultStmt()
  {
    skip(T!"default");
    require2(T!":");
    auto defaultBody = parseCaseOrDefaultBody();
    return new DefaultStmt(defaultBody);
  }

  /// $(BNF ContinueStmt := continue Identifier? ";")
  Statement parseContinueStmt()
  {
    skip(T!"continue");
    auto ident = optionalIdentifier();
    require2(T!";");
    return new ContinueStmt(ident);
  }

  /// $(BNF BreakStmt := break Identifier? ";")
  Statement parseBreakStmt()
  {
    skip(T!"break");
    auto ident = optionalIdentifier();
    require2(T!";");
    return new BreakStmt(ident);
  }

  /// $(BNF ReturnStmt := return Expression? ";")
  Statement parseReturnStmt()
  {
    skip(T!"return");
    Expression expr;
    if (!tokenIs(T!";"))
      expr = parseExpression();
    require2(T!";");
    return new ReturnStmt(expr);
  }

  /// $(BNF
  ////GotoStmt := goto (case Expression? | default | Identifier) ";")
  Statement parseGotoStmt()
  {
    skip(T!"goto");
    auto ident = token;
    Expression caseExpr;
    switch (token.kind)
    {
    case T!"case":
      nT();
      if (tokenIs(T!";"))
        break;
      caseExpr = parseExpression();
      break;
    case T!"default":
      nT();
      break;
    default:
      ident = requireIdentifier(MID.ExpectedAnIdentifier);
    }
    require2(T!";");
    return new GotoStmt(ident, caseExpr);
  }

  /// $(BNF WithStmt := with "(" Expression ")" ScopeStmt)
  Statement parseWithStmt()
  {
    skip(T!"with");
    auto leftParen = token;
    require2(T!"(");
    auto expr = parseExpression();
    requireClosing(T!")", leftParen);
    return new WithStmt(expr, parseScopeStmt());
  }

  /// $(BNF SynchronizedStmt := synchronized ("(" Expression ")")? ScopeStmt)
  Statement parseSynchronizedStmt()
  {
    skip(T!"synchronized");
    Expression expr;
    if (auto leftParen = consumedToken(T!"("))
    {
      expr = parseExpression();
      requireClosing(T!")", leftParen);
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
    skip(T!"try");

    auto tryBody = parseScopeStmt();
    CatchStmt[] catchBodies;
    FinallyStmt finBody;

    while (consumed(T!"catch"))
    {
      auto catchBegin = prevToken;
      Parameter param;
      if (auto leftParen = consumedToken(T!"("))
      {
        auto paramBegin = token;
        Token* name;
        auto type = parseDeclaratorOptId(name);
        param = new Parameter(StorageClass.None, null, type, name, null);
        set(param, paramBegin);
        requireClosing(T!")", leftParen);
      }
      catchBodies ~= set(new CatchStmt(param, parseNoScopeStmt()), catchBegin);
      if (param is null)
        break; // This is a LastCatch
    }

    if (auto t = consumedToken(T!"finally"))
      finBody = set(new FinallyStmt(parseNoScopeStmt()), t);

    if (catchBodies is null && finBody is null)
      error(begin, MID.MissingCatchOrFinally);

    return new TryStmt(tryBody, catchBodies, finBody);
  }

  /// $(BNF ThrowStmt := throw Expression ";")
  Statement parseThrowStmt()
  {
    skip(T!"throw");
    auto expr = parseExpression();
    require2(T!";");
    return new ThrowStmt(expr);
  }

  /// $(BNF ScopeGuardStmt := scope "(" ScopeCondition ")" ScopeGuardBody
  ////ScopeCondition := "exit" | "success" | "failure"
  ////ScopeGuardBody := ScopeStmt | NoScopeStmt)
  Statement parseScopeGuardStmt()
  {
    skip(T!"scope");
    skip(T!"(");
    auto condition = requireIdentifier(MID.ExpectedScopeIdentifier);
    switch (condition ? condition.ident.idKind : IDK.Empty)
    {
    case IDK.exit, IDK.success, IDK.failure: break;
    case IDK.Empty: break; // Don't report error twice.
    default:
      error2(MID.InvalidScopeIdentifier, condition);
    }
    require2(T!")");
    auto scopeBody = tokenIs(T!"{") ? parseScopeStmt() : parseNoScopeStmt();
    return new ScopeGuardStmt(condition, scopeBody);
  }

  /// $(BNF VolatileStmt := volatile (ScopeStmt | NoScopeStmt))
  Statement parseVolatileStmt()
  {
    skip(T!"volatile");
    Statement volatileBody;
    if (tokenIs(T!"{"))
      volatileBody = parseScopeStmt();
    else
      volatileBody = parseNoScopeStmt();
    return new VolatileStmt(volatileBody);
  }

  /// $(BNF PragmaStmt :=
  ////  pragma "(" Identifier ("," ExpressionList)? ")" NoScopeStmt)
  Statement parsePragmaStmt()
  {
    skip(T!"pragma");

    Token* name;
    Expression[] args;
    Statement pragmaBody;

    auto leftParen = token;
    require2(T!"(");
    name = requireIdentifier(MID.ExpectedPragmaIdentifier);

    if (consumed(T!","))
      args = parseExpressionList();
    requireClosing(T!")", leftParen);

    pragmaBody = parseNoScopeOrEmptyStmt();

    return new PragmaStmt(name, args, pragmaBody);
  }

  /// $(BNF StaticIfStmt :=
  ////  static if "(" Expression ")" NoScopeStmt (else NoScopeStmt)?)
  Statement parseStaticIfStmt()
  {
    skip(T!"static");
    skip(T!"if");
    Expression condition;
    Statement ifBody, elseBody;

    auto leftParen = token;
    require2(T!"(");
    condition = parseExpression();
    requireClosing(T!")", leftParen);
    ifBody = parseNoScopeStmt();
    if (consumed(T!"else"))
      elseBody = parseNoScopeStmt();
    return new StaticIfStmt(condition, ifBody, elseBody);
  }

  /// $(BNF StaticAssertStmt :=
  ////  static assert "(" AssignExpr ("," Message)? ")" ";"
  ////Message := AssignExpr)
  Statement parseStaticAssertStmt()
  {
    skip(T!"static");
    skip(T!"assert");
    Expression condition, message;

    require2(T!"(");
    condition = parseAssignExpr(); // Condition.
    if (consumed(T!","))
      message = parseAssignExpr(); // Error message.
    require2(T!")");
    require2(T!";");
    return new StaticAssertStmt(condition, message);
  }

  /// $(BNF DebugStmt :=
  ////  debug DebugCondition? NoScopeStmt (else NoScopeStmt)?)
  Statement parseDebugStmt()
  {
    skip(T!"debug");
    Token* cond;
    Statement debugBody, elseBody;

    // ( Condition )
    if (consumed(T!"("))
    {
      cond = parseIdentOrInt();
      require2(T!")");
    }
    // debug Statement
    // debug ( Condition ) Statement
    debugBody = parseNoScopeStmt();
    // else Statement
    if (consumed(T!"else"))
      elseBody = parseNoScopeStmt();

    return new DebugStmt(cond, debugBody, elseBody);
  }

  /// $(BNF VersionStmt :=
  ////  version VCondition NoScopeStmt (else NoScopeStmt)?)
  Statement parseVersionStmt()
  {
    skip(T!"version");
    Token* cond;
    Statement versionBody, elseBody;

    // ( Condition )
    require2(T!"(");
    cond = parseVersionCondition();
    require2(T!")");
    // version ( Condition ) Statement
    versionBody = parseNoScopeStmt();
    // else Statement
    if (consumed(T!"else"))
      elseBody = parseNoScopeStmt();

    return new VersionStmt(cond, versionBody, elseBody);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                        Assembler parsing methods                        |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// Parses an AsmBlockStmt.
  /// $(BNF AsmBlockStmt := asm "{" AsmStmt* "}")
  Statement parseAsmBlockStmt()
  {
    skip(T!"asm");
    auto leftBrace = token;
    require(T!"{");
    auto ss = new CompoundStmt;
    while (!tokenIs(T!"}") && !tokenIs(T!"EOF"))
      ss ~= parseAsmStmt();
    requireClosing(T!"}", leftBrace);
    return new AsmBlockStmt(set(ss, leftBrace));
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
      if (consumed(T!":"))
      { // Identifier ":" AsmStmt
        s = new LabeledStmt(ident, parseAsmStmt());
        break;
      }

      // JumpOpcode (short | (near | far) ptr)?
      if (Ident.isJumpOpcode(ident.ident.idKind))
      {
        auto jmptype = token.ident;
        if (tokenIs(T!"short"))
          nT();
        else if (tokenIs(T!"Identifier") &&
                 (jmptype is Ident.near || jmptype is Ident.far))
        {
          nT();
          if (tokenIs(T!"Identifier") && token.ident is Ident.ptr)
            skip(T!"Identifier");
          else
            error2(MID.ExpectedButFound, "ptr", token);
        }
      }

      // TODO: Handle opcodes db, ds, di, dl, df, dd, de.
      //       They accept string operands.

    LparseOperands:
      // Opcode Operands? ";"
      Expression[] es;
      if (!tokenIs(T!";"))
        do
          es ~= parseAsmExpr();
        while (consumed(T!","));
      require2(T!";");
      s = new AsmStmt(ident, es);
      break;
    case T!"align":
      // align Integer ";"
      nT();
      auto number = token;
      if (!consumed(T!"Int32"))
        error2(MID.ExpectedIntegerAfterAlign, token);
      require2(T!";");
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
      while (!token.isAsmStatementStart() &&
             !tokenIs(T!"}") &&
             !tokenIs(T!"EOF"));
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
    if (auto qtok = consumedToken(T!"?"))
    {
      auto iftrue = parseAsmExpr();
      auto ctok = token; // ":"
      require(T!":");
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
      switch (prevToken.kind)
      {
      case /*T!"!",*/ T!"is", T!"in", T!"!<>=", T!"!<>", T!"!<=", T!"!<",
           T!"!>=", T!"!>", T!"<>=", T!"<>", T!"~", T!"^^":
        // Use textSpan() for operators like "!is" and "!in".
        error(operator, MID.IllegalAsmBinaryOp, operator.textSpan(prevToken));
        break;
      default:
      }
      auto rhs = parseAsmBinaryExpr(opPrec); // Parse the right-hand side.
      e = makeBinaryExpr(e, rhs, operator);
      set(e, begin);
    }
    return e;
  }

  /// $(BNF AsmPostExpr := AsmUnaryExpr ("[" AsmExpr "]")*)
  Expression parseAsmPostExpr()
  {
    Token* begin = token, leftBracket = void;
    auto e = parseAsmUnaryExpr();
    while ((leftBracket = consumedToken(T!"[")) !is null)
    {
      e = new AsmPostBracketExpr(e, parseAsmExpr());
      requireClosing(T!"]", leftBracket);
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
    case T!"byte",  T!"short",  T!"int",
         T!"float", T!"double", T!"real":
      goto LAsmTypePrefix;
    case T!"Identifier":
      switch (token.ident.idKind)
      {
      case IDK.near, IDK.far,/* "byte",  "short",  "int",*/
           IDK.word, IDK.dword, IDK.qword/*, "float", "double", "real"*/:
      LAsmTypePrefix:
        nT();
        if (tokenIs(T!"Identifier") && token.ident is Ident.ptr)
          skip(T!"Identifier");
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
    case T!"-":
    case T!"+":
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
      auto leftBracket = token;
      nT();
      e = parseAsmExpr();
      requireClosing(T!"]", leftBracket);
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
        if (consumed(T!"("))
          (number = parseAsmExpr()),
          require2(T!")");
        e = new AsmRegisterExpr(register, number);
        break;
      case IDK.ES, IDK.CS, IDK.SS, IDK.DS, IDK.GS, IDK.FS:
        nT();
        Expression number;
        if (consumed(T!":")) // Segment := XX ":" AsmExpr
          number = parseAsmExpr();
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
      e = new IllegalExpr();
      if (!trying)
      { // Insert a dummy token and don't consume current one.
        begin = lexer.insertEmptyTokenBefore(token);
        this.prevToken = begin;
      }
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
    while ((comma = consumedToken(T!",")) !is null)
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
      skip(optok.kind);
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
    if (auto qtok = consumedToken(T!"?"))
    {
      auto iftrue = parseExpression();
      auto ctok = token; // ":"
      require(T!":");
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
      if (tokenIs(T!"!"))
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
        if (tokenIs(T!"new"))
          e = parseNewExpr(e);
        else
          e = parseIdentifierExpr(e);
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
        auto leftBracket = token;
        nT();
        // "[" "]" is the empty SliceExpr
        if (tokenIs(T!"]"))
        {
          e = new SliceExpr(e, null);
          break;
        }
        auto e2 = parseAssignExpr();
        // "[" AssignExpr ".." AssignExpr "]"
        if (auto op = consumedToken(T!".."))
        {
          auto r = set(new RangeExpr(e2, parseAssignExpr(), op), e2.begin);
          e = new SliceExpr(e, r);
        }
        else
        { // "[" ExpressionList "]"
          auto index = [e2];
          if (consumed(T!","))
             index ~= parseExpressionList2(T!"]");
          e = new IndexExpr(e, index);
        }
        requireClosing(T!"]", leftBracket);
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
      require2(T!"(");
      Type type;
      switch (token.kind)
      {
      version(D2)
      {
      case T!")": // Mutable cast: cast "(" ")"
        break;
      case T!"const", T!"immutable", T!"inout", T!"shared":
        auto begin2 = token;
        if (peekNext() != T!")")
          goto default; // ModParenType
        type = new ModifierType(token);
        nT();
        set(type, begin2);
        break;
      } // version(D2)
      default:
       type = parseType();
      }
      require2(T!")");
      e = new CastExpr(parseUnaryExpr(), type);
      break;
    case T!"(":
      if (!tokenAfterParenIs(T!"."))
        goto default;
      // "(" Type ")" "." Identifier
      bool success;
      auto type = tryToParse({
        skip(T!"("); // "("
        auto type = parseType(); // Type
        require(T!")"); // ")"
        require(T!"."); // "."
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
    if (tokenIs(T!"."))
      e = set(new ModuleScopeExpr(), token, token);
    else
      e = parseIdentifierExpr();
    while (consumed(T!"."))
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
    auto nextTok = peekNext();
    if (tokenIs(T!"!") && nextTok != T!"is" && nextTok != T!"in")
    {
      skip(T!"!");
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
    skip(T!"=>");
    return parseAssignExpr();
  }

  /// $(BNF LambdaExpr := LambdaParams "=>" LambdaBody
  ////LambdaParams := Identifier | ParameterList ParamsPostfix)
  Expression parseSingleParamLambdaExpr()
  {
    auto begin = token;
    skip(T!"Identifier");
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
      if (peekNext() == T!"=>")
        e = parseSingleParamLambdaExpr();
      else
        e = parseIdentifierExpr();
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
      cbinstr str = token.strval.str;
      char postfix = token.strval.pf;
      nT();
      // Concatenate adjacent string literals.
      while (tokenIs(T!"String"))
      {
        auto strval = token.strval;
        if (auto pf = strval.pf) // If the string has a postfix char.
        {
          if (pf != postfix)
            error(token, MID.StringPostfixMismatch);
          postfix = pf;
        }
        str ~= strval.str;
        nT();
      }

      void check(cbinstr function(cstring) convert)
      { // Check for invalid UTF-8 sequences and then convert.
        if (!hasInvalidUTF8(str, begin))
          str = convert(cast(cstring)str);
      }

      switch (postfix)
      {
      case 'c': check(x => cast(cbinstr)x); break;
      case 'w': check(x => cast(cbinstr)dil.Unicode.toUTF16(x)); break;
      case 'd': check(x => cast(cbinstr)dil.Unicode.toUTF32(x)); break;
      default:
      }

      // Did the value change due to conversion or multiple string literals?
      if (begin.strval.str !is str)
        str = lexer.lookupString(str); // Insert into table if so.

      e = new StringExpr(str, postfix);
      break;
    case T!"[":
      nT();
      Expression[] exprs;
      if (!tokenIs(T!"]"))
        exprs = [parseAssignExpr()];
      if (consumed(T!":"))
      { // "[" AssignExpr ":"
        Expression[] values;
        while (1)
        {
          values ~= parseAssignExpr();
          if (!consumed(T!",") || tokenIs(T!"]"))
            break;
          exprs ~= parseAssignExpr(); // Keys
          require(T!":");
        }
        e = new AArrayLiteralExpr(exprs, values);
      }
      else
      { // "[" "]" | "[" AssignExpr
        if (consumed(T!",")) // "," ExpressionList2
            exprs ~= parseExpressionList2(T!"]");
        e = new ArrayLiteralExpr(exprs);
      }
      requireClosing(T!"]", begin);
      break;
    case T!"{":
      // DelegateLiteral := { Statements }
      auto funcBody = parseFunctionBody();
      e = new FuncLiteralExpr(funcBody);
      break;
    case T!"function", T!"delegate":
      // FunctionLiteral := ("function" | "delegate")
      //   ReturnType? "(" ArgumentList ")" FunctionPostfix? FunctionBody
      nT(); // Skip function or delegate keyword.
      Type returnType;
      Parameters parameters;
      if (!tokenIs(T!"{"))
      {
        if (!tokenIs(T!"(")) // Optional return type
          returnType = parseBasicTypes();
        parameters = parseParameterList();
        version(D2)
        parameters.postSTCs = parseFunctionPostfix();
      }
      auto funcBody = parseFunctionBody();
      e = new FuncLiteralExpr(begin, returnType, parameters, funcBody);
      break;
    case T!"assert":
      requireNext(T!"(");
      e = parseAssignExpr();
      auto msg = consumed(T!",") ? parseAssignExpr() : null;
      require2(T!")");
      e = new AssertExpr(e, msg);
      break;
    case T!"mixin":
      nT();
      require2(T!"(");
      e = new MixinExpr(parseAssignExpr());
      require2(T!")");
      break;
    case T!"import":
      nT();
      require2(T!"(");
      e = new ImportExpr(parseAssignExpr());
      require2(T!")");
      break;
    case T!"typeid":
      nT();
      require2(T!"(");
      e = new TypeidExpr(parseType());
      require2(T!")");
      break;
    case T!"is":
      nT();
      auto leftParen = token;
      require2(T!"(");

      Type type, specType;
      Token* ident; // optional Identifier
      Token* opTok, specTok;

      type = parseDeclaratorOptId(ident);

      switch (token.kind)
      {
      case T!":", T!"==":
        opTok = token;
        nT();
        switch (token.kind)
        {
        case T!"typedef", T!"struct", T!"union", T!"class", T!"interface",
             T!"enum", T!"function", T!"delegate", T!"super", T!"return":
        case_Const_Immutable_Inout_Shared: // D2
          specTok = token;
          nT();
          break;
        version(D2)
        {
        case T!"const", T!"immutable", T!"inout", T!"shared":
          auto next = peekNext();
          if (next == T!")" || next == T!",")
            goto case_Const_Immutable_Inout_Shared;
          goto default; // It's a type.
        } // version(D2)
        default:
          specType = parseType();
        }
      default:
      }

      TemplateParameters tparams;
      version(D2)
      { // "is" "(" Type Identifier (":" | "==") TypeSpecialization ","
      //          TemplateParameterList ")"
      if (ident && specType && tokenIs(T!","))
        tparams = parseTemplateParameterList2();
      } // version(D2)
      requireClosing(T!")", leftParen);
      e = new IsExpr(type, ident, opTok, specTok, specType, tparams);
      break;
    case T!"(":
      auto t = skipParens(token, T!")");
      if (isFunctionPostfix(t) || // E.g.: "(" int "a" ")" pure
          t.kind == T!"{" || t.kind == T!"=>")
      {
        auto parameters = parseParameterList(); // "(" ParameterList ")"
        parameters.postSTCs = parseFunctionPostfix(); // Optional attributes.
        FuncBodyStmt fstmt;
        if (token.kind == T!"{") // "(" ... ")" "{" ...
          fstmt = parseFunctionBody();
        else if (token.kind == T!"=>") // "(" ... ")" "=>" ...
        {
          e = new LambdaExpr(parameters, parseLambdaExprBody());
          break;
        }
        else
          error(token, MID.ExpectedFunctionBody, token.text);
        e = new FuncLiteralExpr(parameters, fstmt);
      }
      else
      { // ( Expression )
        auto leftParen = token;
        skip(T!"(");
        e = parseExpression();
        requireClosing(T!")", leftParen);
        e = new ParenExpr(e);
      }
      break;
    version(D2)
    {
    case T!"__traits":
      nT();
      auto leftParen = token;
      require2(T!"("); // "("
      auto ident = requireIdentifier(MID.ExpectedAnIdentifier);
      auto args = consumed(T!",") ? parseTemplateArguments2() : null;
      requireClosing(T!")", leftParen); // ")"
      e = new TraitsExpr(ident, args);
      break;
    } // version(D2)
    default:
      if (token.isIntegralType)
      { // IntegralType . Identifier
        auto type = new IntegralType(token.kind);
        nT();
        set(type, begin);
        require2(T!".");
        auto ident = requireIdentifier(MID.ExpectedIdAfterTypeDot);
        e = new TypeDotIdExpr(type, ident);
      }
      else if (token.isSpecialToken)
      {
        e = new SpecialTokenExpr(token);
        nT();
      }
      else
      {
        error2(MID.ExpectedButFound, "Expression", token);
        e = new IllegalExpr();
        if (!trying)
        { // Insert a dummy token and don't consume current one.
          begin = lexer.insertEmptyTokenBefore(token);
          this.prevToken = begin;
        }
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
    skip(T!"new");

    Expression e;
    Expression[] newArguments, ctorArguments;

    if (tokenIs(T!"(")) // NewArguments
      newArguments = parseArguments();

    if (consumed(T!"class"))
    { // NewAnonymousClassExpr
      if (tokenIs(T!"("))
        ctorArguments = parseArguments();

      BaseClassType[] bases;
      if (!tokenIs(T!"{"))
        bases = parseBaseClasses();

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
        auto lBracket = type.begin;
        backtrackTo(lBracket);

        skip(T!"["); // "["
        auto index = parseExpression();
        requireClosing(T!"]", lBracket); // "]"
        type = set(new ArrayType(type.next, index), lBracket);
      }
      else if (tokenIs(T!"(")) // NewArguments
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
    {
    if (peekNext() != T!"(")
    {
      auto mod = token;
      switch (mod.kind)
      {
      case T!"const", T!"immutable", T!"inout", T!"shared":
        nT();
        auto t = new ModifierType(parseType(), mod, false);
        return set(t, mod);
      default:
      }
    }
    } // version(D2)
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
    Type t;
    if (consumed(T!"!")) // TemplateInstance
      t = new TmplInstanceType(next, ident,
        parseOneOrMoreTemplateArguments());
    else // Identifier
      t = new IdentifierType(next, ident);
    return set(t, begin);
  }

  /// $(BNF TypeofType   := typeof "(" Expression ")" | TypeofReturn
  ////TypeofReturn := typeof "(" return ")")
  Type parseTypeofType()
  {
    auto begin = token;
    skip(T!"typeof");
    auto leftParen = token;
    require2(T!"(");
    Expression e;
    if (tokenIs(T!"return"))
    {
    version(D2)
      nT();
    }
    else
      e = parseExpression();
    requireClosing(T!")", leftParen);
    return set(new TypeofType(e), begin);
  }

  /// $(BNF QualifiedType :=
  //// (this | super | TypeofType | ModuleScopeType? IdentifierType)
  //// ("." IdentifierType)*)
  Type parseQualifiedType()
  {
    auto begin = token;
    Type type;

    if (tokenIs(T!"."))
      type = set(new ModuleScopeType(), begin, begin);
    else if (tokenIs(T!"typeof"))
      type = parseTypeofType();
    else if (tokenIs(T!"this") || tokenIs(T!"super")) { // D2
      type = set(new IdentifierType(null, token), begin, begin);
      nT();
    }
    else
      type = parseIdentifierType();

    while (consumed(T!"."))
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
      auto kind = token;
      nT();
      require2(T!"("); // "("
      auto lParen = prevToken;
      t = parseType(); // Type
      requireClosing(T!")", lParen); // ")"
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
        TOK tok = token.kind;
        nT();
        auto parameters = parseParameterList();
        version(D2)
        parameters.postSTCs = parseFunctionPostfix();
        // TODO: add stcs to t.
        if (tok == T!"function")
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
    if (tokenIs(T!"["))
    { // The previously parsed ArrayType.
      auto prevType = result = parseArrayType(lhsType);
      // Continue parsing ArrayTypes.
      while (tokenIs(T!"["))
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
    skip(T!"[");
    if (consumed(T!"]"))
      t = new ArrayType(t);
    else
    {
      bool success;
      Type parseAAType()
      {
        auto type = parseType();
        require(T!"]");
        return type;
      }
      auto assocType = tryToParse(&parseAAType, success);
      if (success)
        t = new ArrayType(t, assocType);
      else
      {
        Expression e = parseAssignExpr(), e2;
        if (consumed(T!".."))
          e2 = parseAssignExpr();
        requireClosing(T!"]", begin);
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
    while (consumed(T!","));
    return expressions;
  }

  /// Parses a list of AssignExpressions.
  /// Allows a trailing comma.
  /// $(BNF ExpressionList2 := AssignExpr ("," AssignExpr)* ","?)
  Expression[] parseExpressionList2(TOK closing_tok)
  {
    Expression[] expressions;
    while (!tokenIs(closing_tok))
    {
      expressions ~= parseAssignExpr();
      if (!consumed(T!","))
        break;
    }
    return expressions;
  }

  /// Parses a list of Arguments.
  /// $(BNF Arguments := "(" ExpressionList? ")")
  Expression[] parseArguments()
  {
    auto leftParen = token;
    skip(T!"(");
    Expression[] args;
    if (!tokenIs(T!")"))
      args = parseExpressionList2(T!")");
    requireClosing(T!")", leftParen);
    return args;
  }

  /// Parses a ParameterList.
  /// $(BNF ParameterList := "(" Parameters? ")"
  ////Parameters := Parameter ("," Parameter)* ","?
  ////Parameter  := StorageClasses? (Type Name? | Type? Name )
  ////              ("=" AssignExpr)?)
  Parameters parseParameterList()
  {
    auto begin = token;
    require2(T!"(");

    auto params = new Parameters();

    Expression defValue; // Default value.

    while (!tokenIs(T!")"))
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

      if (consumed(T!"..."))
        goto LvariadicParam; // Go to common code and leave the loop.

      while (1)
      { // Parse storage classes.
        switch (token.kind)
        {
        version(D2)
        {
        case T!"const", T!"immutable", T!"inout", T!"shared":
          if (peekNext() == T!"(")
            break;
                         stc = tokenIs(T!"const") ? StorageClass.Const :
                           tokenIs(T!"immutable") ? StorageClass.Immutable :
                               tokenIs(T!"inout") ? StorageClass.Inout :
                                                    StorageClass.Shared;
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
          else
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

      if (consumed(T!"="))
        defValue = parseAssignExpr();
      else if (defValue !is null) // Parsed a defValue previously?
        error(name ? name : type.begin, // Position.
          MID.ExpectedParamDefValue,
          name ? name.text : ""); // Name.

      if (consumed(T!"..."))
      {
        if (stcs & (StorageClass.Ref | StorageClass.Out))
          error(paramBegin, MID.IllegalVariadicParam);
      LvariadicParam:
        stcs |= StorageClass.Variadic;
        pushParameter();
        // TODO: allow trailing comma here? DMD doesn't...
        if (!tokenIs(T!")"))
          error(token, MID.ParamsAfterVariadic);
        break;
      }
      // Add a non-variadic parameter to the list.
      pushParameter();

      if (!consumed(T!","))
        break;
    }
    requireClosing(T!")", begin);
    return set(params, begin);
  }

  /// $(BNF TemplateArgumentsOneOrMore :=
  ////  TemplateArgumentList | TemplateArgumentSingle)
  TemplateArguments parseOneOrMoreTemplateArguments()
  {
    version(D2)
    if (!tokenIs(T!"("))
    { // Parse one TArg, but still put it in TemplateArguments.
      auto targs = new TemplateArguments;
      auto begin = token;
      bool success;
      auto typeArg = tryToParse({
        // Don't parse a full Type. TODO: restrict further?
        return parseBasicType();
      }, success);
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
    auto leftParen = token;
    require2(T!"(");
    targs = !tokenIs(T!")") ?
      parseTemplateArguments_() : new TemplateArguments;
    requireClosing(T!")", leftParen);
    return set(targs, leftParen);
  }

  /// $(BNF TemplateArgumentList2 := TemplateArguments (?= "$(RP)"))
  TemplateArguments parseTemplateArguments2()
  {
    version(D2)
    {
    TemplateArguments targs;
    if (!tokenIs(T!")"))
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
    if (tokenIs(T!",") || tokenIs(T!")"))
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
    while (!tokenIs(T!")"))
    {
      bool success;
      auto typeArgument = tryToParse(&parseTypeArgument, success);
      // TemplateArgument := Type | AssignExpr
      targs ~= success ? typeArgument : parseAssignExpr();
      if (!consumed(T!","))
        break;
    }
    set(targs, begin);
    return targs;
  }

  /// $(BNF Constraint := if "(" ConstraintExpr ")")
  Expression parseOptionalConstraint()
  {
    if (!consumed(T!"if"))
      return null;
    auto leftParen = token;
    require2(T!"(");
    auto e = parseExpression();
    requireClosing(T!")", leftParen);
    return e;
  }

  /// $(BNF TemplateParameterList := "(" TemplateParameters? ")")
  TemplateParameters parseTemplateParameterList()
  {
    auto begin = token;
    auto tparams = new TemplateParameters;
    require2(T!"(");
    if (!tokenIs(T!")"))
      parseTemplateParameterList_(tparams);
    requireClosing(T!")", begin);
    return set(tparams, begin);
  }

  /// $(BNF TemplateParameterList2 := "," TemplateParameters "$(RP)")
  TemplateParameters parseTemplateParameterList2()
  {
  version(D2)
  {
    skip(T!",");
    auto begin = token;
    auto tparams = new TemplateParameters;
    if (!tokenIs(T!")"))
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
    while (!tokenIs(T!")"))
    {
      auto paramBegin = token;
      TemplateParam tp;
      Token* ident;
      Type specType, defType;

      void parseSpecAndOrDefaultType()
      {
        if (consumed(T!":"))  // ":" SpecializationType
          specType = parseType();
        if (consumed(T!"=")) // "=" DefaultType
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
        if (consumed(T!":"))  // ":" Specialization
          spec = parseExpOrType();
        if (consumed(T!"=")) // "=" Default
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
          skip(T!"Identifier"); skip(T!"...");
          if (tokenIs(T!","))
            error(MID.TemplateTupleParameter);
          tp = new TemplateTupleParam(ident);
          break;
        case T!",", T!")", T!":", T!"=": // TemplateTypeParam := Identifier
          skip(T!"Identifier");
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
        Expression specValue, defValue;
        auto valueType = parseDeclarator(ident);
        // ":" SpecializationValue
        if (consumed(T!":"))
          specValue = parseCondExpr();
        // "=" DefaultValue
        if (consumed(T!"="))
          defValue = parseCondExpr();
        tp = new TemplateValueParam(valueType, ident, specValue, defValue);
      }

      // Push template parameter.
      tparams ~= set(tp, paramBegin);

      if (!consumed(T!","))
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

  /// Requires a token of kind tok.
  void require(TOK tok)
  {
    if (!consumed(tok))
      error2(MID.ExpectedButFound, Token.toString(tok), token);
  }

  /// Requires a token of kind tok. Uses the token end as the error location.
  void require2(TOK tok)
  {
    if (!consumed(tok))
      error2_eL(MID.ExpectedButFound, Token.toString(tok), token);
  }

  /// Requires the next token to be of kind tok.
  void requireNext(TOK tok)
  {
    nT();
    require(tok);
  }

  /// Parses an optional identifier.
  /// Returns: null or the identifier.
  Token* optionalIdentifier()
  {
    Token* id = token;
    return consumed(T!"Identifier") ? id : null;
  }

  /// Reports an error if the current token is not an identifier.
  /// Params:
  ///   mid = The error message ID to be used.
  /// Returns: The identifier token or null.
  Token* requireIdentifier(MID mid)
  {
    Token* idtok = token;
    if (!consumed(T!"Identifier"))
    {
      error(token, mid, token.text);
      if (!trying)
      {
        idtok = lexer.insertEmptyTokenBefore(token);
        idtok.kind = T!"Identifier";
        idtok.ident = Ident.Empty;
        this.prevToken = idtok;
      }
      else
        idtok = null;
    }
    return idtok;
  }

  /// Reports an error if the closing counterpart of a token is not found.
  void requireClosing(TOK closing, Token* opening)
  {
    assert(closing == T!"}" || closing == T!")" || closing == T!"]");
    assert(opening !is null);
    if (!consumed(closing))
    {
      auto loc = opening.getErrorLocation(lexer.srcText.filePath);
      error(token, MID.ExpectedClosing,
        Token.toString(closing), opening.text, loc.lineNum, loc.colNum,
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
