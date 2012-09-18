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


  private alias TOK T; /// Used often in this class.
  private alias TypeNode Type;

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
    if (tokenIs(T.Module))
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
  static bool isNodeSet(Node node)
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

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                       Declaration parsing methods                       |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// $(BNF ModuleDecl := module Identifier ("." Identifier)* ";")
  Declaration parseModuleDecl()
  {
    auto begin = token;
    skip(T.Module);
    ModuleFQN moduleFQN;
    Token* typeId;
    version(D2)
    {
    if (consumed(T.LParen))
    {
      typeId = requireIdentifier(MID.ExpectedModuleType);
      auto ident = typeId ? typeId.ident : null;
      if (ident && ident !is Ident.safe && ident !is Ident.system)
        error(typeId, MID.ExpectedModuleType);
      require2(T.RParen);
    }
    } // version(D2)
    do
      moduleFQN ~= requireIdentifier(MID.ExpectedModuleIdentifier);
    while (consumed(T.Dot));
    require2(T.Semicolon);
    return set(new ModuleDecl(typeId, moduleFQN), begin);
  }

  /// Parses DeclarationDefinitions until the end of file is hit.
  /// $(BNF DeclDefs := DeclDef*)
  Declaration[] parseDeclarationDefinitions()
  {
    Declaration[] decls;
    while (!tokenIs(T.EOF))
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
    require(T.LBrace);
    while (!tokenIs(T.RBrace) && !tokenIs(T.EOF))
      decls ~= parseDeclarationDefinition();
    requireClosing(T.RBrace, begin);
    set(decls, begin);

    // Restore original values.
    this.linkageType  = linkageType;
    this.protection   = protection;
    this.storageClass = storageClass;

    return decls;
  }

  /// Parses a DeclarationDefinition.
  ///
  /// $(BNF DeclDef := Attributes | ...)
  Declaration parseDeclarationDefinition()
  out(decl)
  { assert(isNodeSet(decl)); }
  body
  {
    auto begin = token;
    Declaration decl;
    switch (token.kind)
    {
    case T.Align,
         T.Pragma,
         // Protection attributes
         T.Export,
         T.Private,
         T.Package,
         T.Protected,
         T.Public,
         // Storage classes
         T.Extern,
         T.Deprecated,
         T.Override,
         T.Abstract,
         T.Synchronized,
         T.Auto,
         T.Scope,
         //T.Static,
         //T.Const,
         T.Final:
    version(D2)
    {
    case //T.Shared,
         T.Gshared,
         //T.Immutable,
         //T.Inout,
         T.Ref,
         T.Pure,
         T.Nothrow,
         T.Thread,
         T.At:
    } // version(D2)
    case_parseAttributes:
      return parseAttributes();
    case T.Alias:
      nT();
      version (D2)
      {
      if (tokenIs(T.Identifier) && peekNext() == T.This)
      {
        auto ident = token;
        skip(T.Identifier);
        skip(T.This);
        require2(T.Semicolon);
        decl = new AliasThisDecl(ident);
        break;
      }
      } // version(D2)

      auto ad = new AliasDecl(parseAttributes(&decl));
      ad.vardecl = decl;
      if (auto var = decl.Is!(VariablesDecl))
      {
        if (auto init = var.firstInit())
          error(init.begin.prevNWS(), MID.AliasHasInitializer);
      }
      else
        error(decl.begin, MID.AliasExpectsVariable, decl.toText());
      decl = ad;
      break;
    case T.Typedef:
      nT();
      auto td = new TypedefDecl(parseAttributes(&decl));
      td.vardecl = decl;
      if (!decl.Is!(VariablesDecl))
        error(decl.begin, MID.TypedefExpectsVariable, decl.toText());
      decl = td;
      break;
    case T.Static:
      switch (peekNext())
      {
      case T.Import:
        goto case_Import;
      case T.This:
        decl = parseStaticCtorDecl();
        break;
      case T.Tilde:
        decl = parseStaticDtorDecl();
        break;
      case T.If:
        decl = parseStaticIfDecl();
        break;
      case T.Assert:
        decl = parseStaticAssertDecl();
        break;
      default:
        goto case_parseAttributes;
      }
      break;
    case T.Import:
    case_Import:
      auto importDecl = parseImportDecl();
      imports ~= importDecl;
      // Handle specially. StorageClass mustn't be set.
      importDecl.setProtection(this.protection);
      return set(importDecl, begin);
    case T.Enum:
      version(D2)
      if (isEnumManifest())
        goto case_parseAttributes;
      decl = parseEnumDecl();
      break;
    case T.Class:
      decl = parseClassDecl();
      break;
    case T.Interface:
      decl = parseInterfaceDecl();
      break;
    case T.Struct, T.Union:
      decl = parseStructOrUnionDecl();
      break;
    case T.This:
      if (peekNext() == T.LParen)
        decl = parseConstructorDecl();
      else
        goto case_Declaration;
      break;
    case T.Tilde:
      decl = parseDestructorDecl();
      break;
    version(D2)
    {
    case T.Const, T.Immutable, T.Inout, T.Shared:
      if (peekNext() == T.LParen)
        goto case_Declaration;
      goto case_parseAttributes;
    } // version(D2)
    else
    { // D1
    case T.Const:
      goto case_parseAttributes;
    }
    case T.Invariant:
      decl = parseInvariantDecl(); // invariant "(" ")"
      break;
    case T.Unittest:
      decl = parseUnittestDecl();
      break;
    case T.Debug:
      decl = parseDebugDecl();
      break;
    case T.Version:
      decl = parseVersionDecl();
      break;
    case T.Template:
      decl = parseTemplateDecl();
      break;
    case T.New:
      decl = parseNewDecl();
      break;
    case T.Delete:
      decl = parseDeleteDecl();
      break;
    case T.Mixin:
      decl = parseMixin!(MixinDecl, Declaration)();
      break;
    case T.Semicolon:
      nT();
      decl = new EmptyDecl();
      break;
    // Declaration
    version(D2)
    {
    //case T.This:
    case T.Super:
    }
    case T.Identifier, T.Dot, T.Typeof:
    case_Declaration:
      return parseVariableOrFunction(this.storageClass, this.protection,
                                     this.linkageType);
    default:
      if (token.isIntegralType)
        goto case_Declaration;
      else if (tokenIs(T.Module))
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
             !tokenIs(T.RBrace) &&
             !tokenIs(T.EOF));
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
    case T.LBrace:
      auto begin = token;
      nT();
      auto decls = new CompoundDecl;
      while (!tokenIs(T.RBrace) && !tokenIs(T.EOF))
        decls ~= parseDeclarationDefinition();
      requireClosing(T.RBrace, begin);
      d = set(decls, begin);
      break;
    case T.Colon:
      // if (noColon == true)
      //   goto default;
      auto begin = token;
      nT();
      auto begin2 = token;
      auto decls = new CompoundDecl;
      while (!tokenIs(T.RBrace) && !tokenIs(T.EOF))
        decls ~= parseDeclarationDefinition();
      d = set(decls, begin2);
      d = set(new ColonBlockDecl(d), begin);
      break;
    case T.Semicolon:
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

  /// Parses either a VariableDeclaration or a FunctionDeclaration.
  /// $(BNF
  ////VariableOrFunctionDeclaration :=
  ////  AutoDecl | VariableDecl | FunctionDecl
  ////AutoDecl      := AutoVariable | AutoTemplate
  ////AutoVariable  := Name "=" Initializer MoreVariables? ";"
  ////VariableDec   :=
  ////  Type Name TypeSuffix? ("=" Initializer)? MoreVariables? ";"
  ////MoreVariables := ("," Name ("=" Initializer)?)+
  ////FunctionDec   :=
  ////  Type Name TemplateParameterList? ParameterList FunctionBody
  ////AutoTemplate  := Name TemplateParameterList ParameterList FunctionBody
  ////Name          := Identifier
  ////)
  /// Params:
  ///   stcs = Previously parsed storage classes.
  ///   protection = Previously parsed protection attribute.
  ///   linkType = Previously parsed linkage type.
  ///   testAutoDeclaration = Whether to check for an AutoDeclaration.
  Declaration parseVariableOrFunction(
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

    // Check for AutoDeclaration: StorageClasses Identifier =
    if (testAutoDeclaration && tokenIs(T.Identifier))
    {
      auto next_kind = peekNext();
      if (next_kind == T.Equal) // "auto" Identifier "="
      { // Auto variable declaration.
        name = token;
        skip(T.Identifier);
        goto LparseVariables;
      }
      else version(D2) if (next_kind == T.LParen)
      { // Check for auto return type (template) function.
        // StorageClasses Name
        //  ("(" TemplateParameterList ")")? "(" ParameterList ")"
        auto peek_token = peekAfter(token); // Skip the Identifier.
        peek_token = skipParens(peek_token, T.RParen);
        next_kind = peek_token.kind; // Token after "(" ... ")"
        if (next_kind == T.LParen)
        { // "(" TemplateParameterList ")" "(" ParameterList ")"
          name = token;
          skip(T.Identifier);
          assert(tokenIs(T.LParen));
          goto LparseTPList; // Continue with parsing a template function.
        }
        else
        if (next_kind == T.LBrace || isFunctionPostfix(peek_token) ||
            next_kind == T.In || next_kind == T.Out || next_kind == T.Body)
        { // "(" ParameterList ")" ("{" | FunctionPostfix | in | out | body)
          name = token;
          skip(T.Identifier);
          assert(tokenIs(T.LParen));
          goto LparseBeforeParams;
        }
      } // version(D2)
    }

    // VariableType or ReturnType
    type = parseBasicTypes();

    if (peekNext() == T.LParen)
    { // ReturnType FunctionName "(" ParameterList ")" FunctionBody
      name = requireIdentifier(MID.ExpectedFunctionName);
      if (!tokenIs(T.LParen))
        nT(); // Skip non-identifier token.

    LparseBeforeTParams:
      assert(tokenIs(T.LParen));
      if (tokenAfterParenIs(T.LParen))
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
    while (consumed(T.Comma))
    {
      names ~= requireIdentifier(MID.ExpectedVariableName);
    LenterLoop:
      values ~= consumed(T.Equal) ? parseInitializer() : null;
    }
    require2(T.Semicolon);
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
    if (tokenIs(T.Void))
    {
      auto next = peekNext();
      if (next == T.Comma || next == T.Semicolon)
        return skip(T.Void), set(new VoidInitExpr(), prevToken);
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
    case T.LBracket:
      auto after_bracket = tokenAfterBracket(T.RBracket);
      if (after_bracket != T.Comma && after_bracket != T.RBracket &&
          after_bracket != T.RBrace && after_bracket != T.Semicolon)
        goto default; // Parse as an AssignExpr.
      // ArrayInitializer := "[" ArrayInitElements? "]"
      Expression[] keys, values;

      skip(T.LBracket);
      while (!tokenIs(T.RBracket))
      {
        Expression key;
        auto value = parseNonVoidInitializer();
        if (consumed(T.Colon))
          (key = value), // Switch roles.
          assert(!(key.Is!(ArrayInitExpr) || key.Is!(StructInitExpr))),
          value = parseNonVoidInitializer(); // Parse actual value.
        keys ~= key;
        values ~= value;
        if (!consumed(T.Comma))
          break;
      }
      requireClosing(T.RBracket, begin);
      init = new ArrayInitExpr(keys, values);
      break;
    case T.LBrace:
      auto after_bracket = tokenAfterBracket(T.RBrace);
      if (after_bracket != T.Comma && after_bracket != T.RBrace &&
          after_bracket != T.RBracket && after_bracket != T.Semicolon)
        goto default; // Parse as an AssignExpr.
      // StructInitializer := "{" StructInitElements? "}"
      Token*[] idents;
      Expression[] values;

      skip(T.LBrace);
      while (!tokenIs(T.RBrace))
      { // Peek for colon to see if this is a member identifier.
        Token* ident;
        if (tokenIs(T.Identifier) && peekNext() == T.Colon)
          (ident = token),
          skip(T.Identifier), skip(T.Colon); // Identifier ":"
        idents ~= ident;
        values ~= parseNonVoidInitializer();
        if (!consumed(T.Comma))
          break;
      }
      requireClosing(T.RBrace, begin);
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
      case T.LBrace:
        funcBody = parseStatements();
        break Loop;
      case T.Semicolon:
        nT();
        break Loop;
      case T.In:
        if (inBody)
          error(MID.InContract);
        nT();
        inBody = parseStatements();
        break;
      case T.Out:
        if (outBody)
          error(MID.OutContract);
        nT();
        if (consumed(T.LParen))
          (outIdent = requireIdentifier(MID.ExpectedAnIdentifier)),
          require2(T.RParen);
        outBody = parseStatements();
        break;
      case T.Body:
        // if (!outBody || !inBody) // TODO:
        //   error2(MID.ExpectedInOutBody, token);
        nT();
        goto case T.LBrace;
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
      case T.Const:     stc = StorageClass.Const;     break;
      case T.Immutable: stc = StorageClass.Immutable; break;
      case T.Inout:     stc = StorageClass.Inout;      break;
      case T.Nothrow:   stc = StorageClass.Nothrow;   break;
      case T.Shared:    stc = StorageClass.Shared;    break;
      case T.Pure:      stc = StorageClass.Pure;      break;
      case T.At:        stc = parseAtAttribute();     break;
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
    case T.Const, T.Immutable, T.Inout, T.Nothrow, T.Shared, T.Pure, T.At:
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

    skip(T.Extern), skip(T.LParen); // extern "("

    if (consumed(T.RParen))
    { // extern "(" ")"
      error(MID.MissingLinkageType);
      return linkageType;
    }

    auto idtok = requireIdentifier(MID.ExpectedLinkageIdentifier);

    switch (idtok.ident.idKind)
    {
    case IDK.C:       linkageType = consumed(T.Plus2) ?
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
    require2(T.RParen);
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
    scope AttributeDecl headAttr =
      new StorageClassDecl(StorageClass.None, emptyDecl);

    AttributeDecl currentAttr = headAttr, prevAttr = headAttr;

    // Parse the attributes.
  Loop:
    while (1)
    {
      auto begin = token;
      switch (token.kind)
      {
      case T.Extern:
        if (peekNext() == T.LParen)
        {
          checkLinkageType(linkageType, parseExternLinkageType(), begin);
          currentAttr = new LinkageDecl(linkageType, emptyDecl);
          testAutoDecl = false;
          break;
        }
                           stc = StorageClass.Extern;       goto Lcommon;
      case T.Override:     stc = StorageClass.Override;     goto Lcommon;
      case T.Deprecated:   stc = StorageClass.Deprecated;   goto Lcommon;
      case T.Abstract:     stc = StorageClass.Abstract;     goto Lcommon;
      case T.Synchronized: stc = StorageClass.Synchronized; goto Lcommon;
      case T.Static:
        switch (peekNext())
        { // Avoid parsing static import, static this etc.
        case T.Import, T.This, T.Tilde, T.If, T.Assert:
          break Loop;
        default:
        }
                           stc = StorageClass.Static;       goto Lcommon;
      case T.Final:        stc = StorageClass.Final;        goto Lcommon;
      version(D2)
      {
      case T.Const, T.Immutable, T.Inout, T.Shared:
        if (peekNext() == T.LParen)
          break Loop;
                           stc = tokenIs(T.Const) ? StorageClass.Const :
                             tokenIs(T.Immutable) ? StorageClass.Immutable :
                                 tokenIs(T.Inout) ? StorageClass.Inout :
                                                    StorageClass.Shared;
        goto Lcommon;
      case T.Enum:
        if (!isEnumManifest())
          break Loop;
                           stc = StorageClass.Manifest;     goto Lcommon;
      case T.Ref:          stc = StorageClass.Ref;          goto Lcommon;
      case T.Pure:         stc = StorageClass.Pure;         goto Lcommon;
      case T.Nothrow:      stc = StorageClass.Nothrow;      goto Lcommon;
      case T.Gshared:      stc = StorageClass.Gshared;      goto Lcommon;
      case T.Thread:       stc = StorageClass.Thread;       goto Lcommon;
      case T.At:           stc = parseAtAttribute();        goto Lcommon;
      } // version(D2)
      else
      { // D1
      case T.Const:        stc = StorageClass.Const;        goto Lcommon;
      }
      case T.Auto:         stc = StorageClass.Auto;         goto Lcommon;
      case T.Scope:        stc = StorageClass.Scope;        goto Lcommon;
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
      case T.Private:   prot = Protection.Private;   goto Lprot;
      case T.Package:   prot = Protection.Package;   goto Lprot;
      case T.Protected: prot = Protection.Protected; goto Lprot;
      case T.Public:    prot = Protection.Public;    goto Lprot;
      case T.Export:    prot = Protection.Export;    goto Lprot;
      Lprot:
        if (protection != Protection.None)
          error2(MID.RedundantProtection, token);
        protection = prot;
        nT();
        currentAttr = new ProtectionDecl(prot, emptyDecl);
        testAutoDecl = false;
        break;
      case T.Align:
        // align ("(" Integer ")")?
        Token* sizetok;
        alignSize = parseAlignAttribute(sizetok);
        // TODO: error msg for redundant align attributes.
        currentAttr = new AlignDecl(sizetok, emptyDecl);
        testAutoDecl = false;
        break;
      case T.Pragma:
        // Pragma := pragma "(" Identifier ("," ExpressionList)? ")"
        nT();
        Token* ident;

        auto leftParen = token;
        require2(T.LParen);
        ident = requireIdentifier(MID.ExpectedPragmaIdentifier);
        auto args = consumed(T.Comma) ? parseExpressionList() : null;
        requireClosing(T.RParen, leftParen);

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
    if (testAutoDecl && tokenIs(T.Identifier)) // "auto" Identifier "="
      decl = // This could be a normal Declaration or an AutoDeclaration
        parseVariableOrFunction(stcs, protection, linkageType, true);
    else
      // Parse a block.
      decl = parseDeclarationsBlock();
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
    skip(T.Align);
    uint size;
    if (consumed(T.LParen))
    {
      if (tokenIs(T.Int32))
        (sizetok = token), (size = token.int_), skip(T.Int32);
      else
        expected(T.Int32);
      require2(T.RParen);
    }
    return size;
  }

  /// $(BNF AtAttribute := "@" Identifier)
  StorageClass parseAtAttribute()
  {
    skip(T.At); // "@"
    auto idtok = tokenIs(T.Identifier) ?
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
    bool isStatic = consumed(T.Static);
    skip(T.Import);

    ModuleFQN[] moduleFQNs;
    Token*[] moduleAliases;
    Token*[] bindNames;
    Token*[] bindAliases;

    do
    {
      ModuleFQN moduleFQN;
      Token* moduleAlias;
      // AliasName = ModuleName
      if (peekNext() == T.Equal)
      {
        moduleAlias = requireIdentifier(MID.ExpectedAliasModuleName);
        skip(T.Equal);
      }
      // Identifier ("." Identifier)*
      do
        moduleFQN ~= requireIdentifier(MID.ExpectedModuleIdentifier);
      while (consumed(T.Dot));
      // Push identifiers.
      moduleFQNs ~= moduleFQN;
      moduleAliases ~= moduleAlias;
    } while (consumed(T.Comma));

    if (consumed(T.Colon))
    { // ImportBind := (BindAlias "=")? BindName
      // ":" ImportBind ("," ImportBind)*
      do
      {
        Token* bindAlias;
        // BindAlias = BindName
        if (peekNext() == T.Equal)
        {
          bindAlias = requireIdentifier(MID.ExpectedAliasImportName);
          skip(T.Equal);
        }
        // Push identifiers.
        bindNames ~= requireIdentifier(MID.ExpectedImportName);
        bindAliases ~= bindAlias;
      } while (consumed(T.Comma));
    }
    require2(T.Semicolon);

    return new ImportDecl(moduleFQNs, moduleAliases, bindNames,
                                 bindAliases, isStatic);
  }

  /// Returns true if this is an enum manifest or
  /// false if it's a normal enum declaration.
  bool isEnumManifest()
  {
    version(D2)
    {
    assert(tokenIs(T.Enum));
    auto next = peekAfter(token);
    auto kind = next.kind;
    if (kind == T.Colon || kind == T.LBrace)
      return false; // Anonymous enum.
    else if (kind == T.Identifier)
    {
      kind = peekAfter(next).kind;
      if (kind == T.Colon || kind == T.LBrace || kind == T.Semicolon)
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
    skip(T.Enum);

    Token* enumName;
    Type baseType;
    EnumMemberDecl[] members;

    enumName = optionalIdentifier();

    if (consumed(T.Colon))
      baseType = parseBasicType();

    if (enumName && consumed(T.Semicolon))
    {}
    else if (auto leftBrace = consumedToken(T.LBrace)) // "{"
    {
      while (!tokenIs(T.RBrace))
      {
        Token* begin = token,
               name; // Name of the enum member.
        Type type; // Optional member type.
        Expression value; // Optional value.

        version(D2)
        {
        auto kind = peekNext();
        if (kind != T.Equal && kind != T.Comma && kind != T.RBrace)
          type = parseType();
        }

        name = requireIdentifier(MID.ExpectedEnumMember);

        if (consumed(T.Equal)) // "=" AssignExpr
          value = parseAssignExpr();

        auto member = new EnumMemberDecl(type, name, value);
        members ~= set(member, begin);

        if (!consumed(T.Comma))
          break;
      }
      requireClosing(T.RBrace, leftBrace); // "}"
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
    skip(T.Class);

    Token* name;
    TemplateParameters tparams;
    Expression constraint;
    BaseClassType[] bases;
    CompoundDecl decls;

    name = requireIdentifier(MID.ExpectedClassName);

    if (tokenIs(T.LParen))
    {
      tparams = parseTemplateParameterList();
      version(D2) constraint = parseOptionalConstraint();
    }

    if (consumed(T.Colon))
      bases = parseBaseClasses();

    if (bases.length == 0 && consumed(T.Semicolon))
    {}
    else if (tokenIs(T.LBrace))
      decls = parseDeclarationDefinitionsBody();
    else
      error2(MID.ExpectedClassBody, token);

    Declaration d = new ClassDecl(name, /+tparams, +/bases, decls);
    if (tparams)
      d = putInsideTemplateDeclaration(begin, name, d, tparams, constraint);
    return d;
  }

  /// $(BNF BaseClasses := BaseClass ("," BaseClass)
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
      case T.Identifier, T.Dot, T.Typeof: goto LparseBasicType;
      case T.Private:   prot = Protection.Private;   break;
      case T.Protected: prot = Protection.Protected; break;
      case T.Package:   prot = Protection.Package;   break;
      case T.Public:    prot = Protection.Public;    break;
      default:
        error2(MID.ExpectedBaseClasses, token);
        return bases;
      }
      nT(); // Skip protection attribute.
    LparseBasicType:
      auto begin = token;
      auto type = parseBasicType();
      bases ~= set(new BaseClassType(prot, type), begin);
    } while (consumed(T.Comma));
    return bases;
  }

  /// $(BNF InterfaceDecl :=
  ////  interface Name TemplateParameterList? (":" BaseClasses) InterfaceBody |
  ////  interface Name ";"
  ////InterfaceBody := DeclDefsBlock)
  Declaration parseInterfaceDecl()
  {
    auto begin = token;
    skip(T.Interface);

    Token* name;
    TemplateParameters tparams;
    Expression constraint;
    BaseClassType[] bases;
    CompoundDecl decls;

    name = requireIdentifier(MID.ExpectedInterfaceName);

    if (tokenIs(T.LParen))
    {
      tparams = parseTemplateParameterList();
      version(D2) constraint = parseOptionalConstraint();
    }

    if (consumed(T.Colon))
      bases = parseBaseClasses();

    if (bases.length == 0 && consumed(T.Semicolon))
    {}
    else if (tokenIs(T.LBrace))
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
    assert(tokenIs(T.Struct) || tokenIs(T.Union));
    auto begin = token;
    nT();

    Token* name;
    TemplateParameters tparams;
    Expression constraint;
    CompoundDecl decls;

    name = optionalIdentifier();

    if (name && tokenIs(T.LParen))
    {
      tparams = parseTemplateParameterList();
      version(D2) constraint = parseOptionalConstraint();
    }

    if (name && consumed(T.Semicolon))
    {}
    else if (tokenIs(T.LBrace))
      decls = parseDeclarationDefinitionsBody();
    else
      error2(begin.kind == T.Struct ?
             MID.ExpectedStructBody : MID.ExpectedUnionBody, token);

    Declaration d;
    if (begin.kind == T.Struct)
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
    skip(T.This);
    if (tokenIs(T.LParen) && tokenAfterParenIs(T.LParen))
      tparams = parseTemplateParameterList(); // "(" TemplateParameterList ")"
    Parameters parameters = new Parameters();
    if (peekNext() != T.This)
      parameters = parseParameterList(); // "(" ParameterList ")"
    else // TODO: Create own class PostBlit?: this "(" this ")"
      require2(T.LParen), skip(T.This), require2(T.RParen);
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
    skip(T.This);
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new ConstructorDecl(parameters, funcBody);
    }
  }

  /// $(BNF DestructorDecl := "~" this "(" ")" FunctionBody)
  Declaration parseDestructorDecl()
  {
    skip(T.Tilde);
    require2(T.This);
    require2(T.LParen);
    require2(T.RParen);
    auto funcBody = parseFunctionBody();
    return new DestructorDecl(funcBody);
  }

  /// $(BNF StaticCtorDecl := static this "(" ")" FunctionBody)
  Declaration parseStaticCtorDecl()
  {
    skip(T.Static);
    skip(T.This);
    require2(T.LParen);
    require2(T.RParen);
    auto funcBody = parseFunctionBody();
    return new StaticCtorDecl(funcBody);
  }

  /// $(BNF
  ////StaticDtorDecl := static "~" this "(" ")" FunctionBody)
  Declaration parseStaticDtorDecl()
  {
    skip(T.Static);
    skip(T.Tilde);
    require2(T.This);
    require2(T.LParen);
    require2(T.RParen);
    auto funcBody = parseFunctionBody();
    return new StaticDtorDecl(funcBody);
  }

  /// $(BNF InvariantDecl := invariant ("(" ")")? FunctionBody)
  Declaration parseInvariantDecl()
  {
    skip(T.Invariant);
    // Optional () for getting ready porting to D 2.0
    if (consumed(T.LParen))
      require2(T.RParen);
    auto funcBody = parseFunctionBody();
    return new InvariantDecl(funcBody);
  }

  /// $(BNF UnittestDecl := unittest FunctionBody)
  Declaration parseUnittestDecl()
  {
    skip(T.Unittest);
    if (!tokenIs(T.LBrace))
      error2(MID.ExpectedUnittestBody, token);
    auto funcBody = parseFunctionBody();
    return new UnittestDecl(funcBody);
  }

  /// Parses an identifier or an integer. Reports an error otherwise.
  /// $(BNF IdentOrInt := Identifier | Integer)
  Token* parseIdentOrInt()
  {
    if (consumed(T.Identifier) || consumed(T.Int32))
      return this.prevToken;
    error2(MID.ExpectedIdentOrInt, token);
    return null;
  }

  /// $(BNF VersionCondition := unittest #*D2.0*# | IdentOrInt)
  Token* parseVersionCondition()
  {
    version(D2)
    if (auto t = consumedToken(T.Unittest))
      return t;
    return parseIdentOrInt();
  }

  /// $(BNF DebugDecl :=
  ////  debug "=" IdentOrInt ";" |
  ////  debug DebugCondition? DeclsBlock (else DeclsBlock)?
  ////DebugCondition := "(" IdentOrInt ")")
  Declaration parseDebugDecl()
  {
    skip(T.Debug);

    Token* spec;
    Token* cond;
    Declaration decls, elseDecls;

    if (consumed(T.Equal))
    { // debug = Integer ;
      // debug = Identifier ;
      spec = parseIdentOrInt();
      require2(T.Semicolon);
    }
    else
    { // "(" Condition ")"
      if (consumed(T.LParen))
      {
        cond = parseIdentOrInt();
        require2(T.RParen);
      }
      // debug DeclsBlock
      // debug ( Condition ) DeclsBlock
      decls = parseDeclarationsBlock();
      // else DeclsBlock
      if (consumed(T.Else))
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
    skip(T.Version);

    Token* spec;
    Token* cond;
    Declaration decls, elseDecls;

    if (consumed(T.Equal))
    { // version = Integer ;
      // version = Identifier ;
      spec = parseIdentOrInt();
      require2(T.Semicolon);
    }
    else
    { // ( Condition )
      require2(T.LParen);
      cond = parseVersionCondition();
      require2(T.RParen);
      // version ( Condition ) DeclsBlock
      decls = parseDeclarationsBlock();
      // else DeclsBlock
      if (consumed(T.Else))
        elseDecls = parseDeclarationsBlock();
    }

    return new VersionDecl(spec, cond, decls, elseDecls);
  }

  /// $(BNF StaticIfDecl :=
  ////  static if "(" AssignExpr ")" DeclsBlock (else DeclsBlock)?)
  Declaration parseStaticIfDecl()
  {
    skip(T.Static);
    skip(T.If);

    Expression condition;
    Declaration ifDecls, elseDecls;

    auto leftParen = token;
    require2(T.LParen);
    condition = parseAssignExpr();
    requireClosing(T.RParen, leftParen);

    ifDecls = parseDeclarationsBlock();

    if (consumed(T.Else))
      elseDecls = parseDeclarationsBlock();

    return new StaticIfDecl(condition, ifDecls, elseDecls);
  }

  /// $(BNF StaticAssertDecl :=
  ////  static assert "(" AssignExpr ("," Message)? ")" ";"
  ////Message          := AssignExpr)
  Declaration parseStaticAssertDecl()
  {
    skip(T.Static);
    skip(T.Assert);
    Expression condition, message;
    auto leftParen = token;
    require2(T.LParen);
    condition = parseAssignExpr();
    if (consumed(T.Comma))
      message = parseAssignExpr();
    requireClosing(T.RParen, leftParen);
    require2(T.Semicolon);
    return new StaticAssertDecl(condition, message);
  }

  /// $(BNF TemplateDecl :=
  ////  template Name TemplateParameterList Constraint? DeclDefsBlock)
  TemplateDecl parseTemplateDecl()
  {
    skip(T.Template);
    auto name = requireIdentifier(MID.ExpectedTemplateName);
    auto tparams = parseTemplateParameterList();
    auto constraint = parseOptionalConstraint();
    auto decls = parseDeclarationDefinitionsBody();
    return new TemplateDecl(name, tparams, constraint, decls);
  }

  /// $(BNF NewDecl := new ParameterList FunctionBody)
  Declaration parseNewDecl()
  {
    skip(T.New);
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new NewDecl(parameters, funcBody);
  }

  /// $(BNF DeleteDecl := delete ParameterList FunctionBody)
  Declaration parseDeleteDecl()
  {
    skip(T.Delete);
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new DeleteDecl(parameters, funcBody);
  }

  /// $(BNF TypeofType   := typeof "(" Expression ")" | TypeofReturn
  ////TypeofReturn := typeof "(" return ")")
  Type parseTypeofType()
  {
    auto begin = token;
    skip(T.Typeof);
    auto leftParen = token;
    require2(T.LParen);
    Expression e;
    if (tokenIs(T.Return))
    {
    version(D2)
      nT();
    }
    else
      e = parseExpression();
    auto type = new TypeofType(e);
    requireClosing(T.RParen, leftParen);
    set(type, begin);
    return type;
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
    skip(T.Mixin);

    static if (is(Class == MixinDecl))
    {
    if (consumed(T.LParen))
    {
      auto leftParen = token;
      auto e = parseAssignExpr();
      requireClosing(T.RParen, leftParen);
      require2(T.Semicolon);
      return new MixinDecl(e);
    }
    else version(D2) if (tokenIs(T.Template))
    {
      auto d = parseTemplateDecl();
      d.isMixin = true;
      return d;
    } // version(D2)
    }

    auto e = parseIdentifiersExpr();
    auto mixinIdent = optionalIdentifier();
    require2(T.Semicolon);

    return new Class(e, mixinIdent);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                        Statement parsing methods                        |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// $(BNF Statements := "{" Statement* "}")
  CompoundStmt parseStatements()
  {
    auto begin = token;
    require(T.LBrace);
    auto statements = new CompoundStmt();
    while (!tokenIs(T.RBrace) && !tokenIs(T.EOF))
      statements ~= parseStatement();
    requireClosing(T.RBrace, begin);
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
      d = parseVariableOrFunction();
      goto LreturnDeclarationStmt;
    }

    switch (token.kind)
    {
    case T.Align:
      Token* sizetok;
      uint size = parseAlignAttribute(sizetok);
      // Restrict align attribute to structs in parsing phase.
      StructDecl structDecl;
      if (tokenIs(T.Struct))
      {
        auto begin2 = token;
        structDecl = parseStructOrUnionDecl().to!(StructDecl);
        structDecl.setAlignSize(size);
        set(structDecl, begin2);
      }
      else
        expected(T.Struct);

      d = structDecl ? cast(Declaration)structDecl : new CompoundDecl;
      d = new AlignDecl(sizetok, d);
      goto LreturnDeclarationStmt;

    case T.Extern, T.Const, T.Auto:
         //T.Final, T.Scope, T.Static:
    version(D2)
    {
    case T.Immutable, T.Inout, T.Pure, T.Shared, T.Gshared,
         T.Ref, T.Nothrow, T.Thread, T.At:
    }
      goto case_parseAttribute;

    case T.Identifier:
      if (peekNext() == T.Colon)
      {
        skip(T.Identifier); skip(T.Colon);
        s = new LabeledStmt(begin, parseNoScopeOrEmptyStmt());
        break;
      }
      goto case T.Dot;
    version(D2)
    {
    case T.This, T.Super:
    }
    case T.Dot, T.Typeof:
      bool success;
      d = tryToParse({ return parseVariableOrFunction(); }, success);
      if (success)
        goto LreturnDeclarationStmt; // Declaration
      else
        goto case_parseExpressionStmt; // Expression

    case T.If:             s = parseIfStmt();            break;
    case T.While:          s = parseWhileStmt();         break;
    case T.Do:             s = parseDoWhileStmt();       break;
    case T.For:            s = parseForStmt();           break;
    case T.Foreach,
         T.ForeachReverse: s = parseForeachStmt();       break;
    case T.Switch:         s = parseSwitchStmt();        break;
    case T.Case:           s = parseCaseStmt();          break;
    case T.Default:        s = parseDefaultStmt();       break;
    case T.Continue:       s = parseContinueStmt();      break;
    case T.Break:          s = parseBreakStmt();         break;
    case T.Return:         s = parseReturnStmt();        break;
    case T.Goto:           s = parseGotoStmt();          break;
    case T.With:           s = parseWithStmt();          break;
    case T.Synchronized:   s = parseSynchronizedStmt();  break;
    case T.Try:            s = parseTryStmt();           break;
    case T.Throw:          s = parseThrowStmt();         break;
    case T.Volatile:       s = parseVolatileStmt();      break;
    case T.Asm:            s = parseAsmBlockStmt();      break;
    case T.Pragma:         s = parsePragmaStmt();        break;
    case T.Debug:          s = parseDebugStmt();         break;
    case T.Version:        s = parseVersionStmt();       break;
    case T.LBrace:         s = parseScopeStmt();         break;
    case T.Semicolon: nT(); s = new EmptyStmt();         break;
    case_T_Scope:          s = parseScopeGuardStmt();    break;
    case_T_Mixin:          s = parseMixin!(MixinStmt)(); break;
    case_parseAttribute:   s = parseAttributeStmt();     break;
    case T.Scope:
      if (peekNext() != T.LParen)
        goto case_parseAttribute;
      goto case_T_Scope;
    case T.Mixin:
      if (peekNext() == T.LParen)
        goto case_parseExpressionStmt; // Parse as expression.
      goto case_T_Mixin;
    case T.Final:
      version(D2)
      {
      if (peekNext() == T.Switch)
        goto case T.Switch;
      }
      goto case_parseAttribute;
    case T.Static:
      switch (peekNext())
      {
      case T.If:     s = parseStaticIfStmt();     break;
      case T.Assert: s = parseStaticAssertStmt(); break;
      default:       goto case_parseAttribute;
      }
      break;
    // DeclDef
    case T.Alias, T.Typedef:
      d = parseDeclarationDefinition();
      goto LreturnDeclarationStmt;
    case T.Enum:
      version(D2)
      if (isEnumManifest())
        goto case_parseAttribute;
      d = parseEnumDecl();
      goto LreturnDeclarationStmt;
    case T.Class:
      d = parseClassDecl();
      goto LreturnDeclarationStmt;
    case T.Import:
      version(D2)
      {
      if (peekNext() != T.LParen)
      {
        d = parseImportDecl();
        goto LreturnDeclarationStmt;
      }
      }
      goto case_parseExpressionStmt;
    case T.Interface:
      d = parseInterfaceDecl();
      goto LreturnDeclarationStmt;
    case T.Struct, T.Union:
      d = parseStructOrUnionDecl();
      // goto LreturnDeclarationStmt;
    LreturnDeclarationStmt:
      set(d, begin);
      s = new DeclarationStmt(d);
      break;
    // Parse an ExpressionStmt:
    // Tokens that start a PrimaryExpr.
    // case T.Identifier, T.Dot, T.Typeof:
    version(D1)
    {
    case T.This:
    case T.Super:
    }
    case T.Null:
    case T.True, T.False:
    // case T.Dollar:
    case T.Int32, T.Int64, T.UInt32, T.UInt64:
    case T.Float32, T.Float64, T.Float80,
         T.IFloat32, T.IFloat64, T.IFloat80:
    case T.Character:
    case T.String:
    case T.LBracket:
    // case T.LBrace:
    case T.Function, T.Delegate:
    case T.Assert:
    // case T.Mixin:
    case T.Typeid:
    case T.Is:
    case T.LParen:
    version(D2)
    {
    case T.Traits:
    }
    // Tokens that can start a UnaryExpr:
    case T.Amp, T.Plus2, T.Minus2, T.Star, T.Minus,
         T.Plus, T.Exclaim, T.Tilde, T.New, T.Delete, T.Cast:
    case_parseExpressionStmt:
      s = new ExpressionStmt(parseExpression());
      require2(T.Semicolon);
      break;
    default:
      if (token.isSpecialToken)
        goto case_parseExpressionStmt;

      if (!tokenIs(T.Dollar))
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
             !tokenIs(T.RBrace) &&
             !tokenIs(T.EOF));
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
    if (tokenIs(T.LBrace))
      s = parseStatements();
    else
    {
      if (tokenIs(T.Semicolon))
        error(MID.ExpectedNonEmptyStatement, token);
      s = parseStatement();
    }
    return s;
  }

  /// $(BNF NoScopeOrEmptyStmt := ";" | NoScopeStmt)
  Statement parseNoScopeOrEmptyStmt()
  {
    if (auto semicolon = consumedToken(T.Semicolon))
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
      case T.Extern:
        if (peekNext() == T.LParen)
        {
          checkLinkageType(linkageType, parseExternLinkageType(), begin);
          currentAttr = new LinkageDecl(linkageType, emptyDecl);
          testAutoDecl = false;
          break;
        }
                        stc = StorageClass.Extern; goto Lcommon;
      case T.Static:    stc = StorageClass.Static; goto Lcommon;
      case T.Final:     stc = StorageClass.Final;  goto Lcommon;
      version(D2)
      {
      case T.Const, T.Immutable, T.Inout, T.Shared:
        if (peekNext() == T.LParen)
          break Loop;
                        stc = tokenIs(T.Const) ? StorageClass.Const :
                          tokenIs(T.Immutable) ? StorageClass.Immutable :
                              tokenIs(T.Inout) ? StorageClass.Inout :
                                                 StorageClass.Shared;
        goto Lcommon;
      case T.Enum:
        if (!isEnumManifest())
          break Loop;
                        stc = StorageClass.Manifest; goto Lcommon;
      case T.Ref:       stc = StorageClass.Ref;      goto Lcommon;
      case T.Pure:      stc = StorageClass.Pure;     goto Lcommon;
      case T.Nothrow:   stc = StorageClass.Nothrow;  goto Lcommon;
      case T.Gshared:   stc = StorageClass.Gshared;  goto Lcommon;
      case T.Thread:    stc = StorageClass.Thread;   goto Lcommon;
      case T.At:        stc = parseAtAttribute();    goto Lcommon;
      } // version(D2)
      else
      { // D1
      case T.Const:     stc = StorageClass.Const;    goto Lcommon;
      }
      case T.Auto:      stc = StorageClass.Auto;     goto Lcommon;
      case T.Scope:     stc = StorageClass.Scope;    goto Lcommon;
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
    case T.Class, T.Interface, T.Struct, T.Union,
         T.Alias, T.Typedef, T.Enum:
      // Set current values.
      this.storageClass = stcs;
      this.linkageType = linkageType;
      // Parse a declaration.
      decl = parseDeclarationDefinition();
      // Clear values.
      this.storageClass = StorageClass.None;
      this.linkageType = LinkageType.None;
      break;
    case T.Template: // TODO:
      // error2("templates are not allowed in functions", token);
      //break;
    default:
      decl =
        parseVariableOrFunction(stcs, protection, linkageType, testAutoDecl);
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
    skip(T.If);

    Declaration variable;
    Expression condition;
    Statement ifBody, elseBody;

    auto leftParen = token;
    require2(T.LParen);

    Type type;
    Token* name;
    auto begin = token; // For start of AutoDecl or normal Declaration.
    bool success;

    tryToParse({
      if (consumed(T.Auto)) // auto Identifier = Expression
        name = requireIdentifier(MID.ExpectedVariableName);
      else // Declarator "=" Expression
        type = parseDeclarator(name);
      require(T.Equal);
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

    requireClosing(T.RParen, leftParen);
    ifBody = parseScopeStmt();
    if (consumed(T.Else))
      elseBody = parseScopeStmt();
    return new IfStmt(variable, condition, ifBody, elseBody);
  }

  /// $(BNF WhileStmt := while "(" Expression ")" ScopeStmt)
  Statement parseWhileStmt()
  {
    skip(T.While);
    auto leftParen = token;
    require2(T.LParen);
    auto condition = parseExpression();
    requireClosing(T.RParen, leftParen);
    return new WhileStmt(condition, parseScopeStmt());
  }

  /// $(BNF DoWhileStmt := do ScopeStmt while "(" Expression ")")
  Statement parseDoWhileStmt()
  {
    skip(T.Do);
    auto doBody = parseScopeStmt();
    require(T.While);
    auto leftParen = token;
    require2(T.LParen);
    auto condition = parseExpression();
    requireClosing(T.RParen, leftParen);
    version(D2)
    require2(T.Semicolon);
    return new DoWhileStmt(condition, doBody);
  }

  /// $(BNF ForStmt :=
  ////  for "(" (NoScopeStmt | ";") Expression? ";" Expression? ")"
  ////    ScopeStmt)
  Statement parseForStmt()
  {
    skip(T.For);

    Statement init, forBody;
    Expression condition, increment;

    auto leftParen = token;
    require2(T.LParen);
    if (!consumed(T.Semicolon))
      init = parseNoScopeStmt();
    if (!tokenIs(T.Semicolon))
      condition = parseExpression();
    require2(T.Semicolon);
    if (!tokenIs(T.RParen))
      increment = parseExpression();
    requireClosing(T.RParen, leftParen);
    forBody = parseScopeStmt();
    return new ForStmt(init, condition, increment, forBody);
  }

  /// $(BNF ForeachStmt :=
  ////  Foreach "(" ForeachVarList ";" Aggregate ")"
  ////    ScopeStmt
  ////Foreach        := foreach | foreach_reverse
  ////ForeachVarList := ForeachVar ("," ForeachVar)*
  ////ForeachVar     := ref? (Identifier | Declarator)
  ////Aggregate      := Expression | ForeachRange
  ////ForeachRange   := Expression ".." Expression # D2.0)
  Statement parseForeachStmt()
  {
    assert(tokenIs(T.Foreach) || tokenIs(T.ForeachReverse));
    TOK tok = token.kind;
    nT();

    auto params = new Parameters;
    Expression e; // Aggregate or LwrExpr

    auto leftParen = token;
    require2(T.LParen);
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
      case T.Inout:
      }
      case T.Ref:
        stc = StorageClass.Ref;
        stctok = token;
        nT();
        // fall through
      case T.Identifier:
        auto next = peekNext();
        if (next == T.Comma || next == T.Semicolon || next == T.RParen)
        { // (ref|inout)? Identifier
          name = requireIdentifier(MID.ExpectedVariableName);
          break;
        }
        // fall through
      default: // (ref|inout)? Declarator
        type = parseDeclarator(name);
      }

      params ~= set(new Parameter(stc, stctok, type, name, null), paramBegin);
    } while (consumed(T.Comma));
    set(params, paramsBegin);

    require2(T.Semicolon);
    e = parseExpression();

    version(D2)
    { //Foreach (ForeachType; LwrExpr .. UprExpr ) ScopeStmt
    if (consumed(T.Dot2))
    {
      // if (params.length != 1)
        // error(MID.XYZ); // TODO: issue error msg
      auto upper = parseExpression();
      requireClosing(T.RParen, leftParen);
      auto forBody = parseScopeStmt();
      return new ForeachRangeStmt(tok, params, e, upper, forBody);
    }
    } // version(D2)
    // Foreach (ForeachTypeList; Aggregate) ScopeStmt
    requireClosing(T.RParen, leftParen);
    auto forBody = parseScopeStmt();
    return new ForeachStmt(tok, params, e, forBody);
  }

  /// $(BNF SwitchStmt := switch "(" Expression ")" ScopeStmt)
  Statement parseSwitchStmt()
  {
    bool isFinal = consumed(T.Final);
    skip(T.Switch);
    auto leftParen = token;
    require2(T.LParen);
    auto condition = parseExpression();
    requireClosing(T.RParen, leftParen);
    auto switchBody = parseScopeStmt();
    return new SwitchStmt(condition, switchBody, isFinal);
  }

  /// Helper function for parsing the body of a default or case statement.
  /// $(BNF CaseOrDefaultBody := ScopeStmt)
  Statement parseCaseOrDefaultBody()
  {
    // This function is similar to parseNoScopeStmt()
    auto begin = token;
    auto s = new CompoundStmt();
    while (!tokenIs(T.Case)   && !tokenIs(T.Default) &&
           !tokenIs(T.RBrace) && !tokenIs(T.EOF))
      s ~= parseStatement();
    if (begin is token) // Nothing consumed.
      begin = this.prevToken;
    set(s, begin);
    return set(new ScopeStmt(s), begin);
  }

  /// $(BNF CaseStmt := case ExpressionList ":" CaseOrDefaultBody)
  Statement parseCaseStmt()
  {
    skip(T.Case);
    auto values = parseExpressionList();
    require2(T.Colon);
    version(D2)
    if (consumed(T.Dot2)) // ".."
    {
      if (values.length > 1)
        error(values[1].begin, MID.CaseRangeStartExpression);
      require(T.Case);
      Expression left = values[0], right = parseAssignExpr();
      require2(T.Colon);
      auto caseBody = parseCaseOrDefaultBody();
      return new CaseRangeStmt(left, right, caseBody);
    } // version(D2)
    auto caseBody = parseCaseOrDefaultBody();
    return new CaseStmt(values, caseBody);
  }

  /// $(BNF DefaultStmt := default ":" CaseOrDefaultBody)
  Statement parseDefaultStmt()
  {
    skip(T.Default);
    require2(T.Colon);
    auto defaultBody = parseCaseOrDefaultBody();
    return new DefaultStmt(defaultBody);
  }

  /// $(BNF ContinueStmt := continue Identifier? ";")
  Statement parseContinueStmt()
  {
    skip(T.Continue);
    auto ident = optionalIdentifier();
    require2(T.Semicolon);
    return new ContinueStmt(ident);
  }

  /// $(BNF BreakStmt := break Identifier? ";")
  Statement parseBreakStmt()
  {
    skip(T.Break);
    auto ident = optionalIdentifier();
    require2(T.Semicolon);
    return new BreakStmt(ident);
  }

  /// $(BNF ReturnStmt := return Expression? ";")
  Statement parseReturnStmt()
  {
    skip(T.Return);
    Expression expr;
    if (!tokenIs(T.Semicolon))
      expr = parseExpression();
    require2(T.Semicolon);
    return new ReturnStmt(expr);
  }

  /// $(BNF
  ////GotoStmt := goto (case Expression? | default | Identifier) ";")
  Statement parseGotoStmt()
  {
    skip(T.Goto);
    auto ident = token;
    Expression caseExpr;
    switch (token.kind)
    {
    case T.Case:
      nT();
      if (tokenIs(T.Semicolon))
        break;
      caseExpr = parseExpression();
      break;
    case T.Default:
      nT();
      break;
    default:
      ident = requireIdentifier(MID.ExpectedAnIdentifier);
    }
    require2(T.Semicolon);
    return new GotoStmt(ident, caseExpr);
  }

  /// $(BNF WithStmt := with "(" Expression ")" ScopeStmt)
  Statement parseWithStmt()
  {
    skip(T.With);
    auto leftParen = token;
    require2(T.LParen);
    auto expr = parseExpression();
    requireClosing(T.RParen, leftParen);
    return new WithStmt(expr, parseScopeStmt());
  }

  /// $(BNF SynchronizedStmt := synchronized ("(" Expression ")")? ScopeStmt)
  Statement parseSynchronizedStmt()
  {
    skip(T.Synchronized);
    Expression expr;
    if (auto leftParen = consumedToken(T.LParen))
    {
      expr = parseExpression();
      requireClosing(T.RParen, leftParen);
    }
    return new SynchronizedStmt(expr, parseScopeStmt());
  }

  /// $(BNF TryStmt :=
  ////  try ScopeStmt
  ////  (CatchStmt* LastCatchStmt? FinallyStmt? |
  ////   CatchStmt)
  ////CatchStmt     := catch "(" BasicType Identifier ")" NoScopeStmt
  ////LastCatchStmt := catch NoScopeStmt
  ////FinallyStmt   := finally NoScopeStmt)
  Statement parseTryStmt()
  {
    auto begin = token;
    skip(T.Try);

    auto tryBody = parseScopeStmt();
    CatchStmt[] catchBodies;
    FinallyStmt finBody;

    while (consumed(T.Catch))
    {
      auto catchBegin = prevToken;
      Parameter param;
      if (auto leftParen = consumedToken(T.LParen))
      {
        auto paramBegin = token;
        Token* name;
        auto type = parseDeclarator(name, true);
        param = new Parameter(StorageClass.None, null, type, name, null);
        set(param, paramBegin);
        requireClosing(T.RParen, leftParen);
      }
      catchBodies ~= set(new CatchStmt(param, parseNoScopeStmt()), catchBegin);
      if (param is null)
        break; // This is a LastCatch
    }

    if (auto t = consumedToken(T.Finally))
      finBody = set(new FinallyStmt(parseNoScopeStmt()), t);

    if (catchBodies is null && finBody is null)
      error(begin, MID.MissingCatchOrFinally);

    return new TryStmt(tryBody, catchBodies, finBody);
  }

  /// $(BNF ThrowStmt := throw Expression ";")
  Statement parseThrowStmt()
  {
    skip(T.Throw);
    auto expr = parseExpression();
    require2(T.Semicolon);
    return new ThrowStmt(expr);
  }

  /// $(BNF ScopeGuardStmt := scope "(" ScopeCondition ")" ScopeGuardBody
  ////ScopeCondition := "exit" | "success" | "failure"
  ////ScopeGuardBody := ScopeStmt | NoScopeStmt)
  Statement parseScopeGuardStmt()
  {
    skip(T.Scope);
    skip(T.LParen);
    auto condition = requireIdentifier(MID.ExpectedScopeIdentifier);
    switch (condition ? condition.ident.idKind : IDK.Empty)
    {
    case IDK.exit, IDK.success, IDK.failure: break;
    case IDK.Empty: break; // Don't report error twice.
    default:
      error2(MID.InvalidScopeIdentifier, condition);
    }
    require2(T.RParen);
    auto scopeBody = tokenIs(T.LBrace) ? parseScopeStmt() : parseNoScopeStmt();
    return new ScopeGuardStmt(condition, scopeBody);
  }

  /// $(BNF VolatileStmt := volatile VolatileBody
  ////VolatileBody := ScopeStmt | NoScopeStmt)
  Statement parseVolatileStmt()
  {
    skip(T.Volatile);
    Statement volatileBody;
    if (tokenIs(T.LBrace))
      volatileBody = parseScopeStmt();
    else
      volatileBody = parseNoScopeStmt();
    return new VolatileStmt(volatileBody);
  }

  /// $(BNF PragmaStmt :=
  ////  pragma "(" PragmaName ("," ExpressionList)? ")" NoScopeStmt)
  Statement parsePragmaStmt()
  {
    skip(T.Pragma);

    Token* name;
    Expression[] args;
    Statement pragmaBody;

    auto leftParen = token;
    require2(T.LParen);
    name = requireIdentifier(MID.ExpectedPragmaIdentifier);

    if (consumed(T.Comma))
      args = parseExpressionList();
    requireClosing(T.RParen, leftParen);

    pragmaBody = parseNoScopeOrEmptyStmt();

    return new PragmaStmt(name, args, pragmaBody);
  }

  /// $(BNF StaticIfStmt :=
  ////  static if "(" Expression ")" NoScopeStmt (else NoScopeStmt)?)
  Statement parseStaticIfStmt()
  {
    skip(T.Static);
    skip(T.If);
    Expression condition;
    Statement ifBody, elseBody;

    auto leftParen = token;
    require2(T.LParen);
    condition = parseExpression();
    requireClosing(T.RParen, leftParen);
    ifBody = parseNoScopeStmt();
    if (consumed(T.Else))
      elseBody = parseNoScopeStmt();
    return new StaticIfStmt(condition, ifBody, elseBody);
  }

  /// $(BNF StaticAssertStmt :=
  ////  static assert "(" AssignExpr ("," Message) ")"
  ////Message := AssignExpr)
  Statement parseStaticAssertStmt()
  {
    skip(T.Static);
    skip(T.Assert);
    Expression condition, message;

    require2(T.LParen);
    condition = parseAssignExpr(); // Condition.
    if (consumed(T.Comma))
      message = parseAssignExpr(); // Error message.
    require2(T.RParen);
    require2(T.Semicolon);
    return new StaticAssertStmt(condition, message);
  }

  /// $(BNF DebugStmt :=
  ////  debug DebugCondition? NoScopeStmt (else NoScopeStmt)?)
  Statement parseDebugStmt()
  {
    skip(T.Debug);
    Token* cond;
    Statement debugBody, elseBody;

    // ( Condition )
    if (consumed(T.LParen))
    {
      cond = parseIdentOrInt();
      require2(T.RParen);
    }
    // debug Statement
    // debug ( Condition ) Statement
    debugBody = parseNoScopeStmt();
    // else Statement
    if (consumed(T.Else))
      elseBody = parseNoScopeStmt();

    return new DebugStmt(cond, debugBody, elseBody);
  }

  /// $(BNF VersionStmt :=
  ////  version VCondition NoScopeStmt (else NoScopeStmt)?)
  Statement parseVersionStmt()
  {
    skip(T.Version);
    Token* cond;
    Statement versionBody, elseBody;

    // ( Condition )
    require2(T.LParen);
    cond = parseVersionCondition();
    require2(T.RParen);
    // version ( Condition ) Statement
    versionBody = parseNoScopeStmt();
    // else Statement
    if (consumed(T.Else))
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
    skip(T.Asm);
    auto leftBrace = token;
    require(T.LBrace);
    auto ss = new CompoundStmt;
    while (!tokenIs(T.RBrace) && !tokenIs(T.EOF))
      ss ~= parseAsmStmt();
    requireClosing(T.RBrace, leftBrace);
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
    alias begin ident;
    switch (token.kind)
    {
    case T.In, T.Int, T.Out: // Keywords that are valid opcodes.
      nT();
      goto LparseOperands;
    case T.Identifier:
      nT();
      if (consumed(T.Colon))
      { // Identifier ":" AsmStmt
        s = new LabeledStmt(ident, parseAsmStmt());
        break;
      }

      // JumpOpcode (short | (near | far) ptr)?
      if (Ident.isJumpOpcode(ident.ident.idKind))
      {
        auto jmptype = token.ident;
        if (tokenIs(T.Short))
          nT();
        else if (tokenIs(T.Identifier) &&
                 (jmptype is Ident.near || jmptype is Ident.far))
        {
          nT();
          if (tokenIs(T.Identifier) && token.ident is Ident.ptr)
            skip(T.Identifier);
          else
            error2(MID.ExpectedButFound, "ptr", token);
        }
      }

      // TODO: Handle opcodes db, ds, di, dl, df, dd, de.
      //       They accept string operands.

    LparseOperands:
      // Opcode Operands? ";"
      Expression[] es;
      if (!tokenIs(T.Semicolon))
        do
          es ~= parseAsmExpr();
        while (consumed(T.Comma));
      require2(T.Semicolon);
      s = new AsmStmt(ident, es);
      break;
    case T.Align:
      // align Integer ";"
      nT();
      auto number = token;
      if (!consumed(T.Int32))
        error2(MID.ExpectedIntegerAfterAlign, token);
      require2(T.Semicolon);
      s = new AsmAlignStmt(number);
      break;
    case T.Semicolon:
      s = new EmptyStmt();
      nT();
      break;
    default:
      s = new IllegalAsmStmt();
      // Skip to next valid token.
      do
        nT();
      while (!token.isAsmStatementStart() &&
             !tokenIs(T.RBrace) &&
             !tokenIs(T.EOF));
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
    if (auto qtok = consumedToken(T.Question)) // "?"
    {
      auto iftrue = parseAsmExpr();
      auto ctok = token; // ":"
      require(T.Colon);
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
      case /*T.Exclaim,*/ T.Is, T.In, T.Unordered, T.UorE, T.UorG, T.UorGorE,
           T.UorL, T.UorLorE, T.LorEorG, T.LorG, T.Tilde, T.Caret2:
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
    while ((leftBracket = consumedToken(T.LBracket)) !is null)
    {
      e = new AsmPostBracketExpr(e, parseAsmExpr());
      requireClosing(T.RBracket, leftBracket);
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
    case T.Byte,  T.Short,  T.Int,
         T.Float, T.Double, T.Real:
      goto LAsmTypePrefix;
    case T.Identifier:
      switch (token.ident.idKind)
      {
      case IDK.near, IDK.far,/* "byte",  "short",  "int",*/
           IDK.word, IDK.dword, IDK.qword/*, "float", "double", "real"*/:
      LAsmTypePrefix:
        nT();
        if (tokenIs(T.Identifier) && token.ident is Ident.ptr)
          skip(T.Identifier);
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
    case T.Minus:
    case T.Plus:
      nT();
      e = new SignExpr(parseAsmUnaryExpr());
      break;
    case T.Exclaim:
      nT();
      e = new NotExpr(parseAsmUnaryExpr());
      break;
    case T.Tilde:
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
  ////  AsmLocalSizeExpr | AsmRegisterExpr | AsmBracketExpr |
  ////  QualifiedExpr
  ////IntExpr          := Integer
  ////FloatExpr        := FloatLiteral | IFloatLiteral
  ////DollarExpr       := "$"
  ////AsmBracketExpr   := "[" AsmExpr "]"
  ////AsmLocalSizeExpr := "__LOCAL_SIZE"
  ////AsmRegisterExpr  := ...
  ////QualifiedExpr    := (ModuleScopeExpr | IdentifierExpr)
  ////                    ("." IdentifierExpr)+
  ////ModuleScopeExpr  := ".")
  Expression parseAsmPrimaryExpr()
  {
    auto begin = token;
    Expression e;
    switch (token.kind)
    {
    case T.Int32, T.Int64, T.UInt32, T.UInt64:
      e = new IntExpr(token);
      nT();
      break;
    case T.Float32, T.Float64, T.Float80,
         T.IFloat32, T.IFloat64, T.IFloat80:
      e = new FloatExpr(token);
      nT();
      break;
    case T.Dollar:
      e = new DollarExpr();
      nT();
      break;
    case T.LBracket:
      // [ AsmExpr ]
      auto leftBracket = token;
      nT();
      e = parseAsmExpr();
      requireClosing(T.RBracket, leftBracket);
      e = new AsmBracketExpr(e);
      break;
    case T.Identifier:
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
        if (consumed(T.LParen))
          (number = parseAsmExpr()),
          require2(T.RParen);
        e = new AsmRegisterExpr(register, number);
        break;
      case IDK.ES, IDK.CS, IDK.SS, IDK.DS, IDK.GS, IDK.FS:
        nT();
        Expression number;
        if (consumed(T.Colon)) // Segment := XX ":" AsmExpr
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
    case T.Dot:
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
  alias Expression function(Expression, Expression, Token*) NewBinaryExpr;

  /// The root method for parsing an Expression.
  /// $(BNF Expression := AssignExpr ("," AssignExpr)*)
  Expression parseExpression()
  {
    Token* begin = token, comma = void;
    auto e = parseAssignExpr();
    while ((comma = consumedToken(T.Comma)) !is null)
      e = set(new CommaExpr(e, parseAssignExpr(), comma), begin);
    return e;
  }

  /// $(BNF AssignExpr := CondExpr (AssignOp AssignExpr)*
  ////AssignOp   := "=" | "<<=" | ">>=" | ">>>=" | "|=" | "&=" |
  ////              "+=" | "-=" | "/=" | "*=" | "%=" | "^=" | "~=" | "^^="
  ////)
  Expression parseAssignExpr()
  {
    auto begin = token;
    auto e = parseCondExpr();
    auto optok = token;
    NewBinaryExpr f = void;
    switch (optok.kind)
    {
    case T.Equal:       f = &newBinaryExpr!(AssignExpr); goto Lcommon;
    case T.Less2Eql:    f = &newBinaryExpr!(LShiftAssignExpr); goto Lcommon;
    case T.Greater2Eql: f = &newBinaryExpr!(RShiftAssignExpr); goto Lcommon;
    case T.Greater3Eql: f = &newBinaryExpr!(URShiftAssignExpr); goto Lcommon;
    case T.PipeEql:     f = &newBinaryExpr!(OrAssignExpr); goto Lcommon;
    case T.AmpEql:      f = &newBinaryExpr!(AndAssignExpr); goto Lcommon;
    case T.PlusEql:     f = &newBinaryExpr!(PlusAssignExpr); goto Lcommon;
    case T.MinusEql:    f = &newBinaryExpr!(MinusAssignExpr); goto Lcommon;
    case T.SlashEql:    f = &newBinaryExpr!(DivAssignExpr); goto Lcommon;
    case T.StarEql:     f = &newBinaryExpr!(MulAssignExpr); goto Lcommon;
    case T.PercentEql:  f = &newBinaryExpr!(ModAssignExpr); goto Lcommon;
    case T.CaretEql:    f = &newBinaryExpr!(XorAssignExpr); goto Lcommon;
    case T.TildeEql:    f = &newBinaryExpr!(CatAssignExpr); goto Lcommon;
    version(D2)
    {
    case T.Caret2Eql:   f = &newBinaryExpr!(PowAssignExpr); goto Lcommon;
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
    if (auto qtok = consumedToken(T.Question)) // "?"
    {
      auto iftrue = parseExpression();
      auto ctok = token; // ":"
      require(T.Colon);
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
    case T.Exclaim:
      auto next = peekNext();
      if (next == T.Is) // "!" is
        goto case T.Is;
      else version(D2) if (next == T.In) // "!" in
        goto case T.In;
      break; // Not a binary operator.
    case T.Pipe2:    p = PREC.OOr;  f = &newBinaryExpr!(OrOrExpr); break;
    case T.Amp2:     p = PREC.AAnd; f = &newBinaryExpr!(AndAndExpr); break;
    case T.Pipe:     p = PREC.Or;   f = &newBinaryExpr!(OrExpr); break;
    case T.Caret:    p = PREC.Xor;  f = &newBinaryExpr!(XorExpr); break;
    case T.Amp:      p = PREC.And;  f = &newBinaryExpr!(AndExpr); break;
    case T.Is:       p = PREC.Cmp;  f = &newBinaryExpr!(IdentityExpr); break;
    case T.In:       p = PREC.Cmp;  f = &newBinaryExpr!(InExpr); break;
    case T.ExclaimEql,
         T.Equal2:   p = PREC.Cmp;  f = &newBinaryExpr!(EqualExpr); break;
    case T.LessEql, T.Less, T.GreaterEql, T.Greater,
         T.Unordered, T.UorE, T.UorG, T.UorGorE,
         T.UorL, T.UorLorE, T.LorEorG, T.LorG:
                     p = PREC.Cmp;   f = &newBinaryExpr!(RelExpr); break;
    case T.Less2:    p = PREC.Shift; f = &newBinaryExpr!(LShiftExpr); break;
    case T.Greater2: p = PREC.Shift; f = &newBinaryExpr!(RShiftExpr); break;
    case T.Greater3: p = PREC.Shift; f = &newBinaryExpr!(URShiftExpr); break;
    case T.Plus:     p = PREC.Plus;  f = &newBinaryExpr!(PlusExpr); break;
    case T.Minus:    p = PREC.Plus;  f = &newBinaryExpr!(MinusExpr); break;
    case T.Tilde:    p = PREC.Plus;  f = &newBinaryExpr!(CatExpr); break;
    case T.Star:     p = PREC.Mul;   f = &newBinaryExpr!(MulExpr); break;
    case T.Slash:    p = PREC.Mul;   f = &newBinaryExpr!(DivExpr); break;
    case T.Percent:  p = PREC.Mul;   f = &newBinaryExpr!(ModExpr); break;
    version(D2)
    {
    case T.Caret2:   p = PREC.Pow;   f = &newBinaryExpr!(PowExpr); break;
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
      if (tokenIs(T.Exclaim))
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
  ////MulExpr    := PowExpr  (MulOp PowExpr)* # D2
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
  ////  (QualifiedExpr | IncOrDecExpr | CallExpr | SliceExpr | IndexExpr)*
  ////QualifiedExpr := "." (NewExpr | IdentifierExpr)
  ////IncOrDecExpr  := "++" | "--"
  ////CallExpr      := "(" Arguments? ")"
  ////SliceExpr     := "[" (AssignExpr ".." AssignExpr)? "]"
  ////IndexExpr     := "[" ExpressionList "]")
  Expression parsePostExpr()
  {
    auto begin = token;
    auto e = parseUnaryExpr();
    while (1)
    {
      switch (token.kind)
      {
      case T.Dot:
        nT();
        if (tokenIs(T.New))
          e = parseNewExpr(e);
        else
          e = parseIdentifierExpr(e);
        continue;
      case T.Plus2:
        e = new PostIncrExpr(e);
        break;
      case T.Minus2:
        e = new PostDecrExpr(e);
        break;
      case T.LParen:
        e = new CallExpr(e, parseArguments());
        goto Lset;
      case T.LBracket:
        // parse Slice- and IndexExpr
        auto leftBracket = token;
        nT();
        // [] is a SliceExpr
        if (tokenIs(T.RBracket))
        {
          e = new SliceExpr(e, null, null);
          break;
        }

        Expression[] es = [parseAssignExpr()];

        // [ AssignExpr .. AssignExpr ]
        if (consumed(T.Dot2))
        {
          e = new SliceExpr(e, es[0], parseAssignExpr());
          requireClosing(T.RBracket, leftBracket);
          goto Lset;
        }

        // [ ExpressionList ]
        if (consumed(T.Comma))
           es ~= parseExpressionList2(T.RBracket);
        requireClosing(T.RBracket, leftBracket);

        e = new IndexExpr(e, es);
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
  ////  PreIncrExpr | DerefExpr | SignExpr |
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
  ////CastExpr      := cast "(" Type ")" UnaryExpr
  ////TypeDotIdExpr := "(" Type ")" "." Identifier)
  Expression parseUnaryExpr()
  {
    auto begin = token;
    Expression e;
    switch (token.kind)
    {
    case T.Amp:
      nT();
      e = new AddressExpr(parseUnaryExpr());
      break;
    case T.Plus2:
      nT();
      e = new PreIncrExpr(parseUnaryExpr());
      break;
    case T.Minus2:
      nT();
      e = new PreDecrExpr(parseUnaryExpr());
      break;
    case T.Star:
      nT();
      e = new DerefExpr(parseUnaryExpr());
      break;
    case T.Minus:
    case T.Plus:
      nT();
      e = new SignExpr(parseUnaryExpr());
      break;
    case T.Exclaim:
      nT();
      e = new NotExpr(parseUnaryExpr());
      break;
    case T.Tilde:
      nT();
      e = new CompExpr(parseUnaryExpr());
      break;
    case T.New:
      e = parseNewExpr();
      return e;
    case T.Delete:
      nT();
      e = new DeleteExpr(parseUnaryExpr());
      break;
    case T.Cast:
      nT();
      require2(T.LParen);
      Type type;
      switch (token.kind)
      {
      version(D2)
      {
      case T.RParen: // Mutable cast: cast "(" ")"
        break;
      case T.Const, T.Immutable, T.Inout, T.Shared:
        auto begin2 = token;
        if (peekNext() != T.RParen)
          goto default; // (const|immutable|inout|shared) "(" Type ")"
        type = tokenIs(T.Const) ? new ConstType(null) :
           tokenIs(T.Immutable) ? new ImmutableType(null) :
               tokenIs(T.Inout) ? new InoutType(null) :
                                  new SharedType(null);
        nT();
        set(type, begin2);
        break;
      } // version(D2)
      default:
       type = parseType();
      }
      require2(T.RParen);
      e = new CastExpr(parseUnaryExpr(), type);
      break;
    case T.LParen:
      if (!tokenAfterParenIs(T.Dot))
        goto default;
      // "(" Type ")" "." Identifier
      bool success;
      auto type = tryToParse({
        skip(T.LParen); // "("
        auto type = parseType(); // Type
        require(T.RParen); // ")"
        require(T.Dot); // "."
        return type;
      }, success);
      if (!success)
        goto default;
      auto ident = requireIdentifier(MID.ExpectedIdAfterTypeDot);
      e = new TypeDotIdExpr(type, ident);
      break;
    default:
      e = parsePrimaryExpr();
      return e;
    }
    assert(e !is null);
    set(e, begin);
    return e;
  }

  /// $(BNF IdentifiersExpr :=
  ////  ModuleScopeExpr? IdentifierExpr ("." IdentifierExpr)*)
  Expression parseIdentifiersExpr()
  {
    Expression e;
    if (tokenIs(T.Dot))
      e = set(new ModuleScopeExpr(), token, token);
    else
      e = parseIdentifierExpr();
    while (consumed(T.Dot))
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
    if (tokenIs(T.Exclaim) && nextTok != T.Is && nextTok != T.In)
    {
      skip(T.Exclaim);
      // Identifier "!" "(" TemplateArguments? ")"
      // Identifier "!" TemplateArgumentSingle
      auto tparams = parseOneOrMoreTemplateArguments();
      e = new TmplInstanceExpr(ident, tparams, next);
    }
    else // Identifier
      e = new IdentifierExpr(ident, next);
    return set(e, begin);
  }

  /// $(BNF LambdaExpr := ParameterList ParamsPostfix "=>" LambdaBody
  ////LambdaBody := AssignExpr)
  FuncBodyStmt parseLambdaExprBody(Parameters params)
  {
    skip(T.EqlGreater);
    auto begin = token;
    auto ae = parseAssignExpr();
    auto estmt = set(new ExpressionStmt(ae), begin);
    return set(new FuncBodyStmt(estmt, null, null, null), begin);
  }

  /// $(BNF LambdaExpr := Identifier "=>" AssignExpr)
  Expression parseSingleParamLambdaExpr()
  {
    auto begin = token;
    skip(T.Identifier);
    auto params = set(new Parameters(), begin);
    auto param = new Parameter(StorageClass.None, null, null, token, null);
    params ~= set(param, begin);
    auto fstmt = parseLambdaExprBody(params);
    return set(new FuncLiteralExpr(null, params, fstmt), begin);
  }

  /// $(BNF PrimaryExpr := ... | ModuleScopeExpr
  ////ModuleScopeExpr := ".")
  Expression parsePrimaryExpr()
  {
    auto begin = token;
    Expression e;
    switch (token.kind)
    {
    case T.Identifier:
      if (peekNext() == T.EqlGreater)
        e = parseSingleParamLambdaExpr();
      else
        e = parseIdentifierExpr();
      return e;
    case T.Typeof:
      e = new TypeofExpr(parseTypeofType());
      break;
    case T.Dot:
      e = set(new ModuleScopeExpr(), begin, begin);
      nT();
      // parseIdentifiersExpr() isn't used; see case T.Dot in parsePostExpr().
      e = parseIdentifierExpr(e);
      return e;
    case T.This:
      e = new ThisExpr();
      goto LnT_and_return;
    case T.Super:
      e = new SuperExpr();
      goto LnT_and_return;
    case T.Null:
      e = new NullExpr();
      goto LnT_and_return;
    case T.True, T.False:
      e = new BoolExpr(tokenIs(T.True));
      goto LnT_and_return;
    case T.Dollar:
      e = new DollarExpr();
      goto LnT_and_return;
    case T.Int32, T.Int64, T.UInt32, T.UInt64:
      e = new IntExpr(token);
      goto LnT_and_return;
    case T.Float32, T.Float64, T.Float80,
         T.IFloat32, T.IFloat64, T.IFloat80:
      e = new FloatExpr(token);
      goto LnT_and_return;
    case T.Character:
      e = new CharExpr(token);
      goto LnT_and_return;
    LnT_and_return:
      nT();
      assert(begin is prevToken);
      set(e, begin, begin);
      return e;
    case T.String:
      cstring str = token.strval.str;
      char postfix = token.strval.pf;
      nT();
      // Concatenate adjacent string literals.
      while (tokenIs(T.String))
      {
        auto pf = token.strval.pf;
        /+if (postfix == 0)
            postfix = pf;
        else+/
        if (pf && pf != postfix)
          error(token, MID.StringPostfixMismatch);
        str.length = str.length - 1; // Exclude '\0'.
        str ~= token.strval.str;
        nT();
      }
      assert(str[$-1] == 0);

      auto bin_str = cast(const(ubyte)[])str;
      if (postfix == 'w')
      { // Convert to UTF16.
        if (!hasInvalidUTF8(str, begin))
          bin_str = cast(typeof(bin_str))dil.Unicode.toUTF16(str);
      }
      else if (postfix == 'd')
      { // Convert to UTF32.
        if (!hasInvalidUTF8(str, begin))
          bin_str = cast(typeof(bin_str))dil.Unicode.toUTF32(str);
      }
      else
      {
        if (begin !is prevToken) // Multiple string literals?
          bin_str = cast(typeof(bin_str))lexer.lookupString(str[0..$-1]);
      }
      e = new StringExpr(bin_str, postfix);
      break;
    case T.LBracket:
      Expression[] values;

      nT();
      if (!consumed(T.RBracket))
      {
        e = parseAssignExpr();
        if (consumed(T.Colon))
          goto LparseAssocArray;
        if (consumed(T.Comma))
          values = [e] ~ parseExpressionList2(T.RBracket);
        requireClosing(T.RBracket, begin);
      }

      e = new ArrayLiteralExpr(values);
      break;

    LparseAssocArray:
      Expression[] keys = [e];

      goto LenterLoop;
      while (!tokenIs(T.RBracket))
      {
        keys ~= parseAssignExpr();
        require(T.Colon);
      LenterLoop:
        values ~= parseAssignExpr();
        if (!consumed(T.Comma))
          break;
      }
      requireClosing(T.RBracket, begin);
      e = new AArrayLiteralExpr(keys, values);
      break;
    case T.LBrace:
      // DelegateLiteral := { Statements }
      auto funcBody = parseFunctionBody();
      e = new FuncLiteralExpr(funcBody);
      break;
    case T.Function, T.Delegate:
      // FunctionLiteral := ("function" | "delegate")
      //   ReturnType? "(" ArgumentList ")" FunctionPostfix? FunctionBody
      nT(); // Skip function or delegate keyword.
      Type returnType;
      Parameters parameters;
      if (!tokenIs(T.LBrace))
      {
        if (!tokenIs(T.LParen)) // Optional return type
          returnType = parseBasicTypes();
        parameters = parseParameterList();
        version(D2)
        parameters.postSTCs = parseFunctionPostfix();
      }
      auto funcBody = parseFunctionBody();
      e = new FuncLiteralExpr(returnType, parameters, funcBody);
      break;
    case T.Assert:
      requireNext(T.LParen);
      e = parseAssignExpr();
      auto msg = consumed(T.Comma) ? parseAssignExpr() : null;
      require2(T.RParen);
      e = new AssertExpr(e, msg);
      break;
    case T.Mixin:
      nT();
      require2(T.LParen);
      e = new MixinExpr(parseAssignExpr());
      require2(T.RParen);
      break;
    case T.Import:
      nT();
      require2(T.LParen);
      e = new ImportExpr(parseAssignExpr());
      require2(T.RParen);
      break;
    case T.Typeid:
      nT();
      require2(T.LParen);
      e = new TypeidExpr(parseType());
      require2(T.RParen);
      break;
    case T.Is:
      nT();
      auto leftParen = token;
      require2(T.LParen);

      Type type, specType;
      Token* ident; // optional Identifier
      Token* opTok, specTok;

      type = parseDeclarator(ident, true);

      switch (token.kind)
      {
      case T.Colon, T.Equal2:
        opTok = token;
        nT();
        switch (token.kind)
        {
        case T.Typedef, T.Struct, T.Union, T.Class, T.Interface,
             T.Enum, T.Function, T.Delegate, T.Super, T.Return:
        case_Const_Immutable_Inout_Shared: // D2
          specTok = token;
          nT();
          break;
        version(D2)
        {
        case T.Const, T.Immutable, T.Inout, T.Shared:
          auto next = peekNext();
          if (next == T.RParen || next == T.Comma)
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
      if (ident && specType && tokenIs(T.Comma))
        tparams = parseTemplateParameterList2();
      } // version(D2)
      requireClosing(T.RParen, leftParen);
      e = new IsExpr(type, ident, opTok, specTok, specType, tparams);
      break;
    case T.LParen:
      auto t = skipParens(token, T.RParen);
      if (isFunctionPostfix(t) || // E.g.: "(" int "a" ")" pure
          t.kind == T.LBrace || t.kind == T.EqlGreater) // ("{" | "=>")
      {
        auto parameters = parseParameterList(); // "(" ParameterList ")"
        parameters.postSTCs = parseFunctionPostfix(); // Optional attributes.
        FuncBodyStmt fstmt;
        if (token.kind == T.LBrace) // "(" ... ")" "{" ...
          fstmt = parseFunctionBody();
        else if (token.kind == T.EqlGreater) // "(" ... ")" "=>" ...
          fstmt = parseLambdaExprBody(parameters);
        else
          error(token, MID.ExpectedFunctionBody, token.text);
        e = new FuncLiteralExpr(null, parameters, fstmt);
      }
      else
      { // ( Expression )
        auto leftParen = token;
        skip(T.LParen);
        e = parseExpression();
        requireClosing(T.RParen, leftParen);
        e = new ParenExpr(e);
      }
      break;
    version(D2)
    {
    case T.Traits:
      nT();
      auto leftParen = token;
      require2(T.LParen); // "("
      auto ident = requireIdentifier(MID.ExpectedAnIdentifier);
      auto args = consumed(T.Comma) ? parseTemplateArguments2() : null;
      requireClosing(T.RParen, leftParen); // ")"
      e = new TraitsExpr(ident, args);
      break;
    } // version(D2)
    default:
      if (token.isIntegralType)
      { // IntegralType . Identifier
        auto type = new IntegralType(token.kind);
        nT();
        set(type, begin);
        require2(T.Dot);
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
    skip(T.New);

    Expression e;
    Expression[] newArguments, ctorArguments;

    if (tokenIs(T.LParen)) // NewArguments
      newArguments = parseArguments();

    if (consumed(T.Class))
    { // NewAnonymousClassExpr
      if (tokenIs(T.LParen))
        ctorArguments = parseArguments();

      BaseClassType[] bases;
      if (!tokenIs(T.LBrace))
        bases = parseBaseClasses();

      auto decls = parseDeclarationDefinitionsBody();
      e = new NewClassExpr(frame, newArguments, ctorArguments, bases, decls);
    }
    else
    { // NewObjectExpr
      auto type = parseBasicTypes();

      // Don't parse arguments if an array type was parsed previously.
      auto arrayType = type.Is!(ArrayType);
      if (arrayType && arrayType.isStatic())
      {}
      else if (arrayType && arrayType.isAssociative())
      { // Backtrack to parse as a StaticArray.
        auto lBracket = type.begin;
        backtrackTo(lBracket);

        skip(T.LBracket); // "["
        type = set(new ArrayType(type.next, parseExpression()), lBracket);
        requireClosing(T.RBracket, lBracket); // "]"
        delete arrayType; // Delete the old type.
      }
      else if (tokenIs(T.LParen)) // NewArguments
        ctorArguments = parseArguments();
      e = new NewExpr(frame, newArguments, type, ctorArguments);
    }
    return set(e, begin);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                          Type parsing methods                           |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// Parses the basic types.
  ///
  /// $(BNF Type := BasicType BasicType2)
  Type parseBasicTypes()
  {
    return parseBasicType2(parseBasicType());
  }

  /// Parses a full Type.
  ///
  /// $(BNF Type     := Modifier BasicType BasicType2 CStyleType?
  ////Modifier := inout | const | immutable | shared)
  Type parseType(Token** pIdent = null)
  {
    version(D2)
    {
    auto begin= token;
    if (peekNext() != T.LParen)
    {
      auto kind = token.kind;
      switch (kind)
      {
      case T.Const, T.Immutable, T.Inout, T.Shared:
        nT();
        auto t = parseType(pIdent);
        t = (kind == T.Const) ?   new ConstType(t) :
          (kind == T.Immutable) ? new ImmutableType(t) :
            (kind == T.Inout) ?   new InoutType(t) :
                                  new SharedType(t);
        return set(t, begin);
      default:
      }
    }
    } // version(D2)
    auto type = parseBasicTypes();
    return (tokenIs(T.LParen) || pIdent) ?
      parseCStyleType(type, pIdent) : type;
  }

  /// Parses a C-style type.
  ///
  /// $(BNF CStyleType := BasicType? InnerCType DeclaratorSuffix?
  ////InnerCType := "(" CStyleType ")" | Ident?
  ////)
  /// Example:
  /// $(PRE
  ////      6~~~~~~~~ 5~  3 1 2~~~~~~~ 4~~~~~
  ////type( outerType [] (*(*)(double))(char) )
  ////Resulting type chain:
  ////* > (double) > * > (char) > [] > outerType
  ////1   2~~~~~~~   3   4~~~~~   5~   6~~~~~~~~)
  /// Read as: a pointer to a function that takes a double,
  /// which returns a pointer to a function that takes a char,
  /// which returns an array of outerType.
  /// Params:
  ///   outerType = The bottommost type in the type chain.
  ///   pIdent    = If null, no identifier is expected.
  ///     If non-null, pIdent receives the parsed identifier.
  Type parseCStyleType(Type outerType, Token** pIdent = null)
  in { assert(outerType !is null); }
  out(res) { assert(res !is null && res.parent is null); }
  body
  {
    auto currentType = parseBasicType2(outerType);

    Type innerType;
    if (auto leftParen = consumedToken(T.LParen)) // Recurse.
      (innerType = parseCStyleType(currentType, pIdent)),
      requireClosing(T.RParen, leftParen);
    else if (auto ident = consumedToken(T.Identifier))
      if (pIdent !is null)
        *pIdent = ident; // Found valid Id.
      else
        error2(MID.UnexpectedIdentInType, ident);
    else if (pIdent !is null)
      *pIdent = token; // Useful for error msg, if an Id was expected.

    auto innerTypeEnd = currentType.parent; // Save before parsing the suffix.

    currentType = parseDeclaratorSuffix(currentType);

    if (innerTypeEnd is null) // No inner Type. End of recursion.
      return currentType; // Return the root of the type chain.
    // Fix the type chain. Let the inner type point to the current type.
    innerTypeEnd.setNext(currentType);
    return innerType;
  }

  /// Parses a Declarator.
  ///
  /// $(BNF Declarator := BasicType CStyleType)
  /// Params:
  ///   ident = Receives the identifier of the declarator.
  ///   identOptional = Whether to report an error for a missing identifier.
  Type parseDeclarator(ref Token* ident, bool identOptional = false)
  {
    auto type = parseType(&ident);
    assert(ident !is null);
    if (ident.kind != T.Identifier)
      (identOptional || error2(MID.ExpectedDeclaratorIdentifier, ident)),
      (ident = null);
    return type;
  }

  /// $(BNF IdentifierType := Identifier | TemplateInstance)
  Type parseIdentifierType(Type next = null)
  {
    auto begin = token;
    auto ident = requireIdentifier(MID.ExpectedAnIdentifier);
    Type t;
    if (consumed(T.Exclaim)) // TemplateInstance
      t = new TmplInstanceType(next, ident,
        parseOneOrMoreTemplateArguments());
    else // Identifier
      t = new IdentifierType(next, ident);
    return set(t, begin);
  }

  /// $(BNF QualifiedType :=
  //// (this | super | ModuleScopeType | TypeofType | IdentifierType)
  //// ("." IdentifierType)*)
  Type parseQualifiedType()
  {
    auto begin = token;
    Type type;

    if (tokenIs(T.Dot))
      type = set(new ModuleScopeType(), begin, begin);
    else if (tokenIs(T.Typeof))
      type = parseTypeofType();
    else if (tokenIs(T.This) || tokenIs(T.Super)) { // D2
      type = set(new IdentifierType(null, token), begin, begin);
      nT();
    }
    else
      type = parseIdentifierType();

    while (consumed(T.Dot))
      type = parseIdentifierType(type);

    return type;
  }

  /// $(BNF BasicType := IntegralType | QualifiedType |
  ////             ConstType | ImmutableType | InoutType | SharedType # D2.0)
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
    case T.This, T.Super:
    }
    case T.Identifier, T.Typeof, T.Dot:
      t = parseQualifiedType();
      return t;
    version(D2)
    { // (const|immutable|inout|shared) "(" Type ")"
    case T.Const, T.Immutable, T.Inout, T.Shared:
      auto kind = token.kind;
      nT();
      require2(T.LParen); // "("
      auto lParen = prevToken;
      t = parseType(); // Type
      requireClosing(T.RParen, lParen); // ")"
      t = (kind == T.Const) ?   new ConstType(t) :
        (kind == T.Immutable) ? new ImmutableType(t) :
          (kind == T.Inout) ?   new InoutType(t) :
                                new SharedType(t);
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
  ////  Type (PointerType | ArrayType | FunctionType | DelegateType)*
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
      case T.Star:
        t = new PointerType(t);
        nT();
        break;
      case T.LBracket:
        t = parseArrayType(t);
        continue;
      case T.Function, T.Delegate:
        TOK tok = token.kind;
        nT();
        auto parameters = parseParameterList();
        version(D2)
        parameters.postSTCs = parseFunctionPostfix();
        // TODO: add stcs to t.
        if (tok == T.Function)
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

  /// Returns true if the token after the closing parenthesis
  /// matches the searched kind.
  /// Params:
  ///   kind = The token kind to test for.
  bool tokenAfterParenIs(TOK kind)
  {
    assert(tokenIs(T.LParen));
    return skipParens(token, T.RParen).kind == kind;
  }

  /// Returns the token kind behind the closing bracket.
  TOK tokenAfterBracket(TOK closing)
  {
    assert(tokenIs(T.LBracket) || tokenIs(T.LBrace));
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
    while ((peek_token = peekAfter(peek_token)).kind != T.EOF)
      if (peek_token.kind == opening)
        ++level;
      else
      if (peek_token.kind == closing && --level == 0) {
        peek_token = peekAfter(peek_token); // Closing token found.
        break;
      }
    return peek_token;
  }

  /// Parse the array types after the declarator (C-style.) E.g.: int a[]
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
    Type prevType; // The previously parsed type.
    if (tokenIs(T.LBracket)) // "["
    {
      result = prevType = parseArrayType(lhsType);
      // Continue parsing ArrayTypes.
      while (tokenIs(T.LBracket)) // "["
      {
        auto arrayType = parseArrayType(lhsType);
        prevType.setNext(arrayType); // Make prevType point to this type.
        prevType = arrayType; // Current type becomes previous type.
      }
    }
    return result;
  }

  /// $(BNF ArrayType := "[" (Type | Expression | SliceExpr) "]"
  ////SliceExpr := Expression ".." Expression)
  Type parseArrayType(Type t)
  {
    auto begin = token;
    skip(T.LBracket);
    if (consumed(T.RBracket))
      t = new ArrayType(t);
    else
    {
      bool success;
      Type parseAAType()
      {
        auto type = parseType();
        require(T.RBracket);
        return type;
      }
      auto assocType = tryToParse(&parseAAType, success);
      if (success)
        t = new ArrayType(t, assocType);
      else
      {
        Expression e = parseExpression(), e2;
        if (consumed(T.Dot2))
          e2 = parseExpression();
        requireClosing(T.RBracket, begin);
        t = new ArrayType(t, e, e2);
      }
    }
    return set(t, begin);
  }

  /// Parses a list of AssignExpressions.
  /// $(BNF ExpressionList := AssignExpr ("," AssignExpr)*)
  Expression[] parseExpressionList()
  {
    Expression[] expressions;
    do
      expressions ~= parseAssignExpr();
    while (consumed(T.Comma));
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
      if (!consumed(T.Comma))
        break;
    }
    return expressions;
  }

  /// Parses a list of Arguments.
  /// $(BNF Arguments := "(" ExpressionList? ")")
  Expression[] parseArguments()
  {
    auto leftParen = token;
    skip(T.LParen);
    Expression[] args;
    if (!tokenIs(T.RParen))
      args = parseExpressionList2(T.RParen);
    requireClosing(T.RParen, leftParen);
    return args;
  }

  /// Parses a ParameterList.
  Parameters parseParameterList()
  {
    auto begin = token;
    require2(T.LParen);

    auto params = new Parameters();

    Expression defValue; // Default value.

    while (!tokenIs(T.RParen))
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

      if (consumed(T.Dot3)) // "..."
        goto LvariadicParam; // Go to common code and leave the loop.

      while (1)
      { // Parse storage classes.
        switch (token.kind)
        {
        version(D2)
        {
        case T.Const, T.Immutable, T.Inout, T.Shared:
          if (peekNext() == T.LParen)
            break;
                       stc = tokenIs(T.Const) ? StorageClass.Const :
                         tokenIs(T.Immutable) ? StorageClass.Immutable :
                             tokenIs(T.Inout) ? StorageClass.Inout :
                                                StorageClass.Shared;
          goto Lcommon;
        case T.Final:  stc = StorageClass.Final;  goto Lcommon;
        case T.Scope:  stc = StorageClass.Scope;  goto Lcommon;
        case T.Static: stc = StorageClass.Static; goto Lcommon;
        case T.Auto:   stc = StorageClass.Auto;   goto Lcommon;
        } // version(D2)
        case T.In:     stc = StorageClass.In;     goto Lcommon;
        case T.Out:    stc = StorageClass.Out;    goto Lcommon;
        version (D1)
        {
        case T.Inout:
        }
        case T.Ref:
                       stc = StorageClass.Ref;    goto Lcommon;
        case T.Lazy:   stc = StorageClass.Lazy;   goto Lcommon;
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
      type = parseDeclarator(name, true);

      if (consumed(T.Equal))
        defValue = parseAssignExpr();
      else if (defValue !is null) // Parsed a defValue previously?
        error(name ? name : type.begin, // Position.
          MID.ExpectedParamDefValue,
          name ? name.text : ""); // Name.

      if (consumed(T.Dot3))
      {
        if (stcs & (StorageClass.Ref | StorageClass.Out))
          error(paramBegin, MID.IllegalVariadicParam);
      LvariadicParam:
        stcs |= StorageClass.Variadic;
        pushParameter();
        // TODO: allow trailing comma here? DMD doesn't...
        if (!tokenIs(T.RParen))
          error(token, MID.ParamsAfterVariadic);
        break;
      }
      // Add a non-variadic parameter to the list.
      pushParameter();

      if (!consumed(T.Comma))
        break;
    }
    requireClosing(T.RParen, begin);
    return set(params, begin);
  }

  /// $(BNF TemplateArgumentsOneOrMore :=
  ////  TemplateArgumentList | TemplateArgumentSingle)
  TemplateArguments parseOneOrMoreTemplateArguments()
  {
    version(D2)
    if (!tokenIs(T.LParen))
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
    require2(T.LParen);
    targs = !tokenIs(T.RParen) ?
      parseTemplateArguments_() : new TemplateArguments;
    requireClosing(T.RParen, leftParen);
    return set(targs, leftParen);
  }

  /// $(BNF TemplateArgumentList2 := TemplateArguments (?= "$(RP)"))
  TemplateArguments parseTemplateArguments2()
  {
    version(D2)
    {
    TemplateArguments targs;
    if (!tokenIs(T.RParen))
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
    auto type = parseType();
    if (tokenIs(T.Comma) || tokenIs(T.RParen))
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
    while (!tokenIs(T.RParen))
    {
      bool success;
      auto typeArgument = tryToParse(&parseTypeArgument, success);
      // TemplateArgument := Type | AssignExpr
      targs ~= success ? typeArgument : parseAssignExpr();
      if (!consumed(T.Comma))
        break;
    }
    set(targs, begin);
    return targs;
  }

  /// $(BNF Constraint := if "(" ConstraintExpr ")")
  Expression parseOptionalConstraint()
  {
    if (!consumed(T.If))
      return null;
    auto leftParen = token;
    require2(T.LParen);
    auto e = parseExpression();
    requireClosing(T.RParen, leftParen);
    return e;
  }

  /// $(BNF TemplateParameterList := "(" TemplateParameters? ")")
  TemplateParameters parseTemplateParameterList()
  {
    auto begin = token;
    auto tparams = new TemplateParameters;
    require2(T.LParen);
    if (!tokenIs(T.RParen))
      parseTemplateParameterList_(tparams);
    requireClosing(T.RParen, begin);
    return set(tparams, begin);
  }

  /// $(BNF TemplateParameterList2 := "," TemplateParameters "$(RP)")
  TemplateParameters parseTemplateParameterList2()
  {
  version(D2)
  {
    skip(T.Comma);
    auto begin = token;
    auto tparams = new TemplateParameters;
    if (!tokenIs(T.RParen))
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
    while (!tokenIs(T.RParen))
    {
      auto paramBegin = token;
      TemplateParam tp;
      Token* ident;
      Type specType, defType;

      void parseSpecAndOrDefaultType()
      {
        if (consumed(T.Colon))  // ":" SpecializationType
          specType = parseType();
        if (consumed(T.Equal)) // "=" DefaultType
          defType = parseType();
      }

      switch (token.kind)
      {
      case T.Alias:
        // TemplateAliasParam := "alias" Identifier
        skip(T.Alias);
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
        if (consumed(T.Colon))  // ":" Specialization
          spec = parseExpOrType();
        if (consumed(T.Equal)) // "=" Default
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
      case T.Identifier:
        ident = token;
        switch (peekNext())
        {
        case T.Dot3:
          // TemplateTupleParam := Identifier "..."
          skip(T.Identifier); skip(T.Dot3);
          if (tokenIs(T.Comma))
            error(MID.TemplateTupleParameter);
          tp = new TemplateTupleParam(ident);
          break;
        case T.Comma, T.RParen, T.Colon, T.Equal:
          // TemplateTypeParam := Identifier
          skip(T.Identifier);
          parseSpecAndOrDefaultType();
          tp = new TemplateTypeParam(ident, specType, defType);
          break;
        default:
          // TemplateValueParam := Declarator
          ident = null;
          goto LTemplateValueParam;
        }
        break;
      version(D2)
      {
      case T.This:
        // TemplateThisParam := "this" TemplateTypeParam
        skip(T.This);
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
        if (consumed(T.Colon))
          specValue = parseCondExpr();
        // "=" DefaultValue
        if (consumed(T.Equal))
          defValue = parseCondExpr();
        tp = new TemplateValueParam(valueType, ident, specValue, defValue);
      }

      // Push template parameter.
      tparams ~= set(tp, paramBegin);

      if (!consumed(T.Comma))
        break;
    }
  }

  /// Returns the string of a token printable to the client.
  cstring getPrintable(Token* token)
  { // TODO: there are some other tokens that have to be handled, e.g. strings.
    return token.kind == T.EOF ? "EOF" : token.text;
  }

  alias require expected;

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
    return consumed(T.Identifier) ? id : null;
  }

  /// Reports an error if the current token is not an identifier.
  /// Params:
  ///   mid = The error message ID to be used.
  /// Returns: The identifier token or null.
  Token* requireIdentifier(MID mid)
  {
    Token* idtok = token;
    if (!consumed(T.Identifier))
    {
      error(token, mid, token.text);
      if (!trying)
      {
        idtok = lexer.insertEmptyTokenBefore(token);
        idtok.kind = T.Identifier;
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
    assert(closing == T.RBrace || closing == T.RParen || closing == T.RBracket);
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
  bool hasInvalidUTF8(cstring str, Token* begin)
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
