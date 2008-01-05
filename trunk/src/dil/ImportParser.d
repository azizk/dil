/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ImportParser;

import dil.parser.Parser;
import dil.Token;
import dil.Enums;
import dil.Declarations;
import dil.Statements;
import dil.SyntaxTree;
import common;

private alias TOK T;

class ImportParser : Parser
{
  this(char[] srcText, string fileName)
  {
    super(srcText, fileName);
  }

  override Declarations start()
  {
    auto decls = new Declarations;
    super.init();
    if (token.type == T.Module)
      decls ~= parseModuleDeclaration();
    while (token.type != T.EOF)
      parseDeclarationDefinition(Protection.None);
    return decls;
  }

  void parseDeclarationDefinitionsBlock(Protection prot)
  {
    skip(T.LBrace);
    while (token.type != T.RBrace && token.type != T.EOF)
      parseDeclarationDefinition(prot);
    skip(T.RBrace);
  }

  void parseDeclarationsBlock(Protection prot)
  {
    switch (token.type)
    {
    case T.LBrace:
      parseDeclarationDefinitionsBlock(prot);
      break;
    case T.Colon:
      nT();
      while (token.type != T.RBrace && token.type != T.EOF)
        parseDeclarationDefinition(prot);
      break;
    default:
      parseDeclarationDefinition(prot);
    }
  }

  bool skipToClosing(T opening, T closing)
  {
    Token* next = token;
    uint level = 1;
    while (1)
    {
      lx.peek(next);
      if (next.type == opening)
        ++level;
      else if (next.type == closing && --level == 0)
        return true;
      else if (next.type == T.EOF)
        break;
    }
    return false;
  }

  void skipToTokenAfterClosingParen()
  {
    skipToClosing(T.LParen, T.RParen);
    nT();
  }

  void skipToTokenAfterClosingBrace()
  {
    skipToClosing(T.LBrace, T.RBrace);
    nT();
  }

  void skip(TOK tok)
  {
    token.type == tok && nT();
  }

  void parseProtectionAttribute()
  {
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
    parseDeclarationsBlock(prot);
  }

