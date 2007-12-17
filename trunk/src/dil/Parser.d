/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Parser;
import dil.Lexer;
import dil.SyntaxTree;
import dil.Token;
import dil.Messages;
import dil.Information;
import dil.Declarations;
import dil.Statements;
import dil.Expressions;
import dil.Types;
import dil.Enums;
import dil.CompilerInfo;
import dil.IdTable;
import common;

/++
  The Parser produces an abstract syntax tree (AST) by analyzing
  the tokens of the provided source code.
+/
class Parser
{
  Lexer lx;
  Token* token; /// Current non-whitespace token.
  Token* prevToken; /// Previous non-whitespace token.

  InformationManager infoMan;
  ParserError[] errors;

  ImportDeclaration[] imports; /// ImportDeclarations in the source text.

  LinkageType linkageType;
  Protection protection;
  StorageClass storageClass;
  uint alignSize = DEFAULT_ALIGN_SIZE;

  private alias TOK T;
  private alias TypeNode Type;

  /++
    Construct a Parser object.
    Params:
      text     = the UTF-8 source code.
      filePath = the path to the source code; used for error messages.
  +/
  this(char[] srcText, string filePath, InformationManager infoMan = null)
  {
    this.infoMan = infoMan;
    lx = new Lexer(srcText, filePath, infoMan);
  }

  protected void init()
  {
    nT();
    prevToken = token;
  }

  void nT()
  {
    prevToken = token;
    do
    {
      lx.nextToken();
      token = lx.token;
    } while (token.isWhitespace) // Skip whitespace
  }

  /++
    Start the parser and return the parsed Declarations.
  +/
  Declarations start()
  {
    init();
    auto begin = token;
    auto decls = new Declarations;
    if (token.type == T.Module)
      decls ~= parseModuleDeclaration();
    decls.addOptChildren(parseDeclarationDefinitions());
    set(decls, begin);
    return decls;
  }

  /++
    Start the parser and return the parsed Expression.
  +/
  Expression start2()
  {
    init();
    return parseExpression();
  }

  uint trying;
  uint errorCount;

  /++
    This method executes the delegate parseMethod and when an error occurred
    the state of the lexer and parser are restored.
  +/
  ReturnType try_(ReturnType)(ReturnType delegate() parseMethod, out bool success)
  {
    auto oldToken     = this.token;
    auto oldPrevToken = this.prevToken;
    auto oldCount     = this.errorCount;

    ++trying;
    auto result = parseMethod();
    --trying;
    // Check if an error occurred.
    if (errorCount != oldCount)
    {
      // Restore members.
      token      = oldToken;
      prevToken  = oldPrevToken;
      lx.token   = oldToken;
      errorCount = oldCount;
      success = false;
    }
    else
      success = true;
    return result;
  }

  /++
    Sets the begin and end tokens of an AST node.
  +/
  Class set(Class)(Class node, Token* begin)
  {
    node.setTokens(begin, this.prevToken);
    return node;
  }

  /++
    Returns true if set() has been called on a node.
  +/
  bool isNodeSet(Node node)
  {
    return node.begin !is null && node.end !is null;
  }

  TOK peekNext()
  {
    Token* next = token;
    do
      lx.peek(next);
    while (next.isWhitespace) // Skip whitespace
    return next.type;
  }

  TOK peekAfter(ref Token* next)
  {
    assert(next !is null);
    do
      lx.peek(next);
    while (next.isWhitespace) // Skip whitespace
    return next.type;
  }

  /++++++++++++++++++++++++++++++
  + Declaration parsing methods +
  ++++++++++++++++++++++++++++++/

  Declaration parseModuleDeclaration()
  {
    auto begin = token;
    ModuleFQN moduleFQN;
    do
    {
      nT();
      moduleFQN ~= requireIdentifier(MSG.ExpectedModuleIdentifier);
    } while (token.type == T.Dot)
    require(T.Semicolon);
    return set(new ModuleDeclaration(moduleFQN), begin);
  }

  /++
    Parse DeclarationDefinitions until the end of file is hit.
    DeclDefs:
      DeclDef
      DeclDefs
  +/
  Declaration[] parseDeclarationDefinitions()
  {
    Declaration[] decls;
    while (token.type != T.EOF)
      decls ~= parseDeclarationDefinition();
    return decls;
  }

  /++
    Parse the body of a template, class, interface, struct or union.
    DeclDefsBlock:
        { }
        { DeclDefs }
  +/
  Declarations parseDeclarationDefinitionsBody()
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
    auto decls = new Declarations;
    require(T.LBrace);
    while (token.type != T.RBrace && token.type != T.EOF)
      decls ~= parseDeclarationDefinition();
    require(T.RBrace);
    set(decls, begin);

    // Restore original values.
    this.linkageType  = linkageType;
    this.protection   = protection;
    this.storageClass = storageClass;

