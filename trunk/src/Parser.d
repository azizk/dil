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
        e = new CallExpression(e, parseArgumentList(T.LParen));
        break;
      case T.LBracket:
        // parse Slice- and IndexExpression
        nT();
        if (lx.token.type == T.RBracket)
        {
          e = new SliceExpression(e, null, null);
          nT();
          break;
        }
        Expression[] es = [parseAssignExpression()];
        if (lx.token.type == T.Slice)
        {
          nT();
          e = new SliceExpression(e, es[0], parseAssignExpression());
//           if (lx.token.type != T.RBracket)
//             error()
          nT();
          break;
        }
        else if (lx.token.type == T.Comma)
        {
           es ~= parseArgumentList(T.RBracket);
        }
//         else if (lx.token.type != T.RBracket)
//           error();
        else
          nT();
        e = new IndexExpression(e, es);
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
    Expression e;
    switch (lx.token.type)
    {
    case T.Identifier:
      break;
    case T.Dot:
      nT();
//       if (lx.token.type != T.Identifier)
//         error();
      e = new GlobalIdExpression(lx.token.srcText);
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
      e = new BoolExpression(lx.token.type == T.True ? true : false);
      break;
    case T.Dollar:
      nT();
      e = new DollarExpression();
      break;
    case T.Int32/*, ...*/: // Number literals
      break;
    case T.CharLiteral, T.WCharLiteral, T.DCharLiteral:
      nT();
      e = new CharLiteralExpression(lx.token.type);
      break;
    case T.String:
      char[] buffer = lx.token.str;
      nT();
      while (lx.token.type == T.String)
      {
        string tmp = lx.token.str;
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
      if (lx.token.type != T.RBracket)
      {
        e = parseAssignExpression();
        if (lx.token.type == T.Colon)
          goto LparseAssocArray;
        else if (lx.token.type == T.Comma)
          values = [e] ~ parseArgumentList(T.RBracket);
//         else if (lx.token.type != T.RBracket)
//           error();
      }

      e = new ArrayLiteralExpression(values);
      break;

    LparseAssocArray:
      Expression[] keys;

      keys ~= e;
      nT(); // Skip colon.
      values ~= parseAssignExpression();

      if (lx.token.type != T.RBracket)
        while (1)
        {
          keys ~= parseAssignExpression();
          if (lx.token.type != T.Colon)
          {
//             error();
            values ~= null;
            if (lx.token.type == T.RBracket)
              break;
            else
              continue;
          }
          nT();
          values ~= parseAssignExpression();
          if (lx.token.type == T.RBracket)
            break;
//           if (lx.token.type != T.Comma)
//             error();
        }
      assert(lx.token.type == T.RBracket);
      nT();
      e = new AssocArrayLiteralExpression(keys, values);
      break;
    case T.LBrace:
      break;
    case T.Function, T.Delegate:
      break;
    case T.Assert:
      break;
    case T.Mixin:
      break;
    case T.Import:
      break;
    case T.Typeid:
      break;
    case T.Is:
      break;
    case T.LParen:
      break;
    default:
      // BasicType . Identifier
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
