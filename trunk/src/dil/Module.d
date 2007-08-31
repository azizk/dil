/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Module;
import dil.SyntaxTree;
import dil.Declarations;
import dil.Parser;
import dil.File;

class Module
{
  string fileName; /// Path to the source file.
  string packageName;
  string moduleName;
  Declarations root; /// The root of the AST.
  ImportDeclaration[] imports;
  ModuleDeclaration moduleDecl;

  this(string fileName)
  {
    this.fileName = fileName;
  }

  void parse()
  {
    auto sourceText = loadFile(fileName);
    auto parser = new Parser(sourceText, fileName);
    parser.start();

    this.root = parser.parseModule();

    if (root.children.length)
    {
      // moduleDecl will be null if first node can't be casted to ModuleDeclaration.
      this.moduleDecl = Cast!(ModuleDeclaration)(root.children[0]);

      this.imports = parser.imports;
    }
  }
}