  void parseDeclarationDefinition(Protection prot)
  {
    switch (token.type)
    {
    case T.Align:
      nT();
      if (token.type == T.LParen)
        nT(), nT(), nT(); // ( Integer )
      parseDeclarationsBlock(prot);
      break;
    case T.Pragma:
      nT();
      skipToTokenAfterClosingParen();
      parseDeclarationsBlock(prot);
      break;
    case T.Export,
         T.Private,
         T.Package,
         T.Protected,
         T.Public:
      parseProtectionAttribute();
      break;
    // Storage classes
    case T.Extern:
      nT();
      token.type == T.LParen && skipToTokenAfterClosingParen();
      parseDeclarationsBlock(prot);
      break;
    case T.Const:
    version(D2)
    {
      if (peekNext() == T.LParen)
        goto case_Declaration;
    }
    case T.Override,
         T.Deprecated,
         T.Abstract,
         T.Synchronized,
         // T.Static,
         T.Final,
         T.Auto,
         T.Scope:
    case_StaticAttribute:
    case_InvariantAttribute:
      nT();
      parseDeclarationsBlock(prot);
      break;
    // End of storage classes.
    case T.Alias, T.Typedef:
      nT();
      goto case_Declaration;
    case T.Static:
      switch (peekNext())
      {
      case T.Import:
        goto case_Import;
      case T.This:
        nT(), nT(); // static this
        skipToTokenAfterClosingParen();
        parseFunctionBody();
        break;
      case T.Tilde:
        nT(), nT(), nT(), nT(), nT(); // static ~ this ( )
        parseFunctionBody();
        break;
      case T.If:
        nT(), nT();
        skipToTokenAfterClosingParen();
        parseDeclarationsBlock(prot);
        if (token.type == T.Else)
          nT(), parseDeclarationsBlock(prot);
        break;
      case T.Assert:
        nT(), nT(); // static assert
        skipToTokenAfterClosingParen();
        skip(T.Semicolon);
        break;
      default:
        goto case_StaticAttribute;
      }
      break;
    case T.Import:
    case_Import:
      auto decl = parseImportDeclaration();
      decl.setProtection(prot); // Set the protection attribute.
      imports ~= CastTo!(ImportDeclaration)(decl);
      break;
    case T.Enum:
      nT();
      token.type == T.Identifier && nT();
      if (token.type == T.Colon)
      {
        nT();
        while (token.type != T.LBrace && token.type != T.EOF)
          nT();
      }
      if (token.type == T.Semicolon)
        nT();
      else
        skipToTokenAfterClosingBrace();
      break;
    case T.Class:
    case T.Interface:
      nT(), skip(T.Identifier); // class Identifier
      token.type == T.LParen && skipToTokenAfterClosingParen(); // Skip template params.
      if (token.type == T.Colon)
      { // BaseClasses
        nT();
        while (token.type != T.LBrace && token.type != T.EOF)
          if (token.type == T.LParen) // Skip ( tokens... )
            skipToTokenAfterClosingParen();
          else
            nT();
      }
      if (token.type == T.Semicolon)
        nT();
      else
        parseDeclarationDefinitionsBlock(Protection.None);
      break;
    case T.Struct, T.Union:
      nT(); skip(T.Identifier);
      token.type == T.LParen && skipToTokenAfterClosingParen();
      if (token.type == T.Semicolon)
        nT();
      else
        parseDeclarationDefinitionsBlock(Protection.None);
      break;
    case T.Tilde:
      nT(); // ~
    case T.This:
      nT(); nT(); nT(); // this ( )
      parseFunctionBody();
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
      token.type == T.LParen && skipToTokenAfterClosingParen();
      parseFunctionBody();
      break;
    case T.Unittest:
      nT();
      parseFunctionBody();
      break;
    case T.Debug:
      nT();
      if (token.type == T.Assign)
      {
        nT(), nT(), nT(); // = Condition ;
        break;
      }
      if (token.type == T.LParen)
        nT(), nT(), nT(); // ( Condition )
      parseDeclarationsBlock(prot);
      if (token.type == T.Else)
        nT(), parseDeclarationsBlock(prot);
      break;
    case T.Version:
      nT();
      if (token.type == T.Assign)
      {
        nT(), nT(), nT(); // = Condition ;
        break;
      }
      nT(), nT(), nT(); // ( Condition )
      parseDeclarationsBlock(prot);
      if (token.type == T.Else)
        nT(), parseDeclarationsBlock(prot);
      break;
    case T.Template:
      nT();
      skip(T.Identifier);
      skipToTokenAfterClosingParen();
      parseDeclarationDefinitionsBlock(Protection.None);
      break;
    case T.New:
      nT();
      skipToTokenAfterClosingParen();
      parseFunctionBody();
      break;
    case T.Delete:
      nT();
      skipToTokenAfterClosingParen();
      parseFunctionBody();
      break;
    case T.Mixin:
      while (token.type != T.Semicolon && token.type != T.EOF)
        if (token.type == T.LParen)
          skipToTokenAfterClosingParen();
        else
          nT();
      skip(T.Semicolon);
      break;
    case T.Semicolon:
      nT();
      break;
    // Declaration
    case T.Identifier, T.Dot, T.Typeof:
    // IntegralType
    case T.Char,   T.Wchar,   T.Dchar,  T.Bool,
         T.Byte,   T.Ubyte,   T.Short,  T.Ushort,
         T.Int,    T.Uint,    T.Long,   T.Ulong,
         T.Float,  T.Double,  T.Real,
         T.Ifloat, T.Idouble, T.Ireal,
         T.Cfloat, T.Cdouble, T.Creal, T.Void:
    case_Declaration:
      while (token.type != T.Semicolon && token.type != T.EOF)
        if (token.type == T.LParen)
          skipToTokenAfterClosingParen();
        else if (token.type == T.LBrace)
          skipToTokenAfterClosingBrace();
        else
          nT();
      skip(T.Semicolon);
      break;
    default:
      nT();
    }
  }

  FunctionBody parseFunctionBody()
  {
    while (1)
    {
      switch (token.type)
      {
      case T.LBrace:
        skipToTokenAfterClosingBrace();
        break;
      case T.Semicolon:
        nT();
        break;
      case T.In:
        nT();
        skipToTokenAfterClosingBrace();
        continue;
      case T.Out:
        nT();
        if (token.type == T.LParen)
          nT(), nT(), nT(); // ( Identifier )
        skipToTokenAfterClosingBrace();
        continue;
      case T.Body:
        nT();
        goto case T.LBrace;
      default:
      }
      break; // Exit loop.
    }
    return null;
  }
}
