/++
  Author: Aziz Köksal
  License: GPL2
+/
module Parser;
import Lexer;
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
    token = &lx.token;
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
if (!trying)
{
writef("\33[32m%s\33[0m", token.type);
try
      writef("%s", prev[0 .. token.end - prev]);
catch
{writef("\33[30mø\33[0m");}
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
    auto oldCount = errorCount;
    auto lexerState = lx.getState();
    auto result = parseMethod();
    // If the length of the array changed we know an error occurred.
    if (errorCount != oldCount)
    {
      lexerState.restore(); // Restore state of the Lexer object.
//       errors = errors[0..len]; // Remove errors that were added when parseMethod() was called.
      errorCount = oldCount;
      success = false;
    }
    else
      success = true;
    --trying;
writef("\33[34m%s\33[0m", success);
    return result;
  }

  /++++++++++++++++++++++++++++++
  + Declaration parsing methods +
  ++++++++++++++++++++++++++++++/

  Declaration[] parseModule()
  {
    Declaration[] decls;

    if (token.type == T.Module)
    {
      ModuleName moduleName;
      do
      {
        nT();
        moduleName ~= requireIdentifier();
      } while (token.type == T.Dot)
      require(T.Semicolon);
      decls ~= new ModuleDeclaration(moduleName);
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
    Declaration decl;
    switch (token.type)
    {
    case T.Extern,
         T.Align,
         T.Pragma,
         T.Private,
         T.Package,
         T.Protected,
         T.Public,
         T.Export,
         T.Deprecated,
         T.Override,
         T.Abstract,
         T.Synchronized,
         //T.Static,
         T.Final,
         T.Const,
         T.Auto,
         T.Scope:
    case_AttributeSpecifier:
      decl = parseAttributeSpecifier();
      break;
    case T.Alias:
      nT();
      decl = new AliasDeclaration(parseDeclarationDefinition());
      break;
    case T.Typedef:
      nT();
      decl = new TypedefDeclaration(parseDeclarationDefinition());
      break;
    case T.Static:
      Token t;
      lx.peek(t);

      switch (t.type)
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
        goto case_AttributeSpecifier;
      }
      assert(0);
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
      decl = parseMixinDeclaration();
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

  Declaration parseDeclaration()
  {
    Type type;
    string ident;

    // Check for AutoDeclaration
    if (token.type == T.Identifier)
    {
      Token next;
      lx.peek(next);
      if (next.type == T.Comma || next.type == T.Assign)
      {
        ident = token.identifier;
        nT();
      }
      else
        goto LnonAutoDeclaration;
    }
    else
    {
    LnonAutoDeclaration:
      type = parseType();
      ident = requireIdentifier();
// writefln("trying=%s,errorCount=%d", trying, errorCount);
// writefln("ident=%s", ident);
      // Type FunctionName ( ParameterList ) FunctionBody
      if (token.type == T.LParen)
      {
//         writef("°Function°");
        // It's a function declaration
        TemplateParameter[] tparams;
        if (isTemplateParameterList())
        {
          // ( TemplateParameterList ) ( ParameterList )
          tparams = parseTemplateParameterList();
        }

        auto params = parseParameterList();
        // ReturnType FunctionName ( ParameterList )
        type = new FunctionType(type, params, tparams);
//         type = parseDeclaratorSuffix(type);
        auto funcBody = parseFunctionBody(new FunctionBody);
        return new FunctionDeclaration(ident, type, null, funcBody);
      }
    }

    // It's a variable declaration.
    string[] idents = [ident];
    Expression[] values;
    goto LenterLoop; // We've already parsed an identifier. Jump to if statement and check for initializer.
    while (token.type == T.Comma)
    {
      idents ~= requireIdentifier();
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
    return new VariableDeclaration(idents, values);
  }

  Expression parseInitializer()
  {
    if (token.type == T.Void)
    {
      Token next;
      lx.peek(next);
      if (next.type == T.Comma || next.type == T.Semicolon)
      {
        nT();
        return new VoidInitializer();
      }
    }
    return parseNonVoidInitializer();
  }

  Expression parseNonVoidInitializer()
  {
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
        string[] idents;
        Expression[] values;

        nT();
        while (token.type != T.RBrace)
        {
          if (token.type == T.Identifier)
          {
            Token next;
            lx.peek(next);
            // Peek for colon to see if this is a member identifier.
            if (next.type == T.Colon)
            {
              idents ~= token.identifier();
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
    return init;
  }

  FunctionBody parseFunctionBody(FunctionBody func)
  {
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
          func.outIdent = requireIdentifier();
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
        // TODO: issue error msg.
        error(MID.ExpectedButFound, "FunctionBody", token.srcText);
      }
      break; // exit while loop
    }
    return func;
  }

  Declaration parseAttributeSpecifier()
  {
    Declaration decl;

    switch (token.type)
    {
    case T.Extern:
      nT();
      Linkage linkage;
      if (token.type == T.LParen)
      {
        nT();
        auto ident = requireIdentifier();
        switch (ident)
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
        default:
          // TODO: issue error msg. Unrecognized LinkageType.
        }
        require(T.RParen);
      }
      decl = new ExternDeclaration(linkage, parseDeclarationsBlock());
      break;
    case T.Align:
      nT();
      int size = -1;
      if (token.type == T.LParen)
      {
        nT();
        if (token.type == T.Int32)
        {
          size = token.int_;
          nT();
        }
        else
          expected(T.Int32);
        require(T.RParen);
      }
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
      string ident;
      Expression[] args;
      Declaration[] decls;

      require(T.LParen);
      ident = requireIdentifier();

      // TODO: pragma(msg,) shouldn't be allowed
      if (token.type == T.Comma)
        args = parseArguments(T.RParen);
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
    // StorageClass attributes
    case T.Override:
    case T.Deprecated:
    case T.Abstract:
    case T.Synchronized:
    case T.Static:
    case T.Final:
    case T.Const:
    case T.Auto:
    case T.Scope:
      nT();
      decl = new AttributeDeclaration(token.type, parseDeclarationsBlock());
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
    string[] moduleAliases;
    string[] bindNames;
    string[] bindAliases;

    nT(); // Skip import keyword.
    do
    {
      ModuleName moduleName;
      string moduleAlias;

      moduleAlias = requireIdentifier();

      // AliasName = ModuleName
      if (token.type == T.Assign)
      {
        nT();
        moduleName ~= requireIdentifier();
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
        moduleName ~= requireIdentifier();
      }

      // Push identifiers.
      moduleNames ~= moduleName;
      moduleAliases ~= moduleAlias;

      // parse : BindAlias = BindName(, BindAlias = BindName)*;
      //       : BindName(, BindName)*;
      if (token.type == T.Colon)
      {
        string bindName, bindAlias;
        do
        {
          nT();
          bindAlias = requireIdentifier();

          if (token.type == T.Assign)
          {
            nT();
            bindName = requireIdentifier();
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

    string enumName;
    Type baseType;
    string[] members;
    Expression[] values;
    bool hasBody;

    nT(); // Skip enum keyword.
    enumName = requireIdentifier();

    if (token.type == T.Colon)
    {
      nT();
      baseType = parseBasicType();
    }

    if (token.type == T.Semicolon)
    {
      //if (ident.length == 0)
        // TODO: issue error msg
      nT();
    }
    else if (token.type == T.LBrace)
    {
      hasBody = true;
      nT();
      do
      {
        members ~= requireIdentifier();

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

    return new EnumDeclaration(enumName, baseType, members, values, hasBody);
  }

  Declaration parseClassDeclaration()
  {
    assert(token.type == T.Class);

    string className;
    TemplateParameter[] tparams;
    BaseClass[] bases;
    Declaration[] decls;
    bool hasBody;

    nT(); // Skip class keyword.
    className = requireIdentifier();

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

    string name;
    TemplateParameter[] tparams;
    BaseClass[] bases;
    Declaration[] decls;
    bool hasBody;

    nT(); // Skip interface keyword.
    name = requireIdentifier();

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

    string name;
    TemplateParameter[] tparams;
    Declaration[] decls;
    bool hasBody;

    nT(); // Skip struct or union keyword.
    // name is optional.
    if (token.type == T.Identifier)
    {
      name = token.identifier;
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
    auto funcBody = parseFunctionBody(new FunctionBody);
    return new ConstructorDeclaration(parameters, funcBody);
  }

  Declaration parseDestructorDeclaration()
  {
    assert(token.type == T.Tilde);
    nT(); // Skip ~
    require(T.This);
    require(T.LParen);
    require(T.RParen);
    auto funcBody = parseFunctionBody(new FunctionBody);
    return new DestructorDeclaration(funcBody);
  }

  Declaration parseStaticConstructorDeclaration()
  {
    assert(token.type == T.Static);
    nT(); // Skip static keyword.
    nT(); // Skip 'this' keyword.
    require(T.LParen);
    require(T.RParen);
    auto funcBody = parseFunctionBody(new FunctionBody);
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
    auto funcBody = parseFunctionBody(new FunctionBody);
    return new StaticDestructorDeclaration(funcBody);
  }

  Declaration parseInvariantDeclaration()
  {
    assert(token.type == T.Invariant);
    nT(); // Skip invariant keyword.
    // Optional () for getting ready porting to D 2.0
    if (token.type == T.LParen)
      requireNext(T.RParen);
    auto funcBody = parseFunctionBody(new FunctionBody);
    return new InvariantDeclaration(funcBody);
  }

  Declaration parseUnittestDeclaration()
  {
    assert(token.type == T.Unittest);

    nT(); // Skip unittest keyword.
    auto funcBody = parseFunctionBody(new FunctionBody);
    return new UnittestDeclaration(funcBody);
  }

  Declaration parseDebugDeclaration()
  {
    assert(token.type == T.Debug);

    nT(); // Skip debug keyword.

    int levelSpec = -1; // debug = Integer ;
    string identSpec;   // debug = Identifier ;
    int levelCond = -1; // debug ( Integer )
    string identCond;   // debug ( Identifier )
    Declaration[] decls, elseDecls;

    void parseIdentOrInt(ref string ident, ref int level)
    {
      nT();
      if (token.type == T.Int32)
        level = token.int_;
      else if (token.type == T.Identifier)
        ident = token.identifier;
      else
      {
        expected(T.Identifier); // TODO: better error msg
        return;
      }
      nT();
    }

    if (token.type == T.Assign)
    {
      parseIdentOrInt(identSpec, levelSpec);
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
        parseIdentOrInt(identCond, levelCond);
        require(T.RParen);
      }

      // debug DeclarationsBlock
      // debug ( Condition ) DeclarationsBlock
      decls = parseDeclarationsBlock();

      // else DeclarationsBlock
      // debug without condition and else body makes no sense
      if (token.type == T.Else && (levelCond != -1 || identCond.length != 0))
      {
        nT();
        //if (token.type == T.Colon)
          // TODO: avoid "else:"?
        elseDecls = parseDeclarationsBlock();
      }
//       else
        // TODO: issue error msg
    }

    return new DebugDeclaration(levelSpec, identSpec, levelCond, identCond, decls, elseDecls);
  }

  Declaration parseVersionDeclaration()
  {
    assert(token.type == T.Version);

    nT(); // Skip version keyword.

    int levelSpec = -1; // version = Integer ;
    string identSpec;   // version = Identifier ;
    int levelCond = -1; // version ( Integer )
    string identCond;   // version ( Identifier )
    Declaration[] decls, elseDecls;

    void parseIdentOrInt(ref string ident, ref int level)
    {
      if (token.type == T.Int32)
        level = token.int_;
      else if (token.type == T.Identifier)
        ident = token.identifier;
      else
      {
        expected(T.Identifier); // TODO: better error msg
        return;
      }
      nT();
    }

    if (token.type == T.Assign)
    {
      nT();
      parseIdentOrInt(identSpec, levelSpec);
      require(T.Semicolon);
    }
    else
    {
      // Condition:
      //     Integer
      //     Identifier

      // ( Condition )
      require(T.LParen);
      parseIdentOrInt(identCond, levelCond);
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

    return new VersionDeclaration(levelSpec, identSpec, levelCond, identCond, decls, elseDecls);
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
    auto templateName = requireIdentifier();
    auto templateParams = parseTemplateParameterList();
    auto decls = parseDeclarationDefinitionsBlock();
    return new TemplateDeclaration(templateName, templateParams, decls);
  }

  Declaration parseNewDeclaration()
  {
    assert(token.type == T.New);
    nT(); // Skip new keyword.
    auto parameters = parseParameterList();
    auto funcBody = parseFunctionBody(new FunctionBody);
    return new NewDeclaration(parameters, funcBody);
  }

  Declaration parseDeleteDeclaration()
  {
    assert(token.type == T.Delete);
    nT(); // Skip delete keyword.
    auto parameters = parseParameterList();
    // TODO: only one parameter of type void* allowed. Check in parsing or semantic phase?
    auto funcBody = parseFunctionBody(new FunctionBody);
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
            Identifier !( TemplateArgumentList )
  +/
  DotListExpression parseDotListExpression()
  {
    Expression[] identList;
    if (token.type == T.Dot)
    {
      nT();
      identList ~= new IdentifierExpression(".");
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
      string ident = requireIdentifier();
      Token next;
      lx.peek(next);
      if (token.type == T.Not && next.type == T.LParen) // Identifier !( TemplateArguments )
      {
        nT(); // Skip !.
        identList ~= new TemplateInstanceExpression(ident, parseTemplateArguments());
      }
      else // Identifier
        identList ~= new IdentifierExpression(ident);

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
            Identifier !( TemplateArgumentList )
  +/
  DotListType parseDotListType()
  {
    Type[] identList;
    if (token.type == T.Dot)
    {
      nT();
      identList ~= new IdentifierType(".");
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
      string ident = requireIdentifier();
      // NB.: Currently Types can't be followed by "!=" so we don't need to peek for "(" when parsing TemplateInstances.
      /+Token next;
      lx.peek(next);+/
      if (token.type == T.Not/+ && next.type == T.LParen+/) // Identifier !( TemplateArguments )
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
            mixin TemplateIdentifier !( TemplateArgumentList ) ;
            mixin TemplateIdentifier !( TemplateArgumentList ) MixinIdentifier ;
  */
  Declaration parseMixinDeclaration()
  {
    assert(token.type == T.Mixin);
    nT(); // Skip mixin keyword.

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
    string mixinIdent;

    // This code is similar to parseDotListType().
    if (token.type == T.Dot)
    {
      nT();
      templateIdent ~= new IdentifierExpression(".");
    }

    while (1)
    {
      string ident = requireIdentifier();
      if (token.type == T.Not) // Identifier !( TemplateArguments )
      {
        // No need to peek for T.LParen. This must be a template instance.
        nT();
        templateIdent ~= new TemplateInstanceExpression(ident, parseTemplateArguments());
      }
      else // Identifier
        templateIdent ~= new IdentifierExpression(ident);

      if (token.type != T.Dot)
        break;
      nT();
    }

    if (token.type == T.Identifier)
    {
      mixinIdent = token.identifier;
      nT();
    }

    require(T.Semicolon);

    return new MixinDeclaration(templateIdent, mixinIdent);
  }

  /+++++++++++++++++++++++++++++
  + Statement parsing methods  +
  +++++++++++++++++++++++++++++/

  Statements parseStatements()
  {
    auto statements = new Statements();
    while (token.type != T.RBrace && token.type != T.EOF)
      statements ~= parseStatement();
    return statements;
  }

  Statement parseStatement()
  {
    assert(token.type != T.RBrace && token.type != T.EOF);

// writefln("°parseStatement:(%d)token='%s'°", lx.loc, token.srcText);

    Statement s;
    Declaration d;
    switch (token.type)
    {
    case T.Extern,
         T.Align:
      d = parseAttributeSpecifier();
      goto case_DeclarationStatement;
/+ Not applicable for statements.
//          T.Deprecated,
//          T.Private,
//          T.Package,
//          T.Protected,
//          T.Public,
//          T.Export,
//          T.Override,
//          T.Abstract,
+/
         //T.Pragma,
         //T.Static,
    case T.Final,
         T.Const,
         T.Auto/+,
         T.Scope+/:
    case_parseAttribute:
      s = parseAttributeStatement();
      break;
    case T.Identifier:
      Token next;
      lx.peek(next);
      if (next.type == T.Colon)
      {
        string ident = token.identifier;
        nT(); // Skip Identifier
        nT(); // Skip :
        s = new LabeledStatement(ident, parseNoScopeStatement());
        break;
      }
      goto case T.Dot;
    case T.Dot, T.Typeof:
      bool success;
      d = try_(parseDeclaration(), success);
// writefln("parseDeclaration()=", failed?"failed":"success");
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
      Token next;
      lx.peek(next);
      if (next.type != T.LParen)
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
      s = new MixinStatement(parseMixinDeclaration());
      break;
    case T.Static:
      Token next;
      lx.peek(next);
      switch (next.type)
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
      assert(0);
    case T.Debug:
      s = parseDebugStatement();
      break;
    case T.Version:
      s = parseVersionStatement();
      break;
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
      s = new DeclarationStatement(d);
      break;
    case T.LBrace:
      s = parseScopeStatement();
      break;
    case T.Semicolon:
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
        s = new IllegalStatement(token.type);
        nT();
      }
    }
    assert(s !is null);
//     writef("§%s§", s.classinfo.name);
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

  Statement parseAttributeStatement()
  {
    switch (token.type)
    {
    case T.Static,
         T.Final,
         T.Const,
         T.Auto,
         T.Scope:
      TOK tok = token.type;
      nT();
      return new AttributeStatement(tok, parseStatement());
    default:
    }
    assert(0);
  }

  Statement parseIfStatement()
  {
    assert(token.type == T.If);
    nT();

    Type type;
    string ident;
    Expression condition;
    Statement ifBody, elseBody;

    require(T.LParen);
    // auto Identifier = Expression
    if (token.type == T.Auto)
    {
      nT();
      ident = requireIdentifier();
      require(T.Assign);
    }
    else
    {
      // Declarator = Expression
      bool success;
      type = try_(parseDeclarator(ident), success);
      if (success)
      {
        require(T.Assign);
      }
      else
      {
        type = null;
        ident = null;
      }
    }
    condition = parseExpression();
    require(T.RParen);
    ifBody = parseScopeStatement();
    if (token.type == T.Else)
    {
      nT();
      elseBody = parseScopeStatement();
    }
    return new IfStatement(type, ident, condition, ifBody, elseBody);
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
    require(T.Semicolon);
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

    Parameters params;
    Expression aggregate;

    require(T.LParen);
    while (1)
    {
      StorageClass stc;
      Type type;
      string ident;

      switch (token.type)
      {
      case T.Ref:
        nT();
        stc = StorageClass.Ref;
        break;
      case T.Identifier:
        Token next;
        lx.peek(next);
        if (next.type == T.Comma || next.type == T.Semicolon || next.type == T.RParen)
        {
          ident = token.identifier;
          nT();
          break;
        }
        // fall through
      default:
        type = parseDeclarator(ident);
      }

      params ~= new Parameter(stc, type, ident, null);

      if (token.type != T.Comma)
        break;
      nT();
    }
    require(T.Semicolon);
    aggregate = parseExpression();
    require(T.RParen);
    auto forBody = parseScopeStatement();
    return new ForeachStatement(tok, params, aggregate, forBody);
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

    auto caseBody = parseScopeStatement();
    return new CaseStatement(values, caseBody);
  }

  Statement parseDefaultStatement()
  {
    assert(token.type == T.Default);
    nT();
    require(T.Colon);
    return new DefaultStatement(parseScopeStatement());
  }

  Statement parseContinueStatement()
  {
    assert(token.type == T.Continue);
    nT();
    string ident;
    if (token.type == T.Identifier)
    {
      ident = token.identifier;
      nT();
    }
    require(T.Semicolon);
    return new ContinueStatement(ident);
  }

  Statement parseBreakStatement()
  {
    assert(token.type == T.Break);
    nT();
    string ident;
    if (token.type == T.Identifier)
    {
      ident = token.identifier;
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
    string ident;
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
      ident = requireIdentifier();
      nT();
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
        string ident;
        auto type = parseDeclarator(ident);
        param = new Parameter(StorageClass.None, type, ident, null);
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

    string condition = requireIdentifier();
    if (condition.length)
      switch (condition)
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

    string ident;
    Expression[] args;
    Statement pragmaBody;

    require(T.LParen);
    ident = requireIdentifier();

    if (token.type == T.Comma)
      args = parseArguments(T.RParen);
    else
      require(T.RParen);

    if (token.type == T.Semicolon)
      nT();
    else
      pragmaBody = parseNoScopeStatement();

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

//     int levelSpec = -1; // debug = Integer ;
//     string identSpec;   // debug = Identifier ;
    int levelCond = -1; // debug ( Integer )
    string identCond;   // debug ( Identifier )
    Statement debugBody, elseBody;

    void parseIdentOrInt(ref string ident, ref int level)
    {
      nT();
      if (token.type == T.Int32)
        level = token.int_;
      else if (token.type == T.Identifier)
        ident = token.identifier;
      else
        expected(T.Identifier); // TODO: better error msg
      nT();
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
        parseIdentOrInt(identCond, levelCond);
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

    return new DebugStatement(/+levelSpec, identSpec,+/ levelCond, identCond, debugBody, elseBody);
  }

  Statement parseVersionStatement()
  {
    assert(token.type == T.Version);

    nT(); // Skip version keyword.

//     int levelSpec = -1; // version = Integer ;
//     string identSpec;   // version = Identifier ;
    int levelCond = -1; // version ( Integer )
    string identCond;   // version ( Identifier )
    Statement versionBody, elseBody;

    void parseIdentOrInt(ref string ident, ref int level)
    {
      if (token.type == T.Int32)
        level = token.int_;
      else if (token.type == T.Identifier)
        ident = token.identifier;
      else
      {
        expected(T.Identifier); // TODO: better error msg
        return;
      }
      nT();
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
      parseIdentOrInt(identCond, levelCond);
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

    return new VersionStatement(/+levelSpec, identSpec,+/ levelCond, identCond, versionBody, elseBody);
  }

  /+++++++++++++++++++++++++++++
  + Assembler parsing methods  +
  +++++++++++++++++++++++++++++/

  Statement parseAsmStatement()
  {
    assert(token.type == T.Asm);
    // TODO: implement asm statements parser.
    return null;
  }

  /+++++++++++++++++++++++++++++
  + Expression parsing methods +
  +++++++++++++++++++++++++++++/

  Expression parseExpression()
  {
    auto e = parseAssignExpression();
    while (token.type == T.Comma)
      e = new CommaExpression(e, parseAssignExpression());
// if (!trying)
// writef("§%s§", e.classinfo.name);
    return e;
  }

  Expression parseAssignExpression()
  {
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
    }
    return e;
  }

  Expression parseCondExpression()
  {
    auto e = parseOrOrExpression();
    if (token.type == T.Question)
    {
      nT();
      auto iftrue = parseExpression();
      require(T.Colon);
      auto iffalse = parseCondExpression();
      e = new CondExpression(e, iftrue, iffalse);
    }
    return e;
  }

  Expression parseOrOrExpression()
  {
    alias parseAndAndExpression parseNext;
    auto e = parseNext();
    if (token.type == T.OrLogical)
    {
      nT();
      e = new OrOrExpression(e, parseNext());
    }
    return e;
  }

  Expression parseAndAndExpression()
  {
    alias parseOrExpression parseNext;
    auto e = parseNext();
    if (token.type == T.AndLogical)
    {
      nT();
      e = new AndAndExpression(e, parseNext());
    }
    return e;
  }

  Expression parseOrExpression()
  {
    alias parseXorExpression parseNext;
    auto e = parseNext();
    if (token.type == T.OrBinary)
    {
      nT();
      e = new OrExpression(e, parseNext());
    }
    return e;
  }

  Expression parseXorExpression()
  {
    alias parseAndExpression parseNext;
    auto e = parseNext();
    if (token.type == T.Xor)
    {
      nT();
      e = new XorExpression(e, parseNext());
    }
    return e;
  }

  Expression parseAndExpression()
  {
    alias parseCmpExpression parseNext;
    auto e = parseNext();
    if (token.type == T.AndBinary)
    {
      nT();
      e = new AndExpression(e, parseNext());
    }
    return e;
  }

  Expression parseCmpExpression()
  {
    auto e = parseShiftExpression();

    TOK operator = token.type;
    switch (operator)
    {
    case T.Equal, T.NotEqual:
      nT();
      e = new EqualExpression(e, parseShiftExpression(), operator);
      break;
    case T.Not:
      Token t;
      lx.peek(t);
      if (t.type != T.Is)
        break;
      nT();
      operator = T.NotIdentity;
      goto LNotIdentity;
    case T.Identity:
      operator = T.Identity;
    LNotIdentity:
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
    }
    return e;
  }

  Expression parseShiftExpression()
  {
    auto e = parseAddExpression();
    while (1)
    {
      switch (token.type)
      {
      case T.LShift:  nT(); e = new LShiftExpression(e, parseAddExpression()); break;
      case T.RShift:  nT(); e = new RShiftExpression(e, parseAddExpression()); break;
      case T.URShift: nT(); e = new URShiftExpression(e, parseAddExpression()); break;
      default: break;
      }
      break;
    }
    return e;
  }

  Expression parseAddExpression()
  {
    auto e = parseMulExpression();
    while (1)
    {
      switch (token.type)
      {
      case T.Plus:  nT(); e = new PlusExpression(e, parseMulExpression()); break;
      case T.Minus: nT(); e = new MinusExpression(e, parseMulExpression()); break;
      case T.Tilde: nT(); e = new CatExpression(e, parseMulExpression()); break;
      default: break;
      }
      break;
    }
    return new Expression();
  }

  Expression parseMulExpression()
  {
    auto e = parseUnaryExpression();
    while (1)
    {
      switch (token.type)
      {
      case T.Mul: nT(); e = new MulExpression(e, parseUnaryExpression()); break;
      case T.Div: nT(); e = new DivExpression(e, parseUnaryExpression()); break;
      case T.Mod: nT(); e = new ModExpression(e, parseUnaryExpression()); break;
      default: break;
      }
      break;
    }
    return new Expression();
  }

  Expression parseUnaryExpression()
  {
    Expression e;
    switch (token.type)
    {
    case T.AndBinary:
      nT(); e = new AddressExpression(parseUnaryExpression());
      break;
    case T.PlusPlus:
      nT(); e = new PreIncrExpression(parseUnaryExpression());
      break;
    case T.MinusMinus:
      nT(); e = new PreDecrExpression(parseUnaryExpression());
      break;
    case T.Mul:
      nT(); e = new DerefExpression(parseUnaryExpression());
      break;
    case T.Minus:
    case T.Plus:
      nT(); e = new SignExpression(parseUnaryExpression(), token.type);
      break;
    case T.Not:
      nT(); e = new NotExpression(parseUnaryExpression());
      break;
    case T.Tilde:
      nT(); e = new CompExpression(parseUnaryExpression());
      break;
    case T.New:
      e = parseNewExpression();
      break;
    case T.Delete:
      nT();
      e = new DeleteExpression(parseUnaryExpression());
      break;
    case T.Cast:
      requireNext(T.LParen);
      auto type = parseType();
      require(T.RParen);
      e = new CastExpression(parseUnaryExpression(), type);
      break;
    case T.LParen:
      // ( Type ) . Identifier
      auto type = parseType();
      require(T.RParen);
      require(T.Dot);
      string ident = requireIdentifier();
      e = new TypeDotIdExpression(type, ident);
      break;
    default:
      e = parsePostExpression(parsePrimaryExpression());
      break;
    }
    assert(e !is null);
    return e;
  }

  Expression parsePostExpression(Expression e)
  {
    while (1)
    {
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
          Token next;
          lx.peek(next);
          if (token.type == T.Not && next.type == T.LParen) // Identifier !( TemplateArguments )
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
        break;
      case T.PlusPlus:
        e = new PostIncrExpression(e);
        break;
      case T.MinusMinus:
        e = new PostDecrExpression(e);
        break;
      case T.LParen:
        e = new CallExpression(e, parseArguments(T.RParen));
        continue;
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
          continue;
        }
        else if (token.type == T.Comma)
        {
           es ~= parseArguments(T.RBracket);
        }
        else
          require(T.RBracket);

        e = new IndexExpression(e, es);
        continue;
      default:
        return e;
      }
      nT();
    }
    assert(0);
  }

  Expression parsePrimaryExpression()
  {
    Expression e;
    switch (token.type)
    {
/*
// Commented out because parseDotListExpression() handles this.
    case T.Identifier:
      string ident = token.identifier;
      nT();
      Token next;
      lx.peek(next);
      if (token.type == T.Not && next.type == T.LParen) // Identifier !( TemplateArguments )
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
      e = new BoolExpression(token.type == T.True ? true : false);
      break;
    case T.Dollar:
      nT();
      e = new DollarExpression();
      break;
    case T.Int32, T.Int64, T.Uint32, T.Uint64:
      nT();
      e = new IntNumberExpression(token.type, token.ulong_);
      break;
    case T.Float32, T.Float64, T.Float80,
         T.Imaginary32, T.Imaginary64, T.Imaginary80:
      nT();
      e = new RealNumberExpression(token.type, token.real_);
      break;
    case T.CharLiteral, T.WCharLiteral, T.DCharLiteral:
      nT();
      e = new CharLiteralExpression(token.type);
      break;
    case T.String:
      // TODO: The Lexer doesn't allocate the tokens on the heap yet. So Token* will not work here.
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

      e = new ArrayLiteralExpression(values);
      break;

    LparseAssocArray:
      Expression[] keys;

      keys ~= e;
      nT(); // Skip colon.
      values ~= parseAssignExpression();

      if (token.type != T.RBracket)
      {
        require(T.Comma);
        while (1)
        {
          keys ~= parseAssignExpression();
          if (token.type != T.Colon)
          {
            expected(T.Colon);
            values ~= null;
            if (token.type == T.RBracket)
              break;
            else
              continue;
          }
          nT();
          values ~= parseAssignExpression();
          if (token.type == T.RBracket)
            break;
          require(T.Comma);
        }
      }
      assert(token.type == T.RBracket);
      nT();
      e = new AssocArrayLiteralExpression(keys, values);
      break;
    case T.LBrace:
      // DelegateLiteral := { Statements }
      auto funcType = new FunctionType(null, Parameters.init);
      auto funcBody = parseFunctionBody(new FunctionBody);
      e = new FunctionLiteralExpression(funcType, funcBody);
      break;
    case T.Function, T.Delegate:
      // FunctionLiteral := (function|delegate) Type? '(' ArgumentList ')' '{' Statements '}'
      TOK funcTok = token.type;
      nT(); // Skip function|delegate token.
      Type returnType;
      Parameters parameters;
      if (token.type != T.LBrace)
      {
        if (token.type != T.LParen) // Optional return type
          returnType = parseType();
        parameters = parseParameterList();
      }
      auto funcType = new FunctionType(returnType, parameters);
      auto funcBody = parseFunctionBody(new FunctionBody);
      e = new FunctionLiteralExpression(funcType, funcBody, funcTok);
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

      Type type;
      SpecializationType specType;
      string ident; // optional Identifier

      type = parseDeclarator(ident, true);

      switch (token.type)
      {
      case T.Colon, T.Equal:
        TOK specTok = token.type;
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
          nT();
          specType = new SpecializationType(specTok, token.type);
          break;
        default:
          specType = new SpecializationType(specTok, parseType());
        }
      default:
      }
      require(T.RParen);
      e = new IsExpression(type, ident, specType);
      break;
    case T.LParen:
      Token t;
      bool success;
      auto parameters = try_(parseParameterList(), success);
      if (success)
      {
        // ( ParameterList ) FunctionBody
        auto funcType = new FunctionType(null, parameters);
        auto funcBody = parseFunctionBody(new FunctionBody);
        e = new FunctionLiteralExpression(funcType, funcBody);
      }
      else
      {
        // ( Expression )
        nT();
        e = parseExpression();
        require(T.RParen);
      }
      break;
    // BasicType . Identifier
    case T.Char,   T.Wchar,   T.Dchar,  T.Bool,
         T.Byte,   T.Ubyte,   T.Short,  T.Ushort,
         T.Int,    T.Uint,    T.Long,   T.Ulong,
         T.Float,  T.Double,  T.Real,
         T.Ifloat, T.Idouble, T.Ireal,
         T.Cfloat, T.Cdouble, T.Creal, T.Void:
      auto type = new Type(token.type);
      requireNext(T.Dot);
      auto ident = requireIdentifier();

      e = new TypeDotIdExpression(type, ident);
      break;
    default:
      // TODO: issue error msg.
      error(MID.ExpectedButFound, "Expression", token.srcText);
      e = new EmptyExpression();
    }
    return e;
  }

  Expression parseNewExpression(/*Expression e*/)
  {
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
      return new NewAnonClassExpression(/*e, */newArguments, bases, ctorArguments, decls);
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
    return new NewExpression(/*e, */newArguments, type, ctorArguments);
  }

  Type parseType()
  {
    return parseBasicType2(parseBasicType());
  }

  Type parseBasicType()
  {
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
      t = new Type(token.type);
      nT();
      break;
/+
    case T.Identifier, T.Dot:
      tident = new IdentifierType([token.identifier]);
      nT();
      // TODO: parse template instance
//       if (token.type == T.Not)
//         parse template instance
    Lident:
      while (token.type == T.Dot)
      {
        nT();
        tident ~= requireIdentifier();
      // TODO: parse template instance
//       if (token.type == T.Not)
//         parse template instance
      }
      t = tident;
      break;
    case T.Typeof:
      requireNext(T.LParen);
      tident = new TypeofType(parseExpression());
      require(T.RParen);
      goto Lident;
+/
    case T.Identifier, T.Typeof, T.Dot:
      t = parseDotListType();
      break;
    default:
      // TODO: issue error msg.
      error(MID.ExpectedButFound, "BasicType", token.srcText);
      t = new UndefinedType();
    }
    return t;
  }

  Type parseBasicType2(Type t)
  {
    while (1)
    {
      switch (token.type)
      {
      case T.Mul:
        t = new PointerType(t);
        nT();
        break;
      case T.LBracket:
        t = parseArrayType(t);
        break;
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
    }
    assert(0);
  }

  bool isTemplateParameterList()
  {
    // We count nested parentheses tokens because template types may appear inside parameter lists; e.g. (int x, Foo!(int) y).
    Token t;
    uint level = 1;
    while (1)
    {
      lx.peek(t);
      switch (t.type)
      {
      case T.RParen:
        if (--level == 0)
        { // Closing parentheses found.
          lx.peek(t);
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
    if (t.type == T.LParen)
      return true;
    return false;
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
      TemplateParameter[] tparams;
      if (isTemplateParameterList())
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
    return t;
  }

  Type parseDeclarator(ref string ident, bool identOptional = false)
  {
    auto t = parseType();

    if (token.type == T.Identifier)
    {
      ident = token.identifier;
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
    require(T.LParen);

    if (token.type == T.RParen)
    {
      nT();
      return Parameters.init;
    }

    Parameters params;
    StorageClass stc;

    while (1)
    {
      stc = StorageClass.In;
      switch (token.type)
      {
      case T.In:   stc = StorageClass.In;   nT(); goto default;
      case T.Out:  stc = StorageClass.Out;  nT(); goto default;
      case T.Ref:  stc = StorageClass.Ref;  nT(); goto default;
      case T.Lazy: stc = StorageClass.Lazy; nT(); goto default;
      case T.Ellipses:
        params ~= new Parameter(StorageClass.Variadic, null, null, null);
        break;
      default:
        string ident;
        auto type = parseDeclarator(ident, true);

        Expression assignExpr;
        if (token.type == T.Assign)
        {
          nT();
          assignExpr = parseAssignExpression();
        }

        if (token.type == T.Ellipses)
        {
          stc |= StorageClass.Variadic;
          params ~= new Parameter(stc, type, ident, assignExpr);
          nT();
          break;
        }

        params ~= new Parameter(stc, type, ident, assignExpr);
        if (token.type == T.Comma)
        {
          nT();
          continue;
        }
        break;
      }
      break;
    }
    require(T.RParen);
    return params;
  }

  TemplateArguments parseTemplateArguments()
  {
    TemplateArguments args;

    require(T.LParen);
    if (token.type == T.RParen)
    {
      nT();
      return null;
    }

    goto LenterLoop;
    do
    {
      nT(); // Skip comma.
    LenterLoop:

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
    } while (token.type == T.Comma)

    require(T.RParen);
    return args;
  }

  TemplateParameter[] parseTemplateParameterList()
  {
    require(T.LParen);
    if (token.type == T.RParen)
      return null;

    TemplateParameter[] tparams;
    while (1)
    {
      TP tp;
      string ident;
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
        ident = requireIdentifier();
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
        ident = token.identifier;
        Token peeked;
        lx.peek(peeked);
        switch (peeked.type)
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

      tparams ~= new TemplateParameter(tp, valueType, ident, specType, defType, specValue, defValue);

      if (token.type != T.Comma)
        break;
      nT();
    }
    require(T.RParen);
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
