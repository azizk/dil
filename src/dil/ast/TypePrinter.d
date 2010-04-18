/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.ast.TypePrinter;

import dil.ast.Visitor,
       dil.ast.Node,
       dil.ast.Types,
       dil.ast.Parameters;
import dil.Enums;
import common;

/// Writes the type chain to a text buffer.
class TypePrinter : Visitor
{
  char[] text; /// The buffer that gets written to.

  /// Returns the type chain as a string.
  /// Params:
  ///   type = the type node to be traversed and printed.
  ///   outerBuffer = append to this buffer.
  char[] print(T type, char[] outerBuffer = null)
  {
    text = outerBuffer;
    visitT(type);
    return text;
  }

  alias TypeNode T;

  /// Writes parameters to the buffer.
  void writeParams(Parameters params)
  {
    assert(params !is null);
    text ~= "(";
    size_t item_count = params.items.length;
    foreach (param; params.items)
    {
      if (param.isCVariadic)
        text ~= "...";
      else
      {
        auto typeBegin = param.type.baseType.begin;
        // StorageClasses Type ParamName ("=" DefValue)?
        if (typeBegin !is param.begin)
          text ~= param.begin.textSpan(typeBegin.prevNWS) ~ " ";

        visitT(param.type);

        if (param.hasName)
          text ~= " " ~ param.nameStr;
        if (param.isDVariadic)
          text ~= "...";
        if (auto v = param.defValue)
          text ~= " = " ~ v.begin.textSpan(v.end);
      }
      --item_count && (text ~= ", "); // Skip for last item.
    }
    text ~= ")";
  }

override:
  T visit(IntegralType t)
  {
    text ~= t.begin.text;
    return t;
  }

  T visit(IdentifierType t)
  {
    t.next && visitT(t.next) && (text ~= ".");
    text ~= t.ident.str;
    return t;
  }

  T visit(TemplateInstanceType t)
  {
    t.next && visitT(t.next) && (text ~= ".");
    text ~= t.ident.str ~ "!";
    auto a = t.targs;
    text ~= a.begin.textSpan(a.end);
    return t;
  }

  T visit(TypeofType t)
  {
    text ~= t.begin.textSpan(t.end);
    return t;
  }

  T visit(PointerType t)
  {
    if (auto cfunc = t.next.Is!(CFuncType))
    { // Skip the CFuncType. Write a D-style function pointer.
      visitT(t.next.next);
      text ~= " function";
      writeParams(cfunc.params);
    }
    else
      visitT(t.next),
      text ~= "*";
    return t;
  }

  T visit(ArrayType t)
  {
    visitT(t.next);
    text ~= "[";
    if (t.isAssociative())
      visitT(t.assocType);
    /+else if (t.isDynamic())
    {}+/
    else if (t.isStatic())
      text ~= t.index1.begin.textSpan(t.index1.end);
    else if (t.isSlice())
      text ~= t.index1.begin.textSpan(t.index1.end) ~
        ".." ~ t.index2.begin.textSpan(t.index2.end);
    text ~= "]";
    return t;
  }

  T visit(FunctionType t)
  {
    visitT(t.next);
    text ~= " function";
    writeParams(t.params);
    return t;
  }

  T visit(DelegateType t)
  {
    visitT(t.next);
    text ~= " delegate";
    writeParams(t.params);
    return t;
  }

  T visit(CFuncType t)
  {
    visitT(t.next);
    writeParams(t.params);
    return t;
  }

  T visit(BaseClassType t)
  {
    text ~= EnumString(t.prot) ~ " ";
    visitT(t.next);
    return t;
  }

  T visit(ConstType t)
  {
    text ~= "const";
    if (t.next !is null)
    {
      text ~= "(";
      visitT(t.next);
      text ~= ")";
    }
    return t;
  }

  T visit(ImmutableType t)
  {
    text ~= "invariant";
    if (t.next !is null)
    {
      text ~= "(";
      visitT(t.next);
      text ~= ")";
    }
    return t;
  }

  T visit(SharedType t)
  {
    text ~= "shared";
    if (t.next !is null)
    {
      text ~= "(";
      visitT(t.next);
      text ~= ")";
    }
    return t;
  }
}
