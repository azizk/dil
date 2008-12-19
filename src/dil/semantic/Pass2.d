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
import dil.lexer.Identifier;
import dil.semantic.Symbol,
       dil.semantic.Symbols,
       dil.semantic.Types,
       dil.semantic.TypesEnum,
       dil.semantic.Scope,
       dil.semantic.Module,
       dil.semantic.Analysis;
import dil.code.Interpreter;
import dil.parser.Parser;
import dil.SourceText;
import dil.Diagnostics;
import dil.Messages;
import dil.Enums;
import dil.CompilerInfo;
import common;

/// The second pass determines the types of symbols and the types
/// of expressions and also evaluates them.
class SemanticPass2 : DefaultVisitor
{
  Scope scop; /// The current scope.
  Module modul; /// The module to be semantically checked.

  /// Constructs a SemanticPass2 object.
  /// Params:
  ///   modul = the module to be checked.
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

  /// Reports an error: new symbol s1 conflicts with existing symbol s2.
  void reportSymbolConflict(Symbol s1, Symbol s2, Identifier* name)
  {
    auto loc = s2.node.begin.getErrorLocation();
    auto locString = Format("{}({},{})", loc.filePath, loc.lineNum, loc.colNum);
    error(s1.node.begin, MSG.DeclConflictsWithDecl, name.str, locString);
  }


  /// Evaluates e and returns the result.
  Expression interpret(Expression e)
  {
    return Interpreter.interpret(e, modul.diag);
  }

  /// Creates an error report.
  void error(Token* token, char[] formatMsg, ...)
  {
    auto location = token.getErrorLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    modul.diag ~= new SemanticError(location, msg);
  }

  /// Some handy aliases.
  private alias Declaration D;
  private alias Expression E; /// ditto
  private alias Statement S; /// ditto
  private alias TypeNode T; /// ditto

  /// The current scope symbol to use for looking up identifiers.
  /// E.g.:
  /// ---
  /// object.method(); // *) object is looked up in the current scope.
  ///                  // *) idScope is set if object is a ScopeSymbol.
  ///                  // *) method will be looked up in idScope.
  /// dil.ast.Node.Node node; // A fully qualified type.
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
      error(idTok, MSG.UndefinedIdentifier, id.str);
    else if (auto scopSymbol = cast(ScopeSymbol)symbol)
      idScope = scopSymbol;

    return symbol;
  }

  /// Reports an error if the type of e is not bool.
  void errorIfBool(Expression e)
  {
    assert(e.type !is null);
    if (e.type.isBaseBool())
      error(e.begin, "the operation is undefined for type bool");
  }

  /// Reports an error if e has no boolean result.
  void errorIfNonBool(Expression e)
  {
    assert(e.type !is null);
    switch (e.kind)
    {
    case NodeKind.DeleteExpression:
      error(e.begin, "the delete operator has no boolean result");
      break;
    case NodeKind.AssignExpression:
      error(e.begin, "the assignment operator '=' has no boolean result");
      break;
    case NodeKind.CondExpression:
      auto cond = e.to!(CondExpression);
      errorIfNonBool(cond.lhs);
      errorIfNonBool(cond.rhs);
      break;
    default:
      if (!e.type.isBaseScalar()) // Only scalar types can be bool.
        error(e.begin, "expression has no boolean result");
    }
  }


  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                Declarations                               |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

