/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.parser.Parser;

import dil.lexer.Lexer,
       dil.lexer.IdTable;
import dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Statements,
       dil.ast.Expressions,
       dil.ast.Types,
       dil.ast.Parameters;
import dil.Messages;
import dil.Diagnostics;
import dil.Enums;
import dil.CompilerInfo;
import dil.SourceText;
import dil.Unicode;
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

  ImportDeclaration[] imports; /// ImportDeclarations in the source text.

  /// Attributes are evaluated in the parsing phase.
  /// TODO: will be removed. SemanticPass1 takes care of attributes.
  LinkageType linkageType;
  Protection protection; /// ditto
  StorageClass storageClass; /// ditto
  uint alignSize = DEFAULT_ALIGN_SIZE; /// ditto

  private alias TOK T; /// Used often in this class.
  private alias TypeNode Type;

  /// Constructs a Parser object.
  /// Params:
  ///   srcText = the UTF-8 source code.
  ///   diag = used for collecting error messages.
  this(SourceText srcText, Diagnostics diag = null)
  {
    this.diag = diag;
    lexer = new Lexer(srcText, diag);
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
    } while (token.isWhitespace) // Skip whitespace
  }

  /// Start the parser and return the parsed Declarations.
  CompoundDeclaration start()
  {
    init();
    auto begin = token;
    auto decls = new CompoundDeclaration;
    if (token.kind == T.Module)
      decls ~= parseModuleDeclaration();
    decls.addOptChildren(parseDeclarationDefinitions());
    set(decls, begin);
    return decls;
  }

  /// Start the parser and return the parsed Expression.
  Expression start2()
  {
    init();
    return parseExpression();
  }

  // Members related to the method try_().
  uint trying; /// Greater than 0 if Parser is in try_().
  uint errorCount; /// Used to track nr. of errors while being in try_().

  /// This method executes the delegate parseMethod and when an error occurred
  /// the state of the lexer and parser is restored.
  /// Returns: the return value of parseMethod().
  RetType try_(RetType)(RetType delegate() parseMethod, out bool success)
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
      success = false;
    }
    else
      success = true;
    return result;
  }

  /// Causes the current call to try_() to fail.
  void try_fail()
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
    node.setTokens(begin, this.prevToken);
    return node;
  }

  /// Sets the begin and end tokens of a syntax tree node.
  Class set(Class)(Class node, Token* begin, Token* end)
  {
    node.setTokens(begin, end);
    return node;
  }

  /// Returns true if set() has been called on a node.
  static bool isNodeSet(Node node)
  {
    return node.begin !is null && node.end !is null;
  }

  /// Returns the token kind of the next token.
  TOK peekNext()
  {
    Token* next = token;
    do
      lexer.peek(next);
    while (next.isWhitespace) // Skip whitespace
    return next.kind;
  }

  /// Returns the token kind of the token that comes after t.
  TOK peekAfter(ref Token* t)
  {
    assert(t !is null);
    do
      lexer.peek(t);
    while (t.isWhitespace) // Skip whitespace
    return t.kind;
  }

  /// Consumes the current token if its kind matches k and returns true.
  bool consumed()(TOK k) // Templatized, so it's inlined.
  {
    return token.kind == k ? (nT(), true) : false;
  }

  /// Consumes the current token if its kind matches k and returns it.
  Token* consumedToken()(TOK k) // Templatized, so it's inlined.
  {
    return token.kind == k ? (nT(), prevToken) : null;
  }

  /// Asserts that the current token is of kind expectedKind,
  /// and then moves to the next token.
  void skip()(TOK expectedKind)
  {
    assert(token.kind == expectedKind /+|| *(int*).init+/, token.text());
    nT();
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                       Declaration parsing methods                       |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// $(BNF ModuleDeclaration := module Identifier ("." Identifier)* ";")
  Declaration parseModuleDeclaration()
  {
    auto begin = token;
    skip(T.Module);
    ModuleFQN moduleFQN;
    Token* typeId;
    version(D2)
    {
    if (consumed(T.LParen))
    {
      typeId = requireIdentifier(MSG.ExpectedModuleType);
      if (typeId && typeId.ident !is Ident.safe &&
                    typeId.ident !is Ident.system &&
                    typeId.ident !is Ident.Empty)
        error(typeId, MSG.ExpectedModuleType);
      require(T.RParen);
    }
    }
    do
      moduleFQN ~= requireIdentifier(MSG.ExpectedModuleIdentifier);
    while (consumed(T.Dot))
    require(T.Semicolon);
    return set(new ModuleDeclaration(typeId, moduleFQN), begin);
  }

  /// Parses DeclarationDefinitions until the end of file is hit.
  /// $(BNF DeclDefs := DeclDef* )
  Declaration[] parseDeclarationDefinitions()
  {
    Declaration[] decls;
    while (token.kind != T.EOF)
      decls ~= parseDeclarationDefinition();
    return decls;
  }

  /// Parse the body of a template, class, interface, struct or union.
  /// $(BNF DeclDefsBlock := "{" DeclDefs? "}" )
  CompoundDeclaration parseDeclarationDefinitionsBody()
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
    auto decls = new CompoundDeclaration;
    require(T.LBrace);
    while (token.kind != T.RBrace && token.kind != T.EOF)
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
         //T.Static,
         T.Final,
         //T.Const,
         //T.Invariant, // D2
         T.Immutable, // D2
         T.Shared, // D2
         T.Gshared, // D2
         T.Ref, // D2
         T.Pure, // D2
         T.Nothrow, // D2
         T.Thread, // D2
         T.At, // D2
         T.Auto,
         T.Scope:
    case_ConstAttribute:
    case_StaticAttribute:
    case_InvariantAttribute: // D 2.0
    case_EnumAttribute: // D 2.0
      return parseAttributes();
    case T.Alias:
      nT();
      version (D2)
      {
      if (token.kind == T.Identifier && peekNext() == T.This)
      {
        auto ident = token;
        skip(T.Identifier);
        skip(T.This);
        require(T.Semicolon);
        decl = new AliasThisDeclaration(ident);
        break;
      }
      } // version(D2)
      auto d = new AliasDeclaration(parseAttributes(&decl));
      if (auto var = decl.Is!(VariablesDeclaration))
      {
        if (auto init = var.firstInit())
          error(init.begin.prevNWS(), MSG.AliasHasInitializer);
      }
      else if (!decl.Is!(FunctionDeclaration))
        error2(MSG.AliasExpectsVariable, decl.begin);
      decl = d;
      break;
    case T.Typedef:
      nT();
      auto td = new TypedefDeclaration(parseAttributes(&decl));
      if (!decl.Is!(VariablesDeclaration) && !decl.Is!(FunctionDeclaration))
        error2(MSG.TypedefExpectsVariable, decl.begin);
      decl = td;
      break;
    case T.Static:
      switch (peekNext())
      {
      case T.Import:
        goto case_Import;
      case T.This:
        decl = parseStaticConstructorDeclaration();
        break;
      case T.Tilde:
        decl = parseStaticDestructorDeclaration();
        break;
      case T.If:
        decl = parseStaticIfDeclaration();
        break;
      case T.Assert:
        decl = parseStaticAssertDeclaration();
        break;
      default:
        goto case_StaticAttribute;
      }
      break;
    case T.Import:
    case_Import:
      auto importDecl = parseImportDeclaration();
      imports ~= importDecl;
      // Handle specially. StorageClass mustn't be set.
      importDecl.setProtection(this.protection);
      return set(importDecl, begin);
    case T.Enum:
      version(D2)
      if (isEnumManifest())
        goto case_EnumAttribute;
      decl = parseEnumDeclaration();
      break;
    case T.Class:
      decl = parseClassDeclaration();
      break;
    case T.Interface:
      decl = parseInterfaceDeclaration();
      break;
    case T.Struct, T.Union:
      decl = parseStructOrUnionDeclaration();
      break;
    case T.This:
      decl = parseConstructorDeclaration();
      break;
    case T.Tilde:
      decl = parseDestructorDeclaration();
      break;
    case T.Const:
      version(D2)
      if (peekNext() == T.LParen)
        goto case_Declaration;
      goto case_ConstAttribute;
    case T.Invariant:
    version(D2)
    {
      auto next = token;
      if (peekAfter(next) == T.LParen)
      {
        if (peekAfter(next) != T.RParen)
          goto case_Declaration;  // invariant ( Type )
      }
      else
        goto case_InvariantAttribute; // invariant as StorageClass.
    }
      decl = parseInvariantDeclaration(); // invariant ( )
      break;
    case T.Unittest:
      decl = parseUnittestDeclaration();
      break;
    case T.Debug:
      decl = parseDebugDeclaration();
      break;
    case T.Version:
      decl = parseVersionDeclaration();
      break;
    case T.Template:
      decl = parseTemplateDeclaration();
      break;
    case T.New:
      decl = parseNewDeclaration();
      break;
    case T.Delete:
      decl = parseDeleteDeclaration();
      break;
    case T.Mixin:
      decl = parseMixin!(MixinDeclaration)();
      break;
    case T.Semicolon:
      nT();
      decl = new EmptyDeclaration();
      break;
    // Declaration
    case T.Identifier, T.Dot, T.Typeof:
    case_Declaration:
      return parseVariableOrFunction(this.storageClass, this.protection,
                                     this.linkageType);
    default:
      if (token.isIntegralType)
        goto case_Declaration;
      else if (token.kind == T.Module)
      {
        decl = parseModuleDeclaration();
        error(begin, MSG.ModuleDeclarationNotFirst);
        return decl;
      }

      decl = new IllegalDeclaration();
      // Skip to next valid token.
      do
        nT();
      while (!token.isDeclDefStart &&
              token.kind != T.RBrace &&
              token.kind != T.EOF)
      auto text = Token.textSpan(begin, this.prevToken);
      error(begin, MSG.IllegalDeclaration, text);
    }
    decl.setProtection(this.protection);
    decl.setStorageClass(this.storageClass);
    assert(!isNodeSet(decl));
    set(decl, begin);
    return decl;
  }

  /// Parses a DeclarationsBlock.
  /// $(BNF DeclarationsBlock := ":" DeclDefs | "{" DeclDefs? "}" | DeclDef )
  Declaration parseDeclarationsBlock(/+bool noColon = false+/)
  {
    Declaration d;
    switch (token.kind)
    {
    case T.LBrace:
      auto begin = token;
      nT();
      auto decls = new CompoundDeclaration;
      while (token.kind != T.RBrace && token.kind != T.EOF)
        decls ~= parseDeclarationDefinition();
      requireClosing(T.RBrace, begin);
      d = set(decls, begin);
      break;
    case T.Colon:
      // if (noColon == true)
      //   goto default;
      nT();
      auto begin = token;
      auto decls = new CompoundDeclaration;
      while (token.kind != T.RBrace && token.kind != T.EOF)
        decls ~= parseDeclarationDefinition();
      d = set(decls, begin);
      break;
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
  ////  AutoDeclaration | VariableDeclaration | FunctionDeclaration
  ////AutoDeclaration := AutoVariable | AutoTemplate
  ////AutoVariable := Name "=" Initializer MoreVariables? ";"
  ////VariableDeclaration := Type Name TypeSuffix? ("=" Initializer)?
  ////                       MoreVariables? ";"
  ////MoreVariables := ("," Name ("=" Initializer)?)+
  ////FunctionDeclaration := Type Name TemplateParameterList?
  ////                       ParameterList FunctionBody
  ////AutoTemplate := Name TemplateParameterList ParameterList FunctionBody
  ////Name := Identifier
  ////)
  /// Params:
  ///   stcs = previously parsed storage classes
  ///   protection = previously parsed protection attribute
  ///   linkType = previously parsed linkage type
  ///   testAutoDeclaration = whether to check for an AutoDeclaration
  Declaration parseVariableOrFunction(StorageClass stcs = StorageClass.None,
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
    if (testAutoDeclaration && token.kind == T.Identifier)
    {
      auto next_kind = peekNext();
      if (next_kind == T.Assign) // "auto" Identifier "="
      { // Auto variable declaration.
        name = token;
        skip(T.Identifier);
        goto LparseVariables;
      }
      else version(D2) if (next_kind == T.LParen)
      { // Check for auto return type (template) function.
        // StorageClasses Name
        //  ("(" TemplateParameterList ")")? "(" ParameterList ")"
        auto peek_token = token;
        peekAfter(peek_token); // Move to the next token, after the Identifier.
        next_kind = skipParens(peek_token, T.RParen);
        if (next_kind == T.LParen)
        {
          name = token;
          skip(T.Identifier);
          assert(token.kind == T.LParen);
          goto LparseTPList; // Continue with parsing a template function.
        }
        else if (next_kind == T.LBrace)
        {
          name = token;
          skip(T.Identifier);
          assert(token.kind == T.LParen);
          goto LparseBeforeParams;
        }
      }
    }

    // VariableType or ReturnType
    type = parseBasicTypes();

    if (token.kind == T.LParen)
    {
      type = parseCStyleType(type, &name);
      if (name.kind != T.Identifier)
        error2(MSG.ExpectedVariableName, name);
    }
    else if(0/+auto leftParen = consumedToken(T.LParen)+/)
    { // FIXME: doesn't work in all cases. :(
      // BasicTypes "(" CStyleType ")" DeclaratorSuffix?
      auto leftParen = token;
      auto innerType = parseCStyleType(type, &name);
      requireClosing(T.RParen, leftParen); // ")"

      bool noInnerType = innerType is type; // type.parent
      // Parse CFuncType?
      bool funcSuffix = noInnerType || token.kind != T.LParen;

      // Parse the suffix.
      auto innerTypeEnd = type.parent; // Save before parsing suffix.
      type.parent = null;
      type = parseDeclaratorSuffix(type, funcSuffix);
      if (innerTypeEnd !is null)
        innerTypeEnd.setNext(type), // Fix the type chain.
        type = innerType;

      if (!noInnerType) // Is the inner type a C-like function?
        if (auto cfunc = innerType.Is!(CFuncType))
          params = cfunc.params; // Retrieve the parameters.

      bool isFunc = params || !funcSuffix;
      if (name.kind != T.Identifier)
        error2(isFunc ? MSG.ExpectedFunctionName :
                        MSG.ExpectedVariableName, name);

      // Parse as a function instead of a variable?
      if (params)
        goto LparseAfterParams;
      if (!funcSuffix) // "(" ParameterList ")"
        goto LparseBeforeTParams;
    }
    else if (peekNext() == T.LParen)
    { // Type FunctionName "(" ParameterList ")" FunctionBody
      name = requireIdentifier(MSG.ExpectedFunctionName);
      if (token.kind != T.LParen)
        nT(); // Skip non-identifier token.

    LparseBeforeTParams:
      assert(token.kind == T.LParen);
      if (tokenAfterParenIs(T.LParen))
      LparseTPList:
        // "(" TemplateParameterList ")" "(" ParameterList ")"
        tparams = parseTemplateParameterList();
    LparseBeforeParams:
      params = parseParameterList();

    LparseAfterParams:
      version(D2)
      {
      auto postfix_stcs = parseFunctionPostfix();
      if (tparams) // if "(" ConstraintExpression ")"
        constraint = parseOptionalConstraint();
      } // version(D2)

      // ReturnType FunctionName "(" ParameterList ")"
      auto funcBody = parseFunctionBody();
      auto fd = new FunctionDeclaration(type, name, params, funcBody);
      fd.setLinkageType(linkType);
      Declaration decl = fd;
      if (tparams)
      { // putInside...() uses these members to set the attributes.
        auto saved_stcs = this.storageClass;
        auto saved_prot = this.protection;
        this.storageClass = stcs;
        this.protection = protection;
        decl =
          putInsideTemplateDeclaration(begin, name, fd, tparams, constraint);
        this.storageClass = saved_stcs;
        this.protection = saved_prot;
      }
      decl.setStorageClass(stcs);
      decl.setProtection(protection);
      return set(decl, begin);
    }
    else
    { // Type VariableName DeclaratorSuffix
      name = requireIdentifier(MSG.ExpectedVariableName);
      type = parseDeclaratorSuffix(type);
    }

  LparseVariables:
    // It's a variables declaration.
    Token*[] names = [name]; // One identifier has been parsed already.
    Expression[] values;
    goto LenterLoop; // Enter the loop and check for an initializer.
    while (consumed(T.Comma))
    {
      names ~= requireIdentifier(MSG.ExpectedVariableName);
    LenterLoop:
      if (consumed(T.Assign))
        values ~= parseInitializer();
      else
        values ~= null;
    }
    require(T.Semicolon);
    auto d = new VariablesDeclaration(type, names, values);
    d.setStorageClass(stcs);
    d.setLinkageType(linkType);
    d.setProtection(protection);
    return set(d, begin);
  }

  /// Parses a variable initializer.
  /// $(BNF Initializer := VoidInitializer | NonVoidInitializer
  ////VoidInitializer := void
  ////NonVoidInitializer := ArrayInitializer | StructInitializer |
  ////                      AssignExpression
  ////ArrayInitializer :=
  ////  "[" (ArrayInitElement ("," ArrayInitElement)* ","?)? "]"
  ////ArrayInitElement := (AssignExpression ":")? NonVoidInitializer
  ////StructInitializer :=
  ////  "{" (StructInitElement ("," StructInitElement)* ","?)? "}"
  ////StructInitElement := (MemberName ":")? NonVoidInitializer
  ////MemberName := Identifier)
  Expression parseInitializer()
  {
    if (token.kind == T.Void)
    {
      auto next = peekNext();
      if (next == T.Comma || next == T.Semicolon)
        return skip(T.Void), set(new VoidInitExpression(), prevToken);
    }
    return parseNonVoidInitializer();
  }

  /// Parses a NonVoidInitializer.
  /// $(BNF NonVoidInitializer :=
  ////  ArrayInitializer | StructInitializer | AssignExpression)
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
        goto default; // Parse as an AssignExpression.
      // ArrayInitializer := "[" ArrayMemberInitializations? "]"
      Expression[] keys, values;

      skip(T.LBracket);
      while (token.kind != T.RBracket)
      {
        Expression key;
        auto value = parseNonVoidInitializer();
        if (consumed(T.Colon))
          (key = value), // Switch roles.
          assert(!(key.Is!(ArrayInitExpression) ||
                   key.Is!(StructInitExpression))),
          value = parseNonVoidInitializer(); // Parse actual value.
        keys ~= key; values ~= value;
        if (!consumed(T.Comma))
          break;
      }
      requireClosing(T.RBracket, begin);
      init = new ArrayInitExpression(keys, values);
      break;
    case T.LBrace:
      auto after_bracket = tokenAfterBracket(T.RBrace);
      if (after_bracket != T.Comma && after_bracket != T.RBrace &&
          after_bracket != T.RBracket && after_bracket != T.Semicolon)
        goto default; // Parse as an AssignExpression.
      // StructInitializer := "{" StructMemberInitializers? "}"
      Token*[] idents;
      Expression[] values;

      skip(T.LBrace);
      while (token.kind != T.RBrace)
      { // Peek for colon to see if this is a member identifier.
        if (token.kind == T.Identifier && peekNext() == T.Colon)
          (idents ~= token),
          skip(T.Identifier), skip(T.Colon); // Identifier ":"
        else
          idents ~= null;
        // NonVoidInitializer
        values ~= parseNonVoidInitializer();
        if (!consumed(T.Comma))
          break;
      }
      requireClosing(T.RBrace, begin);
      init = new StructInitExpression(idents, values);
      break;
    default:
      return parseAssignExpression();
    }
    set(init, begin);
    return init;
  }

  /// Parses the body of a function.
  FuncBodyStatement parseFunctionBody()
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
          (outIdent = requireIdentifier(MSG.ExpectedAnIdentifier)),
          require(T.RParen);
        outBody = parseStatements();
        break;
      case T.Body:
        // if (!outBody || !inBody) // TODO:
        //   error2(MSG.ExpectedInOutBody, token);
        nT();
        goto case T.LBrace;
      default:
        error2(MSG.ExpectedFunctionBody, token);
        break Loop;
      }

    // Restore the original attributes.
    this.storageClass = saved_stcs;
    this.protection = saved_prot;
    this.linkageType = saved_link;

    auto func = new FuncBodyStatement(funcBody, inBody, outBody, outIdent);
    return set(func, begin);
  }

  /// $(BNF FunctionPostfix := (const | immutable | nothrow | shared |
  ////  pure | "@" Identifier)*)
  StorageClass parseFunctionPostfix()
  {
    version(D2)
    {
    StorageClass stcs, stc;
    while (1)
    {
      switch (token.kind)
      {
      case T.Const:
        stc = StorageClass.Const;
        break;
      case T.Immutable, T.Invariant:
        stc = StorageClass.Immutable;
        break;
      case T.Nothrow:
        stc = StorageClass.Nothrow;
        break;
      case T.Shared:
        stc = StorageClass.Shared;
        break;
      case T.Pure:
        stc = StorageClass.Pure;
        break;
      case T.At:
        stc = parseAtAttribute();
        break;
      default:
        return stcs;
      }
      if (stcs & stc)
        error2(MID.RedundantStorageClass, token);
      stcs |= stc;
      nT();
    }
    return stcs;
    }
    assert(0);
  }

  /// $(BNF ExternLinkageType :=
  ///  extern "(" ("C" | "C" "++" | "D" | "Windows" | "Pascal" | "System") ")")
  LinkageType parseExternLinkageType()
  {
    LinkageType linkageType;

    skip(T.Extern), skip(T.LParen); // extern "("

    if (consumed(T.RParen))
    { // extern "(" ")"
      error(MID.MissingLinkageType);
      return linkageType;
    }

    auto idtok = requireIdentifier(MSG.ExpectedLinkageIdentifier);
    IDK idKind = idtok ? idtok.ident.idKind : IDK.Empty;

    switch (idKind)
    {
    case IDK.C:
      if (consumed(T.PlusPlus))
      {
        linkageType = LinkageType.Cpp;
        break;
      }
      linkageType = LinkageType.C;
      break;
    case IDK.D:
      linkageType = LinkageType.D;
      break;
    case IDK.Windows:
      linkageType = LinkageType.Windows;
      break;
    case IDK.Pascal:
      linkageType = LinkageType.Pascal;
      break;
    case IDK.System:
      // Do this in the semantic analysis phase:
      // version(Windows)
      //   linkageType = LinkageType.Windows;
      // else
      //   linkageType = LinkageType.C;
      linkageType = LinkageType.System;
      break;
    case IDK.Empty: break; // Avoid reporting another error below.
    default:
      assert(idtok);
      error2(MID.UnrecognizedLinkageType, idtok);
    }
    require(T.RParen);
    return linkageType;
  }

  /// Reports an error if a linkage type has already been parsed.
  void checkLinkageType(ref LinkageType prev_lt, LinkageType lt, Token* begin)
  {
    if (prev_lt == LinkageType.None)
      prev_lt = lt;
    else
      error(begin, MSG.RedundantLinkageType, Token.textSpan(begin, prevToken));
  }

  /// Parses one or more attributes and a Declaration at the end.
  ///
  /// $(BNF
  ////Attributes := (StorageAttribute | OtherAttributes)*
  ////  (DeclarationsBlock | Declaration)
  ////StorageAttribute := extern | ExternLinkageType | override | abstract |
  ////  auto | synchronized | static | final | const | invariant | enum | scope
  ////
  ////OtherAttributes := AlignAttribute | PragmaAttribute | ProtectionAttribute
  ////AlignAttribute := align ("(" Integer ")")?
  ////PragmaAttribute := pragma "(" Identifier ("," ExpressionList)? ")"
  ////ProtectionAttribute := private | public | package | protected | export)
  /// Params:
  ///   pDecl = set to the non-attribute Declaration if non-null.
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
    scope emptyDecl = new EmptyDeclaration();
    // Function as the head of the attribute chain.
    scope AttributeDeclaration headAttr =
      new StorageClassDeclaration(StorageClass.None, emptyDecl);

    AttributeDeclaration currentAttr = headAttr, prevAttr = headAttr;

    // Parse the attributes.
  Loop:
    while (1)
    {
      auto begin = token;
      switch (token.kind)
      {
      case T.Extern:
        if (peekNext() != T.LParen)
        {
          stc = StorageClass.Extern;
          goto Lcommon;
        }
        checkLinkageType(linkageType, parseExternLinkageType(), begin);
        currentAttr = new LinkageDeclaration(linkageType, emptyDecl);
        testAutoDecl = false;
        break;
      case T.Override:
        stc = StorageClass.Override;
        goto Lcommon;
      case T.Deprecated:
        stc = StorageClass.Deprecated;
        goto Lcommon;
      case T.Abstract:
        stc = StorageClass.Abstract;
        goto Lcommon;
      case T.Synchronized:
        stc = StorageClass.Synchronized;
        goto Lcommon;
      case T.Static:
        switch (peekNext())
        { // Avoid parsing static import, static this etc.
        case T.Import, T.This, T.Tilde, T.If, T.Assert:
          break Loop;
        default:
        }
        stc = StorageClass.Static;
        goto Lcommon;
      case T.Final:
        stc = StorageClass.Final;
        goto Lcommon;
      version(D2)
      {
      case T.Invariant, T.Const, T.Immutable, T.Shared:
        if (peekNext() == T.LParen)
          break Loop;
        switch (token.kind)
        {
        case T.Const:     stc = StorageClass.Const; break;
        case T.Immutable: stc = StorageClass.Immutable; break;
        default:          stc = StorageClass.Shared; break;
        }
        goto Lcommon;
      case T.Enum:
        if (!isEnumManifest())
          break Loop;
        stc = StorageClass.Manifest; // enum as StorageClass.
        goto Lcommon;
      case T.Ref:
        stc = StorageClass.Ref;
        goto Lcommon;
      case T.Pure:
        stc = StorageClass.Pure;
        goto Lcommon;
      case T.Nothrow:
        stc = StorageClass.Nothrow;
        goto Lcommon;
      case T.Gshared:
        stc = StorageClass.Gshared;
        goto Lcommon;
      case T.Thread:
        stc = StorageClass.Thread;
        goto Lcommon;
      case T.At:
        stc = parseAtAttribute();
        goto Lcommon;
      } // version(D2)
      else
      { // D1
      case T.Const:
        stc = StorageClass.Const;
        goto Lcommon;
      }
      case T.Auto:
        stc = StorageClass.Auto;
        goto Lcommon;
      case T.Scope:
        stc = StorageClass.Scope;
        goto Lcommon;
      Lcommon:
        if (stcs & stc) // Issue error if redundant.
          error2(MID.RedundantStorageClass, token);
        stcs |= stc;

        nT();
        currentAttr = new StorageClassDeclaration(stc, emptyDecl);
        testAutoDecl = true;
        break;

      // Non-StorageClass attributes:
      // Protection attributes:
      case T.Private:
        prot = Protection.Private;
        goto Lprot;
      case T.Package:
        prot = Protection.Package;
        goto Lprot;
      case T.Protected:
        prot = Protection.Protected;
        goto Lprot;
      case T.Public:
        prot = Protection.Public;
        goto Lprot;
      case T.Export:
        prot = Protection.Export;
        goto Lprot;
      Lprot:
        if (protection != Protection.None)
          error2(MSG.RedundantProtection, token);
        protection = prot;
        nT();
        currentAttr = new ProtectionDeclaration(prot, emptyDecl);
        testAutoDecl = false;
        break;
      case T.Align:
        // align ("(" Integer ")")?
        Token* sizetok;
        alignSize = parseAlignAttribute(sizetok);
        // TODO: error msg for redundant align attributes.
        currentAttr = new AlignDeclaration(sizetok, emptyDecl);
        testAutoDecl = false;
        break;
      case T.Pragma:
        // Pragma := pragma "(" Identifier ("," ExpressionList)? ")"
        nT();
        Token* ident;

        auto leftParen = token;
        require(T.LParen);
        ident = requireIdentifier(MSG.ExpectedPragmaIdentifier);
        auto args = consumed(T.Comma) ? parseExpressionList() : null;
        requireClosing(T.RParen, leftParen);

        currentAttr = new PragmaDeclaration(ident, args, emptyDecl);
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
    if (testAutoDecl && token.kind == T.Identifier) // "auto" Identifier "="
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
  uint parseAlignAttribute(ref Token* sizetok)
  {
    skip(T.Align);
    uint size = DEFAULT_ALIGN_SIZE; // Global default.
    if (consumed(T.LParen))
    {
      if (token.kind == T.Int32)
        (sizetok = token), (size = token.int_), skip(T.Int32);
      else
        expected(T.Int32);
      require(T.RParen);
    }
    return size;
  }

  /// $(BNF AtAttribute := "@" Identifier)
  StorageClass parseAtAttribute()
  {
    skip(T.At); // "@"
    Token* idtok = token;
    if (token.kind != T.Identifier)
      idtok = requireIdentifier(MSG.ExpectedAttributeId);
    assert(idtok.kind == T.Identifier);
    IDK idKind = idtok ? idtok.ident.idKind : IDK.Empty;
    StorageClass stc;
    switch (idKind)
    {
    case IDK.disable:  stc = StorageClass.Disable;  break;
    case IDK.property: stc = StorageClass.Property; break;
    case IDK.safe:     stc = StorageClass.Safe;     break;
    case IDK.system:   stc = StorageClass.System;   break;
    case IDK.trusted:  stc = StorageClass.Trusted;  break;
    case IDK.Empty: break;
    default:
      assert(idtok);
      error2(MSG.UnrecognizedAttribute, idtok);
    }
    // Return without skipping the identifier.
    return stc;
  }

  /// $(BNF ImportDeclaration := static? import
  ////                     ImportModule ("," ImportModule)*
  ////                     (":" ImportBind ("," ImportBind)*)?
  ////                     ";"
  ////ImportModule := (AliasName "=")? ModuleName
  ////ImportBind := (AliasName "=")? BindName
  ////ModuleName := Identifier ("." Identifier)*
  ////AliasName := Identifier
  ////BindName := Identifier)
  ImportDeclaration parseImportDeclaration()
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
      if (peekNext() == T.Assign)
      {
        moduleAlias = requireIdentifier(MSG.ExpectedAliasModuleName);
        skip(T.Assign);
      }
      // Identifier ("." Identifier)*
      do
        moduleFQN ~= requireIdentifier(MSG.ExpectedModuleIdentifier);
      while (consumed(T.Dot))
      // Push identifiers.
      moduleFQNs ~= moduleFQN;
      moduleAliases ~= moduleAlias;
    } while (consumed(T.Comma))

    if (consumed(T.Colon))
    { // ImportBind := (BindAlias "=")? BindName
      // ":" ImportBind ("," ImportBind)*
      do
      {
        Token* bindAlias;
        // BindAlias = BindName
        if (peekNext() == T.Assign)
        {
          bindAlias = requireIdentifier(MSG.ExpectedAliasImportName);
          skip(T.Assign);
        }
        // Push identifiers.
        bindNames ~= requireIdentifier(MSG.ExpectedImportName);
        bindAliases ~= bindAlias;
      } while (consumed(T.Comma))
    }
    require(T.Semicolon);

    return new ImportDeclaration(moduleFQNs, moduleAliases, bindNames,
                                 bindAliases, isStatic);
  }

  /// Returns true if this is an enum manifest or
  /// false if it's a normal enum declaration.
  bool isEnumManifest()
  {
    version(D2)
    {
    assert(token.kind == T.Enum);
    auto next = token;
    auto kind = peekAfter(next);
    if (kind == T.Colon || kind == T.LBrace)
      return false; // Anonymous enum.
    else if (kind == T.Identifier)
    {
      kind = peekAfter(next);
      if (kind == T.Colon || kind == T.LBrace || kind == T.Semicolon)
        return false; // Named enum.
    }
    return true; // Manifest enum.
    }
    assert(0);
  }

  /// $(BNF
  ////EnumDeclaration := enum Name? (":" BasicType)? EnumBody |
  ////                   enum Name ";"
  ////EnumBody := "{" EnumMembers "}"
  ////EnumMembers := EnumMember ("," EnumMember)* ","?
  ////EnumMembers2 := Type? EnumMember ("," Type? EnumMember)* ","? # D2.0
  ////EnumMember := Name ("=" AssignExpression)?)
  Declaration parseEnumDeclaration()
  {
    skip(T.Enum);

    Token* enumName;
    Type baseType;
    EnumMemberDeclaration[] members;
    bool hasBody;

    enumName = optionalIdentifier();

    if (consumed(T.Colon))
      baseType = parseBasicType();

    if (enumName && consumed(T.Semicolon))
    {}
    else if (auto leftBrace = consumedToken(T.LBrace)) // "{"
    {
      hasBody = true;
      while (token.kind != T.RBrace)
      {
        Token* begin = token,
               name; // Name of the enum member.

        Type type;
      version(D2)
      {
        bool success;
        type = try_({ // Type Identifier "=" AssignExpression
          return parseDeclarator(name);
        }, success);
      }

        name = requireIdentifier(MSG.ExpectedEnumMember);
        Expression value;

        if (consumed(T.Assign))
          value = parseAssignExpression();

        auto member = new EnumMemberDeclaration(type, name, value);
        members ~= set(member, begin);

        if (!consumed(T.Comma))
          break;
      }
      requireClosing(T.RBrace, leftBrace); // "}"
    }
    else
      error2(MSG.ExpectedEnumBody, token);

    return new EnumDeclaration(enumName, baseType, members, hasBody);
  }

  /// Wraps a declaration inside a template declaration.
  /// Params:
  ///   begin = begin token of decl.
  ///   name = name of decl.
  ///   decl = the declaration to be wrapped.
  ///   tparams = the template parameters.
  ///   constraint = the constraint expression.
  TemplateDeclaration putInsideTemplateDeclaration(Token* begin,
                                                   Token* name,
                                                   Declaration decl,
                                                   TemplateParameters tparams,
                                                   Expression constraint)
  {
    set(decl, begin);
    auto cd = new CompoundDeclaration;
    cd ~= decl;
    set(cd, begin);
    decl.setStorageClass(this.storageClass);
    decl.setProtection(this.protection);
    return new TemplateDeclaration(name, tparams, constraint, cd);
  }

  /// $(BNF ClassDeclaration :=
  ////  class Name TemplateParameterList? (":" BaseClasses) ClassBody |
  ////  class Name ";"
  ////ClassBody := DeclarationDefinitionsBody)
  Declaration parseClassDeclaration()
  {
    auto begin = token;
    skip(T.Class);

    Token* name;
    TemplateParameters tparams;
    Expression constraint;
    BaseClassType[] bases;
    CompoundDeclaration decls;

    name = requireIdentifier(MSG.ExpectedClassName);

    if (token.kind == T.LParen)
    {
      tparams = parseTemplateParameterList();
      version(D2) constraint = parseOptionalConstraint();
    }

    if (consumed(T.Colon))
      bases = parseBaseClasses();

    if (bases.length == 0 && consumed(T.Semicolon))
    {}
    else if (token.kind == T.LBrace)
      decls = parseDeclarationDefinitionsBody();
    else
      error2(MSG.ExpectedClassBody, token);

    Declaration d = new ClassDeclaration(name, /+tparams, +/bases, decls);
    if (tparams)
      d = putInsideTemplateDeclaration(begin, name, d, tparams, constraint);
    return d;
  }

  /// $(BNF BaseClasses := BaseClass ("," BaseClass)
  ////BaseClass := Protection? BasicType
  ////Protection := private | public | protected | package)
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
    } while (consumed(T.Comma))
    return bases;
  }

  /// $(BNF InterfaceDeclaration :=
  ////  interface Name TemplateParameterList? (":" BaseClasses) InterfaceBody |
  ////  interface Name ";"
  ////InterfaceBody := DeclarationDefinitionsBody)
  Declaration parseInterfaceDeclaration()
  {
    auto begin = token;
    skip(T.Interface);

    Token* name;
    TemplateParameters tparams;
    Expression constraint;
    BaseClassType[] bases;
    CompoundDeclaration decls;

    name = requireIdentifier(MSG.ExpectedInterfaceName);

    if (token.kind == T.LParen)
    {
      tparams = parseTemplateParameterList();
      version(D2) constraint = parseOptionalConstraint();
    }

    if (consumed(T.Colon))
      bases = parseBaseClasses();

    if (bases.length == 0 && consumed(T.Semicolon))
    {}
    else if (token.kind == T.LBrace)
      decls = parseDeclarationDefinitionsBody();
    else
      error2(MSG.ExpectedInterfaceBody, token);

    Declaration d = new InterfaceDeclaration(name, bases, decls);
    if (tparams)
      d = putInsideTemplateDeclaration(begin, name, d, tparams, constraint);
    return d;
  }

  /// $(BNF StructDeclaration :=
  ////  struct Name? TemplateParameterList? StructBody |
  ////  struct Name ";"
  ////StructBody := DeclarationDefinitionsBody
  ////UnionDeclaration :=
  ////  union Name? TemplateParameterList? UnionBody |
  ////  union Name ";"
  ////UnionBody := DeclarationDefinitionsBody)
  Declaration parseStructOrUnionDeclaration()
  {
    assert(token.kind == T.Struct || token.kind == T.Union);
    auto begin = token;
    skip(token.kind);

    Token* name;
    TemplateParameters tparams;
    Expression constraint;
    CompoundDeclaration decls;

    name = optionalIdentifier();

    if (name && token.kind == T.LParen)
    {
      tparams = parseTemplateParameterList();
      version(D2) constraint = parseOptionalConstraint();
    }

    if (name && consumed(T.Semicolon))
    {}
    else if (token.kind == T.LBrace)
      decls = parseDeclarationDefinitionsBody();
    else
      error2(begin.kind == T.Struct ?
             MSG.ExpectedStructBody :
             MSG.ExpectedUnionBody, token);

    Declaration d;
    if (begin.kind == T.Struct)
    {
      auto sd = new StructDeclaration(name, /+tparams, +/decls);
      sd.setAlignSize(this.alignSize);
      d = sd;
    }
    else
      d = new UnionDeclaration(name, /+tparams, +/decls);

    if (tparams)
      d = putInsideTemplateDeclaration(begin, name, d, tparams, constraint);
    return d;
  }

  /// $(BNF ConstructorDeclaration := this ParameterList FunctionBody)
  Declaration parseConstructorDeclaration()
  {
    skip(T.This);
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new ConstructorDeclaration(parameters, funcBody);
  }

  /// $(BNF DestructorDeclaration := "~" this "(" ")" FunctionBody)
  Declaration parseDestructorDeclaration()
  {
    skip(T.Tilde);
    require(T.This);
    require(T.LParen);
    require(T.RParen);
    auto funcBody = parseFunctionBody();
    return new DestructorDeclaration(funcBody);
  }

  /// $(BNF StaticConstructorDeclaration := static this "(" ")" FunctionBody)
  Declaration parseStaticConstructorDeclaration()
  {
    skip(T.Static);
    skip(T.This);
    require(T.LParen);
    require(T.RParen);
    auto funcBody = parseFunctionBody();
    return new StaticConstructorDeclaration(funcBody);
  }

  /// $(BNF
  ////StaticDestructorDeclaration := static "~" this "(" ")" FunctionBody)
  Declaration parseStaticDestructorDeclaration()
  {
    skip(T.Static);
    skip(T.Tilde);
    require(T.This);
    require(T.LParen);
    require(T.RParen);
    auto funcBody = parseFunctionBody();
    return new StaticDestructorDeclaration(funcBody);
  }

  /// $(BNF InvariantDeclaration := invariant ("(" ")")? FunctionBody)
  Declaration parseInvariantDeclaration()
  {
    skip(T.Invariant);
    // Optional () for getting ready porting to D 2.0
    if (consumed(T.LParen))
      require(T.RParen);
    auto funcBody = parseFunctionBody();
    return new InvariantDeclaration(funcBody);
  }

  /// $(BNF UnittestDeclaration := unittest FunctionBody)
  Declaration parseUnittestDeclaration()
  {
    skip(T.Unittest);
    auto funcBody = parseFunctionBody();
    return new UnittestDeclaration(funcBody);
  }

  /// Parses an identifier or an integer. Reports an error otherwise.
  /// $(BNF IdentOrInt := Identifier | Integer)
  Token* parseIdentOrInt()
  {
    if (consumed(T.Identifier) || consumed(T.Int32))
      return this.prevToken;
    error2(MSG.ExpectedIdentOrInt, token);
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

  /// $(BNF DebugDeclaration := debug "=" IdentOrInt ";" |
  ////                    debug Condition? DeclarationsBlock
  ////                    (else DeclarationsBlock)?
  ////Condition := "(" IdentOrInt ")")
  Declaration parseDebugDeclaration()
  {
    skip(T.Debug);

    Token* spec;
    Token* cond;
    Declaration decls, elseDecls;

    if (consumed(T.Assign))
    { // debug = Integer ;
      // debug = Identifier ;
      spec = parseIdentOrInt();
      require(T.Semicolon);
    }
    else
    { // "(" Condition ")"
      if (consumed(T.LParen))
      {
        cond = parseIdentOrInt();
        require(T.RParen);
      }
      // debug DeclarationsBlock
      // debug ( Condition ) DeclarationsBlock
      decls = parseDeclarationsBlock();
      // else DeclarationsBlock
      if (consumed(T.Else))
        elseDecls = parseDeclarationsBlock();
    }

    return new DebugDeclaration(spec, cond, decls, elseDecls);
  }

  /// $(BNF VersionDeclaration := version "=" IdentOrInt ";" |
  ////                      version Condition DeclarationsBlock
  ////                      (else DeclarationsBlock)?
  ////Condition := "(" IdentOrInt ")")
  Declaration parseVersionDeclaration()
  {
    skip(T.Version);

    Token* spec;
    Token* cond;
    Declaration decls, elseDecls;

    if (consumed(T.Assign))
    { // version = Integer ;
      // version = Identifier ;
      spec = parseIdentOrInt();
      require(T.Semicolon);
    }
    else
    { // ( Condition )
      require(T.LParen);
      cond = parseVersionCondition();
      require(T.RParen);
      // version ( Condition ) DeclarationsBlock
      decls = parseDeclarationsBlock();
      // else DeclarationsBlock
      if (consumed(T.Else))
        elseDecls = parseDeclarationsBlock();
    }

    return new VersionDeclaration(spec, cond, decls, elseDecls);
  }

  /// $(BNF StaticIfDeclaration :=
  ////  static if "(" AssignExpression ")" DeclarationsBlock
  ////  (else DeclarationsBlock)?)
  Declaration parseStaticIfDeclaration()
  {
    skip(T.Static);
    skip(T.If);

    Expression condition;
    Declaration ifDecls, elseDecls;

    auto leftParen = token;
    require(T.LParen);
    condition = parseAssignExpression();
    requireClosing(T.RParen, leftParen);

    ifDecls = parseDeclarationsBlock();

    if (consumed(T.Else))
      elseDecls = parseDeclarationsBlock();

    return new StaticIfDeclaration(condition, ifDecls, elseDecls);
  }

  /// $(BNF StaticAsserDeclaration :=
  ////  static assert "(" AssignExpression ("," Message)? ")" ";"
  ////Message := AssignExpression)
  Declaration parseStaticAssertDeclaration()
  {
    skip(T.Static);
    skip(T.Assert);
    Expression condition, message;
    auto leftParen = token;
    require(T.LParen);
    condition = parseAssignExpression();
    if (consumed(T.Comma))
      message = parseAssignExpression();
    requireClosing(T.RParen, leftParen);
    require(T.Semicolon);
    return new StaticAssertDeclaration(condition, message);
  }

  /// $(BNF TemplateDeclaration :=
  ////  template Name TemplateParameterList Constraint?
  ////  DeclarationDefinitionsBody)
  Declaration parseTemplateDeclaration()
  {
    skip(T.Template);
    auto name = requireIdentifier(MSG.ExpectedTemplateName);
    auto tparams = parseTemplateParameterList();
    auto constraint = parseOptionalConstraint();
    auto decls = parseDeclarationDefinitionsBody();
    return new TemplateDeclaration(name, tparams, constraint, decls);
  }

  /// $(BNF NewDeclaration := new ParameterList FunctionBody)
  Declaration parseNewDeclaration()
  {
    skip(T.New);
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new NewDeclaration(parameters, funcBody);
  }

  /// $(BNF DeleteDeclaration := delete ParameterList FunctionBody)
  Declaration parseDeleteDeclaration()
  {
    skip(T.Delete);
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new DeleteDeclaration(parameters, funcBody);
  }

  /// $(BNF TypeofType := typeof "(" Expression ")" | TypeofReturn
  ////TypeofReturn := typeof "(" return ")")
  Type parseTypeofType()
  {
    auto begin = token;
    skip(T.Typeof);
    auto leftParen = token;
    require(T.LParen);
    Type type;
    switch (token.kind)
    {
    version(D2)
    {
    case T.Return:
      nT();
      type = new TypeofType();
      break;
    }
    default:
      type = new TypeofType(parseExpression());
    }
    requireClosing(T.RParen, leftParen);
    set(type, begin);
    return type;
  }

  /// Parses a MixinDeclaration or MixinStatement.
  /// $(BNF
  ////MixinDecl := (MixinExpression | MixinTemplate) ";"
  ////MixinExpression := mixin "(" AssignExpression ")"
  ////MixinTemplate := mixin TemplateIdentifier
  ////                 ("!" "(" TemplateArguments ")")? MixinIdentifier?)
  Class parseMixin(Class)()
  {
  static assert(is(Class == MixinDeclaration) || is(Class == MixinStatement));
    skip(T.Mixin);

  static if (is(Class == MixinDeclaration))
  {
    if (consumed(T.LParen))
    {
      auto leftParen = token;
      auto e = parseAssignExpression();
      requireClosing(T.RParen, leftParen);
      require(T.Semicolon);
      return new MixinDeclaration(e);
    }
  }

    auto begin = token;
    Expression e;
    Token* mixinIdent;

    if (token.kind == T.Dot)
      e = set(new ModuleScopeExpression(), begin, begin);
    else
      e = parseIdentifierExpression();

    while (consumed(T.Dot))
      e = set(new DotExpression(e, parseIdentifierExpression()), begin);

    mixinIdent = optionalIdentifier();
    require(T.Semicolon);

    return new Class(e, mixinIdent);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                        Statement parsing methods                        |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// $(BNF Statements := "{" Statement* "}")
  CompoundStatement parseStatements()
  {
    auto begin = token;
    require(T.LBrace);
    auto statements = new CompoundStatement();
    while (token.kind != T.RBrace && token.kind != T.EOF)
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
      goto LreturnDeclarationStatement;
    }

    switch (token.kind)
    {
    case T.Align:
      Token* sizetok;
      uint size = parseAlignAttribute(sizetok);
      // Restrict align attribute to structs in parsing phase.
      StructDeclaration structDecl;
      if (token.kind == T.Struct)
      {
        auto begin2 = token;
        structDecl = parseStructOrUnionDeclaration().to!(StructDeclaration);
        structDecl.setAlignSize(size);
        set(structDecl, begin2);
      }
      else
        expected(T.Struct);

      d = structDecl ? cast(Declaration)structDecl : new CompoundDeclaration;
      d = new AlignDeclaration(sizetok, d);
      goto LreturnDeclarationStatement;
      /+ Not applicable for statements.
         T.Private, T.Package, T.Protected, T.Public, T.Export,
         T.Deprecated, T.Override, T.Abstract,+/
    case T.Extern,
         T.Final,
         T.Const,
         T.Invariant, T.Immutable, // D2
         T.Pure,  // D2
         T.Shared, // D2
         T.Gshared, // D2
         T.Ref, // D2
         T.Nothrow, // D2
         T.Thread, // D2
         T.At, // D2
         T.Auto:
         //T.Scope
         //T.Static
    case_parseAttribute:
      s = parseAttributeStatement();
      break;
    case T.Identifier:
      if (peekNext() == T.Colon)
      {
        skip(T.Identifier); skip(T.Colon);
        s = new LabeledStatement(begin, parseNoScopeOrEmptyStatement());
        break;
      }
      goto case T.Dot;
    case T.Dot, T.Typeof:
      bool success;
      d = try_({ return parseVariableOrFunction(); }, success);
      if (success)
        goto LreturnDeclarationStatement; // Declaration
      else
        goto case_parseExpressionStatement; // Expression

    case T.If:
      s = parseIfStatement();
      break;
    case T.While:
      s = parseWhileStatement();
      break;
    case T.Do:
      s = parseDoWhileStatement();
      break;
    case T.For:
      s = parseForStatement();
      break;
    case T.Foreach, T.ForeachReverse:
      s = parseForeachStatement();
      break;
    case T.Switch:
      s = parseSwitchStatement();
      break;
    case T.Case:
      s = parseCaseStatement();
      break;
    case T.Default:
      s = parseDefaultStatement();
      break;
    case T.Continue:
      s = parseContinueStatement();
      break;
    case T.Break:
      s = parseBreakStatement();
      break;
    case T.Return:
      s = parseReturnStatement();
      break;
    case T.Goto:
      s = parseGotoStatement();
      break;
    case T.With:
      s = parseWithStatement();
      break;
    case T.Synchronized:
      s = parseSynchronizedStatement();
      break;
    case T.Try:
      s = parseTryStatement();
      break;
    case T.Throw:
      s = parseThrowStatement();
      break;
    case T.Scope:
      if (peekNext() != T.LParen)
        goto case_parseAttribute;
      s = parseScopeGuardStatement();
      break;
    case T.Volatile:
      s = parseVolatileStatement();
      break;
    case T.Asm:
      s = parseAsmBlockStatement();
      break;
    case T.Pragma:
      s = parsePragmaStatement();
      break;
    case T.Mixin:
      if (peekNext() == T.LParen)
        goto case_parseExpressionStatement; // Parse as expression.
      s = parseMixin!(MixinStatement)();
      break;
    case T.Static:
      switch (peekNext())
      {
      case T.If:
        s = parseStaticIfStatement();
        break;
      case T.Assert:
        s = parseStaticAssertStatement();
        break;
      default:
        goto case_parseAttribute;
      }
      break;
    case T.Debug:
      s = parseDebugStatement();
      break;
    case T.Version:
      s = parseVersionStatement();
      break;
    // DeclDef
    case T.Alias, T.Typedef:
      d = parseDeclarationDefinition();
      goto LreturnDeclarationStatement;
    case T.Enum:
      version(D2)
      if (isEnumManifest())
        goto case_parseAttribute;
      d = parseEnumDeclaration();
      goto LreturnDeclarationStatement;
    case T.Class:
      d = parseClassDeclaration();
      goto LreturnDeclarationStatement;
    case T.Interface:
      d = parseInterfaceDeclaration();
      goto LreturnDeclarationStatement;
    case T.Struct, T.Union:
      d = parseStructOrUnionDeclaration();
      // goto LreturnDeclarationStatement;
    LreturnDeclarationStatement:
      set(d, begin);
      s = new DeclarationStatement(d);
      break;
    case T.LBrace:
      s = parseScopeStatement();
      return s;
    case T.Semicolon:
      nT();
      s = new EmptyStatement();
      break;
    // Parse an ExpressionStatement:
    // Tokens that start a PrimaryExpression.
    // case T.Identifier, T.Dot, T.Typeof:
    case T.This:
    case T.Super:
    case T.Null:
    case T.True, T.False:
    // case T.Dollar:
    case T.Int32, T.Int64, T.Uint32, T.Uint64:
    case T.Float32, T.Float64, T.Float80,
         T.Imaginary32, T.Imaginary64, T.Imaginary80:
    case T.CharLiteral:
    case T.String:
    case T.LBracket:
    // case T.LBrace:
    case T.Function, T.Delegate:
    case T.Assert:
    // case T.Mixin:
    case T.Import:
    case T.Typeid:
    case T.Is:
    case T.LParen:
    case T.Traits: // D2.0
    // Tokens that can start a UnaryExpression:
    case T.AndBinary, T.PlusPlus, T.MinusMinus, T.Mul, T.Minus,
         T.Plus, T.Not, T.Tilde, T.New, T.Delete, T.Cast:
    case_parseExpressionStatement:
      s = new ExpressionStatement(parseExpression());
      require(T.Semicolon);
      break;
    default:
      if (token.isSpecialToken)
        goto case_parseExpressionStatement;

      if (token.kind != T.Dollar)
        // Assert that this isn't a valid expression.
        assert(delegate bool(){
            bool success;
            auto expression = try_(&parseExpression, success);
            return success;
          }() == false, "Didn't expect valid expression."
        );

      // Report error: it's an illegal statement.
      s = new IllegalStatement();
      // Skip to next valid token.
      do
        nT();
      while (!token.isStatementStart &&
              token.kind != T.RBrace &&
              token.kind != T.EOF)
      auto text = Token.textSpan(begin, this.prevToken);
      error(begin, MSG.IllegalStatement, text);
    }
    assert(s !is null);
    set(s, begin);
    return s;
  }

  /// Parses a ScopeStatement.
  /// $(BNF ScopeStatement := NoScopeStatement )
  Statement parseScopeStatement()
  {
    auto s = parseNoScopeStatement();
    return set(new ScopeStatement(s), s.begin);
  }

  /// $(BNF
  ////NoScopeStatement := NonEmptyStatement | BlockStatement
  ////BlockStatement   := Statements)
  Statement parseNoScopeStatement()
  {
    Statement s;
    if (token.kind == T.LBrace)
      s = parseStatements();
    else if(!consumed(T.Semicolon))
      s = parseStatement();
    else
    { // ";"
      error(prevToken, MSG.ExpectedNonEmptyStatement);
      s = set(new EmptyStatement(), prevToken);
    }
    return s;
  }

  /// $(BNF NoScopeOrEmptyStatement := ";" | NoScopeStatement )
  Statement parseNoScopeOrEmptyStatement()
  {
    if (auto semicolon = consumedToken(T.Semicolon))
      return set(new EmptyStatement(), semicolon);
    else
      return parseNoScopeStatement();
  }

  /// $(BNF AttributeStatement := Attributes+
  ////  (VariableOrFunctionDeclaration | DeclarationDefinition)
  ////Attributes := extern | ExternLinkageType | auto | static |
  ////              final | const | invariant | enum | scope)
  Statement parseAttributeStatement()
  {
    StorageClass stcs, stc;
    LinkageType linkageType;
    bool testAutoDecl;

    // Allocate dummy declarations.
    scope emptyDecl = new EmptyDeclaration();
    // Function as the head of the attribute chain.
    scope AttributeDeclaration headAttr =
      new StorageClassDeclaration(StorageClass.None, emptyDecl);

    AttributeDeclaration currentAttr, prevAttr = headAttr;

    // Parse the attributes.
  Loop:
    while (1)
    {
      auto begin = token;
      switch (token.kind)
      {
      case T.Extern:
        if (peekNext() != T.LParen)
        {
          stc = StorageClass.Extern;
          goto Lcommon;
        }
        checkLinkageType(linkageType, parseExternLinkageType(), begin);
        currentAttr = new LinkageDeclaration(linkageType, emptyDecl);
        testAutoDecl = false;
        break;
      case T.Static:
        // Commented out: These stmnts with attributes before them
        // would be illegal anyway.
        // switch (peekNext())
        // { // Avoid parsing static if and static assert.
        // case T.If, T.Assert:
        //   break Loop;
        // default:
        // }
        stc = StorageClass.Static;
        goto Lcommon;
      case T.Final:
        stc = StorageClass.Final;
        goto Lcommon;
      version(D2)
      {
      case T.Invariant, T.Const, T.Immutable, T.Shared:
        if (peekNext() == T.LParen)
          break Loop;
        switch (token.kind)
        {
        case T.Const:     stc = StorageClass.Const; break;
        case T.Immutable: stc = StorageClass.Immutable; break;
        default:          stc = StorageClass.Shared; break;
        }
        goto Lcommon;
      case T.Enum:
        if (!isEnumManifest())
          break Loop;
        stc = StorageClass.Manifest; // enum as StorageClass.
        goto Lcommon;
      case T.Ref:
        stc = StorageClass.Ref;
        goto Lcommon;
      case T.Pure:
        stc = StorageClass.Pure;
        goto Lcommon;
      case T.Nothrow:
        stc = StorageClass.Nothrow;
        goto Lcommon;
      case T.Gshared:
        stc = StorageClass.Gshared;
        goto Lcommon;
      case T.Thread:
        stc = StorageClass.Thread;
        goto Lcommon;
      case T.At:
        stc = parseAtAttribute();
        break;
      } // version(D2)
      else
      { // D1
      case T.Const:
        stc = StorageClass.Const;
        goto Lcommon;
      }
      case T.Auto:
        stc = StorageClass.Auto;
        goto Lcommon;
      case T.Scope:
        // ScopeGuardStatement with attributes isn't allowed anyway.
        // if (peekNext() == T.LParen)
        //   break Loop;
        stc = StorageClass.Scope;
        goto Lcommon;
      Lcommon:
        if (stcs & stc) // Issue error if redundant.
          error2(MID.RedundantStorageClass, token);
        stcs |= stc;

        nT();
        currentAttr = new StorageClassDeclaration(stc, emptyDecl);
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
    return new DeclarationStatement(headAttr.decls);
  }

  /// $(BNF IfStatement := if "(" Condition ")" ScopeStatement
  ////               (else ScopeStatement)?
  ////Condition := AutoDeclaration | VariableDeclaration | Expression)
  Statement parseIfStatement()
  {
    skip(T.If);

    Statement variable;
    Expression condition;
    Statement ifBody, elseBody;

    auto leftParen = token;
    require(T.LParen);

    Token* ident;
    auto begin = token; // For start of AutoDeclaration or normal Declaration.
    // auto Identifier = Expression
    if (consumed(T.Auto))
    {
      ident = requireIdentifier(MSG.ExpectedVariableName);
      require(T.Assign);
      auto init = parseExpression();
      auto v = new VariablesDeclaration(null, [ident], [init]);
      set(v, begin.nextNWS);
      auto d = new StorageClassDeclaration(StorageClass.Auto, v);
      set(d, begin);
      variable = new DeclarationStatement(d);
      set(variable, begin);
    }
    else
    { // Declarator "=" Expression
      bool success;
      auto type = try_({
        auto type = parseDeclarator(ident);
        require(T.Assign);
        return type;
      }, success);
      if (success)
      {
        auto init = parseExpression();
        auto v = new VariablesDeclaration(type, [ident], [init]);
        set(v, begin);
        variable = new DeclarationStatement(v);
        set(variable, begin);
      }
      else // Normal expression.
        condition = parseExpression();
    }
    requireClosing(T.RParen, leftParen);
    ifBody = parseScopeStatement();
    if (consumed(T.Else))
      elseBody = parseScopeStatement();
    return new IfStatement(variable, condition, ifBody, elseBody);
  }

  /// $(BNF WhileStatement := while "(" Expression ")" ScopeStatement)
  Statement parseWhileStatement()
  {
    skip(T.While);
    auto leftParen = token;
    require(T.LParen);
    auto condition = parseExpression();
    requireClosing(T.RParen, leftParen);
    return new WhileStatement(condition, parseScopeStatement());
  }

  /// $(BNF DoWhileStatement := do ScopeStatement while "(" Expression ")")
  Statement parseDoWhileStatement()
  {
    skip(T.Do);
    auto doBody = parseScopeStatement();
    require(T.While);
    auto leftParen = token;
    require(T.LParen);
    auto condition = parseExpression();
    requireClosing(T.RParen, leftParen);
    return new DoWhileStatement(condition, doBody);
  }

  /// $(BNF ForStatement :=
  ////  for "(" (NoScopeStatement | ";") Expression? ";" Expression? ")"
  ////    ScopeStatement)
  Statement parseForStatement()
  {
    skip(T.For);

    Statement init, forBody;
    Expression condition, increment;

    auto leftParen = token;
    require(T.LParen);
    if (!consumed(T.Semicolon))
      init = parseNoScopeStatement();
    if (token.kind != T.Semicolon)
      condition = parseExpression();
    require(T.Semicolon);
    if (token.kind != T.RParen)
      increment = parseExpression();
    requireClosing(T.RParen, leftParen);
    forBody = parseScopeStatement();
    return new ForStatement(init, condition, increment, forBody);
  }

  /// $(BNF ForeachStatement :=
  ////  Foreach "(" ForeachVarList ";" Aggregate ")"
  ////    ScopeStatement
  ////Foreach := foreach | foreach_reverse
  ////ForeachVarList := ForeachVar ("," ForeachVar)*
  ////ForeachVar := ref? (Identifier | Declarator)
  ////Aggregate := Expression | ForeachRange
  ////ForeachRange := Expression ".." Expression # D2.0)
  Statement parseForeachStatement()
  {
    assert(token.kind == T.Foreach || token.kind == T.ForeachReverse);
    TOK tok = token.kind;
    nT();

    auto params = new Parameters;
    Expression e; // Aggregate or LwrExpression

    auto leftParen = token;
    require(T.LParen);
    auto paramsBegin = token;
    do
    {
      auto paramBegin = token;
      StorageClass stc;
      Type type;
      Token* ident;

      switch (token.kind)
      {
      case T.Ref, T.Inout: // T.Inout is deprecated in D2.
        stc = StorageClass.Ref;
        nT();
        // fall through
      case T.Identifier:
        auto next = peekNext();
        if (next == T.Comma || next == T.Semicolon || next == T.RParen)
        { // (ref|inout)? Identifier
          ident = requireIdentifier(MSG.ExpectedVariableName);
          break;
        }
        // fall through
      default: // (ref|inout)? Declarator
        type = parseDeclarator(ident);
      }

      params ~= set(new Parameter(stc, type, ident, null), paramBegin);
    } while (consumed(T.Comma))
    set(params, paramsBegin);

    require(T.Semicolon);
    e = parseExpression();

  version(D2)
  { //Foreach (ForeachType; LwrExpression .. UprExpression ) ScopeStatement
    if (consumed(T.Slice))
    {
      // if (params.length != 1)
        // error(MID.XYZ); // TODO: issue error msg
      auto upper = parseExpression();
      requireClosing(T.RParen, leftParen);
      auto forBody = parseScopeStatement();
      return new ForeachRangeStatement(tok, params, e, upper, forBody);
    }
  }
    // Foreach (ForeachTypeList; Aggregate) ScopeStatement
    requireClosing(T.RParen, leftParen);
    auto forBody = parseScopeStatement();
    return new ForeachStatement(tok, params, e, forBody);
  }

  /// $(BNF SwitchStatement := switch "(" Expression ")" ScopeStatement)
  Statement parseSwitchStatement()
  {
    skip(T.Switch);
    auto leftParen = token;
    require(T.LParen);
    auto condition = parseExpression();
    requireClosing(T.RParen, leftParen);
    auto switchBody = parseScopeStatement();
    return new SwitchStatement(condition, switchBody);
  }

  /// Helper function for parsing the body of a default or case statement.
  /// $(BNF CaseOrDefaultBody := ScopeStatement)
  Statement parseCaseOrDefaultBody()
  {
    // This function is similar to parseNoScopeStatement()
    auto begin = token;
    auto s = new CompoundStatement();
    while (token.kind != T.Case &&
           token.kind != T.Default &&
           token.kind != T.RBrace &&
           token.kind != T.EOF)
      s ~= parseStatement();
    if (begin is token) // Nothing consumed.
      begin = this.prevToken;
    set(s, begin);
    return set(new ScopeStatement(s), begin);
  }

  /// $(BNF CaseStatement := case ExpressionList ":" CaseOrDefaultBody)
  Statement parseCaseStatement()
  {
    skip(T.Case);
    auto values = parseExpressionList();
    require(T.Colon);
    auto caseBody = parseCaseOrDefaultBody();
    return new CaseStatement(values, caseBody);
  }

  /// $(BNF DefaultStatement := default ":" CaseOrDefaultBody)
  Statement parseDefaultStatement()
  {
    skip(T.Default);
    require(T.Colon);
    auto defaultBody = parseCaseOrDefaultBody();
    return new DefaultStatement(defaultBody);
  }

  /// $(BNF ContinueStatement := continue Identifier? ";")
  Statement parseContinueStatement()
  {
    skip(T.Continue);
    auto ident = optionalIdentifier();
    require(T.Semicolon);
    return new ContinueStatement(ident);
  }

  /// $(BNF BreakStatement := break Identifier? ";")
  Statement parseBreakStatement()
  {
    skip(T.Break);
    auto ident = optionalIdentifier();
    require(T.Semicolon);
    return new BreakStatement(ident);
  }

  /// $(BNF ReturnStatement := return Expression? ";")
  Statement parseReturnStatement()
  {
    skip(T.Return);
    Expression expr;
    if (token.kind != T.Semicolon)
      expr = parseExpression();
    require(T.Semicolon);
    return new ReturnStatement(expr);
  }

  /// $(BNF
  ////GotoStatement := goto (case Expression? | default | Identifier) ";")
  Statement parseGotoStatement()
  {
    skip(T.Goto);
    auto ident = token;
    Expression caseExpr;
    switch (token.kind)
    {
    case T.Case:
      nT();
      if (token.kind == T.Semicolon)
        break;
      caseExpr = parseExpression();
      break;
    case T.Default:
      nT();
      break;
    default:
      ident = requireIdentifier(MSG.ExpectedAnIdentifier);
    }
    require(T.Semicolon);
    return new GotoStatement(ident, caseExpr);
  }

  /// $(BNF WithStatement := with "(" Expression ")" ScopeStatement)
  Statement parseWithStatement()
  {
    skip(T.With);
    auto leftParen = token;
    require(T.LParen);
    auto expr = parseExpression();
    requireClosing(T.RParen, leftParen);
    return new WithStatement(expr, parseScopeStatement());
  }

  /// $(BNF SynchronizedStatement :=
  ////  synchronized ("(" Expression ")")? ScopeStatement)
  Statement parseSynchronizedStatement()
  {
    skip(T.Synchronized);
    Expression expr;
    if (auto leftParen = consumedToken(T.LParen))
    {
      expr = parseExpression();
      requireClosing(T.RParen, leftParen);
    }
    return new SynchronizedStatement(expr, parseScopeStatement());
  }

  /// $(BNF TryStatement :=
  ////  try ScopeStatement
  ////  (CatchStatement* LastCatchStatement? FinallyStatement? |
  ////   CatchStatement)
  ////CatchStatement := catch "(" BasicType Identifier ")" NoScopeStatement
  ////LastCatchStatement := catch NoScopeStatement
  ////FinallyStatement := finally NoScopeStatement)
  Statement parseTryStatement()
  {
    auto begin = token;
    skip(T.Try);

    auto tryBody = parseScopeStatement();
    CatchStatement[] catchBodies;
    FinallyStatement finBody;

    while (consumed(T.Catch))
    {
      auto catchBegin = prevToken;
      Parameter param;
      if (auto leftParen = consumedToken(T.LParen))
      {
        auto paramBegin = token;
        Token* name;
        auto type = parseDeclarator(name, true);
        param = new Parameter(StorageClass.None, type, name, null);
        set(param, paramBegin);
        requireClosing(T.RParen, leftParen);
      }
      catchBodies ~= set(new CatchStatement(param, parseNoScopeStatement()),
                         catchBegin);
      if (param is null)
        break; // This is a LastCatch
    }

    if (auto t = consumedToken(T.Finally))
      finBody = set(new FinallyStatement(parseNoScopeStatement()), t);

    if (catchBodies is null && finBody is null)
      error(begin, MSG.MissingCatchOrFinally);

    return new TryStatement(tryBody, catchBodies, finBody);
  }

  /// $(BNF ThrowStatement := throw Expression ";")
  Statement parseThrowStatement()
  {
    skip(T.Throw);
    auto expr = parseExpression();
    require(T.Semicolon);
    return new ThrowStatement(expr);
  }

  /// $(BNF ScopeGuardStatement := scope "(" ScopeCondition ")" ScopeGuardBody
  ////ScopeCondition := "exit" | "success" | "failure"
  ////ScopeGuardBody := ScopeStatement | NoScopeStatement)
  Statement parseScopeGuardStatement()
  {
    skip(T.Scope);
    skip(T.LParen);
    auto condition = requireIdentifier(MSG.ExpectedScopeIdentifier);
    if (condition)
      switch (condition.ident.idKind)
      {
      case IDK.exit, IDK.success, IDK.failure: break;
      default:
        if (condition.ident != Ident.Empty) // Don't report error twice.
          error2(MSG.InvalidScopeIdentifier, condition);
      }
    require(T.RParen);
    auto scopeBody = (token.kind == T.LBrace) ?
                      parseScopeStatement() : parseNoScopeStatement();
    return new ScopeGuardStatement(condition, scopeBody);
  }

  /// $(BNF VolatileStatement := volatile VolatileBody? ";"
  ////VolatileBody := ScopeStatement | NoScopeStatement)
  Statement parseVolatileStatement()
  {
    skip(T.Volatile);
    Statement volatileBody;
    if (token.kind == T.Semicolon)
      nT();
    else if (token.kind == T.LBrace)
      volatileBody = parseScopeStatement();
    else
      volatileBody = parseStatement();
    return new VolatileStatement(volatileBody);
  }

  /// $(BNF PragmaStatement :=
  ////  pragma "(" PragmaName ("," ExpressionList) ")" NoScopeStatement)
  Statement parsePragmaStatement()
  {
    skip(T.Pragma);

    Token* name;
    Expression[] args;
    Statement pragmaBody;

    auto leftParen = token;
    require(T.LParen);
    name = requireIdentifier(MSG.ExpectedPragmaIdentifier);

    if (consumed(T.Comma))
      args = parseExpressionList();
    requireClosing(T.RParen, leftParen);

    pragmaBody = parseNoScopeOrEmptyStatement();

    return new PragmaStatement(name, args, pragmaBody);
  }

  /// $(BNF StaticIfStatement :=
  ////  static if "(" Expression ")" NoScopeStatement
  ////  (else NoScopeStatement)?)
  Statement parseStaticIfStatement()
  {
    skip(T.Static);
    skip(T.If);
    Expression condition;
    Statement ifBody, elseBody;

    auto leftParen = token;
    require(T.LParen);
    condition = parseExpression();
    requireClosing(T.RParen, leftParen);
    ifBody = parseNoScopeStatement();
    if (consumed(T.Else))
      elseBody = parseNoScopeStatement();
    return new StaticIfStatement(condition, ifBody, elseBody);
  }

  /// $(BNF StaticAssertStatement :=
  ////  static assert "(" AssignExpression ("," Message) ")"
  ////Message := AssignExpression)
  Statement parseStaticAssertStatement()
  {
    skip(T.Static);
    skip(T.Assert);
    Expression condition, message;

    require(T.LParen);
    condition = parseAssignExpression(); // Condition.
    if (consumed(T.Comma))
      message = parseAssignExpression(); // Error message.
    require(T.RParen);
    require(T.Semicolon);
    return new StaticAssertStatement(condition, message);
  }

  /// $(BNF DebugStatement := debug Condition? NoScopeStatement
  ////                  (else NoScopeStatement)?
  ////Condition := "(" IdentOrInt ")")
  Statement parseDebugStatement()
  {
    skip(T.Debug);
    Token* cond;
    Statement debugBody, elseBody;

    // ( Condition )
    if (consumed(T.LParen))
    {
      cond = parseIdentOrInt();
      require(T.RParen);
    }
    // debug Statement
    // debug ( Condition ) Statement
    debugBody = parseNoScopeStatement();
    // else Statement
    if (consumed(T.Else))
      elseBody = parseNoScopeStatement();

    return new DebugStatement(cond, debugBody, elseBody);
  }

  /// $(BNF VersionStatement := version Condition NoScopeStatement
  ////                  (else NoScopeStatement)?
  ////Condition := "(" IdentOrInt ")")
  Statement parseVersionStatement()
  {
    skip(T.Version);
    Token* cond;
    Statement versionBody, elseBody;

    // ( Condition )
    require(T.LParen);
    cond = parseVersionCondition();
    require(T.RParen);
    // version ( Condition ) Statement
    versionBody = parseNoScopeStatement();
    // else Statement
    if (consumed(T.Else))
      elseBody = parseNoScopeStatement();

    return new VersionStatement(cond, versionBody, elseBody);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                        Assembler parsing methods                        |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// Parses an AsmBlockStatement.
  /// $(BNF AsmBlockStatement := asm "{" AsmStatement* "}" )
  Statement parseAsmBlockStatement()
  {
    skip(T.Asm);
    auto leftBrace = token;
    require(T.LBrace);
    auto ss = new CompoundStatement;
    while (token.kind != T.RBrace && token.kind != T.EOF)
      ss ~= parseAsmStatement();
    requireClosing(T.RBrace, leftBrace);
    return new AsmBlockStatement(set(ss, leftBrace));
  }

  /// $(BNF
  ////AsmStatement := OpcodeStatement | LabeledStatement |
  ////                AsmAlignStatement | EmptyStatement
  ////OpcodeStatement := Opcode Operands? ";"
  ////Opcode := Identifier
  ////Operands := AsmExpression ("," AsmExpression)*
  ////LabeledStatement := Identifier ":" AsmStatement
  ////AsmAlignStatement := align Integer ";"
  ////EmptyStatement := ";")
  Statement parseAsmStatement()
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
      { // Identifier ":" AsmStatement
        s = new LabeledStatement(ident, parseAsmStatement());
        break;
      }

      // JumpOpcode (short | (near | far) ptr)?
      if (Ident.isJumpOpcode(ident.ident.idKind))
      {
        auto jmptype = token.ident;
        if (token.kind == T.Short)
          nT();
        else if (token.kind == T.Identifier &&
                 (jmptype is Ident.near || jmptype is Ident.far))
        {
          nT();
          if (token.kind == T.Identifier && token.ident is Ident.ptr)
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
      if (token.kind != T.Semicolon)
        do
          es ~= parseAsmExpression();
        while (consumed(T.Comma))
      require(T.Semicolon);
      s = new AsmStatement(ident, es);
      break;
    case T.Align:
      // align Integer ";"
      nT();
      auto number = token;
      if (!consumed(T.Int32))
        error2(MSG.ExpectedIntegerAfterAlign, token);
      require(T.Semicolon);
      s = new AsmAlignStatement(number);
      break;
    case T.Semicolon:
      s = new EmptyStatement();
      nT();
      break;
    default:
      s = new IllegalAsmStatement();
      // Skip to next valid token.
      do
        nT();
      while (!token.isAsmStatementStart &&
              token.kind != T.RBrace &&
              token.kind != T.EOF)
      auto text = Token.textSpan(begin, this.prevToken);
      error(begin, MSG.IllegalAsmStatement, text);
    }
    set(s, begin);
    return s;
  }

  /// $(BNF AsmExpression := AsmCondExpression
  ////AsmCondExpression :=
  ////  AsmOrOrExpression ("?" AsmExpression ":" AsmExpression)? )
  Expression parseAsmExpression()
  {
    auto begin = token;
    auto e = parseAsmOrOrExpression();
    if (auto qtok = consumedToken(T.Question)) // "?"
    {
      auto iftrue = parseAsmExpression();
      auto ctok = token; // ":"
      require(T.Colon);
      auto iffalse = parseAsmExpression();
      e = new CondExpression(e, iftrue, iffalse, qtok, ctok);
      set(e, begin);
    }
    // TODO: create AsmExpression that contains e?
    return e;
  }

  /// $(BNF AsmOrOrExpression :=
  ////  AsmAndAndExpression ("||" AsmAndAndExpression)* )
  Expression parseAsmOrOrExpression()
  {
    alias parseAsmAndAndExpression parseNext;
    auto begin = token;
    auto e = parseNext();
    while (token.kind == T.OrLogical)
    {
      auto tok = token;
      nT();
      e = new OrOrExpression(e, parseNext(), tok);
      set(e, begin);
    }
    return e;
  }

  /// $(BNF AsmAndAndExpression :=
  ////  AsmOrExpression ("&&" AsmOrExpression)* )
  Expression parseAsmAndAndExpression()
  {
    alias parseAsmOrExpression parseNext;
    auto begin = token;
    auto e = parseNext();
    while (token.kind == T.AndLogical)
    {
      auto tok = token;
      nT();
      e = new AndAndExpression(e, parseNext(), tok);
      set(e, begin);
    }
    return e;
  }

  /// $(BNF AsmOrExpression := AsmXorExpression ("|" AsmXorExpression)* )
  Expression parseAsmOrExpression()
  {
    alias parseAsmXorExpression parseNext;
    auto begin = token;
    auto e = parseNext();
    while (token.kind == T.OrBinary)
    {
      auto tok = token;
      nT();
      e = new OrExpression(e, parseNext(), tok);
      set(e, begin);
    }
    return e;
  }

  /// $(BNF AsmXorExpression := AsmAndExpression ("^" AsmAndExpression)* )
  Expression parseAsmXorExpression()
  {
    alias parseAsmAndExpression parseNext;
    auto begin = token;
    auto e = parseNext();
    while (token.kind == T.Xor)
    {
      auto tok = token;
      nT();
      e = new XorExpression(e, parseNext(), tok);
      set(e, begin);
    }
    return e;
  }

  /// $(BNF AsmAndExpression := AsmCmpExpression ("&" AsmCmpExpression)* )
  Expression parseAsmAndExpression()
  {
    alias parseAsmCmpExpression parseNext;
    auto begin = token;
    auto e = parseNext();
    while (token.kind == T.AndBinary)
    {
      auto tok = token;
      nT();
      e = new AndExpression(e, parseNext(), tok);
      set(e, begin);
    }
    return e;
  }

  /// $(BNF AsmCmpExpression := AsmShiftExpression (Op AsmShiftExpression)*
  ////Op := "==" | "!=" | "<" | "<=" | ">" | ">=" )
  Expression parseAsmCmpExpression()
  {
    alias parseAsmShiftExpression parseNext;
    auto begin = token;
    auto e = parseNext();

    auto operator = token;
    switch (operator.kind)
    {
    case T.Equal, T.NotEqual:
      nT();
      e = new EqualExpression(e, parseNext(), operator);
      break;
    case T.LessEqual, T.Less, T.GreaterEqual, T.Greater:
      nT();
      e = new RelExpression(e, parseNext(), operator);
      break;
    default:
      return e;
    }
    set(e, begin);
    return e;
  }

  /// $(BNF AsmShiftExpression := AsmAddExpression (Op AsmAddExpression)*
  ////Op := "<<" | ">>" | ">>>" )
  Expression parseAsmShiftExpression()
  {
    alias parseAsmAddExpression parseNext;
    auto begin = token;
    auto e = parseNext();
    while (1)
    {
      auto operator = token;
      switch (operator.kind)
      {
      case T.LShift:
        nT(); e = new LShiftExpression(e, parseNext(), operator); break;
      case T.RShift:
        nT(); e = new RShiftExpression(e, parseNext(), operator); break;
      case T.URShift:
        nT(); e = new URShiftExpression(e, parseNext(), operator); break;
      default:
        return e;
      }
      set(e, begin);
    }
    assert(0);
  }

  /// $(BNF AsmAddExpression := AsmMulExpression (Op AsmMulExpression)*
  ////Op := "+" | "-" )
  Expression parseAsmAddExpression()
  {
    alias parseAsmMulExpression parseNext;
    auto begin = token;
    auto e = parseNext();
    while (1)
    {
      auto operator = token;
      switch (operator.kind)
      {
      case T.Plus:
        nT(); e = new PlusExpression(e, parseNext(), operator); break;
      case T.Minus:
        nT(); e = new MinusExpression(e, parseNext(), operator); break;
      // Not allowed in asm
      //case T.Tilde:
      //  nT(); e = new CatExpression(e, parseNext(), operator); break;
      default:
        return e;
      }
      set(e, begin);
    }
    assert(0);
  }

  /// $(BNF AsmMulExpression := AsmPostExpression (Op AsmPostExpression)*
  ////Op := "*" | "/" | "%" )
  Expression parseAsmMulExpression()
  {
    alias parseAsmPostExpression parseNext;
    auto begin = token;
    auto e = parseNext();
    while (1)
    {
      auto operator = token;
      switch (operator.kind)
      {
      case T.Mul: nT(); e = new MulExpression(e, parseNext(), operator); break;
      case T.Div: nT(); e = new DivExpression(e, parseNext(), operator); break;
      case T.Mod: nT(); e = new ModExpression(e, parseNext(), operator); break;
      default:
        return e;
      }
      set(e, begin);
    }
    assert(0);
  }

  /// $(BNF AsmPostExpression := AsmUnaryExpression ("[" AsmExpression "]")* )
  Expression parseAsmPostExpression()
  {
    Token* begin = token, leftBracket = void;
    auto e = parseAsmUnaryExpression();
    while ((leftBracket = consumedToken(T.LBracket)) !is null)
    {
      e = new AsmPostBracketExpression(e, parseAsmExpression());
      requireClosing(T.RBracket, leftBracket);
      set(e, begin);
    }
    return e;
  }

  /// $(BNF
  ////AsmUnaryExpression := AsmPrimaryExpression |
  ////  AsmTypeExpression | AsmOffsetExpression | AsmSegExpression |
  ////  SignExpression | NotExpression | ComplementExpression
  ////AsmTypeExpression := TypePrefix "ptr" AsmExpression
  ////TypePrefix := "byte" | "shor" | "int" | "float" | "double" | "real"
  ////              "near" | "far" | "word" | "dword" | "qword"
  ////AsmOffsetExpression := "offset" AsmExpression
  ////AsmSegExpression := "seg" AsmExpression
  ////SignExpression := ("+" | "-") AsmUnaryExpression
  ////NotExpression := "!" AsmUnaryExpression
  ////ComplementExpression := "~" AsmUnaryExpression
  ////)
  Expression parseAsmUnaryExpression()
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
        if (token.kind == T.Identifier && token.ident is Ident.ptr)
          skip(T.Identifier);
        else
          error2(MID.ExpectedButFound, "ptr", token);
        e = new AsmTypeExpression(parseAsmExpression());
        break;
      case IDK.offsetof:
        nT();
        e = new AsmOffsetExpression(parseAsmExpression());
        break;
      case IDK.seg:
        nT();
        e = new AsmSegExpression(parseAsmExpression());
        break;
      default:
        goto LparseAsmPrimaryExpression;
      }
      break;
    case T.Minus:
    case T.Plus:
      nT();
      e = new SignExpression(parseAsmUnaryExpression());
      break;
    case T.Not:
      nT();
      e = new NotExpression(parseAsmUnaryExpression());
      break;
    case T.Tilde:
      nT();
      e = new CompExpression(parseAsmUnaryExpression());
      break;
    default:
    LparseAsmPrimaryExpression:
      e = parseAsmPrimaryExpression();
      return e;
    }
    set(e, begin);
    return e;
  }

  /// $(BNF AsmPrimaryExpression :=
  ////  IntExpression | RealExpression | DollarExpression | DotExpression |
  ////  AsmLocalSizeExpression | AsmRegisterExpression | AsmBracketExpression |
  ////  IdentifierExpression
  ////IntExpression := Integer
  ////RealExpression := Float | Imaginary
  ////DollarExpression := "$"
  ////AsmBracketExpression :=  "[" AsmExpression "]"
  ////AsmLocalSizeExpression := "__LOCAL_SIZE"
  ////AsmRegisterExpression := ...
  ////DotExpression := (ModuleScopeExpression | IdentifierExpression)
  ////                 ("." IdentifierExpression)+
  ////ModuleScopeExpression := ".")
  Expression parseAsmPrimaryExpression()
  {
    auto begin = token;
    Expression e;
    switch (token.kind)
    {
    case T.Int32, T.Int64, T.Uint32, T.Uint64:
      e = new IntExpression(token);
      nT();
      break;
    case T.Float32, T.Float64, T.Float80,
         T.Imaginary32, T.Imaginary64, T.Imaginary80:
      e = new RealExpression(token);
      nT();
      break;
    case T.Dollar:
      e = new DollarExpression();
      nT();
      break;
    case T.LBracket:
      // [ AsmExpression ]
      auto leftBracket = token;
      nT();
      e = parseAsmExpression();
      requireClosing(T.RBracket, leftBracket);
      e = new AsmBracketExpression(e);
      break;
    case T.Identifier:
      auto register = token.ident;
      switch (register.idKind)
      {
      // __LOCAL_SIZE
      case IDK.__LOCAL_SIZE:
        nT();
        e = new AsmLocalSizeExpression();
        break;
      // Register
      case IDK.ST:
        nT();
        Expression number; // (1) - (7)
        if (consumed(T.LParen))
          (number = parseAsmExpression()),
          require(T.RParen);
        e = new AsmRegisterExpression(register, number);
        break;
      case IDK.ES, IDK.CS, IDK.SS, IDK.DS, IDK.GS, IDK.FS:
        nT();
        Expression number;
        if (consumed(T.Colon)) // Segment := XX ":" AsmExpression
          number = parseAsmExpression();
        e = new AsmRegisterExpression(register, number);
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
        e = new AsmRegisterExpression(register);
        break;
      default:
        e = parseIdentifierExpression();
        while (consumed(T.Dot))
          e = set(new DotExpression(e, parseIdentifierExpression()), begin);
      } // end of switch
      break;
    case T.Dot:
      e = set(new ModuleScopeExpression(), begin, begin);
      while (consumed(T.Dot))
        e = set(new DotExpression(e, parseIdentifierExpression()), begin);
      break;
    default:
      error2(MID.ExpectedButFound, "Expression", token);
      e = new IllegalExpression();
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

  /// The root method for parsing an Expression.
  /// $(BNF Expression := AssignExpression ("," AssignExpression)* )
  Expression parseExpression()
  {
    alias parseAssignExpression parseNext;
    auto begin = token;
    auto e = parseNext();
    while (token.kind == T.Comma)
    {
      auto comma = token;
      nT();
      e = new CommaExpression(e, parseNext(), comma);
      set(e, begin);
    }
    return e;
  }

  /// $(BNF AssignExpression := CondExpression (Op AssignExpression)*
  ////Op := "=" | "<<=" | ">>=" | ">>>=" | "|=" |
  ////      "&=" | "+=" | "-=" | "/=" | "*=" | "%=" | "^=" | "~=" | "^^="
  ////)
  Expression parseAssignExpression()
  {
    alias parseAssignExpression parseNext;
    auto begin = token;
    auto e = parseCondExpression();
    switch (token.kind)
    {
    case T.Assign:
      nT(); e = new AssignExpression(e, parseNext()); break;
    case T.LShiftAssign:
      nT(); e = new LShiftAssignExpression(e, parseNext()); break;
    case T.RShiftAssign:
      nT(); e = new RShiftAssignExpression(e, parseNext()); break;
    case T.URShiftAssign:
      nT(); e = new URShiftAssignExpression(e, parseNext()); break;
    case T.OrAssign:
      nT(); e = new OrAssignExpression(e, parseNext()); break;
    case T.AndAssign:
      nT(); e = new AndAssignExpression(e, parseNext()); break;
    case T.PlusAssign:
      nT(); e = new PlusAssignExpression(e, parseNext()); break;
    case T.MinusAssign:
      nT(); e = new MinusAssignExpression(e, parseNext()); break;
    case T.DivAssign:
      nT(); e = new DivAssignExpression(e, parseNext()); break;
    case T.MulAssign:
      nT(); e = new MulAssignExpression(e, parseNext()); break;
    case T.ModAssign:
      nT(); e = new ModAssignExpression(e, parseNext()); break;
    case T.XorAssign:
      nT(); e = new XorAssignExpression(e, parseNext()); break;
    case T.CatAssign:
      nT(); e = new CatAssignExpression(e, parseNext()); break;
    version(D2)
    {
    case T.PowAssign:
      nT(); e = new PowAssignExpression(e, parseNext()); break;
    }
    default:
      return e;
    }
    set(e, begin);
    return e;
  }

  /// $(BNF CondExpression :=
  ////  OrOrExpression ("?" Expression ":" CondExpression)? )
  Expression parseCondExpression()
  {
    auto begin = token;
    auto e = parseOrOrExpression();
    if (auto qtok = consumedToken(T.Question)) // "?"
    {
      auto iftrue = parseExpression();
      auto ctok = token; // ":"
      require(T.Colon);
      auto iffalse = parseCondExpression();
      e = new CondExpression(e, iftrue, iffalse, qtok, ctok);
      set(e, begin);
    }
    return e;
  }

  /// $(BNF OrOrExpression := AndAndExpression ("||" AndAndExpression)* )
  Expression parseOrOrExpression()
  {
    alias parseAndAndExpression parseNext;
    Token* begin = token, operator = void;
    auto e = parseNext();
    while ((operator = consumedToken(T.OrLogical)) !is null)
      e = set(new OrOrExpression(e, parseNext(), operator), begin);
    return e;
  }

  /// $(BNF AndAndExpression := OrExpression ("&&" OrExpression)* )
  Expression parseAndAndExpression()
  {
    alias parseOrExpression parseNext;
    Token* begin = token, operator = void;
    auto e = parseNext();
    while ((operator = consumedToken(T.AndLogical)) !is null)
      e = set(new AndAndExpression(e, parseNext(), operator), begin);
    return e;
  }

  /// $(BNF OrExpression := XorExpression ("|" XorExpression)* )
  Expression parseOrExpression()
  {
    alias parseXorExpression parseNext;
    Token* begin = token, operator = void;
    auto e = parseNext();
    while ((operator = consumedToken(T.OrBinary)) !is null)
      e = set(new OrExpression(e, parseNext(), operator), begin);
    return e;
  }

  /// $(BNF XorExpression := AndExpression ("^" AndExpression)* )
  Expression parseXorExpression()
  {
    alias parseAndExpression parseNext;
    Token* begin = token, operator = void;
    auto e = parseNext();
    while ((operator = consumedToken(T.Xor)) !is null)
      e = set(new XorExpression(e, parseNext(), operator), begin);
    return e;
  }

  /// $(BNF AndExpression := CmpExpression ("&" CmpExpression)* )
  Expression parseAndExpression()
  {
    alias parseCmpExpression parseNext;
    Token* begin = token, operator = void;
    auto e = parseNext();
    while ((operator = consumedToken(T.AndBinary)) !is null)
      e = set(new AndExpression(e, parseNext(), operator), begin);
    return e;
  }

  /// $(BNF CmpExpression := ShiftExpression (Op ShiftExpression)?
  ////Op := "is" | "!" "is" | "in" | "==" | "!=" | "<" | "<=" | ">" |
  ////      ">=" | "!<>=" | "!<>" | "!<=" | "!<" |
  ////      "!>=" | "!>" | "<>=" | "<>")
  Expression parseCmpExpression()
  {
    alias parseShiftExpression parseNext;
    auto begin = token;
    auto e = parseNext();

    auto operator = token;
    switch (operator.kind)
    {
    case T.Equal, T.NotEqual:
      nT();
      e = new EqualExpression(e, parseNext(), operator);
      break;
    case T.Not:
      if (peekNext() != T.Is)
        break;
      nT();
      // fall through
    case T.Is:
      nT();
      e = new IdentityExpression(e, parseNext(), operator);
      break;
    case T.LessEqual, T.Less, T.GreaterEqual, T.Greater,
         T.Unordered, T.UorE, T.UorG, T.UorGorE,
         T.UorL, T.UorLorE, T.LorEorG, T.LorG:
      nT();
      e = new RelExpression(e, parseNext(), operator);
      break;
    case T.In:
      nT();
      e = new InExpression(e, parseNext(), operator);
      break;
    default:
      return e;
    }
    set(e, begin);
    return e;
  }

  /// $(BNF ShiftExpression := AddExpression (Op AddExpression)*
  ////Op := "<<" | ">>" | ">>>")
  Expression parseShiftExpression()
  {
    alias parseAddExpression parseNext;
    auto begin = token;
    auto e = parseNext();
    while (1)
    {
      auto operator = token;
      switch (operator.kind)
      {
      case T.LShift:
        nT(); e = new LShiftExpression(e, parseNext(), operator); break;
      case T.RShift:
        nT(); e = new RShiftExpression(e, parseNext(), operator); break;
      case T.URShift:
        nT(); e = new URShiftExpression(e, parseNext(), operator); break;
      default:
        return e;
      }
      set(e, begin);
    }
    assert(0);
  }

  /// $(BNF AddExpression := MulExpression (Op MulExpression)*
  ////Op := "+" | "-" | "~")
  Expression parseAddExpression()
  {
    alias parseMulExpression parseNext;
    auto begin = token;
    auto e = parseNext();
    while (1)
    {
      auto operator = token;
      switch (operator.kind)
      {
      case T.Plus:
        nT(); e = new PlusExpression(e, parseNext(), operator); break;
      case T.Minus:
        nT(); e = new MinusExpression(e, parseNext(), operator); break;
      case T.Tilde:
        nT(); e = new CatExpression(e, parseNext(), operator); break;
      default:
        return e;
      }
      set(e, begin);
    }
    assert(0);
  }

  /// $(BNF MulExpression := PostExpression (Op PostExpression)*
  ////Op := "*" | "/" | "%")
  ///D2:
  /// $(BNF MulExpression := PowExpression (Op PowExpression)*)
  Expression parseMulExpression()
  {
    version(D2)
    alias parsePowExpression parseNext;
    else
    alias parsePostExpression parseNext;
    auto begin = token;
    auto e = parseNext();
    while (1)
    {
      auto operator = token;
      switch (operator.kind)
      {
      case T.Mul: nT(); e = new MulExpression(e, parseNext(), operator); break;
      case T.Div: nT(); e = new DivExpression(e, parseNext(), operator); break;
      case T.Mod: nT(); e = new ModExpression(e, parseNext(), operator); break;
      default:
        return e;
      }
      set(e, begin);
    }
    assert(0);
  }

  /// $(BNF PowExpression := PostExpression ("^^" PostExpression)*)
  Expression parsePowExpression()
  {
    alias parsePostExpression parseNext;
    Token* begin = token, operator = void;
    auto e = parseNext();
    while ((operator = consumedToken(T.Pow)) !is null)
      e = set(new PowExpression(e, parseNext(), operator), begin);
    return e;
  }

  /// $(BNF PostExpression := UnaryExpression
  ////  (DotExpression | IncOrDecExpression | CallExpression |
  ////   SliceExpression | IndexExpression)*
  ////DotExpression := "." (NewExpression | IdentifierExpression)
  ////IncOrDecExpression := "++" | "--"
  ////CallExpression := "(" Arguments? ")"
  ////SliceExpression := "[" (AssignExpression ".." AssignExpression )? "]"
  ////IndexExpression := "[" ExpressionList "]")
  Expression parsePostExpression()
  {
    auto begin = token;
    auto e = parseUnaryExpression();
    while (1)
    {
      switch (token.kind)
      {
      case T.Dot:
        nT();
        if (token.kind == T.New)
        {
          e = parseNewExpression(e);
          continue;
        }
        e = new DotExpression(e, parseIdentifierExpression());
        goto Lset;
      case T.PlusPlus:
        e = new PostIncrExpression(e);
        break;
      case T.MinusMinus:
        e = new PostDecrExpression(e);
        break;
      case T.LParen:
        e = new CallExpression(e, parseArguments());
        goto Lset;
      case T.LBracket:
        // parse Slice- and IndexExpression
        auto leftBracket = token;
        nT();
        // [] is a SliceExpression
        if (token.kind == T.RBracket)
        {
          e = new SliceExpression(e, null, null);
          break;
        }

        Expression[] es = [parseAssignExpression()];

        // [ AssignExpression .. AssignExpression ]
        if (consumed(T.Slice))
        {
          e = new SliceExpression(e, es[0], parseAssignExpression());
          requireClosing(T.RBracket, leftBracket);
          goto Lset;
        }

        // [ ExpressionList ]
        if (consumed(T.Comma))
           es ~= parseExpressionList();
        requireClosing(T.RBracket, leftBracket);

        e = new IndexExpression(e, es);
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

  /// $(BNF UnaryExpression := PrimaryExpression |
  ////  NewExpression | AddressExpression | PreIncrExpression |
  ////  PreIncrExpression | DerefExpression | SignExpression |
  ////  NotExpression | ComplementExpression | DeleteExpression |
  ////  CastExpression | TypeDotIdExpression
  ////AddressExpression     := "&" UnaryExpression
  ////PreIncrExpression     := "++" UnaryExpression
  ////PreDecrExpression     := "--" UnaryExpression
  ////DerefExpression       := "*" UnaryExpression
  ////SignExpression        := ("-" | "+") UnaryExpression
  ////NotExpression         := "!" UnaryExpression
  ////ComplementExpresson   := "~" UnaryExpression
  ////DeleteExpression      := delete UnaryExpression
  ////CastExpression        := cast "(" Type ")" UnaryExpression
  ////TypeDotIdExpression   := "(" Type ")" "." Identifier)
  Expression parseUnaryExpression()
  {
    auto begin = token;
    Expression e;
    switch (token.kind)
    {
    case T.AndBinary:
      nT();
      e = new AddressExpression(parseUnaryExpression());
      break;
    case T.PlusPlus:
      nT();
      e = new PreIncrExpression(parseUnaryExpression());
      break;
    case T.MinusMinus:
      nT();
      e = new PreDecrExpression(parseUnaryExpression());
      break;
    case T.Mul:
      nT();
      e = new DerefExpression(parseUnaryExpression());
      break;
    case T.Minus:
    case T.Plus:
      nT();
      e = new SignExpression(parseUnaryExpression());
      break;
    case T.Not:
      nT();
      e = new NotExpression(parseUnaryExpression());
      break;
    case T.Tilde:
      nT();
      e = new CompExpression(parseUnaryExpression());
      break;
    case T.New:
      e = parseNewExpression();
      return e;
    case T.Delete:
      nT();
      e = new DeleteExpression(parseUnaryExpression());
      break;
    case T.Cast:
      requireNext(T.LParen);
      Type type;
    version(D2)
      auto begin2 = token;
      switch (token.kind)
      {
      version(D2)
      {
      case T.Const:
        if (peekNext() != T.RParen)
          goto default; // const ( Type )
        type = new ConstType(null); // cast ( const )
        goto Lcommon;
      case T.Invariant:
        if (peekNext() != T.RParen)
          goto default; // invariant ( Type )
        type = new InvariantType(null); // cast ( invariant )
      Lcommon:
        nT();
        set(type, begin2);
        break;
      } // version(D2)
      default:
       type = parseType();
      }
      require(T.RParen);
      e = new CastExpression(parseUnaryExpression(), type);
      break;
    case T.LParen:
      if (!tokenAfterParenIs(T.Dot))
        goto default;
      // "(" Type ")" "." Identifier
      bool success;
      auto type = try_({
        skip(T.LParen); // "("
        auto type = parseType(); // Type
        require(T.RParen); // ")"
        require(T.Dot); // "."
        return type;
      }, success);
      if (!success)
        goto default;
      auto ident = requireIdentifier2(MSG.ExpectedIdAfterTypeDot);
      e = new TypeDotIdExpression(type, ident);
      break;
    default:
      e = parsePrimaryExpression();
      return e;
    }
    assert(e !is null);
    set(e, begin);
    return e;
  }

  /// $(BNF IdentifierExpression := Identifier | TemplateInstance
  ////TemplateInstance := Identifier "!" TemplateArgumentsOneOrMore)
  Expression parseIdentifierExpression()
  {
    auto begin = token;
    auto ident = requireIdentifier2(MSG.ExpectedAnIdentifier);
    Expression e;
    // Peek to avoid parsing: "id !is Exp" or "id !in Exp"
    auto nextTok = peekNext();
    if (token.kind == T.Not && nextTok != T.Is && nextTok != T.In)
    {
      skip(T.Not);
      // Identifier "!" "(" TemplateArguments? ")"
      // Identifier "!" TemplateArgumentSingle
      auto tparams = parseOneOrMoreTemplateArguments();
      e = new TemplateInstanceExpression(ident, tparams);
    }
    else // Identifier
      e = new IdentifierExpression(ident);
    return set(e, begin);
  }

  /// $(BNF PrimaryExpression := ... | ModuleScopeExpression
  ////ModuleScopeExpression := ".")
  Expression parsePrimaryExpression()
  {
    auto begin = token;
    Expression e;
    switch (token.kind)
    {
    case T.Identifier:
      e = parseIdentifierExpression();
      return e;
    case T.Typeof:
      e = new TypeofExpression(parseTypeofType());
      break;
    case T.Dot:
      // No nT() because we want a DotExpression to be parsed afterwards.
      e = set(new ModuleScopeExpression(), begin, begin);
      return e;
    case T.This:
      e = new ThisExpression();
      goto LnT_and_return;
    case T.Super:
      e = new SuperExpression();
      goto LnT_and_return;
    case T.Null:
      e = new NullExpression();
      goto LnT_and_return;
    case T.True, T.False:
      e = new BoolExpression(token.kind == T.True);
      goto LnT_and_return;
    case T.Dollar:
      e = new DollarExpression();
      goto LnT_and_return;
    case T.Int32, T.Int64, T.Uint32, T.Uint64:
      e = new IntExpression(token);
      goto LnT_and_return;
    case T.Float32, T.Float64, T.Float80,
         T.Imaginary32, T.Imaginary64, T.Imaginary80:
      e = new RealExpression(token);
      goto LnT_and_return;
    case T.CharLiteral:
      e = new CharExpression(token.dchar_);
      goto LnT_and_return;
    LnT_and_return:
      nT();
      set(e, begin);
      return e;
    case T.String:
      char[] str = token.str;
      char postfix = token.pf;
      nT();
      while (token.kind == T.String)
      {
        /+if (postfix == 0)
            postfix = token.pf;
        else+/
        if (token.pf && token.pf != postfix)
          error(token, MSG.StringPostfixMismatch);
        str.length = str.length - 1; // Exclude '\0'.
        str ~= token.str;
        nT();
      }
      switch (postfix)
      {
      case 'w':
        if (hasInvalidUTF8(str, begin))
          goto default;
        e = new StringExpression(dil.Unicode.toUTF16(str)); break;
      case 'd':
        if (hasInvalidUTF8(str, begin))
          goto default;
        e = new StringExpression(dil.Unicode.toUTF32(str)); break;
      case 'c':
      default:
        // No checking done to allow for binary data.
        e = new StringExpression(str); break;
      }
      break;
    case T.LBracket:
      Expression[] values;

      nT();
      if (!consumed(T.RBracket))
      {
        e = parseAssignExpression();
        if (consumed(T.Colon))
          goto LparseAssocArray;
        if (consumed(T.Comma))
          values = [e] ~ parseExpressionList();
        requireClosing(T.RBracket, begin);
      }

      e = new ArrayLiteralExpression(values);
      break;

    LparseAssocArray:
      Expression[] keys = [e];

      goto LenterLoop;
      do
      {
        keys ~= parseAssignExpression();
        require(T.Colon);
      LenterLoop:
        values ~= parseAssignExpression();
      } while (consumed(T.Comma))
      requireClosing(T.RBracket, begin);
      e = new AArrayLiteralExpression(keys, values);
      break;
    case T.LBrace:
      // DelegateLiteral := { Statements }
      auto funcBody = parseFunctionBody();
      e = new FunctionLiteralExpression(funcBody);
      break;
    case T.Function, T.Delegate:
      // FunctionLiteral := ("function" | "delegate")
      //                    Type? "(" ArgumentList ")" FunctionBody
      nT(); // Skip function or delegate keyword.
      Type returnType;
      Parameters parameters;
      if (token.kind != T.LBrace)
      {
        if (token.kind != T.LParen) // Optional return type
          returnType = parseBasicTypes();
        parameters = parseParameterList();
      }
      auto funcBody = parseFunctionBody();
      e = new FunctionLiteralExpression(returnType, parameters, funcBody);
      break;
    case T.Assert:
      requireNext(T.LParen);
      e = parseAssignExpression();
      auto msg = consumed(T.Comma) ? parseAssignExpression() : null;
      require(T.RParen);
      e = new AssertExpression(e, msg);
      break;
    case T.Mixin:
      requireNext(T.LParen);
      e = new MixinExpression(parseAssignExpression());
      require(T.RParen);
      break;
    case T.Import:
      requireNext(T.LParen);
      e = new ImportExpression(parseAssignExpression());
      require(T.RParen);
      break;
    case T.Typeid:
      requireNext(T.LParen);
      e = new TypeidExpression(parseType());
      require(T.RParen);
      break;
    case T.Is:
      nT();
      auto leftParen = token;
      require(T.LParen);

      Type type, specType;
      Token* ident; // optional Identifier
      Token* opTok, specTok;

      type = parseDeclarator(ident, true);

      switch (token.kind)
      {
      case T.Colon, T.Equal:
        opTok = token;
        nT();
        switch (token.kind)
        {
        case T.Typedef,
             T.Struct,
             T.Union,
             T.Class,
             T.Interface,
             T.Enum,
             T.Function,
             T.Delegate,
             T.Super,
             T.Return:
        case_Const_Invariant:
          specTok = token;
          nT();
          break;
        case T.Const, T.Invariant:
          auto next = peekNext();
          if (next == T.RParen || next == T.Comma)
            goto case_Const_Invariant;
          // Fall through. It's a type.
        default:
          specType = parseType();
        }
      default:
      }

      TemplateParameters tparams;
    version(D2)
    { // "is" "(" Type Identifier (":" | "==") TypeSpecialization ","
      //          TemplateParameterList ")"
      if (ident && specType && token.kind == T.Comma)
        tparams = parseTemplateParameterList2();
    }
      requireClosing(T.RParen, leftParen);
      e = new IsExpression(type, ident, opTok, specTok, specType, tparams);
      break;
    case T.LParen:
      if (tokenAfterParenIs(T.LBrace)) // Check for "(...) {"
      { // ( ParameterList ) FunctionBody
        auto parameters = parseParameterList();
        auto funcBody = parseFunctionBody();
        e = new FunctionLiteralExpression(null, parameters, funcBody);
      }
      else
      { // ( Expression )
        auto leftParen = token;
        skip(T.LParen);
        e = parseExpression();
        requireClosing(T.RParen, leftParen);
        e = new ParenExpression(e);
      }
      break;
    version(D2)
    {
    case T.Traits:
      nT();
      auto leftParen = token;
      require(T.LParen); // "("
      auto ident = requireIdentifier(MSG.ExpectedAnIdentifier);
      auto args = consumed(T.Comma) ? parseTemplateArguments2() : null;
      requireClosing(T.RParen, leftParen); // ")"
      e = new TraitsExpression(ident, args);
      break;
    }
    default:
      if (token.isIntegralType)
      { // IntegralType . Identifier
        auto type = new IntegralType(token.kind);
        nT();
        set(type, begin);
        require(T.Dot);
        auto ident = requireIdentifier2(MSG.ExpectedIdAfterTypeDot);
        e = new TypeDotIdExpression(type, ident);
      }
      else if (token.isSpecialToken)
      {
        e = new SpecialTokenExpression(token);
        nT();
      }
      else
      {
        error2(MID.ExpectedButFound, "Expression", token);
        e = new IllegalExpression();
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

  /// $(BNF NewExpression := NewAnonClassExpression | NewObjectExpression
  ////NewAnonClassExpression := new NewArguments?
  ////                          class NewArguments?
  ////                          (SuperClass InterfaceClasses)? ClassBody
  ////NewObjectExpression := new NewArguments? Type (NewArguments | NewArray)?
  ////NewArguments := "(" ArgumentList ")"
  ////NewArray     := "[" AssignExpression "]")
  /// Params:
  ///   frame = The frame or 'this' pointer expression.
  Expression parseNewExpression(Expression frame = null)
  {
    auto begin = token;
    skip(T.New);

    Expression[] newArguments, ctorArguments;

    if (token.kind == T.LParen) // NewArguments
      newArguments = parseArguments();

    if (consumed(T.Class))
    { // NewAnonymousClassExpression
      if (token.kind == T.LParen)
        ctorArguments = parseArguments();

      BaseClassType[] bases;
      if (token.kind != T.LBrace)
        bases = parseBaseClasses();

      auto decls = parseDeclarationDefinitionsBody();
      return set(new NewClassExpression(frame, newArguments, bases,
        ctorArguments, decls), begin);
    }

    // NewObjectExpression
    auto type = parseBasicTypes();

    // Don't parse arguments if an array type was parsed previously.
    auto arrayType = type.Is!(ArrayType);
    if (arrayType && arrayType.isStatic())
    {}
    else if(arrayType && arrayType.isAssociative())
    { // Backtrack to parse as a StaticArray.
      auto lBracket = type.begin;
      backtrackTo(lBracket);

      skip(T.LBracket); // "["
      type = set(new ArrayType(type.next, parseExpression()), lBracket);
      requireClosing(T.RBracket, lBracket); // "]"
      delete arrayType; // Delete the old type.
    }
    else if (token.kind == T.LParen) // NewArguments
      ctorArguments = parseArguments();

    return set(new NewExpression(frame, newArguments, type, ctorArguments),
      begin);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                          Type parsing methods                           |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// Parses the basic types.
  ///
  /// $(BNF Type := BasicType BasicType2 )
  Type parseBasicTypes()
  {
    return parseBasicType2(parseBasicType());
  }

  /// Parses a full Type.
  ///
  /// $(BNF Type := BasicType BasicType2 CStyleType? )
  Type parseType()
  {
    version(D2)
    {
    if (peekNext() != T.LParen)
      if (auto begin = consumedToken(T.Const))
        return set(new ConstType(parseType()), begin);
      else if (auto begin = consumedToken(T.Invariant))
        return set(new InvariantType(parseType()), begin);
    }
    auto type = parseBasicTypes();
    return token.kind == T.LParen ? parseCStyleType(type) : type;
  }

  /// Parses a Type with D2.0 const qualifiers.
  ///
  /// $(BNF TypeWithQualifiers := (const | invariant) Type )
  Type parseTypeQualifiers()
  {
    // TODO: move code from parseType() to this func.
    return null;
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
  /// Parameters:
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
        error2(MSG.UnexpectedIdentInType, ident);
    else if (pIdent !is null)
      *pIdent = token; // Useful for error msg, if an Id was expected.

    auto innerTypeEnd = currentType.parent; // Save before parsing the suffix.

    currentType = parseDeclaratorSuffix(currentType, true);

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
  ///   ident = receives the identifier of the declarator.
  ///   identOptional = whether to report an error for a missing identifier.
  Type parseDeclarator(ref Token* ident, bool identOptional = false)
  {
    auto type = parseCStyleType(parseBasicType(), &ident);
    assert(ident !is null);
    if (ident.kind != T.Identifier)
      (identOptional || error2(MSG.ExpectedDeclaratorIdentifier, ident)),
      (ident = null);
    return type;
  }

  /// Parses the parameters of a function in a C-like type declaration.
  Type parseCFuncType(Type returnType)
  {
    assert(returnType !is null);
    auto begin = token;
    auto params = parseParameterList();
    return set(new CFuncType(returnType, params), begin);
  }

  /// $(BNF IdentifierType := Identifier | TemplateInstance)
  Type parseIdentifierType()
  {
    auto begin = token;
    auto ident = requireIdentifier2(MSG.ExpectedAnIdentifier);
    Type t;
    if (consumed(T.Not)) // TemplateInstance
      t = new TemplateInstanceType(ident, parseOneOrMoreTemplateArguments());
    else // Identifier
      t = new IdentifierType(ident);
    return set(t, begin);
  }

  /// $(BNF QualifiedType := (ModuleScopeType | TypeofType | IdentifierType)
  ////                 ("." IdentifierType)* )
  Type parseQualifiedType()
  {
    auto begin = token;
    Type type;
    if (token.kind == T.Dot)
      type = set(new ModuleScopeType(), begin, begin);
    else if (token.kind == T.Typeof)
      type = parseTypeofType();
    else
      type = parseIdentifierType();

    while (consumed(T.Dot))
      type = set(new QualifiedType(type, parseIdentifierType()), begin);
    return type;
  }

  /// $(BNF BasicType := IntegralType | QualifiedType |
  ////             ConstType | InvariantType # D2.0 )
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
    case T.Identifier, T.Typeof, T.Dot:
      t = parseQualifiedType();
      return t;
    version(D2)
    {
    case T.Const, // const "(" Type ")"
         T.Invariant: // invariant "(" Type ")"
      requireNext(T.LParen); // "("
      auto lParen = prevToken;
      t = parseType(); // Type
      requireClosing(T.RParen, lParen); // ")"
      t = (begin.kind == T.Const) ? new ConstType(t): new InvariantType(t);
      break;
    } // version(D2)
    default:
      error2(MID.ExpectedButFound, "BasicType", token);
      t = new IllegalType();
      nT();
    }
    return set(t, begin);
  }

  /// $(BNF BasicType2 := Type
  ////              (PointerType | ArrayType | FunctionType | DelegateType)*
  ////PointerType := "*"
  ////FunctionType := function ParameterList
  ////DelegateType := delegate ParameterList)
  Type parseBasicType2(Type t)
  {
    while (1)
    {
      auto begin = token;
      switch (token.kind)
      {
      case T.Mul:
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
  ///   kind = the kind of token to test for.
  bool tokenAfterParenIs(TOK kind)
  {
    auto peek_token = token;
    return tokenAfterParenIs(kind, peek_token);
  }

  /// ditto
  bool tokenAfterParenIs(TOK kind, ref Token* peek_token)
  {
    assert(peek_token !is null && peek_token.kind == T.LParen);
    return skipParens(peek_token, T.RParen) == kind;
  }

  /// Returns the kind of the token behind the closing bracket.
  TOK tokenAfterBracket(TOK closing)
  {
    assert(token.kind == T.LBracket || token.kind == T.LBrace);
    auto peek_token = token;
    return skipParens(peek_token, closing);
  }

  /// Skips to the token behind the 'closing' token.
  /// Takes nesting into account.
  /// Params:
  ///   peek_token = opening token to start from; used to peek further.
  ///   closing = kind of the closing token.
  /// Returns: the kind of the searched token or TOK.EOF.
  TOK skipParens(ref Token* peek_token, TOK closing)
  {
    assert(peek_token !is null);
    uint level = 1;
    TOK opening = peek_token.kind, current_kind;
    while ((current_kind = peekAfter(peek_token)) != T.EOF)
      if (current_kind == opening)
        ++level;
      else if (current_kind == closing && --level == 0)
        return peekAfter(peek_token); // Closing token found.
    return T.EOF;
  }

  /// Parse the array types after the declarator (C-style.) E.g.: int a[]
  /// Returns: lhsType or a suffix type.
  /// Params:
  ///   lhsType = the type on the left-hand side.
  ///   cfunc   = parse a function parameter list, too?
  Type parseDeclaratorSuffix(Type lhsType, bool cfunc = false)
  { // The Type chain should be as follows:
    // int[3]* Identifier [][1][2]
    //   <– <–.      ·start·–> -.
    //         `---------------´
    // Resulting chain: [][1][2]*[3]int
    auto result = lhsType; // Return lhsType if nothing else is parsed.
    Type prevType; // The previously parsed type.
    if (token.kind == T.LBracket) // "["
    {
      result = prevType = parseArrayType(lhsType);
      // Continue parsing ArrayTypes.
      while (token.kind == T.LBracket) // "["
      {
        auto arrayType = parseArrayType(lhsType);
        prevType.setNext(arrayType); // Make prevType point to this type.
        prevType = arrayType; // Current type becomes previous type.
      }
    }
    if (cfunc && token.kind == T.LParen) // "("
    { // Parse: "(" Parameters? ")"
      auto cfuncType = parseCFuncType(lhsType);
      if (prevType) // Have arrays been parsed?
        prevType.setNext(cfuncType);
      else
        result = cfuncType;
    }
    return result;
  }

  /// $(BNF ArrayType := "[" (Type | Expression | SliceExpression ) "]"
  ////SliceExpression := Expression ".." Expression )
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
      auto assocType = try_(&parseAAType, success);
      if (success)
        t = new ArrayType(t, assocType);
      else
      {
        Expression e = parseExpression(), e2;
        if (consumed(T.Slice))
          e2 = parseExpression();
        requireClosing(T.RBracket, begin);
        t = new ArrayType(t, e, e2);
      }
    }
    return set(t, begin);
  }

  /// Parses a list of AssignExpressions.
  /// $(BNF ExpressionList := AssignExpression ("," AssignExpression)* )
  Expression[] parseExpressionList()
  {
    Expression[] expressions;
    do
      expressions ~= parseAssignExpression();
    while(consumed(T.Comma))
    return expressions;
  }

  /// Parses a list of Arguments.
  /// $(BNF Arguments := "(" ExpressionList? ")" )
  Expression[] parseArguments()
  {
    auto leftParen = token;
    skip(T.LParen);
    Expression[] args;
    if (token.kind != T.RParen)
      args = parseExpressionList();
    requireClosing(T.RParen, leftParen);
    return args;
  }

  /// Parses a ParameterList.
  Parameters parseParameterList()
  out(params)
  {
    if (params.length > 1)
      foreach (param; params.items[0..$-1])
      {
        if (param.isVariadic())
          assert(0, "variadic arguments can only appear "
                    "at the end of the parameter list.");
      }
  }
  body
  {
    auto begin = token;
    require(T.LParen);

    auto params = new Parameters();

    if (consumed(T.RParen))
      return set(params, begin);

    do
    {
      auto paramBegin = token;
      StorageClass stcs, stc;
      Type type;
      Token* ident;
      Expression defValue;

      void pushParameter()
      {
        params ~= set(new Parameter(stcs, type, ident, defValue), paramBegin);
      }

      if (consumed(T.Ellipses))
      {
        stcs = StorageClass.Variadic;
        pushParameter(); // type, ident and defValue will be null.
        break;
      }

      while (1)
      { // Parse storage classes.
        switch (token.kind)
        {
        version(D2)
        {
        case T.Invariant, T.Const, T.Immutable, T.Shared:
          if (peekNext() == T.LParen)
            break;
          switch (token.kind)
          {
          case T.Const:     stc = StorageClass.Const; break;
          case T.Immutable: stc = StorageClass.Immutable; break;
          default:          stc = StorageClass.Shared; break;
          }
          goto Lcommon;
        case T.Final:
          stc = StorageClass.Final;
          goto Lcommon;
        case T.Scope:
          stc = StorageClass.Scope;
          goto Lcommon;
        case T.Static:
          stc = StorageClass.Static;
          goto Lcommon;
        } // end of version(D2)
        case T.In:
          stc = StorageClass.In;
          goto Lcommon;
        case T.Out:
          stc = StorageClass.Out;
          goto Lcommon;
        case T.Inout, T.Ref: // T.Inout is deprecated in D2.
          stc = StorageClass.Ref;
          goto Lcommon;
        case T.Lazy:
          stc = StorageClass.Lazy;
          goto Lcommon;
        Lcommon:
          // Check for redundancy.
          if (stcs & stc)
            error2(MID.RedundantStorageClass, token);
          else
            stcs |= stc;
          nT();
        version(D2)
          continue;
        else
          break; // In D1.0 the grammar only allows one storage class.
        default:
        }
        break; // Break out of inner loop.
      }
      type = parseDeclarator(ident, true);

      if (consumed(T.Assign))
        defValue = parseAssignExpression();

      if (consumed(T.Ellipses))
      {
        stcs |= StorageClass.Variadic;
        pushParameter();
        break;
      }
      pushParameter();

    } while (consumed(T.Comma))
    requireClosing(T.RParen, begin);
    return set(params, begin);
  }

  /// $(BNF TemplateArgumentsOneOrMore :=
  ////  TemplateArgumentList | TemplateArgumentSingle)
  TemplateArguments parseOneOrMoreTemplateArguments()
  {
    version(D2)
    if (token.kind != T.LParen)
    { // Parse one TArg, but still put it in TemplateArguments.
      auto targs = new TemplateArguments;
      auto begin = token;
      bool success;
      auto typeArg = try_({
        // Don't parse a full Type. TODO: restrict further?
        return parseBasicType();
      }, success);
      // Don't parse a full Expression. TODO: restrict further?
      targs ~= success ? typeArg : parsePrimaryExpression();
      return set(targs, begin);
    }
    return parseTemplateArguments();
  }

  /// $(BNF TemplateArgumentList := "(" TemplateArguments? ")")
  TemplateArguments parseTemplateArguments()
  {
    TemplateArguments targs;
    auto leftParen = token;
    require(T.LParen);
    targs = (token.kind != T.RParen) ?
      parseTemplateArguments_() : new TemplateArguments;
    requireClosing(T.RParen, leftParen);
    return set(targs, leftParen);
  }

  /// $(BNF TemplateArgumentList2 := TemplateArguments (?="$(RP)"))
  TemplateArguments parseTemplateArguments2()
  {
    version(D2)
    {
    TemplateArguments targs;
    if (token.kind != T.RParen)
      targs = parseTemplateArguments_();
    else
      error(token, MSG.ExpectedTypeOrExpression);
    return targs;
    } // version(D2)
    else
    assert(0);
  }

  /// Used with method try_().
  /// $(BNF TypeArgument := Type (?= "," | "$(RP)"))
  Type parseTypeArgument()
  {
    auto type = parseType();
    if (token.kind == T.Comma || token.kind == T.RParen)
      return type;
    try_fail();
    return null;
  }

  /// $(BNF TemplateArguments := TemplateArgument ("," TemplateArgument)*
  ////TemplateArgument := TypeArgument | AssignExpression)
  TemplateArguments parseTemplateArguments_()
  {
    auto begin = token;
    auto targs = new TemplateArguments;
    do
    {
      bool success;
      auto typeArgument = try_(&parseTypeArgument, success);
      if (success) // TemplateArgument := Type | Symbol
        targs ~= typeArgument;
      else // TemplateArgument := AssignExpression
        targs ~= parseAssignExpression();
    } while (consumed(T.Comma))
    set(targs, begin);
    return targs;
  }

  /// $(BNF Constraint := "if" "(" ConstraintExpression ")")
  Expression parseOptionalConstraint()
  {
    if (!consumed(T.If))
      return null;
    auto leftParen = token;
    require(T.LParen);
    auto e = parseExpression();
    requireClosing(T.RParen, leftParen);
    return e;
  }

  /// $(BNF TemplateParameterList := "(" TemplateParameters? ")")
  TemplateParameters parseTemplateParameterList()
  {
    auto begin = token;
    auto tparams = new TemplateParameters;
    require(T.LParen);
    if (token.kind != T.RParen)
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
    if (token.kind != T.RParen)
      parseTemplateParameterList_(tparams);
    else
      error(token, MSG.ExpectedTemplateParameters);
    return set(tparams, begin);
  } // version(D2)
  else return null;
  }

  /// Parses template parameters.
  /// $(BNF TemplateParameters := TemplateParameter ("," TemplateParameter)
  ////TemplateParameter := TemplateAliasParam | TemplateTypeParam |
  ////                     TemplateTupleParam | TemplateValueParam |
  ////                     TemplateThisParam
  ////TemplateAliasParam := alias Identifier SpecOrDefaultType
  ////TemplateTypeParam  := Identifier SpecOrDefaultType
  ////TemplateTupleParam := Identifier "..."
  ////TemplateValueParam := Declarator SpecOrDefaultValue
  ////TemplateThisParam  := this Identifier SpecOrDefaultType # D2.0
  ////SpecOrDefaultType  := (":" Type)? ("=" Type)?
  ////SpecOrDefaultValue := (":" Value)? ("=" Value)?
  ////Value := CondExpression
  ////)
  void parseTemplateParameterList_(TemplateParameters tparams)
  {
    do
    {
      auto paramBegin = token;
      TemplateParameter tp;
      Token* ident;
      Type specType, defType;

      void parseSpecAndOrDefaultType()
      {
        if (consumed(T.Colon))  // ":" SpecializationType
          specType = parseType();
        if (consumed(T.Assign)) // "=" DefaultType
          defType = parseType();
      }

      switch (token.kind)
      {
      case T.Alias:
        // TemplateAliasParameter := "alias" Identifier
        skip(T.Alias);
        ident = requireIdentifier(MSG.ExpectedAliasTemplateParam);
      version(D2)
      {
        Node parseExpOrType()
        {
          bool success;
          auto typeArgument = try_(&parseTypeArgument, success);
          return success ? typeArgument : parseCondExpression();
        }
        Node spec, def;
        if (consumed(T.Colon))  // ":" SpecializationType
          spec = parseExpOrType();
        if (consumed(T.Assign)) // "=" DefaultType
          def = parseExpOrType();
        // TODO: expressions are not stored.
        //       TemplateAliasParameter class has to be modified.
        specType = spec && spec.isType() ? spec.to!(Type) : null;
        defType = def && def.isType() ? def.to!(Type) : null;
      }
      else
        parseSpecAndOrDefaultType();
        tp = new TemplateAliasParameter(ident, specType, defType);
        break;
      case T.Identifier:
        ident = token;
        switch (peekNext())
        {
        case T.Ellipses:
          // TemplateTupleParameter := Identifier "..."
          skip(T.Identifier); skip(T.Ellipses);
          if (token.kind == T.Comma)
            error(MID.TemplateTupleParameter);
          tp = new TemplateTupleParameter(ident);
          break;
        case T.Comma, T.RParen, T.Colon, T.Assign:
          // TemplateTypeParameter := Identifier
          skip(T.Identifier);
          parseSpecAndOrDefaultType();
          tp = new TemplateTypeParameter(ident, specType, defType);
          break;
        default:
          // TemplateValueParameter := Declarator
          ident = null;
          goto LTemplateValueParameter;
        }
        break;
      version(D2)
      {
      case T.This:
        // TemplateThisParameter := "this" TemplateTypeParameter
        skip(T.This);
        ident = requireIdentifier(MSG.ExpectedNameForThisTempParam);
        parseSpecAndOrDefaultType();
        tp = new TemplateThisParameter(ident, specType, defType);
        break;
      }
      default:
      LTemplateValueParameter:
        // TemplateValueParameter := Declarator
        Expression specValue, defValue;
        auto valueType = parseDeclarator(ident);
        // ":" SpecializationValue
        if (consumed(T.Colon))
          specValue = parseCondExpression();
        // "=" DefaultValue
        if (consumed(T.Assign))
          defValue = parseCondExpression();
        tp = new TemplateValueParameter(valueType, ident, specValue, defValue);
      }

      // Push template parameter.
      tparams ~= set(tp, paramBegin);

    } while (consumed(T.Comma))
  }

  /// Returns the string of a token printable to the client.
  char[] getPrintable(Token* token)
  { // TODO: there are some other tokens that have to be handled, e.g. strings.
    return token.kind == T.EOF ? "EOF" : token.text;
  }

  alias require expected;

  /// Requires a token of kind tok.
  void require(TOK tok)
  {
    if (token.kind == tok)
      nT();
    else
      error2(MID.ExpectedButFound, Token.toString(tok), token);
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
    Token* id;
    if (token.kind == T.Identifier)
      (id = token), nT();
    return id;
  }

  /// ditto
  Identifier* requireIdentifier2(char[] errorMsg)
  {
    auto idtok = requireIdentifier(errorMsg);
    return idtok ? idtok.ident : null;
  }

  /// Reports an error if the current token is not an identifier.
  /// Params:
  ///   mid = the error message ID to be used.
  /// Returns: the identifier token or null.
  Token* requireIdentifier(MID mid)
  {
    return requireIdentifier(GetMsg(mid));
  }

  /// Reports an error if the current token is not an identifier.
  /// Params:
  ///   errorMsg = the error message to be used.
  /// Returns: the identifier token or null.
  Token* requireIdentifier(char[] errorMsg)
  {
    Token* idtok;
    if (token.kind == T.Identifier)
      (idtok = token), nT();
    else
    {
      error(token, errorMsg, token.text);
      if (!trying)
      {
        idtok = lexer.insertEmptyTokenBefore(token);
        idtok.kind = T.Identifier;
        idtok.ident = Ident.Empty;
        this.prevToken = idtok;
      }
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
      auto loc = opening.getRealLocation();
      auto openingLoc = Format("(opening @{},{})", loc.lineNum, loc.colNum);
      error(token, MSG.ExpectedClosing,
            Token.toString(closing), openingLoc, getPrintable(token));
    }
  }

  /// Returns true if the string str has an invalid UTF-8 sequence.
  bool hasInvalidUTF8(string str, Token* begin)
  {
    auto invalidUTF8Seq = Lexer.findInvalidUTF8Sequence(str);
    if (invalidUTF8Seq.length)
      error(begin, MSG.InvalidUTF8SequenceInString, invalidUTF8Seq);
    return invalidUTF8Seq.length != 0;
  }

  /// Forwards error parameters.
  void error(Token* token, char[] formatMsg, ...)
  {
    error_(token, formatMsg, _arguments, _argptr);
  }
  /// ditto
  void error(MID mid, ...)
  {
    error_(this.token, GetMsg(mid), _arguments, _argptr);
  }

  /// ditto
  void error2(char[] formatMsg, Token* token)
  {
    error(token, formatMsg, getPrintable(token));
  }
  /// ditto
  void error2(MID mid, Token* token)
  {
    error(mid, getPrintable(token));
  }
  /// ditto
  void error2(MID mid, char[] arg, Token* token)
  {
    error(mid, arg, getPrintable(token));
  }

  /// Creates an error report and appends it to a list.
  /// Params:
  ///   token = used to get the location of where the error is.
  ///   formatMsg = the compiler error message.
  void error_(Token* token, char[] formatMsg,
              TypeInfo[] _arguments, va_list _argptr)
  {
    if (trying)
    {
      errorCount++;
      return;
    }
    auto location = token.getErrorLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    auto error = new ParserError(location, msg);
    errors ~= error;
    if (diag !is null)
      diag ~= error;
  }
}
