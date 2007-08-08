/++
  Author: Aziz Köksal
  License: GPL3
+/
module Parser;
import Lexer;
import SyntaxTree;
import Token;
import Messages;
import Information;
import Declarations;
import Statements;
import Expressions;
import Types;
import std.stdio;

private alias TOK T;

class Parser
{
  Lexer lx;
  Token* token;

  Information[] errors;

  this(char[] srcText, string fileName)
  {
    lx = new Lexer(srcText, fileName);
  }

  char* prev;

  void start()
  {
    prev = lx.text.ptr;
    nT();
  }

  void nT()
  {
    do
    {
      lx.nextToken();
      token = lx.token;
if (!trying)
{
writef("\33[32m%s\33[0m", token.type);
      writef("%s", prev[0 .. token.end - prev]);
      prev = token.end;
}
    } while (token.type == T.Comment) // Skip comments
  }

  void skipToOnePast(TOK tok)
  {
    for (; token.type != tok && token.type != T.EOF; nT())
    {}
    nT();
  }

  int trying;
  int errorCount;

  ReturnType try_(ReturnType)(lazy ReturnType parseMethod, out bool success)
  {
writef("\33[31mtry_\33[0m");
    ++trying;
//     auto len = errors.length;
    auto oldToken = token;
    auto oldCount = errorCount;
//     auto lexerState = lx.getState();
    auto result = parseMethod();
    // If the length of the array changed we know an error occurred.
    if (errorCount != oldCount)
    {
//       lexerState.restore(); // Restore state of the Lexer object.
//       errors = errors[0..len]; // Remove errors that were added when parseMethod() was called.
      token = oldToken;
      lx.token = oldToken;
      errorCount = oldCount;
      success = false;
    }
    else
      success = true;
    --trying;
writef("\33[34m%s\33[0m", success);
    return result;
  }

  Class set(Class)(Class node, Token* begin)
  {
    node.setTokens(begin, this.token);
    return node;
  }

  TOK peekNext()
  {
    Token* next = token;
    lx.peek(next);
    return next.type;
  }

  /++++++++++++++++++++++++++++++
  + Declaration parsing methods +
  ++++++++++++++++++++++++++++++/

  Declaration[] parseModule()
  {
    Declaration[] decls;

    if (token.type == T.Module)
    {
      auto begin = token;
      ModuleName moduleName;
      do
      {
        nT();
        moduleName ~= requireId();
      } while (token.type == T.Dot)
      require(T.Semicolon);
      decls ~= set(new ModuleDeclaration(moduleName), begin);
    }
    decls ~= parseDeclarationDefinitions();
    return decls;
  }

  Declaration[] parseDeclarationDefinitions()
  {
    Declaration[] decls;
    while (token.type != T.EOF)
      decls ~= parseDeclarationDefinition();
    return decls;
  }

  /*
    DeclDefsBlock:
        { }
        { DeclDefs }
  */
  Declaration[] parseDeclarationDefinitionsBlock()
  {
    Declaration[] decls;
    require(T.LBrace);
    while (token.type != T.RBrace && token.type != T.EOF)
      decls ~= parseDeclarationDefinition();
    require(T.RBrace);
    return decls;
  }

  Declaration parseDeclarationDefinition()
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
      decl = parseStorageAttribute();
      break;
    case T.Alias:
      nT();
      // TODO: parse StorageClasses?
      decl = new AliasDeclaration(parseDeclaration());
      break;
    case T.Typedef:
      nT();
      // TODO: parse StorageClasses?
      decl = new TypedefDeclaration(parseDeclaration());
      break;
    case T.Static:
      switch (peekNext())
      {
      case T.Import:
        goto case T.Import;
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
      decl = parseImportDeclaration();
      break;
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
      lx.peek(next);
      if (next.type == T.LParen)
      {
        lx.peek(next);
        if (next.type != T.RParen)
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
    // BasicType
    case T.Char,   T.Wchar,   T.Dchar,  T.Bool,
         T.Byte,   T.Ubyte,   T.Short,  T.Ushort,
         T.Int,    T.Uint,    T.Long,   T.Ulong,
         T.Float,  T.Double,  T.Real,
         T.Ifloat, T.Idouble, T.Ireal,
         T.Cfloat, T.Cdouble, T.Creal, T.Void:
    case_Declaration:
      decl = parseDeclaration();
      break;
    /+case T.Module:
      // TODO: Error: module is optional and can appear only once at the top of the source file.
      break;+/
    default:
      // TODO: issue error msg.
      error(MID.ExpectedButFound, "Declaration", token.srcText);
      decl = new IllegalDeclaration(token.type);
      nT();
    }
//     writef("§%s§", decl.classinfo.name);
    set(decl, begin);
    return decl;
  }

  /*
    DeclarationsBlock:
        : DeclDefs
        { }
        { DeclDefs }
        DeclDef
  */
  Declaration[] parseDeclarationsBlock()
  {
    Declaration[] decls;
    switch (token.type)
    {
    case T.LBrace:
      decls = parseDeclarationDefinitionsBlock();
      break;
    case T.Colon:
      nT();
      while (token.type != T.RBrace && token.type != T.EOF)
        decls ~= parseDeclarationDefinition();
      break;
    default:
      decls ~= parseDeclarationDefinition();
    }
    return decls;
  }

  Declaration parseDeclaration(StorageClass stc = StorageClass.None)
  {
    Type type;
    Token* ident;

    // Check for AutoDeclaration
    if (stc != StorageClass.None &&
        token.type == T.Identifier &&
        peekNext() == T.Assign)
    {
      ident = token;
      nT();
    }
    else
    {
      type = parseType();
      ident = requireId();
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
        // ReturnType FunctionName ( ParameterList )
        auto funcBody = parseFunctionBody();
        return new FunctionDeclaration(type, ident, tparams, params, funcBody);
      }
      type = parseDeclaratorSuffix(type);
    }

    // It's a variable declaration.
    Token*[] idents = [ident];
    Expression[] values;
    goto LenterLoop; // We've already parsed an identifier. Jump to if statement and check for initializer.
    while (token.type == T.Comma)
    {
      nT();
      idents ~= requireId();
    LenterLoop:
      if (token.type == T.Assign)
      {
        nT();
        values ~= parseInitializer();
      }
      else
        values ~= null;
    }
    require(T.Semicolon);
    return new VariableDeclaration(type, idents, values);
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
        Token*[] idents;
        Expression[] values;

