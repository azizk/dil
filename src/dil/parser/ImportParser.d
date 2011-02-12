/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.parser.ImportParser;

import dil.parser.Parser;
import dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Statements;
import dil.SourceText;
import dil.Tables;
import dil.Enums;
import common;

private alias TOK T;

/// A light-weight parser which looks only for import statements
/// in the source text.
class ImportParser : Parser
{
  this(SourceText srcText, Tables tables)
  {
    super(srcText, tables);
  }

  override CompoundDecl start()
  {
    auto decls = new CompoundDecl;
    super.init();
    if (token.kind == T.Module)
      decls ~= parseModuleDecl();
    while (token.kind != T.EOF)
      parseDeclarationDefinition(Protection.None);
    return decls;
  }

  void parseDeclarationDefinitionsBlock(Protection prot)
  {
    skip(T.LBrace);
    while (token.kind != T.RBrace && token.kind != T.EOF)
      parseDeclarationDefinition(prot);
    skip(T.RBrace);
  }

  void parseDeclarationsBlock(Protection prot)
  {
    switch (token.kind)
    {
    case T.LBrace:
      parseDeclarationDefinitionsBlock(prot);
      break;
    case T.Colon:
      nT();
      while (token.kind != T.RBrace && token.kind != T.EOF)
        parseDeclarationDefinition(prot);
      break;
    default:
      parseDeclarationDefinition(prot);
    }
  }

  bool skipToClosing(T opening, T closing)
  {
    alias token next;
    uint level = 1;
    while (1)
    {
      lexer.peek(next);
      if (next.kind == opening)
        ++level;
      else if (next.kind == closing && --level == 0)
        return true;
      else if (next.kind == T.EOF)
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
    token.kind == tok && nT();
  }

  void parseProtectionAttribute()
  {
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
    parseDeclarationsBlock(prot);
  }

  void parseDeclarationDefinition(Protection prot)
  {
    switch (token.kind)
    {
    case T.Align:
      nT();
      if (token.kind == T.LParen)
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
      token.kind == T.LParen && skipToTokenAfterClosingParen();
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
        if (token.kind == T.Else)
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
      auto decl = parseImportDecl();
      decl.setProtection(prot); // Set the protection attribute.
      imports ~= decl.to!(ImportDecl);
      break;
    case T.Enum:
      nT();
      token.kind == T.Identifier && nT();
      if (token.kind == T.Colon)
      {
        nT();
        while (token.kind != T.LBrace && token.kind != T.EOF)
          nT();
      }
      if (token.kind == T.Semicolon)
        nT();
      else
        skipToTokenAfterClosingBrace();
      break;
    case T.Class:
    case T.Interface:
      nT(), skip(T.Identifier); // class Identifier
      token.kind == T.LParen && skipToTokenAfterClosingParen(); // Skip template params.
      if (token.kind == T.Colon)
      { // BaseClasses
        nT();
        while (token.kind != T.LBrace && token.kind != T.EOF)
          if (token.kind == T.LParen) // Skip ( tokens... )
            skipToTokenAfterClosingParen();
          else
            nT();
      }
      if (token.kind == T.Semicolon)
        nT();
      else
        parseDeclarationDefinitionsBlock(Protection.None);
      break;
    case T.Struct, T.Union:
      nT(); skip(T.Identifier);
      token.kind == T.LParen && skipToTokenAfterClosingParen();
      if (token.kind == T.Semicolon)
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
      nT();
      token.kind == T.LParen && skipToTokenAfterClosingParen();
      parseFunctionBody();
      break;
    case T.Unittest:
      nT();
      parseFunctionBody();
      break;
    case T.Debug:
      nT();
      if (token.kind == T.Assign)
      {
        nT(), nT(), nT(); // = Condition ;
        break;
      }
      if (token.kind == T.LParen)
        nT(), nT(), nT(); // ( Condition )
      parseDeclarationsBlock(prot);
      if (token.kind == T.Else)
        nT(), parseDeclarationsBlock(prot);
      break;
    case T.Version:
      nT();
      if (token.kind == T.Assign)
      {
        nT(), nT(), nT(); // = Condition ;
        break;
      }
      nT(), nT(), nT(); // ( Condition )
      parseDeclarationsBlock(prot);
      if (token.kind == T.Else)
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
      while (token.kind != T.Semicolon && token.kind != T.EOF)
        if (token.kind == T.LParen)
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
    case_Declaration:
      while (token.kind != T.Semicolon && token.kind != T.EOF)
        if (token.kind == T.LParen)
          skipToTokenAfterClosingParen();
        else if (token.kind == T.LBrace)
          skipToTokenAfterClosingBrace();
        else
          nT();
      skip(T.Semicolon);
      break;
    default:
      if (token.isIntegralType)
        goto case_Declaration;
      nT();
    }
  }

  FuncBodyStmt parseFunctionBody()
  {
    while (1)
    {
      switch (token.kind)
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
        if (token.kind == T.LParen)
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