    return decls;
  }

  Declaration parseDeclarationDefinition()
  out(decl)
  { assert(isNodeSet(decl)); }
  body
  {
    auto begin = token;
    Declaration decl;
    switch (token.type)
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
      // TODO: parse StorageClasses?
      decl = new AliasDeclaration(parseVariableOrFunction());
      break;
    case T.Typedef:
      nT();
      // TODO: parse StorageClasses?
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
      imports ~= CastTo!(ImportDeclaration)(decl);
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
      decl = parseAggregateDeclaration();
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
    /+case T.Module:
      // TODO: Error: module is optional and can appear only once at the top of the source file.
      break;+/
    default:
      if (token.isIntegralType)
        goto case_Declaration;

      decl = new IllegalDeclaration();
      // Skip to next valid token.
      do
        nT();
      while (!token.isDeclDefStart &&
              token.type != T.RBrace &&
              token.type != T.EOF)
      auto text = Token.textSpan(begin, this.prevToken);
      error(begin, MSG.IllegalDeclaration ~ text);
    }
    decl.setProtection(this.protection);
    decl.setStorageClass(this.storageClass);
    assert(!isNodeSet(decl));
    set(decl, begin);
    return decl;
  }

  /++
    DeclarationsBlock:
        : DeclDefs
        { }
        { DeclDefs }
        DeclDef
  +/
  Declaration parseDeclarationsBlock(bool noColon = false)
  {
    Declaration d;
    switch (token.type)
    {
    case T.LBrace:
      auto begin = token;
      nT();
      auto decls = new Declarations;
      while (token.type != T.RBrace && token.type != T.EOF)
        decls ~= parseDeclarationDefinition();
      require(T.RBrace);
      d = set(decls, begin);
      break;
    case T.Colon:
      if (noColon == true)
        goto default;
      nT();
      auto begin = token;
      auto decls = new Declarations;
      while (token.type != T.RBrace && token.type != T.EOF)
        decls ~= parseDeclarationDefinition();
      d = set(decls, begin);
      break;
    default:
      d = parseDeclarationDefinition();
    }
    assert(isNodeSet(d));
    return d;
  }

  Declaration parseDeclarationsBlockNoColon()
  {
    return parseDeclarationsBlock(true);
  }

  /++
    Parses either a VariableDeclaration or a FunctionDeclaration.
    Params:
      stc = the previously parsed storage classes
      optionalParameterList = a hint for how to parse C-style function pointers
  +/
  Declaration parseVariableOrFunction(StorageClass stc = StorageClass.None,
                                      Protection protection = Protection.None,
                                      LinkageType linkType = LinkageType.None,
                                      bool testAutoDeclaration = false,
                                      bool optionalParameterList = true)
  {
    auto begin = token;
    Type type;
    Identifier* ident;

    // Check for AutoDeclaration: StorageClasses Identifier =
    if (testAutoDeclaration &&
        token.type == T.Identifier &&
        peekNext() == T.Assign)
    {
      ident = token.ident;
      nT();
    }
    else
    {
      type = parseType();
      if (token.type == T.LParen)
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
        type = parseCFunctionPointerType(type, ident, optionalParameterList);
      }
      else
      {
        ident = requireIdentifier(MSG.ExpectedFunctionName);
        // Type FunctionName ( ParameterList ) FunctionBody
        if (token.type == T.LParen)
        {
          // It's a function declaration
          TemplateParameters tparams;
          if (tokenAfterParenIs(T.LParen))
          {
            // ( TemplateParameterList ) ( ParameterList )
            tparams = parseTemplateParameterList();
          }

          auto params = parseParameterList();
        version(D2)
        {
          switch (token.type)
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
          auto d = new FunctionDeclaration(type, ident, tparams, params, funcBody);
          d.setStorageClass(stc);
          d.setLinkageType(linkType);
          d.setProtection(protection);
          return set(d, begin);
        }
        type = parseDeclaratorSuffix(type);
      }
    }

    // It's a variable declaration.
    Identifier*[] idents = [ident];
    Expression[] values;
    goto LenterLoop; // We've already parsed an identifier. Jump to if statement and check for initializer.
    while (token.type == T.Comma)
    {
      nT();
      idents ~= requireIdentifier(MSG.ExpectedVariableName);
    LenterLoop:
      if (token.type == T.Assign)
        nT(), (values ~= parseInitializer());
      else
        values ~= null;
    }
    require(T.Semicolon);
    auto d = new VariableDeclaration(type, idents, values);
    d.setStorageClass(stc);
    d.setLinkageType(linkType);
    d.setProtection(protection);
    return set(d, begin);
  }

  Expression parseInitializer()
  {
    if (token.type == T.Void)
    {
      auto begin = token;
      auto next = peekNext();
      if (next == T.Comma || next == T.Semicolon)
      {
        nT();
        return set(new VoidInitializer(), begin);
      }
    }
    return parseNonVoidInitializer();
  }

  Expression parseNonVoidInitializer()
  {
    auto begin = token;
    Expression init;
    switch (token.type)
    {
    case T.LBracket:
      // ArrayInitializer:
      //         [ ]
      //         [ ArrayMemberInitializations ]
      Expression[] keys;
      Expression[] values;

      nT();
      while (token.type != T.RBracket)
      {
        auto e = parseNonVoidInitializer();
        if (token.type == T.Colon)
        {
          nT();
          keys ~= e;
          values ~= parseNonVoidInitializer();
        }
        else
        {
          keys ~= null;
          values ~= e;
        }

        if (token.type != T.Comma)
          break;
        nT();
      }
      require(T.RBracket);
      init = new ArrayInitializer(keys, values);
      break;
    case T.LBrace:
      // StructInitializer:
      //         { }
      //         { StructMemberInitializers }
      Expression parseStructInitializer()
      {
        Identifier*[] idents;
        Expression[] values;

        nT();
        while (token.type != T.RBrace)
        {
          if (token.type == T.Identifier &&
              // Peek for colon to see if this is a member identifier.
              peekNext() == T.Colon)
          {
            idents ~= token.ident;
            nT(), nT(); // Skip Identifier :
          }
          else
            idents ~= null;

          // NonVoidInitializer
          values ~= parseNonVoidInitializer();

          if (token.type != T.Comma)
            break;
          nT();
        }
        require(T.RBrace);
        return new StructInitializer(idents, values);
      }

      bool success;
      auto si = try_(&parseStructInitializer, success);
      if (success)
      {
        init = si;
        break;
      }
      assert(token.type == T.LBrace);
      //goto default;
    default:
      init = parseAssignExpression();
    }
    set(init, begin);
    return init;
  }

  FunctionBody parseFunctionBody()
  {
    auto begin = token;
    auto func = new FunctionBody;
    while (1)
    {
      switch (token.type)
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
        if (token.type == T.LParen)
        {
          nT();
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
    if (token.type != T.LParen)
      return linkageType;

    nT(); // Skip (
    if (token.type == T.RParen)
    {
      nT();
      error(MID.MissingLinkageType);
      return linkageType;
    }

    auto identTok = requireId();

    ID identID = identTok ? identTok.ident.identID : ID.Null;

    switch (identID)
    {
    case ID.C:
      if (token.type == T.PlusPlus)
      {
        nT();
        linkageType = LinkageType.Cpp;
        break;
      }
      linkageType = LinkageType.C;
      break;
    case ID.D:
      linkageType = LinkageType.D;
      break;
    case ID.Windows:
      linkageType = LinkageType.Windows;
      break;
    case ID.Pascal:
      linkageType = LinkageType.Pascal;
      break;
    case ID.System:
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
      // TODO: create new msg RedundantLinkageType.
      error(begin, MSG.RedundantLinkageType ~ Token.textSpan(begin, this.prevToken));
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
      switch (token.type)
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

        auto tok = token.type;
        nT();
        decl = new StorageClassDeclaration(stc_tmp, tok, parse());
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
    assert(token.type == T.Align);
    nT(); // Skip align keyword.
    uint size = DEFAULT_ALIGN_SIZE; // Global default.
    if (token.type == T.LParen)
    {
      nT();
      if (token.type == T.Int32)
        (size = token.int_), nT();
      else
        expected(T.Int32);
      require(T.RParen);
    }
    return size;
  }

  Declaration parseAttributeSpecifier()
  {
    Declaration decl;

    switch (token.type)
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

      if (token.type == T.Comma)
        nT(), (args = parseExpressionList());
      require(T.RParen);

      decl = new PragmaDeclaration(ident, args, parseDeclarationsBlock());
      break;
    default:
      // Protection attributes
      Protection prot;
      switch (token.type)
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
    assert(token.type == T.Import || token.type == T.Static);

    bool isStatic;

    if (token.type == T.Static)
    {
      isStatic = true;
      nT();
    }

    assert(token.type == T.Import);

    ModuleFQN[] moduleFQNs;
    Identifier*[] moduleAliases;
    Identifier*[] bindNames;
    Identifier*[] bindAliases;

    nT(); // Skip import keyword.
    while (1)
    {
      ModuleFQN moduleFQN;
      Identifier* moduleAlias;

      // AliasName = ModuleName
      if (peekNext() == T.Assign)
      {
        moduleAlias = requireIdentifier(MSG.ExpectedAliasModuleName);
        nT(); // Skip =
      }

      // Identifier(.Identifier)*
      while (1)
      {
        moduleFQN ~= requireIdentifier(MSG.ExpectedModuleIdentifier);
        if (token.type != T.Dot)
          break;
        nT();
      }

      // Push identifiers.
      moduleFQNs ~= moduleFQN;
      moduleAliases ~= moduleAlias;

      if (token.type != T.Comma)
        break;
      nT();
    }

    if (token.type == T.Colon)
    {
      // BindAlias = BindName(, BindAlias = BindName)*;
      // BindName(, BindName)*;
      do
      {
        nT();
        Identifier* bindAlias;
        // BindAlias = BindName
        if (peekNext() == T.Assign)
        {
          bindAlias = requireIdentifier(MSG.ExpectedAliasImportName);
          nT(); // Skip =
        }
        // Push identifiers.
        bindNames ~= requireIdentifier(MSG.ExpectedImportName);
        bindAliases ~= bindAlias;
      } while (token.type == T.Comma)
    }

    require(T.Semicolon);

    return new ImportDeclaration(moduleFQNs, moduleAliases, bindNames, bindAliases, isStatic);
  }

  Declaration parseEnumDeclaration()
  {
    assert(token.type == T.Enum);

    Identifier* enumName;
    Type baseType;
    EnumMember[] members;
    bool hasBody;

    nT(); // Skip enum keyword.

    enumName = optionalIdentifier();

    if (token.type == T.Colon)
    {
      nT();
      baseType = parseBasicType();
    }

    if (token.type == T.Semicolon)
    {
      if (enumName is null)
        expected(T.Identifier);
      nT();
    }
    else if (token.type == T.LBrace)
    {
      hasBody = true;
      nT(); // Skip {
      while (token.type != T.RBrace)
      {
        auto begin = token;
        auto name = requireIdentifier(MSG.ExpectedEnumMember);
        Expression value;

        if (token.type == T.Assign)
          nT(), (value = parseAssignExpression());
        else
          value = null;

        members ~= set(new EnumMember(name, value), begin);

        if (token.type != T.Comma)
          break;
        nT(); // Skip ,
      }
      require(T.RBrace);
    }
    else
      error(token, MSG.ExpectedEnumBody, token.srcText);

    return new EnumDeclaration(enumName, baseType, members, hasBody);
  }

  Declaration parseClassDeclaration()
  {
    assert(token.type == T.Class);

    Identifier* className;
    TemplateParameters tparams;
    BaseClass[] bases;
    Declarations decls;

    nT(); // Skip class keyword.
    className = requireIdentifier(MSG.ExpectedClassName);

    if (token.type == T.LParen)
      tparams = parseTemplateParameterList();

    if (token.type == T.Colon)
      bases = parseBaseClasses();

    if (token.type == T.Semicolon)
    {
      if (bases.length != 0)
        error(MID.BaseClassInForwardDeclaration);
      nT();
    }
    else if (token.type == T.LBrace)
      decls = parseDeclarationDefinitionsBody();
    else
      error(token, MSG.ExpectedClassBody, token.srcText);

    return new ClassDeclaration(className, tparams, bases, decls);
  }

  BaseClass[] parseBaseClasses(bool colonLeadsOff = true)
  {
    if (colonLeadsOff)
    {
      assert(token.type == T.Colon);
      nT(); // Skip colon
    }

    BaseClass[] bases;

    while (1)
    {
      Protection prot = Protection.Public;
      switch (token.type)
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
      //if (type.tid != TID.DotList)
        // TODO: issue error msg. base classes can only be one or more identifiers or template instances separated by dots.
      bases ~= set(new BaseClass(prot, type), begin);
      if (token.type != T.Comma)
        break;
      nT();
    }
    return bases;
  }

  Declaration parseInterfaceDeclaration()
  {
    assert(token.type == T.Interface);

    Identifier* name;
    TemplateParameters tparams;
    BaseClass[] bases;
    Declarations decls;

    nT(); // Skip interface keyword.
    name = requireIdentifier(MSG.ExpectedInterfaceName);

    if (token.type == T.LParen)
      tparams = parseTemplateParameterList();

    if (token.type == T.Colon)
      bases = parseBaseClasses();

    if (token.type == T.Semicolon)
    {
      if (bases.length != 0)
        error(MID.BaseClassInForwardDeclaration);
      nT();
    }
    else if (token.type == T.LBrace)
      decls = parseDeclarationDefinitionsBody();
    else
      error(token, MSG.ExpectedInterfaceBody, token.srcText);

    return new InterfaceDeclaration(name, tparams, bases, decls);
  }

  Declaration parseAggregateDeclaration()
  {
    assert(token.type == T.Struct || token.type == T.Union);

    TOK tok = token.type;

    Identifier* name;
    TemplateParameters tparams;
    Declarations decls;

    nT(); // Skip struct or union keyword.

    name = optionalIdentifier();

    if (name && token.type == T.LParen)
      tparams = parseTemplateParameterList();

    if (token.type == T.Semicolon)
    {
      //if (name.length == 0)
        // TODO: error: forward declarations must have a name.
      nT();
    }
    else if (token.type == T.LBrace)
      decls = parseDeclarationDefinitionsBody();
    else
      expected(T.LBrace); // TODO: better error msg

    if (tok == T.Struct)
    {
      auto sd = new StructDeclaration(name, tparams, decls);
      sd.setAlignSize(this.alignSize);
      return sd;
    }
    else
      return new UnionDeclaration(name, tparams, decls);
  }

  Declaration parseConstructorDeclaration()
  {
    assert(token.type == T.This);
    nT(); // Skip 'this' keyword.
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new ConstructorDeclaration(parameters, funcBody);
  }

  Declaration parseDestructorDeclaration()
  {
    assert(token.type == T.Tilde);
    nT(); // Skip ~
    require(T.This);
    require(T.LParen);
    require(T.RParen);
    auto funcBody = parseFunctionBody();
    return new DestructorDeclaration(funcBody);
  }

  Declaration parseStaticConstructorDeclaration()
  {
    assert(token.type == T.Static);
    nT(); // Skip static keyword.
    nT(); // Skip 'this' keyword.
    require(T.LParen);
    require(T.RParen);
    auto funcBody = parseFunctionBody();
    return new StaticConstructorDeclaration(funcBody);
  }

  Declaration parseStaticDestructorDeclaration()
  {
    assert(token.type == T.Static);
    nT(); // Skip static keyword.
    nT(); // Skip ~
    require(T.This);
    require(T.LParen);
    require(T.RParen);
    auto funcBody = parseFunctionBody();
    return new StaticDestructorDeclaration(funcBody);
  }

  Declaration parseInvariantDeclaration()
  {
    assert(token.type == T.Invariant);
    nT(); // Skip invariant keyword.
    // Optional () for getting ready porting to D 2.0
    if (token.type == T.LParen)
      requireNext(T.RParen);
    auto funcBody = parseFunctionBody();
    return new InvariantDeclaration(funcBody);
  }

  Declaration parseUnittestDeclaration()
  {
    assert(token.type == T.Unittest);

    nT(); // Skip unittest keyword.
    auto funcBody = parseFunctionBody();
    return new UnittestDeclaration(funcBody);
  }

  Token* parseIdentOrInt()
  {
    if (token.type == T.Int32 ||
        token.type == T.Identifier)
    {
      auto token = this.token;
      nT();
      return token;
    }
    else
      error(token, MSG.ExpectedIdentOrInt, token.srcText);
    return null;
  }

  Declaration parseDebugDeclaration()
  {
    assert(token.type == T.Debug);
    nT(); // Skip debug keyword.

    Token* spec;
    Token* cond;
    Declaration decls, elseDecls;

    if (token.type == T.Assign)
    { // debug = Integer ;
      // debug = Identifier ;
      nT();
      spec = parseIdentOrInt();
      require(T.Semicolon);
    }
    else
    { // ( Condition )
      if (token.type == T.LParen)
      {
        nT();
        cond = parseIdentOrInt();
        require(T.RParen);
      }
      // debug DeclarationsBlock
      // debug ( Condition ) DeclarationsBlock
      decls = parseDeclarationsBlockNoColon();
      // else DeclarationsBlock
      if (token.type == T.Else)
        nT(), (elseDecls = parseDeclarationsBlockNoColon());
    }

    return new DebugDeclaration(spec, cond, decls, elseDecls);
  }

  Declaration parseVersionDeclaration()
  {
    assert(token.type == T.Version);
    nT(); // Skip version keyword.

    Token* spec;
    Token* cond;
    Declaration decls, elseDecls;

    if (token.type == T.Assign)
    { // version = Integer ;
      // version = Identifier ;
      nT();
      spec = parseIdentOrInt();
      require(T.Semicolon);
    }
    else
    { // ( Condition )
      require(T.LParen);
      cond = parseIdentOrInt();
      require(T.RParen);
      // version ( Condition ) DeclarationsBlock
      decls = parseDeclarationsBlockNoColon();
      // else DeclarationsBlock
      if (token.type == T.Else)
        nT(), (elseDecls = parseDeclarationsBlockNoColon());
    }

    return new VersionDeclaration(spec, cond, decls, elseDecls);
  }

  Declaration parseStaticIfDeclaration()
  {
    assert(token.type == T.Static);

    nT(); // Skip static keyword.
    nT(); // Skip if keyword.

    Expression condition;
    Declaration ifDecls, elseDecls;

    require(T.LParen);
    condition = parseAssignExpression();
    require(T.RParen);

    ifDecls = parseDeclarationsBlockNoColon();

    if (token.type == T.Else)
    {
      nT();
      elseDecls = parseDeclarationsBlockNoColon();
    }

    return new StaticIfDeclaration(condition, ifDecls, elseDecls);
  }

  Declaration parseStaticAssertDeclaration()
  {
    assert(token.type == T.Static);

    nT(); // Skip static keyword.
    nT(); // Skip assert keyword.

    Expression condition, message;

    require(T.LParen);

    condition = parseAssignExpression();

    if (token.type == T.Comma)
    {
      nT();
      message = parseAssignExpression();
    }

    require(T.RParen);
    require(T.Semicolon);

    return new StaticAssertDeclaration(condition, message);
  }

  Declaration parseTemplateDeclaration()
  {
    assert(token.type == T.Template);
    nT(); // Skip template keyword.
    auto templateName = requireIdentifier(MSG.ExpectedTemplateName);
    auto templateParams = parseTemplateParameterList();
    auto decls = parseDeclarationDefinitionsBody();
    return new TemplateDeclaration(templateName, templateParams, decls);
  }

  Declaration parseNewDeclaration()
  {
    assert(token.type == T.New);
    nT(); // Skip new keyword.
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody();
    return new NewDeclaration(parameters, funcBody);
  }

  Declaration parseDeleteDeclaration()
  {
    assert(token.type == T.Delete);
    nT(); // Skip delete keyword.
    auto parameters = parseParameterList();
    // TODO: only one parameter of type void* allowed. Check in parsing or semantic phase?
    auto funcBody = parseFunctionBody();
    return new DeleteDeclaration(parameters, funcBody);
  }

  Type parseTypeofType()
  {
    assert(token.type == T.Typeof);
    Type type;
    requireNext(T.LParen);
    switch (token.type)
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
    return type;
  }

  /+
    DotListExpression:
            . DotListItems
            DotListItems
            Typeof
            Typeof . DotListItems
    DotListItems:
            DotListItem
            DotListItem . DotListItems
    DotListItem:
            Identifier
            TemplateInstance
            NewExpression
    TemplateInstance:
            Identifier !( TemplateArguments )
  +/
  DotListExpression parseDotListExpression()
  {
    assert(token.type == T.Identifier || token.type == T.Dot || token.type == T.Typeof);
    auto begin = token;
    Expression[] identList;
    if (token.type == T.Dot)
    {
      nT();
      identList ~= set(new DotExpression(), begin);
    }
    else if (token.type == T.Typeof)
    {
      auto type = parseTypeofType();
      set(type, begin);
      identList ~= set(new TypeofExpression(type), begin);
      if (token.type != T.Dot)
        goto Lreturn;
      nT();
    }

    while (1)
    {
      begin = token;
      auto ident = requireIdentifier(MSG.ExpectedAnIdentifier);
      Expression e;
      if (token.type == T.Not && peekNext() == T.LParen) // Identifier !( TemplateArguments )
      {
        nT(); // Skip !.
        auto tparams = parseTemplateArguments();
        e = new TemplateInstanceExpression(ident, tparams);
      }
      else // Identifier
        e = new IdentifierExpression(ident);

      identList ~= set(e, begin);

    LnewExpressionLoop:
      if (token.type != T.Dot)
        break;
      nT(); // Skip dot.

      if (token.type == T.New)
      {
        identList ~= parseNewExpression();
        goto LnewExpressionLoop;
      }
    }

  Lreturn:
    return new DotListExpression(identList);
  }

  /+
    DotListType:
            . TypeItems
            TypeItems
            Typeof
            Typeof . TypeItems
    TypeItems:
            TypeItem
            TypeItem . TypeItems
    TypeItem:
            Identifier
            TemplateInstance
    TemplateInstance:
            Identifier !( TemplateArguments )
  +/
  DotListType parseDotListType()
  {
    auto begin = token;
    Type[] identList;
    if (token.type == T.Dot)
    {
      nT();
      identList ~= set(new DotType(), begin);
    }
    else if (token.type == T.Typeof)
    {
      identList ~= set(parseTypeofType(), begin);
      if (token.type != T.Dot)
        goto Lreturn;
      nT();
    }

    while (1)
    {
      begin = token;
      auto ident = requireIdentifier(MSG.ExpectedAnIdentifier);
      Type t;
      // NB.: Currently Types can't be followed by "!=" so we don't need to peek for "(" when parsing TemplateInstances.
      if (token.type == T.Not/+ && peekNext() == T.LParen+/) // Identifier !( TemplateArguments )
      {
        nT(); // Skip !.
        t = new TemplateInstanceType(ident, parseTemplateArguments());
      }
      else // Identifier
        t = new IdentifierType(ident);

      identList ~= set(t, begin);

      if (token.type != T.Dot)
        break;
      nT();
    }
  Lreturn:
    return new DotListType(identList);
  }

  /*
    TemplateMixin:
            mixin ( AssignExpression ) ;
            mixin TemplateIdentifier ;
            mixin TemplateIdentifier MixinIdentifier ;
            mixin TemplateIdentifier !( TemplateArguments ) ;
            mixin TemplateIdentifier !( TemplateArguments ) MixinIdentifier ;
  */
  Class parseMixin(Class)()
  {
    assert(token.type == T.Mixin);
    nT(); // Skip mixin keyword.

  static if (is(Class == MixinDeclaration))
  {
    if (token.type == T.LParen)
    {
      // TODO: What about mixin(...).ident;?
      nT();
      auto e = parseAssignExpression();
      require(T.RParen);
      require(T.Semicolon);
      return new MixinDeclaration(e);
    }
  }

    auto begin = token;
    Expression[] templateIdent;
    Identifier* mixinIdent;

    // This code is similar to parseDotListType().
    if (token.type == T.Dot)
    {
      nT();
      templateIdent ~= set(new DotExpression(), begin);
    }

    while (1)
    {
      begin = token;
      auto ident = requireIdentifier(MSG.ExpectedAnIdentifier);
      Expression e;
      if (token.type == T.Not) // Identifier !( TemplateArguments )
      {
        // No need to peek for T.LParen. This must be a template instance.
        nT();
        auto tparams = parseTemplateArguments();
        e = new TemplateInstanceExpression(ident, tparams);
      }
      else // Identifier
        e = new IdentifierExpression(ident);

      templateIdent ~= set(e, begin);

      if (token.type != T.Dot)
        break;
      nT();
    }

    mixinIdent = optionalIdentifier();
    require(T.Semicolon);

    return new Class(templateIdent, mixinIdent);
  }

  /+++++++++++++++++++++++++++++
  + Statement parsing methods  +
  +++++++++++++++++++++++++++++/

  Statements parseStatements()
  {
    auto begin = token;
    require(T.LBrace);
    auto statements = new Statements();
    while (token.type != T.RBrace && token.type != T.EOF)
      statements ~= parseStatement();
    require(T.RBrace);
    return set(statements, begin);
  }

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

    switch (token.type)
    {
    case T.Align:
      uint size = parseAlignAttribute();
      // Restrict align attribute to structs in parsing phase.
      StructDeclaration structDecl;
      if (token.type == T.Struct)
      {
        auto begin2 = token;
        structDecl = CastTo!(StructDeclaration)(parseAggregateDeclaration());
        structDecl.setAlignSize(size);
        set(structDecl, begin2);
      }
      else
        expected(T.Struct);

      d = new AlignDeclaration(size, structDecl ? cast(Declaration)structDecl : new Declarations);
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
        nT(), nT(); // Skip Identifier :
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
      s = parseAsmStatement();
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
      d = parseAggregateDeclaration();
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
    /+
      Parse ExpressionStatement:
    +/
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

      if (token.type != T.Dollar)
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
              token.type != T.RBrace &&
              token.type != T.EOF)
      auto text = Token.textSpan(begin, this.prevToken);
      error(begin, MSG.IllegalStatement ~ text);
    }
    assert(s !is null);
    set(s, begin);
    return s;
  }

  /++
    ScopeStatement:
        NoScopeStatement
  +/
  Statement parseScopeStatement()
  {
    return new ScopeStatement(parseNoScopeStatement());
  }

  /++
    NoScopeStatement:
        NonEmptyStatement
        BlockStatement
    BlockStatement:
        { }
        { StatementList }
  +/
  Statement parseNoScopeStatement()
  {
    auto begin = token;
    Statement s;
    if (token.type == T.LBrace)
    {
      nT();
      auto ss = new Statements();
      while (token.type != T.RBrace && token.type != T.EOF)
        ss ~= parseStatement();
      require(T.RBrace);
      s = set(ss, begin);
    }
    else if (token.type == T.Semicolon)
    {
      error(token, MSG.ExpectedNonEmptyStatement);
      nT();
      s = set(new EmptyStatement(), begin);
    }
    else
      s = parseStatement();
    return s;
  }

  /++
    NoScopeOrEmptyStatement:
        ;
        NoScopeStatement
  +/
  Statement parseNoScopeOrEmptyStatement()
  {
    if (token.type == T.Semicolon)
    {
      auto begin = token;
      nT();
      return set(new EmptyStatement(), begin);
    }
    else
      return parseNoScopeStatement();
  }

  Statement parseAttributeStatement()
  {
    StorageClass stc, stc_tmp;
    LinkageType prev_linkageType;

    // Nested function.
    Declaration parse()
    {
      auto begin = token;
      Declaration d;
      switch (token.type)
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

        auto tok = token.type;
        nT();
        d = new StorageClassDeclaration(stc_tmp, tok, parse());
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
    assert(token.type == T.If);
    nT();

    Statement variable;
    Expression condition;
    Statement ifBody, elseBody;

    require(T.LParen);

    Identifier* ident;
    auto begin = token; // For start of AutoDeclaration or normal Declaration.
    // auto Identifier = Expression
    if (token.type == T.Auto)
    {
      nT();
      ident = requireIdentifier(MSG.ExpectedVariableName);
      require(T.Assign);
      auto init = parseExpression();
      auto v = new VariableDeclaration(null, [ident], [init]);
      set(v, begin.nextNWS);
      auto d = new StorageClassDeclaration(StorageClass.Auto, T.Auto, v);
      set(d, begin);
      variable = new DeclarationStatement(d);
      set(variable, begin);
    }
    else
    {
      // Declarator = Expression
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
        auto v = new VariableDeclaration(type, [ident], [init]);
        set(v, begin);
        variable = new DeclarationStatement(v);
        set(variable, begin);
      }
      else
        condition = parseExpression();
    }
    require(T.RParen);
    ifBody = parseScopeStatement();
    if (token.type == T.Else)
    {
      nT();
      elseBody = parseScopeStatement();
    }
    return new IfStatement(variable, condition, ifBody, elseBody);
  }

  Statement parseWhileStatement()
  {
    assert(token.type == T.While);
    nT();
    require(T.LParen);
    auto condition = parseExpression();
    require(T.RParen);
    return new WhileStatement(condition, parseScopeStatement());
  }

  Statement parseDoWhileStatement()
  {
    assert(token.type == T.Do);
    nT();
    auto doBody = parseScopeStatement();
    require(T.While);
    require(T.LParen);
    auto condition = parseExpression();
    require(T.RParen);
    return new DoWhileStatement(condition, doBody);
  }

  Statement parseForStatement()
  {
    assert(token.type == T.For);
    nT();
    require(T.LParen);

    Statement init, forBody;
    Expression condition, increment;

    if (token.type != T.Semicolon)
      init = parseNoScopeStatement();
    else
      nT(); // Skip ;
    if (token.type != T.Semicolon)
      condition = parseExpression();
    require(T.Semicolon);
    if (token.type != T.RParen)
      increment = parseExpression();
    require(T.RParen);
    forBody = parseScopeStatement();
    return new ForStatement(init, condition, increment, forBody);
  }

  Statement parseForeachStatement()
  {
    assert(token.type == T.Foreach || token.type == T.Foreach_reverse);
    TOK tok = token.type;
    nT();

    auto params = new Parameters;
    Expression e; // Aggregate or LwrExpression

    require(T.LParen);
    while (1)
    {
      auto paramBegin = token;
      StorageClass stc;
      Type type;
      Identifier* ident;

      switch (token.type)
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

      if (token.type != T.Comma)
        break;
      nT();
    }
    require(T.Semicolon);
    e = parseExpression();
  version(D2)
  { //Foreach (ForeachType; LwrExpression .. UprExpression ) ScopeStatement
    if (token.type == T.Slice)
    {
      // if (params.length != 1)
        // error(MID.XYZ); // TODO: issue error msg
      nT();
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
    assert(token.type == T.Switch);
    nT();

    require(T.LParen);
    auto condition = parseExpression();
    require(T.RParen);
    auto switchBody = parseScopeStatement();
    return new SwitchStatement(condition, switchBody);
  }

  /++
    Helper function for parsing the body of
    a default or case statement.
  +/
  Statement parseCaseOrDefaultBody()
  {
    // This function is similar to parseNoScopeStatement()
    auto begin = token;
    auto s = new Statements();
    while (token.type != T.Case &&
           token.type != T.Default &&
           token.type != T.RBrace &&
           token.type != T.EOF)
      s ~= parseStatement();
    return set(new ScopeStatement(s), begin);
  }

  Statement parseCaseStatement()
  {
    assert(token.type == T.Case);
    nT();
    auto values = parseExpressionList();
    require(T.Colon);
    auto caseBody = parseCaseOrDefaultBody();
    return new CaseStatement(values, caseBody);
  }

  Statement parseDefaultStatement()
  {
    assert(token.type == T.Default);
    nT();
    require(T.Colon);
    auto defaultBody = parseCaseOrDefaultBody();
    return new DefaultStatement(defaultBody);
  }

  Statement parseContinueStatement()
  {
    assert(token.type == T.Continue);
    nT();
    auto ident = optionalIdentifier();
    require(T.Semicolon);
    return new ContinueStatement(ident);
  }

  Statement parseBreakStatement()
  {
    assert(token.type == T.Break);
    nT();
    auto ident = optionalIdentifier();
    return new BreakStatement(ident);
  }

  Statement parseReturnStatement()
  {
    assert(token.type == T.Return);
    nT();
    Expression expr;
    if (token.type != T.Semicolon)
      expr = parseExpression();
    require(T.Semicolon);
    return new ReturnStatement(expr);
  }

  Statement parseGotoStatement()
  {
    assert(token.type == T.Goto);
    nT();
    Identifier* ident;
    Expression caseExpr;
    switch (token.type)
    {
    case T.Case:
      nT();
      if (token.type == T.Semicolon)
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

  Statement parseWithStatement()
  {
    assert(token.type == T.With);
    nT();
    require(T.LParen);
    auto expr = parseExpression();
    require(T.RParen);
    return new WithStatement(expr, parseScopeStatement());
  }

  Statement parseSynchronizedStatement()
  {
    assert(token.type == T.Synchronized);
    nT();
    Expression expr;

    if (token.type == T.LParen)
    {
      nT();
      expr = parseExpression();
      require(T.RParen);
    }
    return new SynchronizedStatement(expr, parseScopeStatement());
  }

  Statement parseTryStatement()
  {
    assert(token.type == T.Try);
    nT();

    auto tryBody = parseScopeStatement();
    CatchBody[] catchBodies;
    FinallyBody finBody;

    while (token.type == T.Catch)
    {
      nT();
      Parameter param;
      if (token.type == T.LParen)
      {
        nT();
        auto begin = token;
        Identifier* ident;
        auto type = parseDeclarator(ident, true);
        param = new Parameter(StorageClass.None, type, ident, null);
        set(param, begin);
        require(T.RParen);
      }
      catchBodies ~= new CatchBody(param, parseNoScopeStatement());
      if (param is null)
        break; // This is a LastCatch
    }

    if (token.type == T.Finally)
    {
      auto begin = token;
      nT();
      finBody = new FinallyBody(parseNoScopeStatement());
      set(finBody, begin);
    }

    if (catchBodies.length == 0 && finBody is null)
    {
      // TODO: issue error msg.
    }

    return new TryStatement(tryBody, catchBodies, finBody);
  }

  Statement parseThrowStatement()
  {
    assert(token.type == T.Throw);
    nT();
    auto expr = parseExpression();
    require(T.Semicolon);
    return new ThrowStatement(expr);
  }

  Statement parseScopeGuardStatement()
  {
    assert(token.type == T.Scope);
    nT();
    assert(token.type == T.LParen);
    nT();
    auto condition = requireIdentifier(MSG.ExpectedScopeIdentifier);
    if (condition)
      switch (condition.identID)
      {
      case ID.exit, ID.success, ID.failure:
        break;
      default:
        // TODO: create MID.InvalidScopeIdentifier
        error(this.prevToken, MSG.InvalidScopeIdentifier, this.prevToken.srcText);
      }
    require(T.RParen);
    Statement scopeBody;
    if (token.type == T.LBrace)
      scopeBody = parseScopeStatement();
    else
      scopeBody = parseNoScopeStatement();
    return new ScopeGuardStatement(condition, scopeBody);
  }

  Statement parseVolatileStatement()
  {
    assert(token.type == T.Volatile);
    nT();
    Statement volatileBody;
    if (token.type == T.Semicolon)
      nT();
    else if (token.type == T.LBrace)
      volatileBody = parseScopeStatement();
    else
      volatileBody = parseStatement();
    return new VolatileStatement(volatileBody);
  }

  Statement parsePragmaStatement()
  {
    assert(token.type == T.Pragma);
    nT();

    Identifier* ident;
    Expression[] args;
    Statement pragmaBody;

    require(T.LParen);
    ident = requireIdentifier(MSG.ExpectedPragmaIdentifier);

    if (token.type == T.Comma)
    {
      nT();
      args = parseExpressionList();
    }
    require(T.RParen);

    pragmaBody = parseNoScopeOrEmptyStatement();

    return new PragmaStatement(ident, args, pragmaBody);
  }

  Statement parseStaticIfStatement()
  {
    assert(token.type == T.Static);
    nT();
    assert(token.type == T.If);
    nT();
    Expression condition;
    Statement ifBody, elseBody;

    require(T.LParen);
    condition = parseExpression();
    require(T.RParen);
    ifBody = parseNoScopeStatement();
    if (token.type == T.Else)
    {
      nT();
      elseBody = parseNoScopeStatement();
    }
    return new StaticIfStatement(condition, ifBody, elseBody);
  }

  Statement parseStaticAssertStatement()
  {
    assert(token.type == T.Static);
    nT();
    assert(token.type == T.Assert);
    nT();
    Expression condition, message;
    require(T.LParen);
    condition = parseAssignExpression();
    if (token.type == T.Comma)
    {
      nT();
      message = parseAssignExpression();
    }
    require(T.RParen);
    require(T.Semicolon);
    return new StaticAssertStatement(condition, message);
  }

  Statement parseDebugStatement()
  {
    assert(token.type == T.Debug);
    nT(); // Skip debug keyword.

    Token* cond;
    Statement debugBody, elseBody;

    // ( Condition )
    if (token.type == T.LParen)
    {
      nT();
      cond = parseIdentOrInt();
      require(T.RParen);
    }
    // debug Statement
    // debug ( Condition ) Statement
    debugBody = parseNoScopeStatement();
    // else Statement
    if (token.type == T.Else)
      nT(), (elseBody = parseNoScopeStatement());

    return new DebugStatement(cond, debugBody, elseBody);
  }

  Statement parseVersionStatement()
  {
    assert(token.type == T.Version);
    nT(); // Skip version keyword.

    Token* cond;
    Statement versionBody, elseBody;

    // ( Condition )
    require(T.LParen);
    cond = parseIdentOrInt();
    require(T.RParen);
    // version ( Condition ) Statement
    versionBody = parseNoScopeStatement();
    // else Statement
    if (token.type == T.Else)
      nT(), (elseBody = parseNoScopeStatement());

    return new VersionStatement(cond, versionBody, elseBody);
  }

  /+++++++++++++++++++++++++++++
  + Assembler parsing methods  +
  +++++++++++++++++++++++++++++/

  Statement parseAsmStatement()
  {
    assert(token.type == T.Asm);
    nT(); // Skip asm keyword.
    require(T.LBrace);
    auto ss = new Statements;
    while (token.type != T.RBrace && token.type != T.EOF)
      ss ~= parseAsmInstruction();
    require(T.RBrace);
    return new AsmStatement(ss);
  }

  Statement parseAsmInstruction()
  {
    auto begin = token;
    Statement s;
    Identifier* ident;
    switch (token.type)
    {
    // Keywords that are valid opcodes.
    case T.In, T.Int, T.Out:
      ident = token.ident;
      nT();
      goto LOpcode;
    case T.Identifier:
      ident = token.ident;
      nT(); // Skip Identifier
      if (token.type == T.Colon)
      {
        // Identifier : AsmInstruction
        nT(); // Skip :
        s = new LabeledStatement(ident, parseAsmInstruction());
        break;
      }

    LOpcode:
      // Opcode ;
      // Opcode Operands ;
      // Opcode
      //     Identifier
      Expression[] es;
      if (token.type != T.Semicolon)
      {
        while (1)
        {
          es ~= parseAsmExpression();
          if (token.type != T.Comma)
            break;
          nT();
        }
      }
      require(T.Semicolon);
      s = new AsmInstruction(ident, es);
      break;
    case T.Align:
      // align Integer;
      nT();
      int number = -1;
      if (token.type == T.Int32)
        (number = token.int_), nT();
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
      s = new IllegalAsmInstruction();
      // Skip to next valid token.
      do
        nT();
      while (!token.isAsmInstructionStart &&
              token.type != T.RBrace &&
              token.type != T.EOF)
      auto text = Token.textSpan(begin, this.prevToken);
      error(begin, MSG.IllegalAsmInstructino ~ text);
    }
    set(s, begin);
    return s;
  }

  Expression parseAsmExpression()
  {
    auto begin = token;
    auto e = parseAsmOrOrExpression();
    if (token.type == T.Question)
    {
      auto tok = token;
      nT();
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
    while (token.type == T.OrLogical)
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
    while (token.type == T.AndLogical)
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
    while (token.type == T.OrBinary)
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
    while (token.type == T.Xor)
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
    while (token.type == T.AndBinary)
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
    switch (operator.type)
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
      switch (operator.type)
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
      switch (operator.type)
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
      switch (operator.type)
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
    while (token.type == T.LBracket)
    {
      nT();
      e = parseAsmExpression();
      e = new AsmPostBracketExpression(e);
      require(T.RBracket);
      set(e, begin);
    }
    return e;
  }

  Expression parseAsmUnaryExpression()
  {
    auto begin = token;
    Expression e;
    switch (token.type)
    {
    case T.Byte,  T.Short,  T.Int,
         T.Float, T.Double, T.Real:
      goto LAsmTypePrefix;
    case T.Identifier:
      switch (token.ident.identID)
      {
      case ID.near, ID.far,/* "byte",  "short",  "int",*/
           ID.word, ID.dword, ID.qword/*, "float", "double", "real"*/:
      LAsmTypePrefix:
        nT();
        if (token.type == T.Identifier && token.ident is Ident.ptr)
          nT();
        else
          error(MID.ExpectedButFound, "ptr", token.srcText);
        e = new AsmTypeExpression(parseAsmExpression());
        break;
      case ID.offset:
        nT();
        e = new AsmOffsetExpression(parseAsmExpression());
        break;
      case ID.seg:
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
    switch (token.type)
    {
    case T.Int32, T.Int64, T.Uint32, T.Uint64:
      e = new IntExpression(token.type, token.ulong_);
      nT();
      break;
    case T.Float32, T.Float64, T.Float80,
         T.Imaginary32, T.Imaginary64, T.Imaginary80:
      e = new RealExpression(token.type, token.real_);
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
      switch (register.identID)
      {
      // __LOCAL_SIZE
      case ID.__LOCAL_SIZE:
        nT();
        e = new AsmLocalSizeExpression();
        break;
      // Register
      case ID.ST:
        nT();
        // (1) - (7)
        int number = -1;
        if (token.type == T.LParen)
        {
          nT();
          if (token.type == T.Int32)
            (number = token.int_), nT();
          else
            expected(T.Int32);
          require(T.RParen);
        }
        e = new AsmRegisterExpression(register, number);
        break;
      case ID.FS:
        nT();
        // TODO: is the colon-number part optional?
        int number = -1;
        if (token.type == T.Colon)
        {
          // :0, :4, :8
          nT();
          if (token.type == T.Int32)
            (number = token.int_), nT();
          if (number != 0 && number != 4 && number != 8)
            error(MID.ExpectedButFound, "0, 4 or 8", token.srcText);
        }
        e = new AsmRegisterExpression(register, number);
        break;
      case ID.AL, ID.AH, ID.AX, ID.EAX,
           ID.BL, ID.BH, ID.BX, ID.EBX,
           ID.CL, ID.CH, ID.CX, ID.ECX,
           ID.DL, ID.DH, ID.DX, ID.EDX,
           ID.BP, ID.EBP, ID.SP, ID.ESP,
           ID.DI, ID.EDI, ID.SI, ID.ESI,
           ID.ES, ID.CS, ID.SS, ID.DS, ID.GS,
           ID.CR0, ID.CR2, ID.CR3, ID.CR4,
           ID.DR0, ID.DR1, ID.DR2, ID.DR3, ID.DR6, ID.DR7,
           ID.TR3, ID.TR4, ID.TR5, ID.TR6, ID.TR7,
           ID.MM0, ID.MM1, ID.MM2, ID.MM3,
           ID.MM4, ID.MM5, ID.MM6, ID.MM7,
           ID.XMM0, ID.XMM1, ID.XMM2, ID.XMM3,
           ID.XMM4, ID.XMM5, ID.XMM6, ID.XMM7:
        nT();
        e = new AsmRegisterExpression(register);
        break;
      default:
        // DotIdentifier
        Expression[] identList;
        while (1)
        {
          auto begin2 = token;
          auto ident = requireIdentifier(MSG.ExpectedAnIdentifier);
          e = new IdentifierExpression(ident);
          set(e, begin2);
          identList ~= e;
          if (token.type != T.Dot)
            break;
          nT(); // Skip dot.
        }
        e = new DotListExpression(identList);
      }
      break;
    default:
      error(MID.ExpectedButFound, "Expression", token.srcText);
      e = new EmptyExpression();
      if (!trying)
      {
        // Insert a dummy token and don't consume current one.
        begin = lx.insertEmptyTokenBefore(token);
        this.prevToken = begin;
      }
    }
    set(e, begin);
    return e;
  }

  /+++++++++++++++++++++++++++++
  + Expression parsing methods +
  +++++++++++++++++++++++++++++/

  Expression parseExpression()
  {
    auto begin = token;
    auto e = parseAssignExpression();
    while (token.type == T.Comma)
    {
      auto comma = token;
      nT();
      e = new CommaExpression(e, parseAssignExpression(), comma);
      set(e, begin);
    }
    return e;
  }

  Expression parseAssignExpression()
  {
    auto begin = token;
    auto e = parseCondExpression();
    while (1)
    {
      switch (token.type)
      {
      case T.Assign:
        nT(); e = new AssignExpression(e, parseAssignExpression());
        break;
      case T.LShiftAssign:
        nT(); e = new LShiftAssignExpression(e, parseAssignExpression());
        break;
      case T.RShiftAssign:
        nT(); e = new RShiftAssignExpression(e, parseAssignExpression());
        break;
      case T.URShiftAssign:
        nT(); e = new URShiftAssignExpression(e, parseAssignExpression());
        break;
      case T.OrAssign:
        nT(); e = new OrAssignExpression(e, parseAssignExpression());
        break;
      case T.AndAssign:
        nT(); e = new AndAssignExpression(e, parseAssignExpression());
        break;
      case T.PlusAssign:
        nT(); e = new PlusAssignExpression(e, parseAssignExpression());
        break;
      case T.MinusAssign:
        nT(); e = new MinusAssignExpression(e, parseAssignExpression());
        break;
      case T.DivAssign:
        nT(); e = new DivAssignExpression(e, parseAssignExpression());
        break;
      case T.MulAssign:
        nT(); e = new MulAssignExpression(e, parseAssignExpression());
        break;
      case T.ModAssign:
        nT(); e = new ModAssignExpression(e, parseAssignExpression());
        break;
      case T.XorAssign:
        nT(); e = new XorAssignExpression(e, parseAssignExpression());
        break;
      case T.CatAssign:
        nT(); e = new CatAssignExpression(e, parseAssignExpression());
        break;
      default:
        return e;
      }
      set(e, begin);
    }
    return e;
  }

  Expression parseCondExpression()
  {
    auto begin = token;
    auto e = parseOrOrExpression();
    if (token.type == T.Question)
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
    while (token.type == T.OrLogical)
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
    while (token.type == T.AndLogical)
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
    while (token.type == T.OrBinary)
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
    while (token.type == T.Xor)
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
    while (token.type == T.AndBinary)
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
    switch (operator.type)
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
      switch (operator.type)
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
      switch (operator.type)
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
      switch (operator.type)
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
      switch (token.type)
      {
      case T.Dot:
        e = new PostDotListExpression(e, parseDotListExpression());
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
        nT();
        // [] is a SliceExpression
        if (token.type == T.RBracket)
        {
          e = new SliceExpression(e, null, null);
          break;
        }

        Expression[] es = [parseAssignExpression()];

        // [ AssignExpression .. AssignExpression ]
        if (token.type == T.Slice)
        {
          nT();
          e = new SliceExpression(e, es[0], parseAssignExpression());
          require(T.RBracket);
          goto Lset;
        }

        // [ ExpressionList ]
        if (token.type == T.Comma)
        {
           nT();
           es ~= parseExpressionList();
        }
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
    switch (token.type)
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
      switch (token.type)
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
        nT();
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
    default:
      e = parsePrimaryExpression();
      return e;
    }
    assert(e !is null);
    set(e, begin);
    return e;
  }

  Expression parsePrimaryExpression()
  {
    auto begin = token;
    Expression e;
    switch (token.type)
    {
    case T.Identifier, T.Dot, T.Typeof:
      e = parseDotListExpression();
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
      e = new IntExpression(token.type, token.ulong_);
      nT();
      break;
    case T.Float32, T.Float64, T.Float80,
         T.Imaginary32, T.Imaginary64, T.Imaginary80:
      e = new RealExpression(token.type, token.real_);
      nT();
      break;
    case T.CharLiteral:
      e = new CharExpression(token);
      nT();
      break;
    case T.String:
      Token*[] stringLiterals;
      do
      {
        stringLiterals ~= token;
        nT();
      } while (token.type == T.String)
      e = new StringExpression(stringLiterals);
      break;
    case T.LBracket:
      Expression[] values;

      nT();
      if (token.type != T.RBracket)
      {
        e = parseAssignExpression();
        if (token.type == T.Colon)
          goto LparseAssocArray;
        if (token.type == T.Comma)
        {
          nT();
          values = [e] ~ parseExpressionList();
        }
        require(T.RBracket);
      }
      else
        nT();

      e = new ArrayLiteralExpression(values);
      break;

    LparseAssocArray:
      Expression[] keys;

      keys ~= e;
      nT(); // Skip colon.
      goto LenterLoop;

      while (1)
      {
        keys ~= parseAssignExpression();
        require(T.Colon);
      LenterLoop:
        values ~= parseAssignExpression();
        if (token.type != T.Comma)
          break;
        nT();
      }
      require(T.RBracket);
      e = new AArrayLiteralExpression(keys, values);
      break;
    case T.LBrace:
      // DelegateLiteral := { Statements }
      auto funcBody = parseFunctionBody();
      e = new FunctionLiteralExpression(funcBody);
      break;
    case T.Function, T.Delegate:
      // FunctionLiteral := (function|delegate) Type? '(' ArgumentList ')' '{' Statements '}'
      nT(); // Skip function|delegate token.
      Type returnType;
      Parameters parameters;
      if (token.type != T.LBrace)
      {
        if (token.type != T.LParen) // Optional return type
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
      if (token.type == T.Comma)
      {
        nT();
        msg = parseAssignExpression();
      }
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

      switch (token.type)
      {
      case T.Colon, T.Equal:
        opTok = token;
        nT();
        switch (token.type)
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
      if (ident && specType && token.type == T.Comma)
        tparams = parseTemplateParameterList2();
    }
      require(T.RParen);
      e = new IsExpression(type, ident, opTok, specTok, specType, tparams);
      break;
    case T.LParen:
      if (tokenAfterParenIs(T.LBrace))
      {
        auto parameters = parseParameterList();
        // ( ParameterList ) FunctionBody
        auto funcBody = parseFunctionBody();
        e = new FunctionLiteralExpression(null, parameters, funcBody);
      }
      else
      {
        // ( Expression )
        nT();
        e = parseExpression();
        require(T.RParen);
        // TODO: create ParenExpression?
      }
      break;
    version(D2)
    {
    case T.Traits:
      nT();
      require(T.LParen);
      auto id = requireIdentifier(MSG.ExpectedAnIdentifier);
      TemplateArguments args;
      if (token.type == T.Comma)
        args = parseTemplateArguments2();
      else
        require(T.RParen);
      e = new TraitsExpression(id, args);
      break;
    }
    default:
      if (token.isIntegralType)
      { // IntegralType . Identifier
        auto type = new IntegralType(token.type);
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
        e = new EmptyExpression();
        if (!trying)
        {
          // Insert a dummy token and don't consume current one.
          begin = lx.insertEmptyTokenBefore(token);
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
    assert(token.type == T.New);
    nT(); // Skip new keyword.

    Expression[] newArguments;
    Expression[] ctorArguments;

    if (token.type == T.LParen)
      newArguments = parseArguments();

    // NewAnonClassExpression:
    //         new (ArgumentList)opt class (ArgumentList)opt SuperClassopt InterfaceClassesopt ClassBody
    if (token.type == T.Class)
    {
      nT();
      if (token.type == T.LParen)
        ctorArguments = parseArguments();

      BaseClass[] bases = token.type != T.LBrace ? parseBaseClasses(false) : null ;

      auto decls = parseDeclarationDefinitionsBody();
      return set(new NewAnonClassExpression(/*e, */newArguments, bases, ctorArguments, decls), begin);
    }

    // NewExpression:
    //         NewArguments Type [ AssignExpression ]
    //         NewArguments Type ( ArgumentList )
    //         NewArguments Type
    auto type = parseType();

    if (token.type == T.LParen)
      ctorArguments = parseArguments();

    return set(new NewExpression(/*e, */newArguments, type, ctorArguments), begin);
  }

  Type parseType()
  {
    return parseBasicType2(parseBasicType());
  }

  Type parseBasicType()
  {
    auto begin = token;
    Type t;

    if (token.isIntegralType)
    {
      t = new IntegralType(token.type);
      nT();
    }
    else
    switch (token.type)
    {
    case T.Identifier, T.Typeof, T.Dot:
      t = parseDotListType();
      assert(!isNodeSet(t));
      break;
    version(D2)
    {
    case T.Const:
      // const ( Type )
      nT();
      require(T.LParen);
      t = parseType();
      require(T.RParen);
      t = new ConstType(t);
      break;
    case T.Invariant:
      // invariant ( Type )
      nT();
      require(T.LParen);
      t = parseType();
      require(T.RParen);
      t = new InvariantType(t);
      break;
    } // version(D2)
    default:
      error(MID.ExpectedButFound, "BasicType", token.srcText);
      t = new UndefinedType();
      nT();
    }
    return set(t, begin);
  }

  Type parseBasicType2(Type t)
  {
    typeof(token) begin;
    while (1)
    {
      begin = token;
      switch (token.type)
      {
      case T.Mul:
        t = new PointerType(t);
        nT();
        break;
      case T.LBracket:
        t = parseArrayType(t);
        continue;
      case T.Function, T.Delegate:
        TOK tok = token.type;
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

  bool tokenAfterParenIs(TOK tok)
  {
    // We count nested parentheses tokens because template types may appear inside parameter lists; e.g. (int x, Foo!(int) y).
    assert(token.type == T.LParen);
    Token* next = token;
    uint level = 1;
  Loop:
    while (1)
    {
      lx.peek(next);
      switch (next.type)
      {
      case T.RParen:
        if (--level == 0)
        { // Last, closing parentheses found.
          do
            lx.peek(next);
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
    return next.type == tok;
  }

  Type parseDeclaratorSuffix(Type t)
  {
    switch (token.type)
    {
    case T.LBracket:
      // Type Identifier ArrayType
      // ArrayType := [] or [Type] or [Expression..Expression]
      do
        t = parseArrayType(t);
      while (token.type == T.LBracket)
      break;
/+ // parsed in parseDeclaration()
    case T.LParen:
      TemplateParameters tparams;
      if (tokenAfterParenIs(T.LParen))
      {
        // ( TemplateParameterList ) ( ParameterList )
        tparams = parseTemplateParameterList();
      }

      auto params = parseParameterList();
      // ReturnType FunctionName ( ParameterList )
      t = new FunctionType(t, params, tparams);
      break;
+/
    default:
      break;
    }
    return t;
  }

  Type parseArrayType(Type t)
  {
    assert(token.type == T.LBracket);
    auto begin = token;
    nT();
    if (token.type == T.RBracket)
    {
      t = new ArrayType(t);
      nT();
    }
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
        if (token.type == T.Slice)
        {
          nT();
          e2 = parseExpression();
        }
        t = new ArrayType(t, e, e2);
        require(T.RBracket);
      }
    }
    set(t, begin);
    return t;
  }

  Type parseCFunctionPointerType(Type type, ref Identifier* ident, bool optionalParamList)
  {
    assert(token.type == T.LParen);
    assert(type !is null);
    auto begin = token;
    nT(); // Skip (
    type = parseBasicType2(type);
    if (token.type == T.LParen)
    {
      // Can be nested.
      type = parseCFunctionPointerType(type, ident, true);
    }
    else if (token.type == T.Identifier)
    {
      // The identifier of the function pointer and the declaration.
      ident = token.ident;
      nT();
      type = parseDeclaratorSuffix(type);
    }
    require(T.RParen);

    Parameters params;
    if (optionalParamList)
      params = token.type == T.LParen ? parseParameterList() : null;
    else
      params = parseParameterList();

    type = set(new CFuncPointerType(type, params), begin);
    return type;
  }

  Type parseDeclarator(ref Identifier* ident, bool identOptional = false)
  {
    auto t = parseType();

    if (token.type == T.LParen)
    {
      t = parseCFunctionPointerType(t, ident, true);
    }
    else if (token.type == T.Identifier)
    {
      ident = token.ident;
      nT();
      t = parseDeclaratorSuffix(t);
    }

    if (ident is null && !identOptional)
      error(token, MSG.ExpectedDeclaratorIdentifier, token.srcText);

    return t;
  }

  /++
    Parse a list of AssignExpressions.
    ExpressionList:
      AssignExpression
      AssignExpression , ExpressionList
  +/
  Expression[] parseExpressionList()
  {
    Expression[] expressions;
    while (1)
    {
      expressions ~= parseAssignExpression();
      if (token.type != T.Comma)
        break;
      nT();
    }
    return expressions;
  }

  /++
    Arguments:
      ( )
      ( ExpressionList )
  +/
  Expression[] parseArguments()
  {
    assert(token.type == T.LParen);
    nT();
    Expression[] args;
    if (token.type != TOK.RParen)
      args = parseExpressionList();
    require(TOK.RParen);
    return args;
  }

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

    if (token.type == T.RParen)
    {
      nT();
      return set(params, begin);
    }

  Loop:
    while (1)
    {
      auto paramBegin = token;
      StorageClass stc, tmp;
      Type type;
      Identifier* ident;
      Expression defValue;

      void pushParameter()
      {
        params ~= set(new Parameter(stc, type, ident, defValue), paramBegin);
      }

      if (token.type == T.Ellipses)
      {
        nT();
        stc = StorageClass.Variadic;
        pushParameter(); // type, ident and defValue will be null.
        break Loop;
      }

    Lstc_loop:
      switch (token.type)
      {
    version(D2)
    {
      case T.Invariant: // D2.0
        if (peekNext() == T.LParen)
          goto default;
        tmp = StorageClass.Invariant;
        goto Lcommon;
      case T.Const: // D2.0
        if (peekNext() == T.LParen)
          goto default;
        tmp = StorageClass.Const;
        goto Lcommon;
      case T.Final: // D2.0
        tmp = StorageClass.Final;
        goto Lcommon;
      case T.Scope: // D2.0
        tmp = StorageClass.Scope;
        goto Lcommon;
      case T.Static: // D2.0
        tmp = StorageClass.Static;
        goto Lcommon;
    }
      case T.In:
        tmp = StorageClass.In;
        goto Lcommon;
      case T.Out:
        tmp = StorageClass.Out;
        goto Lcommon;
      case T.Inout, T.Ref:
        tmp = StorageClass.Ref;
        goto Lcommon;
      case T.Lazy:
        tmp = StorageClass.Lazy;
        goto Lcommon;
      Lcommon:
        // Check for redundancy.
        if (stc & tmp)
          error(MID.RedundantStorageClass, token.srcText);
        else
          stc |= tmp;
        nT();
      version(D2)
        goto Lstc_loop;
      else
        goto default; // In D1.0 only one stc per parameter is allowed.
      default:
        type = parseDeclarator(ident, true);

        if (token.type == T.Assign)
          nT(), (defValue = parseAssignExpression());

        if (token.type == T.Ellipses)
        {
          nT();
          stc |= StorageClass.Variadic;
          pushParameter();
          break Loop;
        }

        pushParameter();

        if (token.type != T.Comma)
          break Loop;
        nT();
      }
    }
    require(T.RParen);
    return set(params, begin);
  }

  TemplateArguments parseTemplateArguments()
  {
    TemplateArguments targs;
    require(T.LParen);
    if (token.type != T.RParen)
      targs = parseTemplateArguments_();
    require(T.RParen);
    return targs;
  }

version(D2)
{
  TemplateArguments parseTemplateArguments2()
  {
    assert(token.type == T.Comma);
    nT();
    TemplateArguments targs;
    if (token.type != T.RParen)
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
    while (1)
    {
      Type parseType_()
      {
        auto type = parseType();
        if (token.type == T.Comma || token.type == T.RParen)
          return type;
        ++errorCount; // Cause try_() to fail.
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
      if (token.type != T.Comma)
        break; // Exit loop.
      nT();
    }
    set(targs, begin);
    return targs;
  }

  TemplateParameters parseTemplateParameterList()
  {
    TemplateParameters tparams;
    require(T.LParen);
    if (token.type != T.RParen)
      tparams = parseTemplateParameterList_();
    require(T.RParen);
    return tparams;
  }

version(D2)
{
  TemplateParameters parseTemplateParameterList2()
  {
    assert(token.type == T.Comma);
    nT();
    TemplateParameters tparams;
    if (token.type != T.RParen)
      tparams = parseTemplateParameterList_();
    else
      error(token, MSG.ExpectedTemplateParameters);
    return tparams;
  }
} // version(D2)

  TemplateParameters parseTemplateParameterList_()
  {
    auto begin = token;
    auto tparams = new TemplateParameters;

    while (1)
    {
      auto paramBegin = token;
      TemplateParameter tp;
      Identifier* ident;
      Type specType, defType;

      void parseSpecAndOrDefaultType()
      {
        // : SpecializationType
        if (token.type == T.Colon)
        {
          nT();
          specType = parseType();
        }
        // = DefaultType
        if (token.type == T.Assign)
        {
          nT();
          defType = parseType();
        }
      }

      switch (token.type)
      {
      case T.Alias:
        // TemplateAliasParameter:
        //         alias Identifier
        nT(); // Skip alias keyword.
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
          nT(); // Skip Identifier.
          nT(); // Skip Ellipses.
          if (token.type == T.Comma)
            error(MID.TemplateTupleParameter);
          tp = new TemplateTupleParameter(ident);
          break;
        case T.Comma, T.RParen, T.Colon, T.Assign:
          // TemplateTypeParameter:
          //         Identifier
          nT(); // Skip Identifier.
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
        nT(); // Skip 'this' keyword.
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
        if (token.type == T.Colon)
        {
          nT();
          specValue = parseCondExpression();
        }
        // = DefaultValue
        if (token.type == T.Assign)
        {
          nT();
          defValue = parseCondExpression();
        }
        tp = new TemplateValueParameter(valueType, ident, specValue, defValue);
      }

      // Push template parameter.
      tparams ~= set(tp, paramBegin);

      if (token.type != T.Comma)
        break;
      nT();
    }
    set(tparams, begin);
    return tparams;
  }

  void expected(TOK tok)
  {
    if (token.type != tok)
      error(MID.ExpectedButFound, Token.toString(tok), token.srcText);
  }

  void require(TOK tok)
  {
    if (token.type == tok)
      nT();
    else
      error(MID.ExpectedButFound, Token.toString(tok), token.srcText);
  }

  void requireNext(TOK tok)
  {
    nT();
    require(tok);
  }

  Identifier* optionalIdentifier()
  {
    Identifier* id;
    if (token.type == T.Identifier)
      (id = token.ident), nT();
    return id;
  }

  Identifier* requireIdentifier()
  {
    Identifier* id;
    if (token.type == T.Identifier)
      (id = token.ident), nT();
    else
      error(MID.ExpectedButFound, "Identifier", token.srcText);
    return id;
  }

  /++
    Params:
      errorMsg = an error that has no message ID yet.
  +/
  Identifier* requireIdentifier(char[] errorMsg)
  {
    Identifier* id;
    if (token.type == T.Identifier)
      (id = token.ident), nT();
    else
      error(token, errorMsg, token.srcText);
    return id;
  }

  Identifier* requireIdentifier(MID mid)
  {
    Identifier* id;
    if (token.type == T.Identifier)
      (id = token.ident), nT();
    else
      error(mid, token.srcText);
    return id;
  }

  Token* requireId()
  {
    if (token.type == T.Identifier)
    {
      auto id = token;
      nT();
      return id;
    }
    else
      error(MID.ExpectedButFound, "Identifier", token.srcText);
    return null;
  }

  Token* requireIdToken(char[] errorMsg)
  {
    Token* idtok;
    if (token.type == T.Identifier)
      (idtok = token), nT();
    else
      error(token, errorMsg, token.srcText);
    return idtok;
  }

  /// Reports an error that has no message ID yet.
  void error(Token* token, char[] formatMsg, ...)
  {
    error_(token, formatMsg, _arguments, _argptr);
  }

  void error(MID mid, ...)
  {
    error_(this.token, GetMsg(mid), _arguments, _argptr);
  }

  void error_(Token* token, char[] formatMsg, TypeInfo[] _arguments, void* _argptr)
  {
    if (trying)
    {
      ++errorCount;
      return;
    }
    auto location = token.getLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    auto error = new ParserError(location, msg);
    errors ~= error;
    if (infoMan !is null)
      infoMan ~= error;
  }
}