        nT();
        while (token.type != T.RBrace)
        {
          if (token.type == T.Identifier)
          {
            // Peek for colon to see if this is a member identifier.
            if (peekNext() == T.Colon)
            {
              idents ~= token;
              nT();
              nT();
            }
          }
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
      auto si = try_(parseStructInitializer(), success);
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
        require(T.LBrace);
        func.funcBody = parseStatements();
        require(T.RBrace);
        break;
      case T.Semicolon:
        nT();
        break;
      case T.In:
        //if (func.inBody)
          // TODO: issue error msg.
        nT();
        require(T.LBrace);
        func.inBody = parseStatements();
        require(T.RBrace);
        continue;
      case T.Out:
        //if (func.outBody)
          // TODO: issue error msg.
        nT();
        if (token.type == T.LParen)
        {
          nT();
          func.outIdent = requireId();
          require(T.RParen);
        }
        require(T.LBrace);
        func.outBody = parseStatements();
        require(T.RBrace);
        continue;
      case T.Body:
        nT();
        goto case T.LBrace;
      default:
        error(MID.ExpectedButFound, "FunctionBody", token.srcText);
      }
      break; // exit while loop
    }
    set(func, begin);
    return func;
  }

  Declaration parseStorageAttribute()
  {
    StorageClass stc, tmp;

    void addStorageClass()
    {
      if (stc & tmp)
      {
        error(MID.RedundantStorageClass, token.srcText);
      }
      else
        stc |= tmp;
    }

    Declaration[] parse()
    {
      Declaration decl;
      switch (token.type)
      {
      case T.Extern:
        tmp = StorageClass.Extern;
        addStorageClass();
        nT();
        Linkage linkage;
        if (token.type == T.LParen)
        {
          nT();
          auto ident = requireId();
          switch (ident ? ident.identifier : null)
          {
          case "C":
            if (token.type == T.PlusPlus)
            {
              nT();
              linkage = Linkage.Cpp;
              break;
            }
            linkage = Linkage.C;
            break;
          case "D":
            linkage = Linkage.D;
            break;
          case "Windows":
            linkage = Linkage.Windows;
            break;
          case "Pascal":
            linkage = Linkage.Pascal;
            break;
          case "System":
            linkage = Linkage.System;
            break;
          default:
            // TODO: issue error msg. Unrecognized LinkageType.
          }
          require(T.RParen);
        }
        decl = new ExternDeclaration(linkage, parse());
        break;
      case T.Override:
        tmp = StorageClass.Override;
        goto Lcommon;
      case T.Deprecated:
        tmp = StorageClass.Deprecated;
        goto Lcommon;
      case T.Abstract:
        tmp = StorageClass.Abstract;
        goto Lcommon;
      case T.Synchronized:
        tmp = StorageClass.Synchronized;
        goto Lcommon;
      case T.Static:
        tmp = StorageClass.Static;
        goto Lcommon;
      case T.Final:
        tmp = StorageClass.Final;
        goto Lcommon;
      case T.Const:
      version(D2)
      {
        if (peekNext() == T.LParen)
          goto case_Declaration;
      }
        tmp = StorageClass.Const;
        goto Lcommon;
      version(D2)
      {
      case T.Invariant: // D 2.0
        if (peekNext() == T.LParen)
          goto case_Declaration;
        tmp = StorageClass.Invariant;
        goto Lcommon;
      }
      case T.Auto:
        tmp = StorageClass.Auto;
        goto Lcommon;
      case T.Scope:
        tmp = StorageClass.Scope;
        goto Lcommon;
      Lcommon:
        addStorageClass();
        auto tok = token.type;
        nT();
        decl = new AttributeDeclaration(tok, parse());
        break;
      case T.Identifier:
      case_Declaration:
        // This could be a normal Declaration or an AutoDeclaration
        decl = parseDeclaration(stc);
        break;
      default:
        return parseDeclarationsBlock();
      }
      return [decl];
    }
    return parse()[0];
  }

  Token* parseAlignAttribute()
  {
    assert(token.type == T.Align);
    nT(); // Skip align keyword.
    Token* tok;
    if (token.type == T.LParen)
    {
      nT();
      if (token.type == T.Int32)
      {
        tok = token;
        nT();
      }
      else
        expected(T.Int32);
      require(T.RParen);
    }
    return tok;
  }

  Declaration parseAttributeSpecifier()
  {
    Declaration decl;

    switch (token.type)
    {
    case T.Align:
      int size = -1;
      auto intTok = parseAlignAttribute();
      if (intTok)
        size = intTok.int_;
      decl = new AlignDeclaration(size, parseDeclarationsBlock());
      break;
    case T.Pragma:
      // Pragma:
      //     pragma ( Identifier )
      //     pragma ( Identifier , ExpressionList )
      // ExpressionList:
      //     AssignExpression
      //     AssignExpression , ExpressionList
      nT();
      Token* ident;
      Expression[] args;
      Declaration[] decls;

      require(T.LParen);
      ident = requireId();

      if (token.type == T.Comma)
      {
        // Parse at least one argument.
        nT();
        args ~= parseAssignExpression();
      }

      if (token.type == T.Comma)
        args ~= parseArguments(T.RParen);
      else
        require(T.RParen);

      if (token.type == T.Semicolon)
        nT();
      else
        decls = parseDeclarationsBlock();

      decl = new PragmaDeclaration(ident, args, decls);
      break;
    // Protection attributes
    case T.Private:
    case T.Package:
    case T.Protected:
    case T.Public:
    case T.Export:
      auto tok = token.type;
      nT();
      decl = new AttributeDeclaration(tok, parseDeclarationsBlock());
      break;
    default:
      assert(0);
    }
    return decl;
  }

  Declaration parseImportDeclaration()
  {
    assert(token.type == T.Import || token.type == T.Static);

    Declaration decl;
    bool isStatic;

    if (token.type == T.Static)
    {
      isStatic = true;
      nT();
    }

    ModuleName[] moduleNames;
    Token*[] moduleAliases;
    Token*[] bindNames;
    Token*[] bindAliases;

    nT(); // Skip import keyword.
    do
    {
      ModuleName moduleName;
      Token* moduleAlias;

      moduleAlias = requireId();

      // AliasName = ModuleName
      if (token.type == T.Assign)
      {
        nT();
        moduleName ~= requireId();
      }
      else // import Identifier [^=]
      {
        moduleName ~= moduleAlias;
        moduleAlias = null;
      }


      // parse Identifier(.Identifier)*
      while (token.type == T.Dot)
      {
        nT();
        moduleName ~= requireId();
      }

      // Push identifiers.
      moduleNames ~= moduleName;
      moduleAliases ~= moduleAlias;

      // parse : BindAlias = BindName(, BindAlias = BindName)*;
      //       : BindName(, BindName)*;
      if (token.type == T.Colon)
      {
        Token* bindName, bindAlias;
        do
        {
          nT();
          bindAlias = requireId();

          if (token.type == T.Assign)
          {
            nT();
            bindName = requireId();
          }
          else
          {
            bindName = bindAlias;
            bindAlias = null;
          }

          // Push identifiers.
          bindNames ~= bindName;
          bindAliases ~= bindAlias;

        } while (token.type == T.Comma)
        break;
      }
    } while (token.type == T.Comma)
    require(T.Semicolon);

    return new ImportDeclaration(moduleNames, moduleAliases, bindNames, bindAliases);
  }

  Declaration parseEnumDeclaration()
  {
    assert(token.type == T.Enum);

    Token* enumName;
    Type baseType;
    Token*[] members;
    Expression[] values;
    bool hasBody;

    nT(); // Skip enum keyword.

    if (token.type == T.Identifier)
    {
      enumName = token;
      nT();
    }

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
      nT();
      do
      {
        members ~= requireId();

        if (token.type == T.Assign)
        {
          nT();
          values ~= parseAssignExpression();
        }
        else
          values ~= null;

        if (token.type == T.Comma)
          nT();
        else if (token.type != T.RBrace)
        {
          expected(T.RBrace);
          break;
        }
      } while (token.type != T.RBrace)
      nT();
    }
    else
      error(MID.ExpectedButFound, "enum declaration", token.srcText);

    return new EnumDeclaration(enumName, baseType, members, values, hasBody);
  }

  Declaration parseClassDeclaration()
  {
    assert(token.type == T.Class);

    Token* className;
    TemplateParameters tparams;
    BaseClass[] bases;
    Declaration[] decls;
    bool hasBody;

    nT(); // Skip class keyword.
    className = requireId();

    if (token.type == T.LParen)
    {
      tparams = parseTemplateParameterList();
    }

    if (token.type == T.Colon)
      bases = parseBaseClasses();

    if (token.type == T.Semicolon)
    {
      //if (bases.length != 0)
        // TODO: Error: bases classes are not allowed in forward declarations.
      nT();
    }
    else if (token.type == T.LBrace)
    {
      hasBody = true;
      // TODO: think about setting a member status variable to a flag InClassBody... this way we can check for DeclDefs that are illegal in class bodies in the parsing phase.
      decls = parseDeclarationDefinitionsBlock();
    }
    else
      expected(T.LBrace); // TODO: better error msg

    return new ClassDeclaration(className, tparams, bases, decls, hasBody);
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
        // TODO: issue error msg
        return bases;
      }
      nT(); // Skip protection attribute.
    LparseBasicType:
      auto type = parseBasicType();
      //if (type.tid != TID.DotList)
        // TODO: issue error msg. base classes can only be one or more identifiers or template instances separated by dots.
      bases ~= new BaseClass(prot, type);
      if (token.type != T.Comma)
        break;
    }
    return bases;
  }

  Declaration parseInterfaceDeclaration()
  {
    assert(token.type == T.Interface);

    Token* name;
    TemplateParameters tparams;
    BaseClass[] bases;
    Declaration[] decls;
    bool hasBody;

    nT(); // Skip interface keyword.
    name = requireId();

    if (token.type == T.LParen)
    {
      tparams = parseTemplateParameterList();
    }

    if (token.type == T.Colon)
      bases = parseBaseClasses();

    if (token.type == T.Semicolon)
    {
      //if (bases.length != 0)
        // TODO: error: base classes are not allowed in forward declarations.
      nT();
    }
    else if (token.type == T.LBrace)
    {
      hasBody = true;
      decls = parseDeclarationDefinitionsBlock();
    }
    else
      expected(T.LBrace); // TODO: better error msg

    // TODO: error if decls.length == 0

    return new InterfaceDeclaration(name, tparams, bases, decls, hasBody);
  }

  Declaration parseAggregateDeclaration()
  {
    assert(token.type == T.Struct || token.type == T.Union);

    TOK tok = token.type;

    Token* name;
    TemplateParameters tparams;
    Declaration[] decls;
    bool hasBody;

    nT(); // Skip struct or union keyword.
    // name is optional.
    if (token.type == T.Identifier)
    {
      name = token;
      nT();
      if (token.type == T.LParen)
      {
        tparams = parseTemplateParameterList();
      }
    }

    if (token.type == T.Semicolon)
    {
      //if (name.length == 0)
        // TODO: error: forward declarations must have a name.
      nT();
    }
    else if (token.type == T.LBrace)
    {
      hasBody = true;
      decls = parseDeclarationDefinitionsBlock();
    }
    else
      expected(T.LBrace); // TODO: better error msg

    // TODO: error if decls.length == 0

    if (tok == T.Struct)
      return new StructDeclaration(name, tparams, decls, hasBody);
    else
      return new UnionDeclaration(name, tparams, decls, hasBody);
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

  Declaration parseDebugDeclaration()
  {
    assert(token.type == T.Debug);

    nT(); // Skip debug keyword.

    Token* spec; // debug = Integer ;
                 // debug = Identifier ;
    Token* cond; // debug ( Integer )
                 // debug ( Identifier )
    Declaration[] decls, elseDecls;

    void parseIdentOrInt(ref Token* tok)
    {
      nT();
      if (token.type == T.Int32 ||
          token.type == T.Identifier)
      {
        tok = token;
        nT();
      }
      else
        expected(T.Identifier); // TODO: better error msg
    }

    if (token.type == T.Assign)
    {
      parseIdentOrInt(spec);
      require(T.Semicolon);
    }
    else
    {
      // Condition:
      //     Integer
      //     Identifier
      // ( Condition )
      if (token.type == T.LParen)
      {
        parseIdentOrInt(cond);
        require(T.RParen);
      }

      // debug DeclarationsBlock
      // debug ( Condition ) DeclarationsBlock
      decls = parseDeclarationsBlock();

      // else DeclarationsBlock
      if (token.type == T.Else)
      {
        nT();
        //if (token.type == T.Colon)
          // TODO: avoid "else:"?
        elseDecls = parseDeclarationsBlock();
      }
    }

    return new DebugDeclaration(spec, cond, decls, elseDecls);
  }

  Declaration parseVersionDeclaration()
  {
    assert(token.type == T.Version);

    nT(); // Skip version keyword.

    Token* spec; // version = Integer ;
                 // version = Identifier ;
    Token* cond; // version ( Integer )
                 // version ( Identifier )
    Declaration[] decls, elseDecls;

    void parseIdentOrInt(ref Token* tok)
    {
      if (token.type == T.Int32 ||
          token.type == T.Identifier)
      {
        tok = token;
        nT();
      }
      else
        expected(T.Identifier); // TODO: better error msg
    }

    if (token.type == T.Assign)
    {
      nT();
      parseIdentOrInt(spec);
      require(T.Semicolon);
    }
    else
    {
      // Condition:
      //     Integer
      //     Identifier

      // ( Condition )
      require(T.LParen);
      parseIdentOrInt(cond);
      require(T.RParen);

      // version ( Condition ) DeclarationsBlock
      decls = parseDeclarationsBlock();

      // else DeclarationsBlock
      if (token.type == T.Else)
      {
        nT();
        //if (token.type == T.Colon)
          // TODO: avoid "else:"?
        elseDecls = parseDeclarationsBlock();
      }
    }

    return new VersionDeclaration(spec, cond, decls, elseDecls);
  }

  Declaration parseStaticIfDeclaration()
  {
    assert(token.type == T.Static);

    nT(); // Skip static keyword.
    nT(); // Skip if keyword.

    Expression condition;
    Declaration[] ifDecls, elseDecls;

    require(T.LParen);
    condition = parseAssignExpression();
    require(T.RParen);

    if (token.type != T.Colon)
      ifDecls = parseDeclarationsBlock();
    else
      expected(T.LBrace); // TODO: better error msg

    if (token.type == T.Else)
    {
      nT();
      if (token.type != T.Colon)
        elseDecls = parseDeclarationsBlock();
      else
        expected(T.LBrace); // TODO: better error msg
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
    auto templateName = requireId();
    auto templateParams = parseTemplateParameterList();
    auto decls = parseDeclarationDefinitionsBlock();
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
    Expression[] identList;
    if (token.type == T.Dot)
    {
      identList ~= new IdentifierExpression(token);
      nT();
    }
    else if (token.type == T.Typeof)
    {
      requireNext(T.LParen);
      auto type = new TypeofType(parseExpression());
      require(T.RParen);
      identList ~= new TypeofExpression(type);
      if (token.type != T.Dot)
        goto Lreturn;
      nT();
    }

    while (1)
    {
      auto ident = requireId();
      Expression e;
      if (token.type == T.Not && peekNext() == T.LParen) // Identifier !( TemplateArguments )
      {
        nT(); // Skip !.
        e = new TemplateInstanceExpression(ident, parseTemplateArguments());
      }
      else // Identifier
        e = new IdentifierExpression(ident);

      identList ~= e;

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
    Type[] identList;
    if (token.type == T.Dot)
    {
      identList ~= new IdentifierType(token);
      nT();
    }
    else if (token.type == T.Typeof)
    {
      requireNext(T.LParen);
      identList ~= new TypeofType(parseExpression());
      require(T.RParen);
      if (token.type != T.Dot)
        goto Lreturn;
      nT();
    }

    while (1)
    {
      auto ident = requireId();
      // NB.: Currently Types can't be followed by "!=" so we don't need to peek for "(" when parsing TemplateInstances.
      if (token.type == T.Not/+ && peekNext() == T.LParen+/) // Identifier !( TemplateArguments )
      {
        nT(); // Skip !.
        identList ~= new TemplateInstanceType(ident, parseTemplateArguments());
      }
      else // Identifier
        identList ~= new IdentifierType(ident);

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
    auto begin = token;
    nT(); // Skip mixin keyword.

  static if (is(Class == MixinDeclaration))
    if (token.type == T.LParen)
    {
      // TODO: What about mixin(...).ident;?
      nT();
      auto e = parseAssignExpression();
      require(T.RParen);
      require(T.Semicolon);
      return new MixinDeclaration(e);
    }

    Expression[] templateIdent;
    Token* mixinIdent;

    // This code is similar to parseDotListType().
    if (token.type == T.Dot)
    {
      templateIdent ~= new IdentifierExpression(token);
      nT();
    }

    while (1)
    {
      auto ident = requireId();
      Expression e;
      if (token.type == T.Not) // Identifier !( TemplateArguments )
      {
        // No need to peek for T.LParen. This must be a template instance.
        nT();
        e = new TemplateInstanceExpression(ident, parseTemplateArguments());
      }
      else // Identifier
        e = new IdentifierExpression(ident);

      templateIdent ~= e;

      if (token.type != T.Dot)
        break;
      nT();
    }

    if (token.type == T.Identifier)
    {
      mixinIdent = token;
      nT();
    }

    require(T.Semicolon);

    return new Class(templateIdent, mixinIdent);
  }

  /+++++++++++++++++++++++++++++
  + Statement parsing methods  +
  +++++++++++++++++++++++++++++/

  Statements parseStatements()
  {
    auto begin = token;
    auto statements = new Statements();
    while (token.type != T.RBrace && token.type != T.EOF)
      statements ~= parseStatement();
    return set(statements, begin);
  }

  Statement parseStatement()
  {
// writefln("°parseStatement:(%d)token='%s'°", lx.loc, token.srcText);
    auto begin = token;
    Statement s;
    Declaration d;
    switch (token.type)
    {
    case T.Align:
      int size = -1;
      auto intTok = parseAlignAttribute();
      if (intTok)
        size = intTok.int_;
      // Restrict align attribute to structs in parsing phase.
      Declaration structDecl;
      if (token.type == T.Struct)
        structDecl = parseAggregateDeclaration();
      else
        expected(T.Struct);
      d = new AlignDeclaration(size, structDecl ? [structDecl] : null);
      goto case_DeclarationStatement;
/+ Not applicable for statements.
//          T.Private,
//          T.Package,
//          T.Protected,
//          T.Public,
//          T.Export,
//          T.Deprecated,
//          T.Override,
//          T.Abstract,
+/
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
        auto ident = token;
        nT(); // Skip Identifier
        nT(); // Skip :
        s = new LabeledStatement(ident, parseNoScopeOrEmptyStatement());
        break;
      }
      goto case T.Dot;
    case T.Dot, T.Typeof:
      bool success;
      d = try_(parseDeclaration(), success);
      if (success)
        goto case_DeclarationStatement; // Declaration
      else
        goto default; // Expression
    // BasicType
    case T.Char,   T.Wchar,   T.Dchar,  T.Bool,
         T.Byte,   T.Ubyte,   T.Short,  T.Ushort,
         T.Int,    T.Uint,    T.Long,   T.Ulong,
         T.Float,  T.Double,  T.Real,
         T.Ifloat, T.Idouble, T.Ireal,
         T.Cfloat, T.Cdouble, T.Creal, T.Void:
    case_parseDeclaration:
      d = parseDeclaration();
      goto case_DeclarationStatement;
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
        goto default; // Parse as expression.
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
      goto case_DeclarationStatement;
    case T.Enum:
      d = parseEnumDeclaration();
      goto case_DeclarationStatement;
    case T.Class:
      d = parseClassDeclaration();
      goto case_DeclarationStatement;
    case T.Interface:
      d = parseInterfaceDeclaration();
      goto case_DeclarationStatement;
    case T.Struct, T.Union:
      d = parseAggregateDeclaration();
      goto case_DeclarationStatement;
    case_DeclarationStatement:
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
    default:
      bool success;
      auto expression = try_(parseExpression(), success);
// writefln("parseExpression()=", failed?"failed":"success");
      if (success)
      {
        require(T.Semicolon);
        s = new ExpressionStatement(expression);
      }
      else
      {
        error(MID.ExpectedButFound, "Statement", token.srcText);
        s = new IllegalStatement(token);
        nT();
      }
    }
    assert(s !is null);
//     writef("§%s§", s.classinfo.name);
    set(s, begin);
    return s;
  }

  /+
    ScopeStatement:
        NoScopeStatement
  +/
  Statement parseScopeStatement()
  {
    return new ScopeStatement(parseNoScopeStatement());
  }

  /+
    NoScopeStatement:
        NonEmptyStatement
        BlockStatement
    BlockStatement:
        { }
        { StatementList }
  +/
  Statement parseNoScopeStatement()
  {
    Statement s;
    if (token.type == T.LBrace)
    {
      nT();
      auto ss = new Statements();
      while (token.type != T.RBrace && token.type != T.EOF)
        ss ~= parseStatement();
      require(T.RBrace);
      s = ss;
    }
    else if (token.type == T.Semicolon)
    {
      error(MID.ExpectedButFound, "non-empty statement", ";");
      s = new EmptyStatement();
      nT();
    }
    else
      s = parseStatement();
    return s;
  }

  /+
    NoScopeOrEmptyStatement:
        ;
        NoScopeStatement
  +/
  Statement parseNoScopeOrEmptyStatement()
  {
    if (token.type == T.Semicolon)
      nT();
    else
      return parseNoScopeStatement();
    return null;
  }

  Statement parseAttributeStatement()
  {
    StorageClass stc, tmp;

    void addStorageClass()
    {
      if (stc & tmp)
      {
        error(MID.RedundantStorageClass, token.srcText);
      }
      else
        stc |= tmp;
    }

    Statement parse()
    {
      auto begin = token;
      Statement s;
      switch (token.type)
      {
      case T.Extern:
        tmp = StorageClass.Extern;
        addStorageClass();
        nT();
        Linkage linkage;
        if (token.type == T.LParen)
        {
          nT();
          auto ident = requireId();
          switch (ident ? ident.identifier : null)
          {
          case "C":
            if (token.type == T.PlusPlus)
            {
              nT();
              linkage = Linkage.Cpp;
              break;
            }
            linkage = Linkage.C;
            break;
          case "D":
            linkage = Linkage.D;
            break;
          case "Windows":
            linkage = Linkage.Windows;
            break;
          case "Pascal":
            linkage = Linkage.Pascal;
            break;
          case "System":
            linkage = Linkage.System;
            break;
          default:
            // TODO: issue error msg. Unrecognized LinkageType.
          }
          require(T.RParen);
        }
        s = new ExternStatement(linkage, parse());
        break;
      case T.Static:
        tmp = StorageClass.Static;
        goto Lcommon;
      case T.Final:
        tmp = StorageClass.Final;
        goto Lcommon;
      case T.Const:
      version(D2)
      {
        if (peekNext() == T.LParen)
          goto case_Declaration;
      }
        tmp = StorageClass.Const;
        goto Lcommon;
      version(D2)
      {
      case T.Invariant: // D 2.0
        if (peekNext() == T.LParen)
          goto case_Declaration;
        tmp = StorageClass.Invariant;
        goto Lcommon;
      }
      case T.Auto:
        tmp = StorageClass.Auto;
        goto Lcommon;
      case T.Scope:
        tmp = StorageClass.Scope;
        goto Lcommon;
      Lcommon:
        addStorageClass();
        auto tok = token.type;
        nT();
        s = new AttributeStatement(tok, parse());
        break;
      // TODO: allow "scope class", "abstract scope class" in function bodies?
      //case T.Class:
      default:
      case_Declaration:
        s = new DeclarationStatement(parseDeclaration(stc));
      }
      set(s, begin);
      return s;
    }
    return parse();
  }

  Statement parseIfStatement()
  {
    assert(token.type == T.If);
    nT();

    Statement variable;
    Expression condition;
    Statement ifBody, elseBody;

    require(T.LParen);

    Token* ident;
    // auto Identifier = Expression
    if (token.type == T.Auto)
    {
      auto a = new AttributeStatement(token.type, null);
      nT();
      ident = requireId();
      require(T.Assign);
      auto init = parseExpression();
      a.statement = new DeclarationStatement(new VariableDeclaration(null, [ident], [init]));
      variable = a;
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
      auto type = try_(parseDeclaratorAssign(), success);
      if (success)
      {
        auto init = parseExpression();
        variable = new DeclarationStatement(new VariableDeclaration(type, [ident], [init]));
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
      Token* stcTok;
      Type type;
      Token* ident;

      switch (token.type)
      {
      case T.Ref, T.Inout:
        stcTok = token;
        nT();
        // fall through
      case T.Identifier:
        auto next = peekNext();
        if (next == T.Comma || next == T.Semicolon || next == T.RParen)
        {
          ident = token;
          nT();
          break;
        }
        // fall through
      default:
        type = parseDeclarator(ident);
      }

      params ~= set(new Parameter(stcTok, type, ident, null), paramBegin);

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

  Statement parseCaseDefaultBody()
  {
    // This function is similar to parseNoScopeStatement()
    auto s = new Statements();
    while (token.type != T.Case &&
            token.type != T.Default &&
            token.type != T.RBrace &&
            token.type != T.EOF)
      s ~= parseStatement();
    return new ScopeStatement(s);
  }

  Statement parseCaseStatement()
  {
    assert(token.type == T.Case);
    // T.Case skipped in do-while.
    Expression[] values;
    do
    {
      nT();
      values ~= parseAssignExpression();
    } while (token.type == T.Comma)
    require(T.Colon);

    auto caseBody = parseCaseDefaultBody();
    return new CaseStatement(values, caseBody);
  }

  Statement parseDefaultStatement()
  {
    assert(token.type == T.Default);
    nT();
    require(T.Colon);
    return new DefaultStatement(parseCaseDefaultBody());
  }

  Statement parseContinueStatement()
  {
    assert(token.type == T.Continue);
    nT();
    Token* ident;
    if (token.type == T.Identifier)
    {
      ident = token;
      nT();
    }
    require(T.Semicolon);
    return new ContinueStatement(ident);
  }

  Statement parseBreakStatement()
  {
    assert(token.type == T.Break);
    nT();
    Token* ident;
    if (token.type == T.Identifier)
    {
      ident = token;
      nT();
    }
    require(T.Semicolon);
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
    Token* ident;
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
      ident = requireId();
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
        Token* ident;
        auto type = parseDeclarator(ident);
        param = new Parameter(null, type, ident, null);
        require(T.RParen);
      }
      catchBodies ~= new CatchBody(param, parseNoScopeStatement());
      if (param is null)
        break; // This is a LastCatch
    }

    if (token.type == T.Finally)
    {
      nT();
      finBody = new FinallyBody(parseNoScopeStatement());
    }

    if (catchBodies.length == 0 || finBody is null)
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

    Token* condition = requireId();
    if (condition)
      switch (condition.identifier)
      {
      case "exit":
      case "success":
      case "failure":
        break;
      default:
        // TODO: issue error msg.
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

    Token* ident;
    Expression[] args;
    Statement pragmaBody;

    require(T.LParen);
    ident = requireId();

    if (token.type == T.Comma)
    {
      // Parse at least one argument.
      nT();
      args ~= parseAssignExpression();
    }

    if (token.type == T.Comma)
      args ~= parseArguments(T.RParen);
    else
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

    Token* cond; // debug ( Integer )
                 // debug ( Identifier )
    Statement debugBody, elseBody;

    void parseIdentOrInt(ref Token* tok)
    {
      nT();
      if (token.type == T.Int32 ||
          token.type == T.Identifier)
      {
        tok = token;
        nT();
      }
      else
        expected(T.Identifier); // TODO: better error msg
    }

//     if (token.type == T.Assign)
//     {
//       parseIdentOrInt(identSpec, levelSpec);
//       require(T.Semicolon);
//     }
//     else
    {
      // Condition:
      //     Integer
      //     Identifier

      // ( Condition )
      if (token.type == T.LParen)
      {
        parseIdentOrInt(cond);
        require(T.RParen);
      }

      // debug Statement
      // debug ( Condition ) Statement
      debugBody = parseNoScopeStatement();

      // else Statement
      if (token.type == T.Else)
      {
        // debug without condition and else body makes no sense
        //if (levelCond == -1 && identCond.length == 0)
          // TODO: issue error msg
        nT();
        elseBody = parseNoScopeStatement();
      }
    }

    return new DebugStatement(cond, debugBody, elseBody);
  }

  Statement parseVersionStatement()
  {
    assert(token.type == T.Version);

    nT(); // Skip version keyword.

    Token* cond; // version ( Integer )
                 // version ( Identifier )
    Statement versionBody, elseBody;

    void parseIdentOrInt(ref Token* tok)
    {
      if (token.type == T.Int32 ||
          token.type == T.Identifier)
      {
        tok = token;
        nT();
      }
      else
        expected(T.Identifier); // TODO: better error msg
    }

//     if (token.type == T.Assign)
//     {
//       parseIdentOrInt(identSpec, levelSpec);
//       require(T.Semicolon);
//     }
//     else
    {
      // Condition:
      //     Integer
      //     Identifier

      // ( Condition )
      require(T.LParen);
      parseIdentOrInt(cond);
      require(T.RParen);

      // version ( Condition ) Statement
      versionBody = parseNoScopeStatement();

      // else Statement
      if (token.type == T.Else)
      {
        nT();
        elseBody = parseNoScopeStatement();
      }
    }

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
    switch (token.type)
    {
    case T.Identifier:
      auto ident = token;
      auto next = peekNext();
      if (next == T.Colon)
      {
        // Identifier : AsmInstruction
        nT(); // Skip Identifier
        nT(); // Skip :
        s = new LabeledStatement(ident, parseAsmInstruction());
        break;
      }

      // Opcode ;
      // Opcode Operands ;
      // Opcode
      //     Identifier
      Expression[] es;
      if (next != T.Semicolon)
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
    case T.Semicolon:
      s = new EmptyStatement();
      nT();
      break;
    default:
      error(MID.ExpectedButFound, "AsmStatement", token.srcText);
      s = new IllegalAsmInstruction(token);
      nT();
    }
    set(s, begin);
    return s;
  }

  Expression parseAsmExpression()
  {
    auto begin = token;
    auto e = parseOrOrExpression();
    if (token.type == T.Question)
    {
      nT();
      auto iftrue = parseAsmExpression();
      require(T.Colon);
      auto iffalse = parseAsmExpression();
      e = new CondExpression(e, iftrue, iffalse);
      set(e, begin);
    }
    // TODO: create AsmExpression that contains e?
    return e;
  }

  Expression parseAsmOrOrExpression()
  {
    auto begin = token;
    alias parseAsmAndAndExpression parseNext;
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
    auto begin = token;
    alias parseAsmOrExpression parseNext;
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
    auto begin = token;
    alias parseAsmXorExpression parseNext;
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
    while (token.type == T.RBracket)
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
    case T.Identifier:
      switch (token.identifier)
      {
      case "near", "far",   "byte",  "short",  "int",
           "word", "dword", "float", "double", "real":
        nT();
        if (token.type == T.Identifier && token.identifier == "ptr")
          nT();
        else
          error(MID.ExpectedButFound, "ptr", token.srcText);
        e = new AsmTypeExpression(parseAsmUnaryExpression());
        break;
      case "offset":
        nT();
        e = new AsmOffsetExpression(parseAsmUnaryExpression());
        break;
      case "seg":
        nT();
        e = new AsmSegExpression(parseAsmUnaryExpression());
        break;
      default:
      }
      goto default;
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
      e = new IntNumberExpression(token.type, token.ulong_);
      nT();
      break;
    case T.Float32, T.Float64, T.Float80,
         T.Imaginary32, T.Imaginary64, T.Imaginary80:
      e = new RealNumberExpression(token.type, token.real_);
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
      switch (token.identifier)
      {
      // __LOCAL_SIZE
      case "__LOCAL_SIZE":
        e = new AsmLocalSizeExpression();
        nT();
        break;
      // Register
      case "ST":
        auto register = token;
        nT();
        // (1) - (7)
        Token* number;
        if (token.type == T.LParen)
        {
          nT();
          if (token.type == T.Int32)
          {
            number = token;
            nT();
          }
          else
            expected(T.Int32);
          require(T.RParen);
        }
        e = new AsmRegisterExpression(register, number);
        break;
      case "AL", "AH", "AX", "EAX",
           "BL", "BH", "BX", "EBX",
           "CL", "CH", "CX", "ECX",
           "DL", "DH", "DX", "EDX",
           "BP", "EBP",
           "SP", "ESP",
           "DI", "EDI",
           "SI", "ESI",
           "ES", "CS", "SS", "DS", "GS", "FS",
           "CR0", "CR2", "CR3", "CR4",
           "DR0", "DR1", "DR2", "DR3", "DR6", "DR7",
           "TR3", "TR4", "TR5", "TR6", "TR7",
           "MM0", "MM1", "MM2", "MM3", "MM4", "MM5", "MM6", "MM7",
           "XMM0", "XMM1", "XMM2", "XMM3", "XMM4", "XMM5", "XMM6", "XMM7":
          e = new AsmRegisterExpression(token);
          nT();
        break;
      default:
        // DotIdentifier
        auto begin2 = token;
        Expression[] identList;
        goto LenterLoop;
        while (token.type == T.Dot)
        {
          nT();
          begin2 = token;
          auto ident = requireId();
        LenterLoop:
          e = new IdentifierExpression(token);
          nT();
          set(e, begin2);
          identList ~= e;
        }
        e = new DotListExpression(identList);
      }
      break;
    default:
      error(MID.ExpectedButFound, "Expression", token.srcText);
      e = new EmptyExpression();
      break;
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
// if (!trying)
// writef("§%s§", e.classinfo.name);
    return e;
  }

  Expression parseAssignExpression()
  {
    typeof(token) begin;
    auto e = parseCondExpression();
    while (1)
    {
      begin = token;
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
      nT();
      auto iftrue = parseExpression();
      require(T.Colon);
      auto iffalse = parseCondExpression();
      e = new CondExpression(e, iftrue, iffalse);
      set(e, begin);
    }
    return e;
  }

  Expression parseOrOrExpression()
  {
    auto begin = token;
    alias parseAndAndExpression parseNext;
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
    auto begin = token;
    alias parseOrExpression parseNext;
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
    auto begin = token;
    alias parseXorExpression parseNext;
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
    auto begin = token;
    alias parseAndExpression parseNext;
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
    auto begin = token;
    alias parseCmpExpression parseNext;
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
    auto begin = token;
    auto e = parseShiftExpression();

    auto operator = token;
    switch (operator.type)
    {
    case T.Equal, T.NotEqual:
      nT();
      e = new EqualExpression(e, parseShiftExpression(), operator);
      break;
    case T.Not:
      if (peekNext() != T.Is)
        break;
      nT();
      // fall through
    case T.Is:
      nT();
      e = new IdentityExpression(e, parseShiftExpression(), operator);
      break;
    case T.LessEqual, T.Less, T.GreaterEqual, T.Greater,
         T.Unordered, T.UorE, T.UorG, T.UorGorE,
         T.UorL, T.UorLorE, T.LorEorG, T.LorG:
      nT();
      e = new RelExpression(e, parseShiftExpression(), operator);
      break;
    case T.In:
      nT();
      e = new InExpression(e, parseShiftExpression(), operator);
      break;
    default:
      return e;
    }
    set(e, begin);
    return e;
  }

  Expression parseShiftExpression()
  {
    auto begin = token;
    auto e = parseAddExpression();
    while (1)
    {
      auto operator = token;
      switch (operator.type)
      {
      case T.LShift:  nT(); e = new LShiftExpression(e, parseAddExpression(), operator); break;
      case T.RShift:  nT(); e = new RShiftExpression(e, parseAddExpression(), operator); break;
      case T.URShift: nT(); e = new URShiftExpression(e, parseAddExpression(), operator); break;
      default:
        return e;
      }
      set(e, begin);
    }
    assert(0);
  }

  Expression parseAddExpression()
  {
    auto begin = token;
    auto e = parseMulExpression();
    while (1)
    {
      auto operator = token;
      switch (operator.type)
      {
      case T.Plus:  nT(); e = new PlusExpression(e, parseMulExpression(), operator); break;
      case T.Minus: nT(); e = new MinusExpression(e, parseMulExpression(), operator); break;
      case T.Tilde: nT(); e = new CatExpression(e, parseMulExpression(), operator); break;
      default:
        return e;
      }
      set(e, begin);
    }
    assert(0);
  }

  Expression parseMulExpression()
  {
    auto begin = token;
    auto e = parseUnaryExpression();
    while (1)
    {
      auto operator = token;
      switch (operator.type)
      {
      case T.Mul: nT(); e = new MulExpression(e, parseUnaryExpression(), operator); break;
      case T.Div: nT(); e = new DivExpression(e, parseUnaryExpression(), operator); break;
      case T.Mod: nT(); e = new ModExpression(e, parseUnaryExpression(), operator); break;
      default:
        return e;
      }
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
      auto type = try_(parseType_(), success);
      if (success)
      {
        auto ident = requireId();
        e = new TypeDotIdExpression(type, ident);
        break;
      }
      goto default;
    default:
      e = parsePostExpression(parsePrimaryExpression());
      return e;
    }
    assert(e !is null);
    set(e, begin);
    return e;
  }

  Expression parsePostExpression(Expression e)
  {
    typeof(token) begin;
    while (1)
    {
      begin = token;
      switch (token.type)
      {
/*
// Commented out because parseDotListExpression() handles this.
      case T.Dot:
        nT();
        if (token.type == T.Identifier)
        {
          string ident = token.identifier;
          nT();
          if (token.type == T.Not && peekNext() == T.LParen) // Identifier !( TemplateArguments )
          {
            nT(); // Skip !.
            e = new DotTemplateInstanceExpression(e, ident, parseTemplateArguments());
          }
          else
          {
            e = new DotIdExpression(e, ident);
            nT();
          }
        }
        else if (token.type == T.New)
          e = parseNewExpression(e);
        else
          expected(T.Identifier);
        continue;
*/
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
        e = new CallExpression(e, parseArguments(T.RParen));
        goto Lset;
      case T.LBracket:
        // parse Slice- and IndexExpression
        nT();
        if (token.type == T.RBracket)
        {
          e = new SliceExpression(e, null, null);
          break;
        }

        Expression[] es = [parseAssignExpression()];

        if (token.type == T.Slice)
        {
          nT();
          e = new SliceExpression(e, es[0], parseAssignExpression());
          require(T.RBracket);
          goto Lset;
        }
        else if (token.type == T.Comma)
        {
           es ~= parseArguments(T.RBracket);
        }
        else
          require(T.RBracket);

        e = new IndexExpression(e, es);
        goto Lset;
      default:
        return e;
      }
      nT();
    Lset:
      set(e, begin);
    }
    assert(0);
  }

  Expression parsePrimaryExpression()
  {
    auto begin = token;
    Expression e;
    switch (token.type)
    {
/*
// Commented out because parseDotListExpression() handles this.
    case T.Identifier:
      string ident = token.identifier;
      nT();
      if (token.type == T.Not && peekNext() == T.LParen) // Identifier !( TemplateArguments )
      {
        nT(); // Skip !.
        e = new TemplateInstanceExpression(ident, parseTemplateArguments());
      }
      else
        e = new IdentifierExpression(ident);
      break;
    case T.Dot:
      nT();
      e = new IdentifierExpression(".");
      break;
*/
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
      e = new IntNumberExpression(token.type, token.ulong_);
      nT();
      break;
    case T.Float32, T.Float64, T.Float80,
         T.Imaginary32, T.Imaginary64, T.Imaginary80:
      e = new RealNumberExpression(token.type, token.real_);
      nT();
      break;
    case T.CharLiteral, T.WCharLiteral, T.DCharLiteral:
      nT();
      e = new CharLiteralExpression();
      break;
    case T.String:
      Token*[] stringLiterals;
      do
      {
        stringLiterals ~= token;
        nT();
      } while (token.type == T.String)
      e = new StringLiteralsExpression(stringLiterals);
      break;
    case T.LBracket:
      Expression[] values;

      nT();
      if (token.type != T.RBracket)
      {
        e = parseAssignExpression();
        if (token.type == T.Colon)
          goto LparseAssocArray;
        else if (token.type == T.Comma)
          values = [e] ~ parseArguments(T.RBracket);
        else
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
      e = new AssocArrayLiteralExpression(keys, values);
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
/*
// Commented out because parseDotListExpression() handles this.
    case T.Typeof:
      requireNext(T.LParen);
      auto type = new TypeofType(parseExpression());
      require(T.RParen);
      if (token.type == T.Dot)
      { // typeof ( Expression ) . Identifier
        nT();
        string ident = requireIdentifier;
        e = new TypeDotIdExpression(type, ident);
      }
      else // typeof ( Expression )
        e = new TypeofExpression(type);
      break;
*/
    case T.Is:
      requireNext(T.LParen);

      Type type, specType;
      Token* ident; // optional Identifier
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
          specTok = token;
          nT();
          break;
        default:
          specType = parseType();
        }
      default:
      }
      require(T.RParen);
      e = new IsExpression(type, ident, opTok, specTok, specType);
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
    // BasicType . Identifier
    case T.Char,   T.Wchar,   T.Dchar,  T.Bool,
         T.Byte,   T.Ubyte,   T.Short,  T.Ushort,
         T.Int,    T.Uint,    T.Long,   T.Ulong,
         T.Float,  T.Double,  T.Real,
         T.Ifloat, T.Idouble, T.Ireal,
         T.Cfloat, T.Cdouble, T.Creal, T.Void:
      auto type = new IntegralType(token.type);
      nT();
      set(type, begin);
      require(T.Dot);
      auto ident = requireId();

      e = new TypeDotIdExpression(type, ident);
      break;
    version(D2)
    {
    case T.Traits:
      nT();
      require(T.LParen);
      auto id = requireId();
      TemplateArguments args;
      if (token.type == T.Comma)
      {
        args = parseTemplateArguments2();
      }
      else
        require(T.RParen);
      e = new TraitsExpression(id, args);
      break;
    }
    default:
      // TODO: issue error msg.
      error(MID.ExpectedButFound, "Expression", token.srcText);
      e = new EmptyExpression();
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
      newArguments = parseArguments(T.RParen);

    // NewAnonClassExpression:
    //         new (ArgumentList)opt class (ArgumentList)opt SuperClassopt InterfaceClassesopt ClassBody
    if (token.type == T.Class)
    {
      nT();
      if (token.type == T.LParen)
        ctorArguments = parseArguments(T.RParen);

      BaseClass[] bases = token.type != T.LBrace ? parseBaseClasses(false) : null ;

      auto decls = parseDeclarationDefinitionsBlock();
      return set(new NewAnonClassExpression(/*e, */newArguments, bases, ctorArguments, decls), begin);
    }

    // NewExpression:
    //         NewArguments Type [ AssignExpression ]
    //         NewArguments Type ( ArgumentList )
    //         NewArguments Type
    auto type = parseType();
    if (type.tid == TID.DotList && token.type == T.LParen)
    {
      ctorArguments = parseArguments(T.RParen);
    }
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
//     IdentifierType tident;

    switch (token.type)
    {
    case T.Char,   T.Wchar,   T.Dchar,  T.Bool,
         T.Byte,   T.Ubyte,   T.Short,  T.Ushort,
         T.Int,    T.Uint,    T.Long,   T.Ulong,
         T.Float,  T.Double,  T.Real,
         T.Ifloat, T.Idouble, T.Ireal,
         T.Cfloat, T.Cdouble, T.Creal, T.Void:
      t = new IntegralType(token.type);
      nT();
      set(t, begin);
      break;
    case T.Identifier, T.Typeof, T.Dot:
      t = parseDotListType();
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
      set(t, begin);
      break;
    case T.Invariant:
      // invariant ( Type )
      nT();
      require(T.LParen);
      t = parseType();
      require(T.RParen);
      t = new InvariantType(t);
      set(t, begin);
      break;
    }
    default:
      // TODO: issue error msg.
      error(MID.ExpectedButFound, "BasicType", token.srcText);
      t = new UndefinedType();
      nT();
      set(t, begin);
    }
    return t;
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
        t = new FunctionType(t, parameters);
        if (tok == T.Function)
          t = new PointerType(t);
        else
          t = new DelegateType(t);
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
    while (1)
    {
      lx.peek(next);
      switch (next.type)
      {
      case T.RParen:
        if (--level == 0)
        { // Closing parentheses found.
          lx.peek(next);
          break;
        }
        continue;
      case T.LParen:
        ++level;
        continue;
      case T.EOF:
        break;
      default:
        continue;
      }
      break;
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
      auto assocType = try_(parseType(), success);
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
      }
      require(T.RBracket);
    }
    set(t, begin);
    return t;
  }

  Type parseDeclarator(ref Token* ident, bool identOptional = false)
  {
    auto t = parseType();

    if (token.type == T.Identifier)
    {
      ident = token;
      nT();
      t = parseDeclaratorSuffix(t);
    }
    else if (!identOptional)
      expected(T.Identifier);

    return t;
  }

  Expression[] parseArguments(TOK terminator)
  {
    assert(token.type == T.LParen || token.type == T.LBracket || token.type == T.Comma);
    assert(terminator == T.RParen || terminator == T.RBracket);
    Expression[] args;

    nT();
    if (token.type == terminator)
    {
      nT();
      return null;
    }

    goto LenterLoop;
    do
    {
      nT();
    LenterLoop:
      args ~= parseAssignExpression();
    } while (token.type == T.Comma)

    require(terminator);
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

    while (1)
    {
      auto paramBegin = token;
      Token* stcTok;
      StorageClass stc, tmp;

      if (token.type == T.Ellipses)
      {
        nT();
        params ~= set(new Parameter(null, null, null, null), paramBegin);
        break; // Exit loop.
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
        if (stc & tmp)
          error(MID.RedundantStorageClass, token.srcText);
        else
          stc |= tmp;
        nT();
        goto Lstc_loop;
      }
      else // else body of version(D2)
      {
      case T.In, T.Out, T.Inout, T.Ref, T.Lazy:
        stcTok = token;
        nT();
        goto default;
      }
      default:
      version(D2)
      {
        if (stc != StorageClass.None)
          stcTok = begin;
      }
        Token* ident;
        auto type = parseDeclarator(ident, true);

        Expression assignExpr;
        if (token.type == T.Assign)
        {
          nT();
          assignExpr = parseAssignExpression();
        }

        if (token.type == T.Ellipses)
        {
          auto p = set(new Parameter(stcTok, type, ident, assignExpr), paramBegin);
          p.stc |= StorageClass.Variadic;
          params ~= p;
          nT();
          break; // Exit loop.
        }

        params ~= set(new Parameter(stcTok, type, ident, assignExpr), paramBegin);

        if (token.type != T.Comma)
          break; // Exit loop.
        nT();
        continue;
      }
      break; // Exit loop.
    }
    require(T.RParen);
    return set(params, begin);
  }

  TemplateArguments parseTemplateArguments()
  {
    auto begin = token;
    auto args = new TemplateArguments;

    require(T.LParen);
    if (token.type != T.RParen)
    {
      while (1)
      {
        bool success;
        auto typeArgument = try_(parseType(), success);
        if (success)
        {
          // TemplateArgument:
          //         Type
          //         Symbol
          args ~= typeArgument;
        }
        else
        {
          // TemplateArgument:
          //         AssignExpression
          args ~= parseAssignExpression();
        }
        if (token.type != T.Comma)
          break; // Exit loop.
        nT();
      }
    }
    require(T.RParen);
    set(args, begin);
    return args;
  }
version(D2)
{
  TemplateArguments parseTemplateArguments2()
  {
    assert(token.type == T.Comma);
    nT();
    auto begin = token;
    auto args = new TemplateArguments;

    if (token.type != T.RParen)
    {
      while (1)
      {
        bool success;
        auto typeArgument = try_(parseType(), success);
        if (success)
        {
          // TemplateArgument:
          //         Type
          //         Symbol
          args ~= typeArgument;
        }
        else
        {
          // TemplateArgument:
          //         AssignExpression
          args ~= parseAssignExpression();
        }
        if (token.type != T.Comma)
          break; // Exit loop.
        nT();
      }
    }
    else
      error(MID.ExpectedButFound, "Type/Expression", ")");
    require(T.RParen);
    set(args, begin);
    return args;
  }
} // version(D2)
  TemplateParameters parseTemplateParameterList()
  {
    auto begin = token;
    require(T.LParen);
    if (token.type == T.RParen)
      return null;

    auto tparams = new TemplateParameters;
    while (1)
    {
      auto paramBegin = token;
      TP tp;
      Token* ident;
      Type valueType;
      Type specType, defType;
      Expression specValue, defValue;

      switch (token.type)
      {
      case T.Alias:
        // TemplateAliasParameter:
        //         alias Identifier
        tp = TP.Alias;
        nT(); // Skip alias keyword.
        ident = requireId();
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
        break;
      case T.Identifier:
        ident = token;
        switch (peekNext())
        {
        case T.Ellipses:
          // TemplateTupleParameter:
          //         Identifier ...
          tp = TP.Tuple;
          nT(); // Skip Identifier.
          nT(); // Skip Ellipses.
          // if (token.type == T.Comma)
          //  error(); // TODO: issue error msg for variadic param not being last.
          break;
        case T.Comma, T.RParen, T.Colon, T.Assign:
          // TemplateTypeParameter:
          //         Identifier
          tp = TP.Type;
          nT(); // Skip Identifier.
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
          break;
        default:
          // TemplateValueParameter:
          //         Declarator
          ident = null;
          goto LTemplateValueParameter;
        }
        break;
      default:
      LTemplateValueParameter:
        // TemplateValueParameter:
        //         Declarator
        tp = TP.Value;
        valueType = parseDeclarator(ident);
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
      }

      tparams ~= set(new TemplateParameter(tp, valueType, ident, specType, defType, specValue, defValue), paramBegin);

      if (token.type != T.Comma)
        break;
      nT();
    }
    require(T.RParen);
    set(tparams, begin);
    return tparams;
  }

  void expected(TOK tok)
  {
    if (token.type != tok)
      error(MID.ExpectedButFound, Token.Token.toString(tok), token.srcText);
  }

  void require(TOK tok)
  {
    if (token.type == tok)
      nT();
    else
      error(MID.ExpectedButFound, Token.Token.toString(tok), token.srcText);
  }

  void requireNext(TOK tok)
  {
    nT();
    require(tok);
  }

  string requireIdentifier()
  {
    string identifier;
    if (token.type == T.Identifier)
    {
      identifier = token.identifier;
      nT();
    }
    else
      error(MID.ExpectedButFound, "Identifier", token.srcText);
    return identifier;
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

  void error(MID id, ...)
  {
    if (trying)
    {
      ++errorCount;
      return;
    }

//     if (errors.length == 10)
//       return;
    errors ~= new Information(InfoType.Parser, id, lx.loc, arguments(_arguments, _argptr));
//     writefln("(%d)P: ", lx.loc, errors[$-1].getMsg);
  }
}
