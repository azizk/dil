/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.parser.ImportParser;

import dil.parser.Parser;
import dil.lexer.Tables;
import dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Statements;
import dil.SourceText,
       dil.Enums;
import common;

/// A light-weight parser which looks only for import statements
/// in the source text.
class ImportParser : Parser
{
  this(SourceText srcText, LexerTables tables)
  {
    super(srcText, tables);
  }

  override CompoundDecl start()
  {
    auto decls = new CompoundDecl;
    super.init();
    if (token.kind == T!"module")
      decls ~= parseModuleDecl();
    while (token.kind != T!"EOF")
      parseDeclarationDefinition(Protection.None);
    return decls;
  }

  void parseDeclarationDefinitionsBlock(Protection prot)
  {
    skip(T!"{");
    while (token.kind != T!"}" && token.kind != T!"EOF")
      parseDeclarationDefinition(prot);
    skip(T!"}");
  }

  void parseDeclarationsBlock(Protection prot)
  {
    switch (token.kind)
    {
    case T!"{":
      parseDeclarationDefinitionsBlock(prot);
      break;
    case T!":":
      nT();
      while (token.kind != T!"}" && token.kind != T!"EOF")
        parseDeclarationDefinition(prot);
      break;
    default:
      parseDeclarationDefinition(prot);
    }
  }

  bool skipToClosing(TOK opening, TOK closing)
  {
    alias next = token;
    uint level = 1;
    while (1)
    {
      lexer.peek(next);
      if (next.kind == opening)
        ++level;
      else if (next.kind == closing && --level == 0)
        return true;
      else if (next.kind == T!"EOF")
        break;
    }
    return false;
  }

  void skipToTokenAfterClosingParen()
  {
    skipToClosing(T!"(", T!")");
    nT();
  }