override
{
  D visit(CompoundDeclaration d)
  {
    return super.visit(d);
  }

  D visit(EnumDeclaration d)
  {
    uint number = 0;
    bool firstEnumValue = true;
    bool enumAssignedAValue = false;

    //malformed EnumMember
    if(d.symbol is null)
      return d;

    d.symbol.setCompleting();

    Type type = Types.Int; // Default to int.

    if (d.baseType)
      type = visitT(d.baseType).type;

    // TODO: Done...this works, but type is always defaulting to Int if the
    //EnumBaseType is an Enum type. For D2.x the type doesn't have to be
    //an integral type.
    if (!type.isIntegral())
    {
      error(d.begin, MSG.EnumBaseTypeInvalid);
      return d;
    }

    // Set the enum's base type.
    d.symbol.type.baseType = type;

    enterScope(d.symbol);

    //Enum must have at least one member
    if (d.members is null)
    {
      error(d.begin, MSG.EnumMustHaveMember);
      return d;
    }


    number = 0;
    foreach (member; d.members)
    {
      Expression finalValue;
      member.symbol.setCompleting();
      if (member.value)
      {
        member.value = visitE(member.value);
        finalValue = interpret(member.value);

	//Check that each member evaluates to an integral or enum type D1.0
	if(finalValue.hasType())
	{
	  if (!finalValue.type.isBaseScalar())
	  {
	    error(d.begin, MSG.EnumMemberTypeInvalid);
	    return d;
	  }
	} 
	else
	{
	  //This section should be correct for enum {enumMember=enumType.enumMember}
	  //once interpreter has been updated for enum basetypes
	  error(d.begin, MSG.EnumIntegerExprExpected);
	  return d;
	}

        if (finalValue is Interpreter.NAR)
          finalValue = new IntExpression(0, d.symbol.type);
	else 
	{
	  //TODO this conversion to IntExp is only valid for D1...need to change for D2
	  //need to implement finalValue.castTo!(type)
	  if(finalValue !is null)
	    number = finalValue.to!(IntExpression).number;
	}

	firstEnumValue = false;

      }
      else
      {
	if (firstEnumValue)
	{
          finalValue = new IntExpression(0, d.symbol.type);
	  firstEnumValue = false;
	} 
	else
	{
	  finalValue = new IntExpression(number, d.symbol.type);
	  enumAssignedAValue = true;
	}
      }

      if (enumAssignedAValue)
      switch (type.tid)
      {
      case TYP.Bool :
	  if (number >= 2) goto LvalueOverflow;
	  break;
      case TYP.Byte :
	  if (number >= 128) goto LvalueOverflow;
	  break;
      case TYP.Char :
      case TYP.Ubyte :
	  if (number >= 256) goto LvalueOverflow;
	  break;
      case TYP.Short :
	  if (number >= 0x9000) goto LvalueOverflow;
	  break;
      case TYP.Wchar :
      case TYP.Ushort :
	  if (number >= 0x10000) goto LvalueOverflow;
	  break;
      case TYP.Int :
	  if (number >= 0x80000000) goto LvalueOverflow;
	  break;
      case TYP.Dchar :
      case TYP.Uint :
	  if (number >= 0x100000000) goto LvalueOverflow;
	  break;
      case TYP.Long :
	  if (number >= 0x8000000000000000) goto LvalueOverflow;
	  break;
      case TYP.Ulong :
	  if ((number == 0x0) && (enumAssignedAValue)) goto LvalueOverflow;
	  break;
      LvalueOverflow:
	  error(d.begin, MSG.EnumOverflow);
	  return d;
      default:
	  break;
      }

      debug(sema)
      {
        Stdout(type);
	Stdout(" - ");
        Stdout(finalValue.to!(IntExpression).number).newline;
      }


      member.symbol.value = finalValue;
      member.symbol.setComplete();
      number++;
    }

    exitScope();
    d.symbol.setComplete();
    return d;
  }

  D visit(MixinDeclaration md)
  {
    if (md.decls)
      return md.decls;
    if (md.isMixinExpression)
    {
      md.argument = visitE(md.argument);
      auto expr = interpret(md.argument);
      if (expr is Interpreter.NAR)
        return md;
      auto stringExpr = expr.Is!(StringExpression);
      if (stringExpr is null)
      {
        error(md.begin, MSG.MixinArgumentMustBeString);
        return md;
      }
      else
      { // Parse the declarations in the string.
        auto loc = md.begin.getErrorLocation();
        auto filePath = loc.filePath;
        auto sourceText = new SourceText(filePath, stringExpr.getString());
        auto parser = new Parser(sourceText, modul.diag);
        md.decls = parser.start();
      }
    }
    else
    {
      // TODO: implement template mixin.
    }
    return md.decls;
  }



  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                   Types                                   |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

  T visit(TypeofType t)
  {
    t.e = visitE(t.e);
    t.type = t.e.type;
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

  T visit(QualifiedType t)
  {
    if (t.lhs.Is!(QualifiedType) is null)
      idScope = null; // Reset at left-most type.
    visitT(t.lhs);
    visitT(t.rhs);
    t.type = t.rhs.type;
    return t;
  }

  T visit(IdentifierType t)
  {
    Type typ = Types.Int;
    auto idToken = t.begin;
    auto symbol = search(idToken);
    // TODO: save symbol or its type in t...this is defaulting to Int!! FIX
    t.type = typ;
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


  /+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  |                                Expressions                                |
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+/

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

  E visit(OrOrExpression e)
  {
    if (!e.hasType)
    {
      e.lhs = visitE(e.lhs);
      errorIfNonBool(e.lhs); // Left operand must be bool.
      e.rhs = visitE(e.rhs);
      if (e.rhs.type == Types.Void)
        e.type = Types.Void; // According to spec.
      else
        (e.type = Types.Bool), // Otherwise type is bool and
        errorIfNonBool(e.rhs); // right operand must be bool.
    }
    return e;
  }

  E visit(AndAndExpression e)
  {
    if (!e.hasType)
    {
      e.lhs = visitE(e.lhs);
      errorIfNonBool(e.lhs); // Left operand must be bool.
      e.rhs = visitE(e.rhs);
      if (e.rhs.type == Types.Void)
        e.type = Types.Void; // According to spec.
      else
        (e.type = Types.Bool), // Otherwise type is bool and
        errorIfNonBool(e.rhs); // right operand must be bool.
    }
    return e;
  }

  E visit(PlusExpression e)
  {
    if(!e.type)
    {
      e.lhs = visitE(e.lhs);
      e.rhs = visitE(e.rhs);
      if (e.lhs.type.isPointer && e.rhs.type.isIntegral())
      {
        e.type = e.lhs.type;
	//TODO resulting value is the pointer plus e.rhs*(e.lhs.type.sizeof)
      }
      else if (e.rhs.type.isPointer && e.lhs.type.isIntegral())
      {
	e.type = e.rhs.type;
	//TODO reverse operands then same as above
	//TODO resulting value is the pointer plus e.rhs*(e.lhs.type.sizeof)
      }
      else if (e.rhs.type.isPointer && e.lhs.type.isPointer())
      {
        error(e.begin, MSG.CannotAddPointers);
        return e;
      }
      else
        e.type = e.rhs.type;
    }
    return e;
  }

  E visit(MinusExpression e)
  {
    if(!e.type)
    {
      e.lhs = visitE(e.lhs);
      e.rhs = visitE(e.rhs);
      if (e.lhs.type.isPointer && e.rhs.type.isIntegral())
      {
        e.type = e.lhs.type;
      }
      else if (e.rhs.type.isPointer && e.lhs.type.isIntegral())
      {
	//TODO error
	return e;
      }
      else if (e.rhs.type.isPointer && e.lhs.type.isPointer())
      {
        if (e.rhs.type.tid != e.lhs.type.tid)
	{
	  //TODO error
	  return e;
	}
      }
      else
        e.type = e.rhs.type;
    }
    return e;
  }

  E visit(MulExpression e)
  {
    if(!e.type)
    {
      e.lhs = visitE(e.lhs);
      e.rhs = visitE(e.rhs);
      e.type = e.rhs.type;
    }
    return e;
  }

  E visit(DivExpression e)
  {
    if(!e.type)
    {
      e.lhs = visitE(e.lhs);
      e.rhs = visitE(e.rhs);
      e.type = e.rhs.type;
    }
    return e;
  }

  E visit(ModExpression e)
  {
    if(!e.type)
    {
      e.lhs = visitE(e.lhs);
      e.rhs = visitE(e.rhs);
      e.type = e.rhs.type;
    }
    return e;
  }

  E visit(AssignExpression e)
  {
    if (e.type)
      return e;
    //TODO check for type mismatch
    return e;
  }

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
    if (!e.type)
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
    return e;
  }

  E visit(StringExpression e)
  {
    return e;
  }

  E visit(IdentifierExpression e)
  {
    if (e.hasType)
      return e;
    debug(sema) Stdout.formatln("", e);
    auto idToken = e.idToken();
    e.symbol = search(idToken);
    return e;
  }

  E visit(MixinExpression me)
  {
    if (me.type)
      return me.expr;
    me.expr = visitE(me.expr);
    auto expr = interpret(me.expr);
    if (expr is Interpreter.NAR)
      return me;
    auto stringExpr = expr.Is!(StringExpression);
    if (stringExpr is null)
     error(me.begin, MSG.MixinArgumentMustBeString);
    else
    {
      auto loc = me.begin.getErrorLocation();
      auto filePath = loc.filePath;
      auto sourceText = new SourceText(filePath, stringExpr.getString());
      auto parser = new Parser(sourceText, modul.diag);
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
    auto expr = interpret(ie.expr);
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
