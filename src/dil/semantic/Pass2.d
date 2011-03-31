/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.semantic.Pass2;

import dil.ast.DefaultVisitor,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;
import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Types,
       dil.semantic.Scope,
       dil.semantic.Module,
       dil.semantic.Analysis;
import dil.code.Interpreter;
import dil.lexer.Identifier;
import dil.parser.Parser;
import dil.i18n.Messages;
import dil.SourceText,
       dil.Diagnostics,
       dil.Enums;
import common;

/// The second pass determines the types of symbols and the types
/// of expressions and also evaluates them.
class SemanticPass2 : DefaultVisitor
{
  Scope scop; /// The current scope.
  Module modul; /// The module to be semantically checked.

  /// Constructs a SemanticPass2 object.
  /// Params:
  ///   modul = The module to be checked.
  this(Module modul)
  {
    this.modul = modul;
  }

  /// Start semantic analysis.
  void run()
  {
    assert(modul.root !is null);
    // Create module scope.
    scop = new Scope(null, modul);
    modul.semanticPass = 2;
    visit(modul.root);
  }

  /// Enters a new scope.
  void enterScope(ScopeSymbol s)
  {
    scop = scop.enter(s);
  }

  /// Exits the current scope.
  void exitScope()
  {
    scop = scop.exit();
  }

  /// Evaluates e and returns the result.
  Expression interpret(Expression e)
  {
    return Interpreter.interpret(e, modul.cc.diag);
  }

  /// Creates an error report.
  void error(Token* token, MID mid, ...)
  {
    auto location = token.getErrorLocation(modul.filePath());
    auto msg = modul.cc.diag.formatMsg(mid, _arguments, _argptr);
    modul.cc.diag ~= new SemanticError(location, msg);
  }

  /// Some handy aliases.
  private alias Declaration D;
  private alias Expression E; /// ditto
  private alias Statement S; /// ditto
  private alias TypeNode T; /// ditto

  /// The current scope symbol to use for looking up identifiers.
  ///
  /// E.g.:
  /// ---
  /// / // * "object" is looked up in the current scope.
  /// / // * idScope is set if "object" is a ScopeSymbol.
  /// / // * "method" will be looked up in idScope.
  /// object.method();
  /// / // * "dil" is looked up in the current scope
  /// / // * idScope is set if "dil" is a ScopeSymbol.
  /// / // * "ast" will be looked up in idScope.
  /// / // * idScope is set if "ast" is a ScopeSymbol.
  /// / // * etc.
  /// dil.ast.Node.Node node;
  /// ---
  ScopeSymbol idScope;

