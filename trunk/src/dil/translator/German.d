/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.translator.German;

import dil.ast.DefaultVisitor;
import dil.ast.Node;
import dil.ast.Declarations,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;
import tango.io.Print;

private alias Declaration D;

/++
  Traverses a D syntax tree and explains in German.
+/
class GermanTranslator : DefaultVisitor
{
  Print!(char) put;

  char[] indent;
  char[] indentStep;

  Declaration inAggregate;
  Declaration inFunc;

  /++
    Construct a GermanTranslator.
    Params:
      put = buffer to print to.
      indentStep = added at every indendation step.
  +/
  this(Print!(char) put, char[] indentStep)
  {
    this.put = put;
    this.indentStep = indentStep;
  }

  /// Start translation.
  void translate(Node root)
  {
    visitN(root);
  }

  scope class Indent
  {
    char[] old_indent;
    this()
    {
      old_indent = this.outer.indent;
      this.outer.indent ~= this.outer.indentStep;
    }

    ~this()
    { this.outer.indent = old_indent; }

    char[] toString()
    { return this.outer.indent; }
  }

  scope class Enter(T)
  {
    T t_save;
    this(T t)
    {
      auto t_save = t;
      static if (is(T == ClassDeclaration) ||
                 is(T == InterfaceDeclaration) ||
                 is(T == StructDeclaration) ||
                 is(T == UnionDeclaration))
        this.outer.inAggregate = t;
      static if (is(T == FunctionDeclaration) ||
                 is(T == ConstructorDeclaration))
        this.outer.inFunc = t;
    }

    ~this()
    {
      static if (is(T == ClassDeclaration) ||
                 is(T == InterfaceDeclaration) ||
                 is(T == StructDeclaration) ||
                 is(T == UnionDeclaration))
        this.outer.inAggregate = t_save;
      static if (is(T == FunctionDeclaration) ||
                 is(T == ConstructorDeclaration))
        this.outer.inFunc = t_save;
    }
  }

  alias Enter!(ClassDeclaration) EnteredClass;
  alias Enter!(FunctionDeclaration) EnteredFunction;
  alias Enter!(ConstructorDeclaration) EnteredConstructor;


override:
  D visit(ModuleDeclaration n)
  {
    put.format("Das Modul '{}'", n.moduleName.str);
    if (n.packages.length)
      put.format(" im Paket '{}'", n.getPackageName('.'));
    put(".").newline;
    return n;
  }

  D visit(ClassDeclaration n)
  {
    scope E = new EnteredClass(n);
    put(indent).formatln("'{}' is eine Klasse mit den Eigenschaften:", n.name.str);
    scope I = new Indent();
    n.decls && visitD(n.decls);
    return n;
  }

  D visit(VariableDeclaration n)
  {
    char[] was;
    if (inAggregate)
      was = "MemberVariable";
    else if (inFunc)
      was = "lokale Variable";
    else
      was = "globale Variable";
    foreach (name; n.idents)
    {
      put(indent).format("'{}' ist eine {} des Typs: ", name.str, was);
      if (n.typeNode)
        visitT(n.typeNode);
      else
        put("auto");
      put.newline;
    }
    return n;
  }

  D visit(FunctionDeclaration n)
  {
    scope E = new EnteredFunction(n);
    char[] was = inAggregate ? "Methode" : "Funktion";
    put(indent).format("'{}' ist eine {} ", n.name.str, was);
    if (n.params.length)
      put("mit den Argumenten"), visitN(n.params);
    else
      put("ohne Argumente");
    put.newline;
    scope I = new Indent();
    return n;
  }

  D visit(ConstructorDeclaration n)
  {
    scope E = new EnteredConstructor(n);
    put(indent)("Ein Konstruktor ");
    if (n.params.length == 1)
      put("mit dem Argument "),put((visitN(n.params), "."));
    else if (n.params.length > 1)
      put("mit den Argumenten "),put((visitN(n.params), "."));
    else
      put("ohne Argumente.");
    put.newline;
    return n;
  }

  D visit(StaticConstructorDeclaration n)
  {
    put(indent)("Statischer Konstruktor.").newline;
    return n;
  }

  D visit(DestructorDeclaration n)
  {
    put(indent)("Destruktor.").newline;
    return n;
  }

  D visit(StaticDestructorDeclaration n)
  {
    put(indent)("Statischer Destruktor.").newline;
    return n;
  }

  D visit(InvariantDeclaration n)
  {
    put(indent)("Eine Unveränderliche.").newline;
    return n;
  }

  D visit(UnittestDeclaration n)
  {
    put(".").newline;
    return n;
  }

  Node visit(Parameter n)
  {
    put.format("'{}' des Typs \"", n.name ? n.name.str : "unbenannt");
    visitN(n.type);
    put(\");
    return n;
  }

  TypeNode visit(ArrayType n)
  {
    if (n.assocType)
      visitT(n.assocType);
    else if (n.e)
      visitE(n.e), n.e2 && visitE(n.e2);
    else
      put("dynamisches Array von "), visitT(n.next);
    return n;
  }

  TypeNode visit(PointerType n)
  {
    put("Zeiger auf "), visitT(n.next);
    return n;
  }

  TypeNode visit(IntegralType n)
  {
    put(n.begin.srcText);
    return n;
  }
}
