/++
  Author: Aziz Köksal
  License: GPL2
+/
module Parser;
import Lexer;
import Token;
import Messages;
import Information;
import Expressions;

enum STC
{
  Abstract,
  Auto,
  Const,
  Deprecated,
  Extern,
  Final,
  Invariant,
  Override,
  Scope,
  Static,
  Synchronized
}

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

  void nT()
  {
    lx.nextToken();
    token = &lx.token;
  }

  Expression parseExpression()
  {
    auto e = parseAssignExpression();
    while (token.type == TOK.Comma)
      e = new CommaExpression(e, parseAssignExpression());
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
        break;
      }
      break;
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
    TOK operator = token.type;

    auto e = parseShiftExpression();

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
    return parsePostExpression();
  }

  Expression parsePostExpression()
  {
    auto e = parsePreExpression();
    while (1)
    {
      switch (token.type)
      {
      case T.Dot:
        nT();
        if (token.type == T.Identifier)
          e = new DotIdExpression(e);
        else if (token.type == T.New)
          e = parseNewExpression(e);
        break;
      case T.PlusPlus:
        nT();
        e = new PostIncrExpression(e);
        break;
      case T.MinusMinus:
        nT();
        e = new PostDecrExpression(e);
        break;
      case T.LParen:
        e = new CallExpression(e, parseArgumentList(T.LParen));
        break;
      case T.LBracket:
        // parse Slice- and IndexExpression
        nT();
        if (token.type == T.RBracket)
        {
          e = new SliceExpression(e, null, null);
          nT();
          break;
        }

        Expression[] es = [parseAssignExpression()];

        if (token.type == T.Slice)
        {
          nT();
          e = new SliceExpression(e, es[0], parseAssignExpression());
          require(T.RBracket);
          break;
        }
        else if (token.type == T.Comma)
        {
           es ~= parseArgumentList(T.RBracket);
        }
        else
          require(T.RBracket);

        e = new IndexExpression(e, es);
        break;
      }
    }
    return e;
  }

  Expression parsePreExpression()
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
      // parseNewExpression();
      break;
    case T.Delete:
      nT();
      e = new DeleteExpression(parseUnaryExpression());
      break;
    case T.Cast:
      nT();
      // Type type = parseType();
      e = new CastExpression(parseUnaryExpression() /*, type*/);
      break;
    case T.LParen:
      // parse ( Type ) . Identifier
      break;
    default:
      e = parsePrimaryExpression();
      break;
    }
    assert(e !is null);
    return e;
  }

  Expression parsePrimaryExpression()
  {
    Expression e;
    switch (token.type)
    {
    case T.Identifier:
      e = new IdentifierExpression(token.srcText);
      nT();
      break;
    case T.Dot:
      requireNext(T.Identifier);
      e = new GlobalIdExpression(token.srcText);
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
    case T.Int32/*, ...*/: // Number literals
      break;
    case T.CharLiteral, T.WCharLiteral, T.DCharLiteral:
      nT();
      e = new CharLiteralExpression(token.type);
      break;
    case T.String:
      char[] buffer = token.str;
      char postfix = token.pf;
      nT();
      while (token.type == T.String)
      {
        string tmp = token.str;
//         if (postfix != token.pf)
//           error();
        if (tmp.length > 1)
        {
          buffer[$-1] = tmp[0]; // replace '\0'
          buffer ~= tmp[1..$]; // append the rest
        }
        nT();
      }
      e = new StringLiteralExpression(buffer);
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
          values = [e] ~ parseArgumentList(T.RBracket);
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
            errorIfNot(T.Colon);
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
      break;
    case T.Function, T.Delegate:
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
      e = new TypeidExpression();
      break;
    case T.Is:
//       e = new IsExpression();
      break;
    case T.LParen:
      break;
    // BasicType . Identifier
    case T.Void, T.Char, T.Wchar, T.Dchar, T.Bool, T.Byte, T.Ubyte,
         T.Short, T.Ushort, T.Int, T.Uint, T.Long, T.Ulong,
         T.Float, T.Double, T.Real, T.Ifloat, T.Idouble, T.Ireal,
         T.Cfloat, T.Cdouble, T.Creal:
    TOK type = token.type;

    requireNext(T.Dot);

    string ident;
    if (token.type == T.Identifier)
    {
      ident = token.srcText;
      nT();
    }
    else
      errorIfNot(T.Identifier);

    e = new TypeDotIdExpression(type, ident);
    default:
    }
    return e;
  }

  Expression parseNewExpression(Expression e)
  {
    return null;
  }

  Expression[] parseArgumentList(TOK terminator)
  {
    Expression[] es;

    nT();
    if (token.type == terminator)
    {
      nT();
      return null;
    }

    while (1)
    {
      es ~= parseAssignExpression();
      if (token.type == terminator)
        break;
      require(T.Comma);
    }
    nT();
    return es;
  }

  void errorIfNot(TOK tok)
  {
    if (token.type != tok)
      error(MID.ExpectedButFound, tok, token.srcText);
  }

  void require(TOK tok)
  {
    if (token.type == tok)
      nT();
    else
      error(MID.ExpectedButFound, tok, token.srcText);
  }

  void requireNext(TOK tok)
  {
    nT();
    if (token.type == tok)
      nT();
    else
      error(MID.ExpectedButFound, tok, token.srcText);
  }

  void error(MID id, ...)
  {
    errors ~= new Information(Information.Type.Parser, id, lx.loc, arguments(_arguments, _argptr));
  }
}
