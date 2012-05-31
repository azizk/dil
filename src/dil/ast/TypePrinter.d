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
class TypePrinter : Visitor2
{
  char[] text; /// The buffer that gets written to.

  /// Returns the type chain as a string.
  /// Params:
  ///   type = The type node to be traversed and printed.
  ///   outerBuffer = Append to this buffer.
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
    write("(");
    auto item_count = params.items.length;
    foreach (param; params.items)
    {
      if (param.isCVariadic)
        write("...");
      else
      {
        // Write storage class(es).
        auto lastSTC = param.tokenOfLastSTC();
        if (lastSTC) // Write storage classes.
          write(param.begin, lastSTC),
          write(" ");

        param.type && visitT(param.type);

        if (param.hasName)
          write(" "), write(param.nameStr);
        if (param.isDVariadic)
          write("...");
        if (auto v = param.defValue)
          write(" = "), write(v.begin, v.end);
      }
      --item_count && write(", "); // Skip for last item.
    }
    write(")");
  }

  void write(cstring text)
  {
    this.text ~= text;
  }

  void write(Token* begin, Token* end)
  {
    this.text ~= begin.textSpan(end);
  }

override:
  alias super.visit visit;

  void visit(IntegralType t)
  {
    write(t.begin.text);
  }

  void visit(IdentifierType t)
  {
    t.next && (visitT(t.next), write("."));
    write(t.id.str);
  }

  void visit(TemplateInstanceType t)
  {
    t.next && (visitT(t.next), write("."));
    write(t.id.str), write("!");
    auto a = t.targs;
    write(a.begin, a.end);
  }

  void visit(TypeofType t)
  {
    write(t.begin, t.end);
  }

  void visit(PointerType t)
  {
    if (auto cfunc = t.next.Is!(CFuncType))
    { // Skip the CFuncType. Write a D-style function pointer.
      visitT(t.next.next);
      write(" function");
      writeParams(cfunc.params);
    }
    else
      visitT(t.next),
      write("*");
  }

  void visit(ArrayType t)
  {
    visitT(t.next);
    write("[");
    if (t.isAssociative())
      visitT(t.assocType);
    /+else if (t.isDynamic())
    {}+/
    else if (t.isStatic())
      write(t.index1.begin, t.index1.end);
    else if (t.isSlice())
      write(t.index1.begin, t.index1.end),
      write(".."),
      write(t.index2.begin, t.index2.end);
    write("]");
  }

  void visit(FunctionType t)
  {
    visitT(t.next);
    write(" function");
    writeParams(t.params);
  }

  void visit(DelegateType t)
  {
    visitT(t.next);
    write(" delegate");
    writeParams(t.params);
  }

  void visit(CFuncType t)
  {
    visitT(t.next);
    writeParams(t.params);
  }

  void visit(BaseClassType t)
  {
    write(EnumString(t.prot) ~ " ");
    visitT(t.next);
  }

  void visit(ConstType t)
  {
    write("const");
    if (t.next !is null)
    {
      write("(");
      visitT(t.next);
      write(")");
    }
  }

  void visit(ImmutableType t)
  {
    write("immutable");
    if (t.next !is null)
    {
      write("(");
      visitT(t.next);
      write(")");
    }
  }

  void visit(InoutType t)
  {
    write("inout");
    if (t.next !is null)
    {
      write("(");
      visitT(t.next);
      write(")");
    }
  }

  void visit(SharedType t)
  {
    write("shared");
    if (t.next !is null)
    {
      write("(");
      visitT(t.next);
      write(")");
    }
  }
}
