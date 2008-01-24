/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Pass2;

import dil.ast.DefaultVisitor;
import dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;
import dil.lexer.Identifier;
import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Types,
       dil.semantic.Scope,
       dil.semantic.Module,
       dil.semantic.Analysis,
       dil.semantic.Interpreter;
import dil.parser.Parser;
import dil.Location;
import dil.Information;
import dil.Messages;
import dil.Enums;
import dil.CompilerInfo;
import common;

class SemanticPass2 : DefaultVisitor
{
  Scope scop; /// The current scope.
  Module modul; /// The module to be semantically checked.

  this(Module modul)
  {
    this.modul = modul;
  }

  /// Start semantic analysis.
  void start()
  {
    assert(modul.root !is null);
    // Create module scope.
    scop = new Scope(null, modul);
    visit(modul.root);
  }

  void enterScope(ScopeSymbol s)
  {
    scop = scop.enter(s);
  }

  void exitScope()
  {
    scop = scop.exit();
  }

  void error(Token* token, char[] formatMsg, ...)
  {
    auto location = token.getErrorLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    modul.infoMan ~= new SemanticError(location, msg);
  }

  private alias Declaration D;
  private alias Expression E;
  private alias Statement S;
  private alias TypeNode T;

override
{
  D visit(CompoundDeclaration d)
  {
    return super.visit(d);
  }

  D visit(MixinDeclaration md)
  {
    /+
    if (type)
      return this.expr;
    // TODO:
    auto expr = this.expr.semantic(scop);
    expr = expr.evaluate();
    if (expr is null)
      return this;
    auto strExpr = TryCast!(StringExpression)(expr);
    if (strExpr is null)
     error(scop, MSG.MixinArgumentMustBeString);
    else
    {
      auto loc = this.begin.getErrorLocation();
      auto filePath = loc.filePath;
      auto parser = new_ExpressionParser(strExpr.getString(), filePath, scop.infoMan);
      expr = parser.parse();
      expr = expr.semantic(scop);
    }
    this.expr = expr;
    this.type = expr.type;
    return expr;
    +/
    return md;
  }

  T visit(TypeofType t)
  {
    t.e = visitE(t.e);
    t.type = t.e.type;
    return t;
  }

  T visit(ArrayType t)
  {
    return t;
  }

  T visit(PointerType t)
  {
    t.type = visitT(t.next).type.ptrTo();
    return t;
  }

  T visit(IntegralType t)
  {
    // A table mapping the kind of a token to its corresponding semantic Type.
    TypeBasic[TOK] tok2Type = [
      TOK.Char : Types.Char,   TOK.Wchar : Types.Wchar,   TOK.Dchar : Types.Dchar, TOK.Bool : Types.Bool,
      TOK.Byte : Types.Byte,   TOK.Ubyte : Types.Ubyte,   TOK.Short : Types.Short, TOK.Ushort : Types.Ushort,
      TOK.Int : Types.Int,    TOK.Uint : Types.Uint,    TOK.Long : Types.Long,  TOK.Ulong : Types.Ulong,
      TOK.Cent : Types.Cent,   TOK.Ucent : Types.Ucent,
      TOK.Float : Types.Float,  TOK.Double : Types.Double,  TOK.Real : Types.Real,
      TOK.Ifloat : Types.Ifloat, TOK.Idouble : Types.Idouble, TOK.Ireal : Types.Ireal,
      TOK.Cfloat : Types.Cfloat, TOK.Cdouble : Types.Cdouble, TOK.Creal : Types.Creal, TOK.Void : Types.Void
    ];
    assert(t.tok in tok2Type);
    t.type = tok2Type[t.tok];
    return t;
  }

  E visit(ParenExpression e)
  {
    if (!e.type)
    {
      e.next = visitE(e.next);
      e.type = e.next.type;
    }
    return e;
  }

  E visit(CommaExpression e)
  {
    if (!e.type)
    {
      e.lhs = visitE(e.lhs);
      e.rhs = visitE(e.rhs);
      e.type = e.rhs.type;
    }
    return e;
  }

  E visit(OrOrExpression)
  { return null; }

  E visit(AndAndExpression)
  { return null; }

  E visit(SpecialTokenExpression e)
  {
    if (e.type)
      return e.value;
    switch (e.specialToken.kind)
    {
    case TOK.LINE, TOK.VERSION:
      e.value = new IntExpression(e.specialToken.uint_, Types.Uint);
      break;
    case TOK.FILE, TOK.DATE, TOK.TIME, TOK.TIMESTAMP, TOK.VENDOR:
      e.value = new StringExpression(e.specialToken.str);
      break;
    default:
      assert(0);
    }
    e.type = e.value.type;
    return e.value;
  }

  E visit(DollarExpression e)
  {
    if (e.type)
      return e;
    e.type = Types.Size_t;
    // if (!inArraySubscript)
    //   error("$ can only be in an array subscript.");
    return e;
  }

  E visit(NullExpression e)
  {
    if (!e.type)
      e.type = Types.Void_ptr;
    return e;
  }

  E visit(BoolExpression e)
  {
    if (e.type)
      return e;
    e.value = new IntExpression(e.toBool(), Types.Bool);
    e.type = Types.Bool;
    return e;
  }

  E visit(IntExpression e)
  {
    if (e.type)
      return e;

    if (e.number & 0x8000_0000_0000_0000)
      e.type = Types.Ulong; // 0xFFFF_FFFF_FFFF_FFFF
    else if (e.number & 0xFFFF_FFFF_0000_0000)
      e.type = Types.Long; // 0x7FFF_FFFF_FFFF_FFFF
    else if (e.number & 0x8000_0000)
      e.type = Types.Uint; // 0xFFFF_FFFF
    else
      e.type = Types.Int; // 0x7FFF_FFFF
    return e;
  }

  E visit(RealExpression e)
  {
    if (e.type)
      e.type = Types.Double;
    return e;
  }

  E visit(ComplexExpression e)
  {
    if (!e.type)
      e.type = Types.Cdouble;
    return e;
  }

  E visit(CharExpression e)
  {
    if (e.type)
      return e;
    if (e.character <= 0xFF)
      e.type = Types.Char;
    else if (e.character <= 0xFFFF)
      e.type = Types.Wchar;
    else
      e.type = Types.Dchar;
    return e;
  }

  E visit(StringExpression e)
  {
    return e;
  }

  E visit(MixinExpression me)
  {
    if (me.type)
      return me.expr;
    me.expr = visitE(me.expr);
    auto expr = Interpreter.interpret(me.expr, modul.infoMan, scop);
    if (expr is Interpreter.NAR)
      return me;
    auto stringExpr = expr.Is!(StringExpression);
    if (stringExpr is null)
     error(me.begin, MSG.MixinArgumentMustBeString);
    else
    {
      auto loc = me.begin.getErrorLocation();
      auto filePath = loc.filePath;
      auto parser = new Parser(stringExpr.getString(), filePath, modul.infoMan);
      expr = parser.start2();
      expr = visitE(expr); // Check expression.
    }
    me.expr = expr;
    me.type = expr.type;
    return me.expr;
  }

  E visit(ImportExpression ie)
  {
    if (ie.type)
      return ie.expr;
    ie.expr = visitE(ie.expr);
    auto expr = Interpreter.interpret(ie.expr, modul.infoMan, scop);
    if (expr is Interpreter.NAR)
      return ie;
    auto stringExpr = expr.Is!(StringExpression);
    //if (stringExpr is null)
    //  error(me.begin, MSG.ImportArgumentMustBeString);
    // TODO: load file
    //ie.expr = new StringExpression(loadImportFile(stringExpr.getString()));
    return ie.expr;
  }
}
}
