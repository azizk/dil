/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.parser.Parser;

import dil.lexer.Lexer;
import dil.ast.Node;
import dil.ast.Declarations;
import dil.ast.Statements;
import dil.ast.Expressions;
import dil.ast.Types;
import dil.ast.Parameters;
import dil.lexer.IdTable;
import dil.Messages;
import dil.Information;
import dil.Enums;
import dil.CompilerInfo;
import dil.SourceText;
import dil.Unicode;
import common;

/// The Parser produces a full parse tree by examining
/// the list of tokens provided by the Lexer.
class Parser
{
  Lexer lexer; /// Used to lex the source code.
  Token* token; /// Current non-whitespace token.
  Token* prevToken; /// Previous non-whitespace token.

  InfoManager infoMan;
  ParserError[] errors;

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
  ///   text     = the UTF-8 source code.
  ///   infoMan  = used for collecting error messages.
  this(SourceText srcText, InfoManager infoMan = null)
  {
    this.infoMan = infoMan;
    lexer = new Lexer(srcText, infoMan);
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
  /// the state of the lexer and parser are restored.
  /// Returns: the return value of parseMethod().
  ReturnType try_(ReturnType)(ReturnType delegate() parseMethod, out bool success)
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

  /// Sets the begin and end tokens of a syntax tree node.
  Class set(Class)(Class node, Token* begin)
  {
    node.setTokens(begin, this.prevToken);
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

  /// Asserts that the current token is of kind expectedKind,
  /// and then moves to the next token.
  void skip()(TOK expectedKind)
  {
    assert(token.kind == expectedKind /+|| *(int*).init+/, token.srcText());
    nT();
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                        Declaration parsing methods                        |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  Declaration parseModuleDeclaration()
  {
    skip(T.Module);
    auto begin = token;
    ModuleFQN moduleFQN;
    do
      moduleFQN ~= requireIdentifier(MSG.ExpectedModuleIdentifier);
    while (consumed(T.Dot))
    require(T.Semicolon);
    return set(new ModuleDeclaration(moduleFQN), begin);
  }

  /// Parses DeclarationDefinitions until the end of file is hit.
  /// $(PRE
  /// DeclDefs :=
  ///     DeclDef
  ///     DeclDefs
  /// )
  Declaration[] parseDeclarationDefinitions()
  {
    Declaration[] decls;
    while (token.kind != T.EOF)
      decls ~= parseDeclarationDefinition();
    return decls;
  }

  /// Parse the body of a template, class, interface, struct or union.
  /// $(PRE
  /// DeclDefsBlock :=
  ///     { }
  ///     { DeclDefs }
  /// )
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
    require(T.RBrace);
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
         T.Public:
      decl = parseAttributeSpecifier();
      break;
    // Storage classes
    case T.Extern,
         T.Deprecated,
         T.Override,
         T.Abstract,
         T.Synchronized,
         //T.Static,
         T.Final,
         T.Const,
         //T.Invariant, // D 2.0
         T.Auto,
         T.Scope:
    case_StaticAttribute:
    case_InvariantAttribute: // D 2.0
      return parseStorageAttribute();
    case T.Alias:
      nT();
      decl = new AliasDeclaration(parseVariableOrFunction());
      break;
    case T.Typedef:
      nT();
      decl = new TypedefDeclaration(parseVariableOrFunction());
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
      decl = parseImportDeclaration();
      imports ~= decl.to!(ImportDeclaration);
      // Handle specially. StorageClass mustn't be set.
      decl.setProtection(this.protection);
      return set(decl, begin);
    case T.Enum:
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
    case T.Invariant:
    version(D2)
    {
      auto next = token;
      if (peekAfter(next) == T.LParen)
      {
        if (peekAfter(next) != T.RParen)
          goto case_Declaration;
      }
      else
        goto case_InvariantAttribute;
    }
      decl = parseInvariantDeclaration();
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
      return parseVariableOrFunction(this.storageClass, this.protection, this.linkageType);
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
  /// $(PRE
  /// DeclarationsBlock :=
  ///     : DeclDefs
  ///     { }
  ///     { DeclDefs }
  ///     DeclDef
  /// )
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
      require(T.RBrace);
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
  /// Params:
  ///   stc = previously parsed storage classes
  ///   protection = previously parsed protection attribute
  ///   linkType = previously parsed linkage type
  ///   testAutoDeclaration = whether to check for an AutoDeclaration
  ///   optionalParameterList = a hint for how to parse C-style function pointers
  Declaration parseVariableOrFunction(StorageClass stc = StorageClass.None,
                                      Protection protection = Protection.None,
                                      LinkageType linkType = LinkageType.None,
                                      bool testAutoDeclaration = false,
                                      bool optionalParameterList = true)
  {
    auto begin = token;
    Type type;
    Identifier* name;

    // Check for AutoDeclaration: StorageClasses Identifier =
    if (testAutoDeclaration &&
        token.kind == T.Identifier &&
        peekNext() == T.Assign)
    {
      name = token.ident;
      skip(T.Identifier);
    }
    else
    {
      type = parseType(); // VariableType or ReturnType
      if (token.kind == T.LParen)
      {
        // C-style function pointers make the grammar ambiguous.
        // We have to treat them specially at function scope.
        // Example:
        //   void foo() {
        //     // A pointer to a function taking an integer and returning 'some_type'.
        //     some_type (*p_func)(int);
        //     // In the following case precedence is given to a CallExpression.
        //     something(*p); // 'something' may be a function/method or an object having opCall overloaded.
        //   }
        //   // A pointer to a function taking no parameters and returning 'something'.
        //   something(*p);
        type = parseCFunctionPointerType(type, name, optionalParameterList);
      }
      else if (peekNext() == T.LParen)
      { // Type FunctionName ( ParameterList ) FunctionBody
        name = requireIdentifier(MSG.ExpectedFunctionName);
        name || nT(); // Skip non-identifier token.
        assert(token.kind == T.LParen);
        // It's a function declaration
        TemplateParameters tparams;
        if (tokenAfterParenIs(T.LParen))
          // ( TemplateParameterList ) ( ParameterList )
          tparams = parseTemplateParameterList();

        auto params = parseParameterList();
      version(D2)
      {
        switch (token.kind)
        {
        case T.Const:
          stc |= StorageClass.Const;
          nT();
          break;
        case T.Invariant:
          stc |= StorageClass.Invariant;
          nT();
          break;
        default:
        }
      }
        // ReturnType FunctionName ( ParameterList )
        auto funcBody = parseFunctionBody();
        auto fd = new FunctionDeclaration(type, name,/+ tparams,+/ params, funcBody);
        fd.setStorageClass(stc);
        fd.setLinkageType(linkType);
        fd.setProtection(protection);
        if (tparams)
        {
          auto d = putInsideTemplateDeclaration(begin, name, fd, tparams);
          d.setStorageClass(stc);
          d.setProtection(protection);
          return set(d, begin);
        }
        return set(fd, begin);
      }
      else
      { // Type VariableName DeclaratorSuffix
        name = requireIdentifier(MSG.ExpectedVariableName);
        type = parseDeclaratorSuffix(type);
      }
    }

    // It's a variables declaration.
    Identifier*[] names = [name]; // One identifier has been parsed already.
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
    d.setStorageClass(stc);
    d.setLinkageType(linkType);
    d.setProtection(protection);
    return set(d, begin);
  }

  /// Parses a variable initializer.
  Expression parseInitializer()
  {
    if (token.kind == T.Void)
    {
      auto begin = token;
      auto next = peekNext();
      if (next == T.Comma || next == T.Semicolon)
      {
        skip(T.Void);
        return set(new VoidInitExpression(), begin);
      }
    }
    return parseNonVoidInitializer();
  }

  Expression parseNonVoidInitializer()
  {
    auto begin = token;
    Expression init;
    switch (token.kind)
    {
    case T.LBracket:
      // ArrayInitializer:
      //         [ ]
      //         [ ArrayMemberInitializations ]
      Expression[] keys;
      Expression[] values;

      skip(T.LBracket);
      while (token.kind != T.RBracket)
      {
        auto e = parseNonVoidInitializer();
        if (consumed(T.Colon))
        {
          keys ~= e;
          values ~= parseNonVoidInitializer();
        }
        else
        {
          keys ~= null;
          values ~= e;
        }

        if (!consumed(T.Comma))
          break;
      }
      require(T.RBracket);
      init = new ArrayInitExpression(keys, values);
      break;
    case T.LBrace:
      // StructInitializer:
      //         { }
      //         { StructMemberInitializers }
      Expression parseStructInitializer()
      {
        Identifier*[] idents;
        Expression[] values;

        skip(T.LBrace);
        while (token.kind != T.RBrace)
        {
          if (token.kind == T.Identifier &&
              // Peek for colon to see if this is a member identifier.
              peekNext() == T.Colon)
          {
            idents ~= token.ident;
            skip(T.Identifier), skip(T.Colon);
          }
          else
            idents ~= null;

          // NonVoidInitializer
          values ~= parseNonVoidInitializer();

          if (!consumed(T.Comma))
            break;
        }
        require(T.RBrace);
        return new StructInitExpression(idents, values);
      }

      bool success;
      auto si = try_(&parseStructInitializer, success);
      if (success)
      {
        init = si;
        break;
      }
      assert(token.kind == T.LBrace);
      //goto default;
    default:
      init = parseAssignExpression();
    }
    set(init, begin);
    return init;
  }

  FuncBodyStatement parseFunctionBody()
  {
    auto begin = token;
    auto func = new FuncBodyStatement;
    while (1)
    {
      switch (token.kind)
      {
      case T.LBrace:
        func.funcBody = parseStatements();
        break;
      case T.Semicolon:
        nT();
        break;
      case T.In:
        if (func.inBody)
          error(MID.InContract);
        nT();
        func.inBody = parseStatements();
        continue;
      case T.Out:
        if (func.outBody)
          error(MID.OutContract);
        nT();
        if (consumed(T.LParen))
        {
          func.outIdent = requireIdentifier(MSG.ExpectedAnIdentifier);
          require(T.RParen);
        }
        func.outBody = parseStatements();
        continue;
      case T.Body:
        nT();
        goto case T.LBrace;
      default:
        error(token, MSG.ExpectedFunctionBody, token.srcText);
      }
      break; // Exit loop.
    }
    set(func, begin);
    func.finishConstruction();
    return func;
  }

  LinkageType parseLinkageType()
  {
    LinkageType linkageType;

    if (!consumed(T.LParen))
      return linkageType;

    if (consumed(T.RParen))
    { // extern()
      error(MID.MissingLinkageType);
      return linkageType;
    }

    auto identTok = requireId();

    IDK idKind = identTok ? identTok.ident.idKind : IDK.Null;

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
      linkageType = LinkageType.System;
      break;
    default:
      error(MID.UnrecognizedLinkageType, token.srcText);
    }
    require(T.RParen);
    return linkageType;
  }

  void checkLinkageType(ref LinkageType prev_lt, LinkageType lt, Token* begin)
  {
    if (prev_lt == LinkageType.None)
      prev_lt = lt;
    else
      error(begin, MSG.RedundantLinkageType, Token.textSpan(begin, this.prevToken));
  }

  Declaration parseStorageAttribute()
  {
    StorageClass stc, stc_tmp;
    LinkageType prev_linkageType;

    auto saved_storageClass = this.storageClass; // Save.
    // Nested function.
    Declaration parse()
    {
      Declaration decl;
      auto begin = token;
      switch (token.kind)
      {
      case T.Extern:
        if (peekNext() != T.LParen)
        {
          stc_tmp = StorageClass.Extern;
          goto Lcommon;
        }

        nT();
        auto linkageType = parseLinkageType();
        checkLinkageType(prev_linkageType, linkageType, begin);

        auto saved = this.linkageType; // Save.
        this.linkageType = linkageType; // Set.
        decl = new LinkageDeclaration(linkageType, parse());
        set(decl, begin);
        this.linkageType = saved; // Restore.
        break;
      case T.Override:
        stc_tmp = StorageClass.Override;
        goto Lcommon;
      case T.Deprecated:
        stc_tmp = StorageClass.Deprecated;
        goto Lcommon;
      case T.Abstract:
        stc_tmp = StorageClass.Abstract;
        goto Lcommon;
      case T.Synchronized:
        stc_tmp = StorageClass.Synchronized;
        goto Lcommon;
      case T.Static:
        stc_tmp = StorageClass.Static;
        goto Lcommon;
      case T.Final:
        stc_tmp = StorageClass.Final;
        goto Lcommon;
      case T.Const:
      version(D2)
      {
        if (peekNext() == T.LParen)
          goto case_Declaration;
      }
        stc_tmp = StorageClass.Const;
        goto Lcommon;
      version(D2)
      {
      case T.Invariant: // D 2.0
        auto next = token;
        if (peekAfter(next) == T.LParen)
        {
          if (peekAfter(next) != T.RParen)
            goto case_Declaration; // invariant ( Type )
          decl = parseDeclarationDefinition(); // invariant ( )
          decl.setStorageClass(stc);
          break;
        }
        // invariant as StorageClass.
        stc_tmp = StorageClass.Invariant;
        goto Lcommon;
      }
      case T.Auto:
        stc_tmp = StorageClass.Auto;
        goto Lcommon;
      case T.Scope:
        stc_tmp = StorageClass.Scope;
        goto Lcommon;
      Lcommon:
        // Issue error if redundant.
        if (stc & stc_tmp)
          error(MID.RedundantStorageClass, token.srcText);
        else
          stc |= stc_tmp;

        nT();
        decl = new StorageClassDeclaration(stc_tmp, parse());
        set(decl, begin);
        break;
      case T.Identifier:
      case_Declaration:
        // This could be a normal Declaration or an AutoDeclaration
        decl = parseVariableOrFunction(stc, this.protection, prev_linkageType, true);
        break;
      default:
        this.storageClass = stc; // Set.
        decl = parseDeclarationsBlock();
        this.storageClass = saved_storageClass; // Reset.
      }
      assert(isNodeSet(decl));
      return decl;
    }
    return parse();
  }

  uint parseAlignAttribute()
  {
    skip(T.Align);
    uint size = DEFAULT_ALIGN_SIZE; // Global default.
    if (consumed(T.LParen))
    {
      if (token.kind == T.Int32)
        (size = token.int_), skip(T.Int32);
      else
        expected(T.Int32);
      require(T.RParen);
    }
    return size;
  }

  Declaration parseAttributeSpecifier()
  {
    Declaration decl;

    switch (token.kind)
    {
    case T.Align:
      uint alignSize = parseAlignAttribute();
      auto saved = this.alignSize; // Save.
      this.alignSize = alignSize; // Set.
      decl = new AlignDeclaration(alignSize, parseDeclarationsBlock());
      this.alignSize = saved; // Restore.
      break;
    case T.Pragma:
      // Pragma:
      //     pragma ( Identifier )
      //     pragma ( Identifier , ExpressionList )
      nT();
      Identifier* ident;
      Expression[] args;

      require(T.LParen);
      ident = requireIdentifier(MSG.ExpectedPragmaIdentifier);

      if (consumed(T.Comma))
        args = parseExpressionList();
      require(T.RParen);

      decl = new PragmaDeclaration(ident, args, parseDeclarationsBlock());
      break;
    default:
      // Protection attributes
      Protection prot;
      switch (token.kind)
      {
      case T.Private:
        prot = Protection.Private; break;
      case T.Package:
        prot = Protection.Package; break;
      case T.Protected:
        prot = Protection.Protected; break;
      case T.Public:
        prot = Protection.Public; break;
      case T.Export:
        prot = Protection.Export; break;
      default:
        assert(0);
      }
      nT();
      auto saved = this.protection; // Save.
      this.protection = prot; // Set.
      decl = new ProtectionDeclaration(prot, parseDeclarationsBlock());
      this.protection = saved; // Restore.
    }
    return decl;
  }

  Declaration parseImportDeclaration()
  {
    bool isStatic = consumed(T.Static);
    skip(T.Import);

    ModuleFQN[] moduleFQNs;
    Identifier*[] moduleAliases;
    Identifier*[] bindNames;
    Identifier*[] bindAliases;

    do
    {
      ModuleFQN moduleFQN;
      Identifier* moduleAlias;
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
    { // BindAlias "=" BindName ("," BindAlias "=" BindName)*;
      // BindName ("," BindName)*;
      do
      {
        Identifier* bindAlias;
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

    return new ImportDeclaration(moduleFQNs, moduleAliases, bindNames, bindAliases, isStatic);
  }

  Declaration parseEnumDeclaration()
  {
    skip(T.Enum);

    Identifier* enumName;
    Type baseType;
    EnumMemberDeclaration[] members;
    bool hasBody;

    enumName = optionalIdentifier();

    if (consumed(T.Colon))
      baseType = parseBasicType();

    if (enumName && consumed(T.Semicolon))
    {}
    else if (consumed(T.LBrace))
    {
      hasBody = true;
      while (token.kind != T.RBrace)
      {
        auto begin = token;
        auto name = requireIdentifier(MSG.ExpectedEnumMember);
        Expression value;

        if (consumed(T.Assign))
          value = parseAssignExpression();
        else
          value = null;

        members ~= set(new EnumMemberDeclaration(name, value), begin);

        if (!consumed(T.Comma))
          break;
      }
      require(T.RBrace);
    }
    else
      error(token, MSG.ExpectedEnumBody, token.srcText);

    return new EnumDeclaration(enumName, baseType, members, hasBody);
  }

  /// Wraps a declaration inside a template declaration.
  /// Params:
  ///   begin = begin token of decl.
  ///   name = name of decl.
  ///   decl = the declaration to be wrapped.
  ///   tparams = the template parameters.
  TemplateDeclaration putInsideTemplateDeclaration(Token* begin,
                                                   Identifier* name,
                                                   Declaration decl,
                                                   TemplateParameters tparams)
  {
    set(decl, begin);
    auto cd = new CompoundDeclaration;
    cd ~= decl;
    set(cd, begin);
    return new TemplateDeclaration(name, tparams, cd);
  }

  Declaration parseClassDeclaration()
  {
    auto begin = token;
    skip(T.Class);

    Identifier* className;
    TemplateParameters tparams;
    BaseClassType[] bases;
    CompoundDeclaration decls;

    className = requireIdentifier(MSG.ExpectedClassName);

    if (token.kind == T.LParen)
      tparams = parseTemplateParameterList();

    if (token.kind == T.Colon)
      bases = parseBaseClasses();

    if (bases.length == 0 && consumed(T.Semicolon))
    {}
    else if (token.kind == T.LBrace)
      decls = parseDeclarationDefinitionsBody();
    else
      error(token, MSG.ExpectedClassBody, token.srcText);

    Declaration d = new ClassDeclaration(className, /+tparams, +/bases, decls);
    if (tparams)
      d = putInsideTemplateDeclaration(begin, className, d, tparams);
    return d;
  }

  BaseClassType[] parseBaseClasses(bool colonLeadsOff = true)
  {
    colonLeadsOff && skip(T.Colon);

    BaseClassType[] bases;
    do
    {
      Protection prot = Protection.Public;
      switch (token.kind)
      {
      case T.Identifier, T.Dot, T.Typeof: goto LparseBasicType;
      case T.Private:   prot = Protection.Private;   break;
      case T.Protected: prot = Protection.Protected; break;
      case T.Package:   prot = Protection.Package;   break;
      case T.Public:  /*prot = Protection.Public;*/  break;
      default:
        error(MID.ExpectedBaseClasses, token.srcText);
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

  Declaration parseInterfaceDeclaration()
  {
    auto begin = token;
    skip(T.Interface);

    Identifier* name;
    TemplateParameters tparams;
    BaseClassType[] bases;
    CompoundDeclaration decls;

    name = requireIdentifier(MSG.ExpectedInterfaceName);

    if (token.kind == T.LParen)
      tparams = parseTemplateParameterList();

    if (token.kind == T.Colon)
      bases = parseBaseClasses();

    if (bases.length == 0 && consumed(T.Semicolon))
    {}
    else if (token.kind == T.LBrace)
      decls = parseDeclarationDefinitionsBody();
    else
      error(token, MSG.ExpectedInterfaceBody, token.srcText);

    Declaration d = new InterfaceDeclaration(name, /+tparams, +/bases, decls);
    if (tparams)
      d = putInsideTemplateDeclaration(begin, name, d, tparams);
    return d;
  }

  Declaration parseStructOrUnionDeclaration()
  {
    assert(token.kind == T.Struct || token.kind == T.Union);
    auto begin = token;
    skip(token.kind);

    Identifier* name;
    TemplateParameters tparams;
    CompoundDeclaration decls;

    name = optionalIdentifier();

    if (name && token.kind == T.LParen)
      tparams = parseTemplateParameterList();

    if (name && consumed(T.Semicolon))
    {}
    else if (token.kind == T.LBrace)
      decls = parseDeclarationDefinitionsBody();
    else
      error(token, begin.kind == T.Struct ?
                   MSG.ExpectedStructBody :
                   MSG.ExpectedUnionBody, token.srcText);

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
      d = putInsideTemplateDeclaration(begin, name, d, tparams);
    return d;
  }

  Declaration parseConstructorDeclaration()
  {
    skip(T.This);
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new ConstructorDeclaration(parameters, funcBody);
  }

  Declaration parseDestructorDeclaration()
  {
    skip(T.Tilde);
    require(T.This);
    require(T.LParen);
    require(T.RParen);
    auto funcBody = parseFunctionBody();
    return new DestructorDeclaration(funcBody);
  }

  Declaration parseStaticConstructorDeclaration()
  {
    skip(T.Static);
    skip(T.This);
    require(T.LParen);
    require(T.RParen);
    auto funcBody = parseFunctionBody();
    return new StaticConstructorDeclaration(funcBody);
  }

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

  Declaration parseInvariantDeclaration()
  {
    skip(T.Invariant);
    // Optional () for getting ready porting to D 2.0
    if (consumed(T.LParen))
      require(T.RParen);
    auto funcBody = parseFunctionBody();
    return new InvariantDeclaration(funcBody);
  }

  Declaration parseUnittestDeclaration()
  {
    skip(T.Unittest);
    auto funcBody = parseFunctionBody();
    return new UnittestDeclaration(funcBody);
  }

  Token* parseIdentOrInt()
  {
    if (consumed(T.Int32) || consumed(T.Identifier))
      return this.prevToken;
    error(token, MSG.ExpectedIdentOrInt, token.srcText);
    return null;
  }

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
    { // ( Condition )
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
      cond = parseIdentOrInt();
      require(T.RParen);
      // version ( Condition ) DeclarationsBlock
      decls = parseDeclarationsBlock();
      // else DeclarationsBlock
      if (consumed(T.Else))
        elseDecls = parseDeclarationsBlock();
    }

    return new VersionDeclaration(spec, cond, decls, elseDecls);
  }

  Declaration parseStaticIfDeclaration()
  {
    skip(T.Static);
    skip(T.If);

    Expression condition;
    Declaration ifDecls, elseDecls;

    require(T.LParen);
    condition = parseAssignExpression();
    require(T.RParen);

    ifDecls = parseDeclarationsBlock();

    if (consumed(T.Else))
      elseDecls = parseDeclarationsBlock();

    return new StaticIfDeclaration(condition, ifDecls, elseDecls);
  }

  Declaration parseStaticAssertDeclaration()
  {
    skip(T.Static);
    skip(T.Assert);
    Expression condition, message;
    require(T.LParen);
    condition = parseAssignExpression();
    if (consumed(T.Comma))
      message = parseAssignExpression();
    require(T.RParen);
    require(T.Semicolon);
    return new StaticAssertDeclaration(condition, message);
  }

  Declaration parseTemplateDeclaration()
  {
    skip(T.Template);
    auto templateName = requireIdentifier(MSG.ExpectedTemplateName);
    auto templateParams = parseTemplateParameterList();
    auto decls = parseDeclarationDefinitionsBody();
    return new TemplateDeclaration(templateName, templateParams, decls);
  }

  Declaration parseNewDeclaration()
  {
    skip(T.New);
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new NewDeclaration(parameters, funcBody);
  }

  Declaration parseDeleteDeclaration()
  {
    skip(T.Delete);
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new DeleteDeclaration(parameters, funcBody);
  }

  Type parseTypeofType()
  {
    auto begin = token;
    skip(T.Typeof);
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
    require(T.RParen);
    set(type, begin);
    return type;
  }

  /// Parses a MixinDeclaration or MixinStatement.
  /// $(PRE
  /// TemplateMixin :=
  ///         mixin ( AssignExpression ) ;
  ///         mixin TemplateIdentifier ;
  ///         mixin TemplateIdentifier MixinIdentifier ;
  ///         mixin TemplateIdentifier !( TemplateArguments ) ;
  ///         mixin TemplateIdentifier !( TemplateArguments ) MixinIdentifier ;
  /// )
  Class parseMixin(Class)()
  {
  static assert(is(Class == MixinDeclaration) || is(Class == MixinStatement));
    skip(T.Mixin);

  static if (is(Class == MixinDeclaration))
  {
    if (consumed(T.LParen))
    {
      auto e = parseAssignExpression();
      require(T.RParen);
      require(T.Semicolon);
      return new MixinDeclaration(e);
    }
  }

    auto begin = token;
    Expression e;
    Identifier* mixinIdent;

    if (consumed(T.Dot))
      e = set(new ModuleScopeExpression(parseIdentifierExpression()), begin);
    else
      e = parseIdentifierExpression();

    while (consumed(T.Dot))
      e = set(new DotExpression(e, parseIdentifierExpression()), begin);

    mixinIdent = optionalIdentifier();
    require(T.Semicolon);

    return new Class(e, mixinIdent);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                         Statement parsing methods                         |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  CompoundStatement parseStatements()
  {
    auto begin = token;
    require(T.LBrace);
    auto statements = new CompoundStatement();
    while (token.kind != T.RBrace && token.kind != T.EOF)
      statements ~= parseStatement();
    require(T.RBrace);
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
      uint size = parseAlignAttribute();
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

      d = new AlignDeclaration(size, structDecl ? cast(Declaration)structDecl : new CompoundDeclaration);
      goto LreturnDeclarationStatement;
      /+ Not applicable for statements.
         T.Private, T.Package, T.Protected, T.Public, T.Export,
         T.Deprecated, T.Override, T.Abstract,+/
    case T.Extern,
         T.Final,
         T.Const,
         T.Auto:
         //T.Scope
         //T.Static
    case_parseAttribute:
      s = parseAttributeStatement();
      return s;
    case T.Identifier:
      if (peekNext() == T.Colon)
      {
        auto ident = token.ident;
        skip(T.Identifier); skip(T.Colon);
        s = new LabeledStatement(ident, parseNoScopeOrEmptyStatement());
        break;
      }
      goto case T.Dot;
    case T.Dot, T.Typeof:
      bool success;
      d = try_(delegate {
          return parseVariableOrFunction(StorageClass.None,
                                         Protection.None,
                                         LinkageType.None, false, false);
        }, success
      );
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
    case T.Foreach, T.Foreach_reverse:
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
      break;
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

  /// $(PRE
  /// Parses a ScopeStatement.
  /// ScopeStatement :=
  ///     NoScopeStatement
  /// )
  Statement parseScopeStatement()
  {
    return new ScopeStatement(parseNoScopeStatement());
  }

  /// $(PRE
  /// NoScopeStatement :=
  ///     NonEmptyStatement
  ///     BlockStatement
  /// BlockStatement :=
  ///     { }
  ///     { StatementList }
  /// )
  Statement parseNoScopeStatement()
  {
    auto begin = token;
    Statement s;
    if (consumed(T.LBrace))
    {
      auto ss = new CompoundStatement();
      while (token.kind != T.RBrace && token.kind != T.EOF)
        ss ~= parseStatement();
      require(T.RBrace);
      s = set(ss, begin);
    }
    else if (token.kind == T.Semicolon)
    {
      error(token, MSG.ExpectedNonEmptyStatement);
      nT();
      s = set(new EmptyStatement(), begin);
    }
    else
      s = parseStatement();
    return s;
  }

  /// $(PRE
  /// NoScopeOrEmptyStatement :=
  ///     ;
  ///     NoScopeStatement
  /// )
  Statement parseNoScopeOrEmptyStatement()
  {
    if (consumed(T.Semicolon))
      return set(new EmptyStatement(), this.prevToken);
    else
      return parseNoScopeStatement();
  }

  Statement parseAttributeStatement()
  {
    StorageClass stc, stc_tmp;
    LinkageType prev_linkageType;

    Declaration parse() // Nested function.
    {
      auto begin = token;
      Declaration d;
      switch (token.kind)
      {
      case T.Extern:
        if (peekNext() != T.LParen)
        {
          stc_tmp = StorageClass.Extern;
          goto Lcommon;
        }

        nT();
        auto linkageType = parseLinkageType();
        checkLinkageType(prev_linkageType, linkageType, begin);

        d = new LinkageDeclaration(linkageType, parse());
        break;
      case T.Static:
        stc_tmp = StorageClass.Static;
        goto Lcommon;
      case T.Final:
        stc_tmp = StorageClass.Final;
        goto Lcommon;
      case T.Const:
      version(D2)
      {
        if (peekNext() == T.LParen)
          goto case_Declaration;
      }
        stc_tmp = StorageClass.Const;
        goto Lcommon;
      version(D2)
      {
      case T.Invariant: // D 2.0
        if (peekNext() == T.LParen)
          goto case_Declaration;
        stc_tmp = StorageClass.Invariant;
        goto Lcommon;
      }
      case T.Auto:
        stc_tmp = StorageClass.Auto;
        goto Lcommon;
      case T.Scope:
        stc_tmp = StorageClass.Scope;
        goto Lcommon;
      Lcommon:
        // Issue error if redundant.
        if (stc & stc_tmp)
          error(MID.RedundantStorageClass, token.srcText);
        else
          stc |= stc_tmp;

        nT();
        d = new StorageClassDeclaration(stc_tmp, parse());
        break;
      // TODO: allow "scope class", "abstract scope class" in function bodies?
      //case T.Class:
      default:
      case_Declaration:
        return parseVariableOrFunction(stc, Protection.None, prev_linkageType, true);
      }
      return set(d, begin);
    }
    return new DeclarationStatement(parse());
  }

  Statement parseIfStatement()
  {
    skip(T.If);

    Statement variable;
    Expression condition;
    Statement ifBody, elseBody;

    require(T.LParen);

    Identifier* ident;
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
    { // Declarator = Expression
      Type parseDeclaratorAssign()
      {
        auto type = parseDeclarator(ident);
        require(T.Assign);
        return type;
      }
      bool success;
      auto type = try_(&parseDeclaratorAssign, success);
      if (success)
      {
        auto init = parseExpression();
        auto v = new VariablesDeclaration(type, [ident], [init]);
        set(v, begin);
        variable = new DeclarationStatement(v);
        set(variable, begin);
      }
      else
        condition = parseExpression();
    }
    require(T.RParen);
    ifBody = parseScopeStatement();
    if (consumed(T.Else))
      elseBody = parseScopeStatement();
    return new IfStatement(variable, condition, ifBody, elseBody);
  }

  Statement parseWhileStatement()
  {
    skip(T.While);
    require(T.LParen);
    auto condition = parseExpression();
    require(T.RParen);
    return new WhileStatement(condition, parseScopeStatement());
  }

  Statement parseDoWhileStatement()
  {
    skip(T.Do);
    auto doBody = parseScopeStatement();
    require(T.While);
    require(T.LParen);
    auto condition = parseExpression();
    require(T.RParen);
    return new DoWhileStatement(condition, doBody);
  }

  Statement parseForStatement()
  {
    skip(T.For);

    Statement init, forBody;
    Expression condition, increment;

    require(T.LParen);
    if (!consumed(T.Semicolon))
      init = parseNoScopeStatement();
    if (token.kind != T.Semicolon)
      condition = parseExpression();
    require(T.Semicolon);
    if (token.kind != T.RParen)
      increment = parseExpression();
    require(T.RParen);
    forBody = parseScopeStatement();
    return new ForStatement(init, condition, increment, forBody);
  }

  Statement parseForeachStatement()
  {
    assert(token.kind == T.Foreach || token.kind == T.Foreach_reverse);
    TOK tok = token.kind;
    nT();

    auto params = new Parameters;
    Expression e; // Aggregate or LwrExpression

    require(T.LParen);
    auto paramsBegin = token;
    do
    {
      auto paramBegin = token;
      StorageClass stc;
      Type type;
      Identifier* ident;

      switch (token.kind)
      {
      case T.Ref, T.Inout:
        stc = StorageClass.Ref;
        nT();
        // fall through
      case T.Identifier:
        auto next = peekNext();
        if (next == T.Comma || next == T.Semicolon || next == T.RParen)
        {
          ident = requireIdentifier(MSG.ExpectedVariableName);
          break;
        }
        // fall through
      default:
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
      require(T.RParen);
      auto forBody = parseScopeStatement();
      return new ForeachRangeStatement(tok, params, e, upper, forBody);
    }
  }
    // Foreach (ForeachTypeList; Aggregate) ScopeStatement
    require(T.RParen);
    auto forBody = parseScopeStatement();
    return new ForeachStatement(tok, params, e, forBody);
  }

  Statement parseSwitchStatement()
  {
    skip(T.Switch);
    require(T.LParen);
    auto condition = parseExpression();
    require(T.RParen);
    auto switchBody = parseScopeStatement();
    return new SwitchStatement(condition, switchBody);
  }

  /// Helper function for parsing the body of a default or case statement.
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
    set(s, begin);
    return set(new ScopeStatement(s), begin);
  }

  Statement parseCaseStatement()
  {
    skip(T.Case);
    auto values = parseExpressionList();
    require(T.Colon);
    auto caseBody = parseCaseOrDefaultBody();
    return new CaseStatement(values, caseBody);
  }

  Statement parseDefaultStatement()
  {
    skip(T.Default);
    require(T.Colon);
    auto defaultBody = parseCaseOrDefaultBody();
    return new DefaultStatement(defaultBody);
  }

  Statement parseContinueStatement()
  {
    skip(T.Continue);
    auto ident = optionalIdentifier();
    require(T.Semicolon);
    return new ContinueStatement(ident);
  }

  Statement parseBreakStatement()
  {
    skip(T.Break);
    auto ident = optionalIdentifier();
    require(T.Semicolon);
    return new BreakStatement(ident);
  }

  Statement parseReturnStatement()
  {
    skip(T.Return);
    Expression expr;
    if (token.kind != T.Semicolon)
      expr = parseExpression();
    require(T.Semicolon);
    return new ReturnStatement(expr);
  }

  Statement parseGotoStatement()
  {
    skip(T.Goto);
    Identifier* ident;
    Expression caseExpr;
    switch (token.kind)
    {
    case T.Case:
      ident = token.ident;
      nT();
      if (token.kind == T.Semicolon)
        break;
      caseExpr = parseExpression();
      break;
    case T.Default:
      ident = token.ident;
      nT();
      break;
    default:
      ident = requireIdentifier(MSG.ExpectedAnIdentifier);
    }
    require(T.Semicolon);
    return new GotoStatement(ident, caseExpr);
  }

  Statement parseWithStatement()
  {
    skip(T.With);
    require(T.LParen);
    auto expr = parseExpression();
    require(T.RParen);
    return new WithStatement(expr, parseScopeStatement());
  }

  Statement parseSynchronizedStatement()
  {
    skip(T.Synchronized);
    Expression expr;
    if (consumed(T.LParen))
    {
      expr = parseExpression();
      require(T.RParen);
    }
    return new SynchronizedStatement(expr, parseScopeStatement());
  }

  Statement parseTryStatement()
  {
    auto begin = token;
    skip(T.Try);

    auto tryBody = parseScopeStatement();
    CatchStatement[] catchBodies;
    FinallyStatement finBody;

    while (consumed(T.Catch))
    {
      Parameter param;
      if (consumed(T.LParen))
      {
        auto begin2 = token;
        Identifier* ident;
        auto type = parseDeclarator(ident, true);
        param = new Parameter(StorageClass.None, type, ident, null);
        set(param, begin2);
        require(T.RParen);
      }
      catchBodies ~= set(new CatchStatement(param, parseNoScopeStatement()), begin);
      if (param is null)
        break; // This is a LastCatch
      begin = token;
    }

    if (consumed(T.Finally))
      finBody = set(new FinallyStatement(parseNoScopeStatement()), prevToken);

    if (catchBodies.length == 0 && finBody is null)
      assert(begin.kind == T.Try), error(begin, MSG.MissingCatchOrFinally);

    return new TryStatement(tryBody, catchBodies, finBody);
  }

  Statement parseThrowStatement()
  {
    skip(T.Throw);
    auto expr = parseExpression();
    require(T.Semicolon);
    return new ThrowStatement(expr);
  }

  Statement parseScopeGuardStatement()
  {
    skip(T.Scope);
    skip(T.LParen);
    auto condition = requireIdentifier(MSG.ExpectedScopeIdentifier);
    if (condition)
      switch (condition.idKind)
      {
      case IDK.exit, IDK.success, IDK.failure:
        break;
      default:
        error(this.prevToken, MSG.InvalidScopeIdentifier, this.prevToken.srcText);
      }
    require(T.RParen);
    Statement scopeBody;
    if (token.kind == T.LBrace)
      scopeBody = parseScopeStatement();
    else
      scopeBody = parseNoScopeStatement();
    return new ScopeGuardStatement(condition, scopeBody);
  }

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

  Statement parsePragmaStatement()
  {
    skip(T.Pragma);

    Identifier* ident;
    Expression[] args;
    Statement pragmaBody;

    require(T.LParen);
    ident = requireIdentifier(MSG.ExpectedPragmaIdentifier);

    if (consumed(T.Comma))
      args = parseExpressionList();
    require(T.RParen);

    pragmaBody = parseNoScopeOrEmptyStatement();

    return new PragmaStatement(ident, args, pragmaBody);
  }

  Statement parseStaticIfStatement()
  {
    skip(T.Static);
    skip(T.If);
    Expression condition;
    Statement ifBody, elseBody;

    require(T.LParen);
    condition = parseExpression();
    require(T.RParen);
    ifBody = parseNoScopeStatement();
    if (consumed(T.Else))
      elseBody = parseNoScopeStatement();
    return new StaticIfStatement(condition, ifBody, elseBody);
  }

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

  Statement parseVersionStatement()
  {
    skip(T.Version);
    Token* cond;
    Statement versionBody, elseBody;

    // ( Condition )
    require(T.LParen);
    cond = parseIdentOrInt();
    require(T.RParen);
    // version ( Condition ) Statement
    versionBody = parseNoScopeStatement();
    // else Statement
    if (consumed(T.Else))
      elseBody = parseNoScopeStatement();

    return new VersionStatement(cond, versionBody, elseBody);
  }

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                         Assembler parsing methods                         |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// Parses an AsmBlockStatement.
  Statement parseAsmBlockStatement()
  {
    skip(T.Asm);
    require(T.LBrace);
    auto ss = new CompoundStatement;
    while (token.kind != T.RBrace && token.kind != T.EOF)
      ss ~= parseAsmStatement();
    require(T.RBrace);
    return new AsmBlockStatement(ss);
  }

  Statement parseAsmStatement()
  {
    auto begin = token;
    Statement s;
    Identifier* ident;
    switch (token.kind)
    {
    // Keywords that are valid opcodes.
    case T.In, T.Int, T.Out:
      ident = token.ident;
      nT();
      goto LOpcode;
    case T.Identifier:
      ident = token.ident;
      nT();
      if (consumed(T.Colon))
      { // Identifier : AsmStatement
        s = new LabeledStatement(ident, parseAsmStatement());
        break;
      }

    LOpcode:
      // Opcode ;
      // Opcode Operands ;
      // Opcode
      //     Identifier
      Expression[] es;
      if (token.kind != T.Semicolon)
        do
          es ~= parseAsmExpression();
        while (consumed(T.Comma))
      require(T.Semicolon);
      s = new AsmStatement(ident, es);
      break;
    case T.Align:
      // align Integer;
      nT();
      int number = -1;
      if (token.kind == T.Int32)
        (number = token.int_), skip(T.Int32);
      else
        error(token, MSG.ExpectedIntegerAfterAlign, token.srcText);
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

  Expression parseAsmExpression()
  {
    auto begin = token;
    auto e = parseAsmOrOrExpression();
    if (consumed(T.Question))
    {
      auto tok = this.prevToken;
      auto iftrue = parseAsmExpression();
      require(T.Colon);
      auto iffalse = parseAsmExpression();
      e = new CondExpression(e, iftrue, iffalse, tok);
      set(e, begin);
    }
    // TODO: create AsmExpression that contains e?
    return e;
  }

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
      case T.LShift:  nT(); e = new LShiftExpression(e, parseNext(), operator); break;
      case T.RShift:  nT(); e = new RShiftExpression(e, parseNext(), operator); break;
      case T.URShift: nT(); e = new URShiftExpression(e, parseNext(), operator); break;
      default:
        return e;
      }
      set(e, begin);
    }
    assert(0);
  }

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
      case T.Plus:  nT(); e = new PlusExpression(e, parseNext(), operator); break;
      case T.Minus: nT(); e = new MinusExpression(e, parseNext(), operator); break;
      // Not allowed in asm
      //case T.Tilde: nT(); e = new CatExpression(e, parseNext(), operator); break;
      default:
        return e;
      }
      set(e, begin);
    }
    assert(0);
  }

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

  Expression parseAsmPostExpression()
  {
    auto begin = token;
    auto e = parseAsmUnaryExpression();
    while (consumed(T.LBracket))
    {
      e = new AsmPostBracketExpression(e, parseAsmExpression());
      require(T.RBracket);
      set(e, begin);
    }
    return e;
  }

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
          error(MID.ExpectedButFound, "ptr", token.srcText);
        e = new AsmTypeExpression(parseAsmExpression());
        break;
      case IDK.offset:
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
    case T.Dot:
      nT();
      e = new ModuleScopeExpression(parseIdentifierExpression());
      while (consumed(TOK.Dot))
      {
        e = new DotExpression(e, parseIdentifierExpression());
        set(e, begin);
      }
      break;
    default:
    LparseAsmPrimaryExpression:
      e = parseAsmPrimaryExpression();
      return e;
    }
    set(e, begin);
    return e;
  }

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
      nT();
      e = parseAsmExpression();
      require(T.RBracket);
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
        // (1) - (7)
        int number = -1;
        if (consumed(T.LParen))
        {
          if (token.kind == T.Int32)
            (number = token.int_), skip(T.Int32);
          else
            expected(T.Int32);
          require(T.RParen);
        }
        e = new AsmRegisterExpression(register, number);
        break;
      case IDK.FS:
        nT();
        // TODO: is the colon-number part optional?
        int number = -1;
        if (consumed(T.Colon))
        {
          // :0, :4, :8
          if (token.kind == T.Int32)
            (number = token.int_), skip(T.Int32);
          if (number != 0 && number != 4 && number != 8)
            error(MID.ExpectedButFound, "0, 4 or 8", token.srcText);
        }
        e = new AsmRegisterExpression(register, number);
        break;
      case IDK.AL, IDK.AH, IDK.AX, IDK.EAX,
           IDK.BL, IDK.BH, IDK.BX, IDK.EBX,
           IDK.CL, IDK.CH, IDK.CX, IDK.ECX,
           IDK.DL, IDK.DH, IDK.DX, IDK.EDX,
           IDK.BP, IDK.EBP, IDK.SP, IDK.ESP,
           IDK.DI, IDK.EDI, IDK.SI, IDK.ESI,
           IDK.ES, IDK.CS, IDK.SS, IDK.DS, IDK.GS,
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
        while (consumed(TOK.Dot))
        {
          e = new DotExpression(e, parseIdentifierExpression());
          set(e, begin);
        }
      } // end of switch
      break;
    default:
      error(MID.ExpectedButFound, "Expression", token.srcText);
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

  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                        Expression parsing methods                         |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  /// Parses an Expression.
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
    default:
      return e;
    }
    set(e, begin);
    return e;
  }

  Expression parseCondExpression()
  {
    auto begin = token;
    auto e = parseOrOrExpression();
    if (token.kind == T.Question)
    {
      auto tok = token;
      nT();
      auto iftrue = parseExpression();
      require(T.Colon);
      auto iffalse = parseCondExpression();
      e = new CondExpression(e, iftrue, iffalse, tok);
      set(e, begin);
    }
    return e;
  }

  Expression parseOrOrExpression()
  {
    alias parseAndAndExpression parseNext;
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

  Expression parseAndAndExpression()
  {
    alias parseOrExpression parseNext;
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

  Expression parseOrExpression()
  {
    alias parseXorExpression parseNext;
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

  Expression parseXorExpression()
  {
    alias parseAndExpression parseNext;
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

  Expression parseAndExpression()
  {
    alias parseCmpExpression parseNext;
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

  Expression parseCmpExpression()
  {
    alias parseShiftExpression parseNext;
    auto begin = token;
    auto e = parseShiftExpression();

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
      case T.LShift:  nT(); e = new LShiftExpression(e, parseNext(), operator); break;
      case T.RShift:  nT(); e = new RShiftExpression(e, parseNext(), operator); break;
      case T.URShift: nT(); e = new URShiftExpression(e, parseNext(), operator); break;
      default:
        return e;
      }
      set(e, begin);
    }
    assert(0);
  }

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
      case T.Plus:  nT(); e = new PlusExpression(e, parseNext(), operator); break;
      case T.Minus: nT(); e = new MinusExpression(e, parseNext(), operator); break;
      case T.Tilde: nT(); e = new CatExpression(e, parseNext(), operator); break;
      default:
        return e;
      }
      set(e, begin);
    }
    assert(0);
  }

  Expression parseMulExpression()
  {
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

  Expression parsePostExpression()
  {
    auto begin = token;
    auto e = parseUnaryExpression();
    while (1)
    {
      while (consumed(T.Dot))
      {
        e = new DotExpression(e, parseNewOrIdentifierExpression());
        set(e, begin);
      }

      switch (token.kind)
      {
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
          require(T.RBracket);
          goto Lset;
        }

        // [ ExpressionList ]
        if (consumed(T.Comma))
           es ~= parseExpressionList();
        require(T.RBracket);

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
      switch (token.kind)
      {
      version(D2)
      {
      auto begin2 = token;
      case T.Const:
        type = new ConstType(null);
        goto case_break;
      case T.Invariant:
        type = new InvariantType(null);
      case_break:
        nT();
        set(type, begin2);
        break;
      }
      default:
       type = parseType();
      }
      require(T.RParen);
      e = new CastExpression(parseUnaryExpression(), type);
      break;
    case T.LParen:
      // ( Type ) . Identifier
      Type parseType_()
      {
        skip(T.LParen);
        auto type = parseType();
        require(T.RParen);
        require(T.Dot);
        return type;
      }
      bool success;
      auto type = try_(&parseType_, success);
      if (success)
      {
        auto ident = requireIdentifier(MSG.ExpectedIdAfterTypeDot);
        e = new TypeDotIdExpression(type, ident);
        break;
      }
      goto default;
    case T.Dot:
      nT();
      e = new ModuleScopeExpression(parseIdentifierExpression());
      break;
    default:
      e = parsePrimaryExpression();
      return e;
    }
    assert(e !is null);
    set(e, begin);
    return e;
  }

  /// $(PRE
  /// IdentifierExpression :=
  ///         Identifier
  ///         TemplateInstance
  /// TemplateInstance :=
  ///         Identifier !( TemplateArguments )
  /// )
  Expression parseIdentifierExpression()
  {
    auto begin = token;
    auto ident = requireIdentifier(MSG.ExpectedAnIdentifier);
    Expression e;
    // Peek for '(' to avoid matching: id !is id
    if (token.kind == T.Not && peekNext() == T.LParen)
    { // Identifier !( TemplateArguments )
      skip(T.Not);
      auto tparams = parseTemplateArguments();
      e = new TemplateInstanceExpression(ident, tparams);
    }
    else // Identifier
      e = new IdentifierExpression(ident);
    return set(e, begin);
  }

  Expression parseNewOrIdentifierExpression()
  {
    return token.kind == T.New ? parseNewExpression() :  parseIdentifierExpression();
  }

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
    case T.This:
      nT();
      e = new ThisExpression();
      break;
    case T.Super:
      nT();
      e = new SuperExpression();
      break;
    case T.Null:
      nT();
      e = new NullExpression();
      break;
    case T.True, T.False:
      nT();
      e = new BoolExpression();
      break;
    case T.Dollar:
      nT();
      e = new DollarExpression();
      break;
    case T.Int32, T.Int64, T.Uint32, T.Uint64:
      e = new IntExpression(token);
      nT();
      break;
    case T.Float32, T.Float64, T.Float80,
         T.Imaginary32, T.Imaginary64, T.Imaginary80:
      e = new RealExpression(token);
      nT();
      break;
    case T.CharLiteral:
      e = new CharExpression(token.dchar_);
      nT();
      break;
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
        if (checkString(begin, str))
          goto default;
        e = new StringExpression(dil.Unicode.toUTF16(str)); break;
      case 'd':
        if (checkString(begin, str))
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
        require(T.RBracket);
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
      require(T.RBracket);
      e = new AArrayLiteralExpression(keys, values);
      break;
    case T.LBrace:
      // DelegateLiteral := { Statements }
      auto funcBody = parseFunctionBody();
      e = new FunctionLiteralExpression(funcBody);
      break;
    case T.Function, T.Delegate:
      // FunctionLiteral := ("function"|"delegate") Type? "(" ArgumentList ")" FunctionBody
      nT(); // Skip function or delegate keyword.
      Type returnType;
      Parameters parameters;
      if (token.kind != T.LBrace)
      {
        if (token.kind != T.LParen) // Optional return type
          returnType = parseType();
        parameters = parseParameterList();
      }
      auto funcBody = parseFunctionBody();
      e = new FunctionLiteralExpression(returnType, parameters, funcBody);
      break;
    case T.Assert:
      Expression msg;
      requireNext(T.LParen);
      e = parseAssignExpression();
      if (consumed(T.Comma))
        msg = parseAssignExpression();
      require(T.RParen);
      e = new AssertExpression(e, msg);
      break;
    case T.Mixin:
      requireNext(T.LParen);
      e = parseAssignExpression();
      require(T.RParen);
      e = new MixinExpression(e);
      break;
    case T.Import:
      requireNext(T.LParen);
      e = parseAssignExpression();
      require(T.RParen);
      e = new ImportExpression(e);
      break;
    case T.Typeid:
      requireNext(T.LParen);
      auto type = parseType();
      require(T.RParen);
      e = new TypeidExpression(type);
      break;
    case T.Is:
      requireNext(T.LParen);

      Type type, specType;
      Identifier* ident; // optional Identifier
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
          if (peekNext() != T.LParen)
            goto case_Const_Invariant;
          // Fall through. It's a type.
        default:
          specType = parseType();
        }
      default:
      }

      TemplateParameters tparams;
    version(D2)
    {
      // is ( Type Identifier : TypeSpecialization , TemplateParameterList )
      // is ( Type Identifier == TypeSpecialization , TemplateParameterList )
      if (ident && specType && token.kind == T.Comma)
        tparams = parseTemplateParameterList2();
    }
      require(T.RParen);
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
        skip(T.LParen);
        e = parseExpression();
        require(T.RParen);
        e = new ParenExpression(e);
      }
      break;
    version(D2)
    {
    case T.Traits:
      requireNext(T.LParen);
      auto id = requireIdentifier(MSG.ExpectedAnIdentifier);
      TemplateArguments args;
      if (token.kind == T.Comma)
        args = parseTemplateArguments2();
      else
        require(T.RParen);
      e = new TraitsExpression(id, args);
      break;
    }
    default:
      if (token.isIntegralType)
      { // IntegralType . Identifier
        auto type = new IntegralType(token.kind);
        nT();
        set(type, begin);
        require(T.Dot);
        auto ident = requireIdentifier(MSG.ExpectedIdAfterTypeDot);
        e = new TypeDotIdExpression(type, ident);
      }
      else if (token.isSpecialToken)
      {
        e = new SpecialTokenExpression(token);
        nT();
      }
      else
      {
        error(MID.ExpectedButFound, "Expression", token.srcText);
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

  Expression parseNewExpression(/*Expression e*/)
  {
    auto begin = token;
    skip(T.New);

    Expression[] newArguments;
    Expression[] ctorArguments;

    if (token.kind == T.LParen)
      newArguments = parseArguments();

    // NewAnonClassExpression:
    //         new (ArgumentList)opt class (ArgumentList)opt SuperClassopt InterfaceClassesopt ClassBody
    if (consumed(T.Class))
    {
      if (token.kind == T.LParen)
        ctorArguments = parseArguments();

      BaseClassType[] bases = token.kind != T.LBrace ? parseBaseClasses(false) : null ;

      auto decls = parseDeclarationDefinitionsBody();
      return set(new NewAnonClassExpression(/*e, */newArguments, bases, ctorArguments, decls), begin);
    }

    // NewExpression:
    //         NewArguments Type [ AssignExpression ]
    //         NewArguments Type ( ArgumentList )
    //         NewArguments Type
    auto type = parseType();

    if (token.kind == T.LParen)
      ctorArguments = parseArguments();

    return set(new NewExpression(/*e, */newArguments, type, ctorArguments), begin);
  }

  /// Parses a Type.
  Type parseType()
  {
    return parseBasicType2(parseBasicType());
  }

  Type parseIdentifierType()
  {
    auto begin = token;
    auto ident = requireIdentifier(MSG.ExpectedAnIdentifier);
    Type t;
    if (consumed(T.Not)) // Identifier !( TemplateArguments )
      t = new TemplateInstanceType(ident, parseTemplateArguments());
    else // Identifier
      t = new IdentifierType(ident);
    return set(t, begin);
  }

  Type parseQualifiedType()
  {
    auto begin = token;
    Type type;
    if (consumed(T.Dot))
      type = set(new ModuleScopeType(parseIdentifierType()), begin);
    else if (token.kind == T.Typeof)
      type = parseTypeofType();
    else
      type = parseIdentifierType();

    while (consumed(T.Dot))
      type = set(new QualifiedType(type, parseIdentifierType()), begin);
    return type;
  }

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
    case T.Const:
      // const ( Type )
      requireNext(T.LParen);
      t = parseType();
      require(T.RParen);
      t = new ConstType(t);
      break;
    case T.Invariant:
      // invariant ( Type )
      requireNext(T.LParen);
      t = parseType();
      require(T.RParen);
      t = new InvariantType(t);
      break;
    } // version(D2)
    default:
      error(MID.ExpectedButFound, "BasicType", token.srcText);
      t = new IllegalType();
      nT();
    }
    return set(t, begin);
  }

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
  /// is of kind tok.
  bool tokenAfterParenIs(TOK tok)
  {
    // We count nested parentheses tokens because template types
    // may appear inside parameter lists. E.g.: (int x, Foo!(int) y)
    assert(token.kind == T.LParen);
    Token* next = token;
    uint level = 1;
  Loop:
    while (1)
    {
      lexer.peek(next);
      switch (next.kind)
      {
      case T.RParen:
        if (--level == 0)
        { // Last, closing parentheses found.
          do
            lexer.peek(next);
          while (next.isWhitespace)
          break Loop;
        }
        break;
      case T.LParen:
        ++level;
        break;
      case T.EOF:
        break Loop;
      default:
      }
    }
    return next.kind == tok;
  }

  /// Parse the array types after the declarator (C-style.) E.g.: int a[]
  Type parseDeclaratorSuffix(Type lhsType)
  {
    // The Type chain should be as follows:
    // int[3]* Identifier [][32]
    //   <- <-             ->  -.
    //       ^-----------------´
    // Resulting chain: [][32]*[3]int
    Type parseNext() // Nested function required to accomplish this.
    {
      if (token.kind != T.LBracket)
        return lhsType; // Break recursion; return Type on the left hand side of the Identifier.

      auto begin = token;
      Type t;
      skip(T.LBracket);
      if (consumed(T.RBracket))
        t = new ArrayType(parseNext()); // [ ]
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
          t = new ArrayType(parseNext(), assocType); // [ Type ]
        else
        {
          Expression e = parseExpression(), e2;
          if (consumed(T.Slice))
            e2 = parseExpression();
          require(T.RBracket);
          t = new ArrayType(parseNext(), e, e2); // [ Expression .. Expression ]
        }
      }
      set(t, begin);
      return t;
    }
    return parseNext();
  }

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
        require(T.RBracket);
        t = new ArrayType(t, e, e2);
      }
    }
    set(t, begin);
    return t;
  }

  Type parseCFunctionPointerType(Type type, ref Identifier* ident, bool optionalParamList)
  {
    assert(type !is null);
    auto begin = token;
    skip(T.LParen);

    type = parseBasicType2(type);
    if (token.kind == T.LParen)
    { // Can be nested.
      type = parseCFunctionPointerType(type, ident, true);
    }
    else if (token.kind == T.Identifier)
    { // The identifier of the function pointer and the declaration.
      ident = token.ident;
      nT();
      type = parseDeclaratorSuffix(type);
    }
    require(T.RParen);

    Parameters params;
    if (optionalParamList)
      params = token.kind == T.LParen ? parseParameterList() : null;
    else
      params = parseParameterList();

    type = new CFuncPointerType(type, params);
    return set(type, begin);
  }

  Type parseDeclarator(ref Identifier* ident, bool identOptional = false)
  {
    auto t = parseType();

    if (token.kind == T.LParen)
      t = parseCFunctionPointerType(t, ident, true);
    else if (token.kind == T.Identifier)
    {
      ident = token.ident;
      nT();
      t = parseDeclaratorSuffix(t);
    }

    if (ident is null && !identOptional)
      error(token, MSG.ExpectedDeclaratorIdentifier, token.srcText);

    return t;
  }

  /// Parses a list of AssignExpressions.
  /// $(PRE
  /// ExpressionList :=
  ///   AssignExpression
  ///   AssignExpression , ExpressionList
  /// )
  Expression[] parseExpressionList()
  {
    Expression[] expressions;
    do
      expressions ~= parseAssignExpression();
    while(consumed(T.Comma))
    return expressions;
  }

  /// Parses a list of Arguments.
  /// $(PRE
  /// Arguments :=
  ///   ( )
  ///   ( ExpressionList )
  /// )
  Expression[] parseArguments()
  {
    skip(T.LParen);
    Expression[] args;
    if (token.kind != T.RParen)
      args = parseExpressionList();
    require(T.RParen);
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
          assert(0, "variadic arguments can only appear at the end of the parameter list.");
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
      StorageClass stc, stc_;
      Type type;
      Identifier* ident;
      Expression defValue;

      void pushParameter()
      {
        params ~= set(new Parameter(stc, type, ident, defValue), paramBegin);
      }

      if (consumed(T.Ellipses))
      {
        stc = StorageClass.Variadic;
        pushParameter(); // type, ident and defValue will be null.
        break;
      }

      while (1)
      { // Parse storage classes.
        switch (token.kind)
        {
      version(D2)
      {
        case T.Invariant: // D2.0
          if (peekNext() == T.LParen)
            break;
          stc_ = StorageClass.Invariant;
          goto Lcommon;
        case T.Const: // D2.0
          if (peekNext() == T.LParen)
            break;
          stc_ = StorageClass.Const;
          goto Lcommon;
        case T.Final: // D2.0
          stc_ = StorageClass.Final;
          goto Lcommon;
        case T.Scope: // D2.0
          stc_ = StorageClass.Scope;
          goto Lcommon;
        case T.Static: // D2.0
          stc_ = StorageClass.Static;
          goto Lcommon;
      }
        case T.In:
          stc_ = StorageClass.In;
          goto Lcommon;
        case T.Out:
          stc_ = StorageClass.Out;
          goto Lcommon;
        case T.Inout, T.Ref:
          stc_ = StorageClass.Ref;
          goto Lcommon;
        case T.Lazy:
          stc_ = StorageClass.Lazy;
          goto Lcommon;
        Lcommon:
          // Check for redundancy.
          if (stc & stc_)
            error(MID.RedundantStorageClass, token.srcText);
          else
            stc |= stc_;
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
        stc |= StorageClass.Variadic;
        pushParameter();
        break;
      }
      pushParameter();

    } while (consumed(T.Comma))
    require(T.RParen);
    return set(params, begin);
  }

  TemplateArguments parseTemplateArguments()
  {
    TemplateArguments targs;
    require(T.LParen);
    if (token.kind != T.RParen)
      targs = parseTemplateArguments_();
    require(T.RParen);
    return targs;
  }