  /// Searches for a symbol.
  Symbol search(Token* idTok)
  {
    assert(idTok.kind == TOK.Identifier);
    auto id = idTok.ident;
    Symbol symbol;

    if (idScope is null)
      symbol = scop.search(id);
    else
      symbol = idScope.lookup(id);

    if (symbol is null)
      error(idTok, MID.UndefinedIdentifier, id.str);
    else if (auto scopSymbol = cast(ScopeSymbol)symbol)
      idScope = scopSymbol;

    return symbol;
  }

override
{
  D visit(CompoundDecl d)
  {
    return super.visit(d);
  }

  D visit(EnumDecl d)
  {
    d.symbol.setCompleting();

    Type type = Types.Int32; // Default to int.
    if (d.baseType)
      type = visitT(d.baseType).type;
    // Set the enum's base type.
    d.symbol.type.baseType = type;

    // TODO: check base type. must be basic type or another enum.

    enterScope(d.symbol);

    foreach (member; d.members)
    {
      Expression finalValue;
      member.symbol.setCompleting();
      if (member.value)
      {
        member.value = visitE(member.value);
        finalValue = interpret(member.value);
        if (finalValue is Interpreter.NAR)
          finalValue = new IntExpr(0, d.symbol.type);
      }
      //else
        // TODO: increment a number variable and assign that to value.
      member.symbol.value = finalValue;
      member.symbol.setComplete();
    }

    exitScope();
    d.symbol.setComplete();
    return d;
  }

  D visit(MixinDecl md)
  {
    if (md.decls)
      return md.decls;
    if (md.isMixinExpr)
    {
      md.argument = visitE(md.argument);
      auto expr = interpret(md.argument);
      if (expr is Interpreter.NAR)
        return md;
      auto stringExpr = expr.Is!(StringExpr);
      if (stringExpr is null)
      {
        error(md.begin, MID.MixinArgumentMustBeString);
        return md;
      }
      else
      { // Parse the declarations in the string.
        auto loc = md.begin.getErrorLocation(modul.filePath());
        auto filePath = loc.filePath;
        auto sourceText = new SourceText(filePath, stringExpr.getString());
        auto lxtables = modul.cc.tables.lxtables;
        auto parser = new Parser(sourceText, lxtables, modul.cc.diag);
        md.decls = parser.start();
      }
    }
    else
    {
      // TODO: implement template mixin.
    }
    return md.decls;
  }

  // Type nodes:

  T visit(TypeofType t)
  {
    t.expr = visitE(t.expr);
    t.type = t.expr.type;
    return t;
  }

  T visit(ArrayType t)
  {
    auto baseType = visitT(t.next).type;
    if (t.isAssociative)
      t.type = baseType.arrayOf(visitT(t.assocType).type);
    else if (t.isDynamic)
      t.type = baseType.arrayOf();
    else if (t.isStatic)
    {}
    else
      assert(t.isSlice);
    return t;
  }

  T visit(PointerType t)
  {
    t.type = visitT(t.next).type.ptrTo();
    return t;
  }

  T visit(IdentifierType t)
  {
    auto idToken = t.begin;
    auto symbol = search(idToken);
    // TODO: save symbol or its type in t.
    return t;
  }

  T visit(TemplateInstanceType t)
  {
    auto idToken = t.begin;
    auto symbol = search(idToken);
    // TODO: save symbol or its type in t.
    return t;
  }

  T visit(ModuleScopeType t)
  {
    idScope = modul;
    return t;
  }

  T visit(IntegralType t)
  {
    t.type = Types.fromTOK(t.tok);
    return t;
  }

  // Expression nodes:

  E visit(ParenExpr e)
  {
    if (!e.type)
    {
      e.next = visitE(e.next);
      e.type = e.next.type;
    }
    return e;
  }

  E visit(CommaExpr e)
  {
    if (!e.type)
    {
      e.lhs = visitE(e.lhs);
      e.rhs = visitE(e.rhs);
      e.type = e.rhs.type;
    }
    return e;
  }

  E visit(OrOrExpr)
  { return null; }

  E visit(AndAndExpr)
  { return null; }

  E visit(SpecialTokenExpr e)
  {
    if (e.type)
      return e.value;
    switch (e.specialToken.kind)
    {
    case TOK.LINE, TOK.VERSION:
      e.value = new IntExpr(e.specialToken.uint_, Types.UInt32);
      break;
    case TOK.FILE, TOK.DATE, TOK.TIME, TOK.TIMESTAMP, TOK.VENDOR:
      e.value = new StringExpr(e.specialToken.strval.str);
      break;
    default:
      assert(0);
    }
    e.type = e.value.type;
    return e.value;
  }

  E visit(DollarExpr e)
  {
    if (e.type)
      return e;
    e.type = modul.cc.tables.types.Size_t;
    // if (!inArraySubscript)
    //   error("$ can only be in an array subscript.");
    return e;
  }

  E visit(NullExpr e)
  {
    if (!e.type)
      e.type = Types.Void_ptr;
    return e;
  }

  E visit(BoolExpr e)
  {
    if (e.type)
      return e;
    e.value = new IntExpr(e.toBool(), Types.Bool);
    e.type = Types.Bool;
    return e;
  }

  E visit(IntExpr e)
  {
    if (e.type)
      return e;

    if (e.number & 0x8000_0000_0000_0000)
      e.type = Types.UInt64; // 0xFFFF_FFFF_FFFF_FFFF
    else if (e.number & 0xFFFF_FFFF_0000_0000)
      e.type = Types.Int64; // 0x7FFF_FFFF_FFFF_FFFF
    else if (e.number & 0x8000_0000)
      e.type = Types.UInt32; // 0xFFFF_FFFF
    else
      e.type = Types.Int32; // 0x7FFF_FFFF
    return e;
  }

  E visit(FloatExpr e)
  {
    if (!e.type)
      e.type = Types.Float64;
    return e;
  }

  E visit(ComplexExpr e)
  {
    if (!e.type)
      e.type = Types.CFloat64;
    return e;
  }

  E visit(CharExpr e)
  {
    return e;
  }

  E visit(StringExpr e)
  {
    return e;
  }

  E visit(MixinExpr me)
  {
    if (me.type)
      return me.expr;
    me.expr = visitE(me.expr);
    auto expr = interpret(me.expr);
    if (expr is Interpreter.NAR)
      return me;
    auto stringExpr = expr.Is!(StringExpr);
    if (stringExpr is null)
     error(me.begin, MID.MixinArgumentMustBeString);
    else
    {
      auto loc = me.begin.getErrorLocation(modul.filePath());
      auto filePath = loc.filePath;
      auto sourceText = new SourceText(filePath, stringExpr.getString());
      auto lxtables = modul.cc.tables.lxtables;
      auto parser = new Parser(sourceText, lxtables, modul.cc.diag);
      expr = parser.start2();
      expr = visitE(expr); // Check expression.
    }
    me.expr = expr;
    me.type = expr.type;
    return me.expr;
  }

  E visit(ImportExpr ie)
  {
    if (ie.type)
      return ie.expr;
    ie.expr = visitE(ie.expr);
    auto expr = interpret(ie.expr);
    if (expr is Interpreter.NAR)
      return ie;
    auto stringExpr = expr.Is!(StringExpr);
    //if (stringExpr is null)
    //  error(me.begin, MID.ImportArgumentMustBeString);
    // TODO: load file
    //ie.expr = new StringExpr(loadImportFile(stringExpr.getString()));
    return ie.expr;
  }
}
}
