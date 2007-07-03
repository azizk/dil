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
  TOK delegate() nT;

  Information[] errors;

  this(char[] srcText, string fileName)
  {
    lx = new Lexer(srcText, fileName);
    nT = &lx.nextToken;
  }

  Expression parseExpression()
  {
    auto e = parseAssignExpression();
    while (lx.token.type == TOK.Comma)
      e = new CommaExpression(e, parseAssignExpression());
    return e;
  }

  Expression parseAssignExpression()
  {
    auto e = parseCondExpression();
    while (1)
    {
      switch (lx.token.type)
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
    if (lx.token.type == T.Question)
    {
      nT();
      auto iftrue = parseExpression();
//       if (lx.toke.type != TOK.Colon)
//         error();
      auto iffalse = parseCondExpression();
      e = new CondExpression(e, iftrue, iffalse);
    }
    return e;
  }

  Expression parseOrOrExpression()
  {
    alias parseAndAndExpression parseNext;
    auto e = parseNext();
    if (lx.token.type == T.OrLogical)
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
    if (lx.token.type == T.AndLogical)
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
    if (lx.token.type == T.OrBinary)
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
    if (lx.token.type == T.Xor)
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
    if (lx.token.type == T.AndBinary)
    {
      nT();
      e = new AndExpression(e, parseNext());
    }
    return e;
  }

  Expression parseCmpExpression()
  {
    TOK operator = lx.token.type;

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
      e = new IsExpression(e, parseShiftExpression(), operator);
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
      switch (lx.token.type)
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
      switch (lx.token.type)
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
      switch (lx.token.type)
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
      switch (lx.token.type)
      {
      case T.Dot:
        nT();
        if (lx.token.type == T.Identifier)
          e = new DotIdExpression(e);
        else if (lx.token.type == T.New)
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
        nT();
        e = new CallExpression(e, parseArgumentList(T.LParen));
        break;
      case T.LBracket:
        // parse Slice- and IndexExpression
        break;
      }
    }
    return e;
  }

  Expression parsePreExpression()
  {
    Expression e;
    switch (lx.token.type)
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
      nT(); e = new SignExpression(parseUnaryExpression(), lx.token.type);
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
    return null;
  }

  Expression parseNewExpression(Expression e)
  {
    return null;
  }

  Expression[] parseArgumentList(TOK terminator)
  {
    Expression[] es;

    nT();
    if (lx.token.type == terminator)
    {
      nT();
      return null;
    }

    while (1)
    {
      es ~= parseAssignExpression();
      if (lx.token.type == terminator)
        break;
//       if (lx.token.type != T.Comma)
//         error();
    }
//     if (lx.token.type != terminator)
//       error();
    nT();
    return es;
  }

  void error(MID id, ...)
  {
    errors ~= new Information(Information.Type.Parser, id, lx.loc, arguments(_arguments, _argptr));
  }
}