  void skipToTokenAfterClosingBrace()
  {
    skipToClosing(T!"{", T!"}");
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
    case T!"private":
      prot = Protection.Private; break;
    case T!"package":
      prot = Protection.Package; break;
    case T!"protected":
      prot = Protection.Protected; break;
    case T!"public":
      prot = Protection.Public; break;
    case T!"export":
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
    case T!"align":
      nT();
      if (token.kind == T!"(")
        nT(), nT(), nT(); // ( Integer )
      parseDeclarationsBlock(prot);
      break;
    case T!"pragma":
      nT();
      skipToTokenAfterClosingParen();
      parseDeclarationsBlock(prot);
      break;
    case T!"export",
         T!"private",
         T!"package",
         T!"protected",
         T!"public":
      parseProtectionAttribute();
      break;
    // Storage classes
    case T!"extern":
      nT();
      token.kind == T!"(" && skipToTokenAfterClosingParen();
      parseDeclarationsBlock(prot);
      break;
    case T!"const":
    version(D2)
    {
      if (peekNext() == T!"(")
        goto case_Declaration;
    }
      goto case;
    case T!"override",
         T!"deprecated",
         T!"abstract",
         T!"synchronized",
         // T!"static",
         T!"final",
         T!"auto",
         T!"scope":
    case_StaticAttribute:
    case_InvariantAttribute:
      nT();
      parseDeclarationsBlock(prot);
      break;
    // End of storage classes.
    case T!"alias", T!"typedef":
      nT();
      goto case_Declaration;
    case T!"static":
      switch (peekNext())
      {
      case T!"import":
        goto case_Import;
      case T!"this":
        nT(), nT(); // static this
        skipToTokenAfterClosingParen();
        skipFunctionBody();
        break;
      case T!"~":
        nT(), nT(), nT(), nT(), nT(); // static ~ this ( )
        skipFunctionBody();
        break;
      case T!"if":
        nT(), nT();
        skipToTokenAfterClosingParen();
        parseDeclarationsBlock(prot);
        if (token.kind == T!"else")
          nT(), parseDeclarationsBlock(prot);
        break;
      case T!"assert":
        nT(), nT(); // static assert
        skipToTokenAfterClosingParen();
        skip(T!";");
        break;
      default:
        goto case_StaticAttribute;
      }
      break;
    case T!"import":
    case_Import:
      auto decl = parseImportDecl();
      decl.setProtection(prot); // Set the protection attribute.
      imports ~= decl.to!(ImportDecl);
      break;
    case T!"enum":
      nT();
      token.kind == T!"Identifier" && nT();
      if (token.kind == T!":")
      {
        nT();
        while (token.kind != T!"{" && token.kind != T!"EOF")
          nT();
      }
      if (token.kind == T!";")
        nT();
      else
        skipToTokenAfterClosingBrace();
      break;
    case T!"class", T!"interface":
      nT(), skip(T!"Identifier"); // class Identifier
      token.kind == T!"(" && skipToTokenAfterClosingParen(); // Skip template params.
      if (token.kind == T!":")
      { // BaseClasses
        nT();
        while (token.kind != T!"{" && token.kind != T!"EOF")
          if (token.kind == T!"(") // Skip ( tokens... )
            skipToTokenAfterClosingParen();
          else
            nT();
      }
      if (token.kind == T!";")
        nT();
      else
        parseDeclarationDefinitionsBlock(Protection.None);
      break;
    case T!"struct", T!"union":
      nT(); skip(T!"Identifier");
      token.kind == T!"(" && skipToTokenAfterClosingParen();
      if (token.kind == T!";")
        nT();
      else
        parseDeclarationDefinitionsBlock(Protection.None);
      break;
    case T!"~":
      nT();
      goto case;
    case T!"this":
      nT(); nT(); nT(); // this ( )
      skipFunctionBody();
      break;
    case T!"invariant":
    version(D2)
    {
      auto next = peekAfter(token);
      if (next.kind == T!"(")
      {
        if (peekAfter(next).kind != T!")")
          goto case_Declaration;
      }
      else
        goto case_InvariantAttribute;
    }
      nT();
      token.kind == T!"(" && skipToTokenAfterClosingParen();
      skipFunctionBody();
      break;
    case T!"unittest":
      nT();
      skipFunctionBody();
      break;
    case T!"debug":
      nT();
      if (token.kind == T!"=")
      {
        nT(), nT(), nT(); // = Condition ;
        break;
      }
      if (token.kind == T!"(")
        nT(), nT(), nT(); // ( Condition )
      parseDeclarationsBlock(prot);
      if (token.kind == T!"else")
        nT(), parseDeclarationsBlock(prot);
      break;
    case T!"version":
      nT();
      if (token.kind == T!"=")
      {
        nT(), nT(), nT(); // = Condition ;
        break;
      }
      nT(), nT(), nT(); // ( Condition )
      parseDeclarationsBlock(prot);
      if (token.kind == T!"else")
        nT(), parseDeclarationsBlock(prot);
      break;
    case T!"template":
      nT();
      skip(T!"Identifier");
      skipToTokenAfterClosingParen();
      parseDeclarationDefinitionsBlock(Protection.None);
      break;
    case T!"new":
      nT();
      skipToTokenAfterClosingParen();
      skipFunctionBody();
      break;
    case T!"delete":
      nT();
      skipToTokenAfterClosingParen();
      skipFunctionBody();
      break;
    case T!"mixin":
      while (token.kind != T!";" && token.kind != T!"EOF")
        if (token.kind == T!"(")
          skipToTokenAfterClosingParen();
        else
          nT();
      skip(T!";");
      break;
    case T!";":
      nT();
      break;
    // Declaration
    case T!"Identifier", T!".", T!"typeof":
    case_Declaration:
      while (token.kind != T!";" && token.kind != T!"EOF")
        if (token.kind == T!"(")
          skipToTokenAfterClosingParen();
        else if (token.kind == T!"{")
          skipToTokenAfterClosingBrace();
        else
          nT();
      skip(T!";");
      break;
    default:
      if (token.isIntegralType)
        goto case_Declaration;
      nT();
    }
  }

  void skipFunctionBody()
  {
    while (1)
    {
      switch (token.kind)
      {
      case T!"{":
        skipToTokenAfterClosingBrace();
        break;
      case T!";":
        nT();
        break;
      case T!"in":
        nT();
        skipToTokenAfterClosingBrace();
        continue;
      case T!"out":
        nT();
        if (token.kind == T!"(")
          nT(), nT(), nT(); // ( Identifier )
        skipToTokenAfterClosingBrace();
        continue;
      case T!"body":
        nT();
        goto case T!"{";
      default:
      }
      break; // Exit loop.
    }
  }
}
