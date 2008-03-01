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

/// Translates a syntax tree into German.
class GermanTranslator : DefaultVisitor
{
  Print!(char) put; /// Output buffer.

  char[] indent; /// Current indendation string.
  char[] indentStep; /// Appended to indent at each indendation level.

  Declaration inAggregate; /// Current aggregate.
  Declaration inFunc; /// Current function.

  bool pluralize; /// Whether to use the plural when printing the next types.
  bool pointer; /// Whether next types should consider the previous pointer.

  /// Construct a GermanTranslator.
  /// Params:
  ///   put = buffer to print to.
  ///   indentStep = added at every indendation step.
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

  /// Increases the indentation when instantiated.
  /// The indentation is restored when the instance goes out of scope.
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

  /// Saves an outer member when instantiated.
  /// It is restored when the instance goes out of scope.
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
  alias Enter!(InterfaceDeclaration) EnteredInterface;
  alias Enter!(StructDeclaration) EnteredStruct;
  alias Enter!(UnionDeclaration) EnteredUnion;
  alias Enter!(FunctionDeclaration) EnteredFunction;
  alias Enter!(ConstructorDeclaration) EnteredConstructor;

  /// Prints the location of a node: @(lin,col)
  void printLoc(Node node)
  {
    auto loc = node.begin.getRealLocation();
    put(indent).formatln("@({},{})",/+ loc.filePath,+/ loc.lineNum, loc.colNum);
  }

override:
  D visit(ModuleDeclaration n)
  {
    printLoc(n);
    put.format("Dies ist das Modul '{}'", n.moduleName.str);
    if (n.packages.length)
      put.format(" im Paket '{}'", n.getPackageName('.'));
    put(".").newline;
    return n;
  }

  D visit(ImportDeclaration n)
  {
    printLoc(n);
    put("Importiert Symbole aus einem anderen Modul bzw. Module.").newline;
    return n;
  }

  D visit(ClassDeclaration n)
  {
    printLoc(n);
    scope E = new EnteredClass(n);
    put(indent).formatln("'{}' is eine Klasse mit den Eigenschaften:", n.name.str);
    scope I = new Indent();
    n.decls && visitD(n.decls);
    return n;
  }

  D visit(InterfaceDeclaration n)
  {
    printLoc(n);
    scope E = new EnteredInterface(n);
    put(indent).formatln("'{}' is ein Interface mit den Eigenschaften:", n.name.str);
    scope I = new Indent();
    n.decls && visitD(n.decls);
    return n;
  }

  D visit(StructDeclaration n)
  {
    printLoc(n);
    scope E = new EnteredStruct(n);
    put(indent).formatln("'{}' is eine Datenstruktur mit den Eigenschaften:", n.name.str);
    scope I = new Indent();
    n.decls && visitD(n.decls);
    return n;
  }

  D visit(UnionDeclaration n)
  {
    printLoc(n);
    scope E = new EnteredUnion(n);
    put(indent).formatln("'{}' is eine Datenunion mit den Eigenschaften:", n.name.str);
    scope I = new Indent();
    n.decls && visitD(n.decls);
    return n;
  }

  D visit(VariablesDeclaration n)
  {
    printLoc(n);
    char[] was;
    if (inAggregate)
      was = "Membervariable";
    else if (inFunc)
      was = "lokale Variable";
    else
      was = "globale Variable";
    foreach (name; n.names)
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
    printLoc(n);
    char[] was;
    if (inAggregate)
      was = "Methode";
    else if(inFunc)
      was = "geschachtelte Funktion";
    else
      was = "Funktion";
    scope E = new EnteredFunction(n);
    put(indent).format("'{}' ist eine {} ", n.name.str, was);
    if (n.params.length == 1)
      put("mit dem Argument "), visitN(n.params);
    else if (n.params.length > 1)
      put("mit den Argumenten "), visitN(n.params);
    else
      put("ohne Argumente");
    put(".").newline;
    scope I = new Indent();
    return n;
  }

  D visit(ConstructorDeclaration n)
  {
    printLoc(n);
    scope E = new EnteredConstructor(n);
    put(indent)("Ein Konstruktor ");
    if (n.params.length == 1)
      put("mit dem Argument "), visitN(n.params);
    else if (n.params.length > 1)
      put("mit den Argumenten "), visitN(n.params);
    else
      put("ohne Argumente");
    put(".").newline;
    return n;
  }

  D visit(StaticConstructorDeclaration n)
  {
    printLoc(n);
    put(indent)("Ein statischer Konstruktor.").newline;
    return n;
  }

  D visit(DestructorDeclaration n)
  {
    printLoc(n);
    put(indent)("Ein Destruktor.").newline;
    return n;
  }

  D visit(StaticDestructorDeclaration n)
  {
    printLoc(n);
    put(indent)("Ein statischer Destruktor.").newline;
    return n;
  }

  D visit(InvariantDeclaration n)
  {
    printLoc(n);
    put(indent)("Eine Unveränderliche.").newline;
    return n;
  }

  D visit(UnittestDeclaration n)
  {
    printLoc(n);
    put(indent)("Ein Komponententest.").newline;
    return n;
  }

  Node visit(Parameter n)
  {
    put.format("'{}' des Typs \"", n.name ? n.name.str : "unbenannt");
    n.type && visitN(n.type);
    put(\");
    return n;
  }

  Node visit(Parameters n)
  {
    if (n.length > 1)
    {
      visitN(n.children[0]);
      foreach (node; n.children[1..$])
        put(", "), visitN(node);
    }
    else
      super.visit(n);
    return n;
  }

  TypeNode visit(ArrayType n)
  {
    char[] c1 = "s", c2 = "";
    if (pluralize)
      (c1 = pointer ? ""[] : "n"), (c2 = "s");
    pointer = false;
    if (n.assocType)
      put.format("assoziative{} Array{} von ", c1, c2);
//       visitT(n.assocType);
    else if (n.e1)
    {
      if (n.e2)
        put.format("gescheibte{} Array{} von ", c1, c2);
      else
        put.format("statische{} Array{} von ", c1, c2);
//       visitE(n.e), n.e2 && visitE(n.e2);
    }
    else
      put.format("dynamische{} Array{} von ", c1, c2);
    // Types following arrays should be in plural.
    pluralize = true;
    visitT(n.next);
    pluralize = false;
    return n;
  }

  TypeNode visit(PointerType n)
  {
    char[] c = pluralize ? (pointer ? ""[] : "n") : "";
    pointer = true;
    put.format("Zeiger{} auf ", c), visitT(n.next);
    return n;
  }

  TypeNode visit(QualifiedType n)
  {
    visitT(n.lhs);
    put(".");
    visitT(n.rhs);
    return n;
  }

  TypeNode visit(IdentifierType n)
  {
    put(n.ident.str);
    return n;
  }

  TypeNode visit(IntegralType n)
  {
    char[] c = pluralize ? "s"[] : "";
    if (n.tok == TOK.Void) // Avoid pluralizing "void"
      c = "";
    put.format("{}{}", n.begin.srcText, c);
    return n;
  }
}