version(D2)
{
  TemplateArguments parseTemplateArguments2()
  {
    skip(T.Comma);
    TemplateArguments targs;
    if (token.kind != T.RParen)
      targs = parseTemplateArguments_();
    else
      error(token, MSG.ExpectedTypeOrExpression);
    require(T.RParen);
    return targs;
  }
} // version(D2)

  TemplateArguments parseTemplateArguments_()
  {
    auto begin = token;
    auto targs = new TemplateArguments;
    do
    {
      Type parseType_()
      {
        auto type = parseType();
        if (token.kind == T.Comma || token.kind == T.RParen)
          return type;
        errorCount++; // Cause try_() to fail.
        return null;
      }
      bool success;
      auto typeArgument = try_(&parseType_, success);
      if (success)
        // TemplateArgument:
        //         Type
        //         Symbol
        targs ~= typeArgument;
      else
        // TemplateArgument:
        //         AssignExpression
        targs ~= parseAssignExpression();
    } while (consumed(T.Comma))
    set(targs, begin);
    return targs;
  }

  TemplateParameters parseTemplateParameterList()
  {
    auto begin = token;
    auto tparams = new TemplateParameters;
    require(T.LParen);
    if (token.kind != T.RParen)
      parseTemplateParameterList_(tparams);
    require(T.RParen);
    return set(tparams, begin);
  }

version(D2)
{
  TemplateParameters parseTemplateParameterList2()
  {
    skip(T.Comma);
    auto begin = token;
    auto tparams = new TemplateParameters;
    if (token.kind != T.RParen)
      parseTemplateParameterList_(tparams);
    else
      error(token, MSG.ExpectedTemplateParameters);
    return set(tparams, begin);
  }
} // version(D2)

  /// Parses template parameters.
  void parseTemplateParameterList_(TemplateParameters tparams)
  {
    do
    {
      auto paramBegin = token;
      TemplateParameter tp;
      Identifier* ident;
      Type specType, defType;

      void parseSpecAndOrDefaultType()
      {
        // : SpecializationType
        if (consumed(T.Colon))
          specType = parseType();
        // = DefaultType
        if (consumed(T.Assign))
          defType = parseType();
      }

      switch (token.kind)
      {
      case T.Alias:
        // TemplateAliasParameter:
        //         alias Identifier
        skip(T.Alias);
        ident = requireIdentifier(MSG.ExpectedAliasTemplateParam);
        parseSpecAndOrDefaultType();
        tp = new TemplateAliasParameter(ident, specType, defType);
        break;
      case T.Identifier:
        ident = token.ident;
        switch (peekNext())
        {
        case T.Ellipses:
          // TemplateTupleParameter:
          //         Identifier ...
          skip(T.Identifier); skip(T.Ellipses);
          if (token.kind == T.Comma)
            error(MID.TemplateTupleParameter);
          tp = new TemplateTupleParameter(ident);
          break;
        case T.Comma, T.RParen, T.Colon, T.Assign:
          // TemplateTypeParameter:
          //         Identifier
          skip(T.Identifier);
          parseSpecAndOrDefaultType();
          tp = new TemplateTypeParameter(ident, specType, defType);
          break;
        default:
          // TemplateValueParameter:
          //         Declarator
          ident = null;
          goto LTemplateValueParameter;
        }
        break;
      version(D2)
      {
      case T.This:
        // TemplateThisParameter
        //         this TemplateTypeParameter
        skip(T.This);
        ident = requireIdentifier(MSG.ExpectedNameForThisTempParam);
        parseSpecAndOrDefaultType();
        tp = new TemplateThisParameter(ident, specType, defType);
        break;
      }
      default:
      LTemplateValueParameter:
        // TemplateValueParameter:
        //         Declarator
        Expression specValue, defValue;
        auto valueType = parseDeclarator(ident);
        // : SpecializationValue
        if (consumed(T.Colon))
          specValue = parseCondExpression();
        // = DefaultValue
        if (consumed(T.Assign))
          defValue = parseCondExpression();
        tp = new TemplateValueParameter(valueType, ident, specValue, defValue);
      }

      // Push template parameter.
      tparams ~= set(tp, paramBegin);

    } while (consumed(T.Comma))
  }

  alias require expected;

  /// Requires a token of kind tok.
  void require(TOK tok)
  {
    if (token.kind == tok)
      nT();
    else
      error(MID.ExpectedButFound, Token.toString(tok), token.srcText);
  }

  /// Requires the next token to be of kind tok.
  void requireNext(TOK tok)
  {
    nT();
    require(tok);
  }

  /// Optionally parses an identifier.
  /// Returns: null or the identifier.
  Identifier* optionalIdentifier()
  {
    Identifier* id;
    if (token.kind == T.Identifier)
      (id = token.ident), skip(T.Identifier);
    return id;
  }

  Identifier* requireIdentifier()
  {
    Identifier* id;
    if (token.kind == T.Identifier)
      (id = token.ident), skip(T.Identifier);
    else
      error(MID.ExpectedButFound, "Identifier", token.srcText);
    return id;
  }

  /// Reports an error if the current token is not an identifier.
  /// Params:
  ///   errorMsg = the error message to be used.
  /// Returns: null or the identifier.
  Identifier* requireIdentifier(char[] errorMsg)
  {
    Identifier* id;
    if (token.kind == T.Identifier)
      (id = token.ident), skip(T.Identifier);
    else
      error(token, errorMsg, token.srcText);
    return id;
  }

  /// Reports an error if the current token is not an identifier.
  /// Params:
  ///   mid = the error message ID to be used.
  /// Returns: null or the identifier.
  Identifier* requireIdentifier(MID mid)
  {
    Identifier* id;
    if (token.kind == T.Identifier)
      (id = token.ident), skip(T.Identifier);
    else
      error(mid, token.srcText);
    return id;
  }

  /// Reports an error if the current token is not an identifier.
  /// Returns: null or the token.
  Token* requireId()
  {
    Token* idtok;
    if (token.kind == T.Identifier)
      (idtok = token), skip(T.Identifier);
    else
      error(MID.ExpectedButFound, "Identifier", token.srcText);
    return idtok;
  }

  Token* requireIdToken(char[] errorMsg)
  {
    Token* idtok;
    if (token.kind == T.Identifier)
      (idtok = token), skip(T.Identifier);
    else
    {
      error(token, errorMsg, token.srcText);
      idtok = lexer.insertEmptyTokenBefore(token);
      this.prevToken = idtok;
    }
    return idtok;
  }

  /// Returns true if the string str has an invalid UTF-8 sequence.
  bool checkString(Token* begin, string str)
  {
    auto utf8Seq = Lexer.findInvalidUTF8Sequence(str);
    if (utf8Seq.length)
      error(begin, MSG.InvalidUTF8SequenceInString, utf8Seq);
    return utf8Seq.length != 0;
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

  /// Creates an error report and appends it to a list.
  /// Params:
  ///   token = used to get the location of where the error is.
  ///   formatMsg = the compiler error message.
  void error_(Token* token, char[] formatMsg, TypeInfo[] _arguments, Arg _argptr)
  {
    if (trying)
    {
      ++errorCount;
      return;
    }
    auto location = token.getErrorLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    auto error = new ParserError(location, msg);
    errors ~= error;
    if (infoMan !is null)
      infoMan ~= error;
  }
}
