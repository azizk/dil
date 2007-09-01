/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Module;
import dil.SyntaxTree;
import dil.Declarations;
import dil.Parser;
import dil.Lexer;
import dil.File;
import std.path;

class Module
{
  bool isLightweight; /// If true an ImportParser is used instead of a full Parser.
  string fileName; /// Path to the source file.
  string packageName;
  string moduleName;
  Declarations root; /// The root of the AST.
  ImportDeclaration[] imports;
  ModuleDeclaration moduleDecl;
  private Parser parser;

  Module[] modules;

  this(string fileName, bool isLight = false)
  {
    this.fileName = fileName;
    this.isLightweight = isLightweight;
  }

  void parse()
  {
    auto sourceText = loadFile(fileName);
    if (this.isLightweight)
      this.parser = new ImportParser(sourceText, fileName);
    else
      this.parser = new Parser(sourceText, fileName);

    this.root = parser.start();

    if (root.children.length)
    {
      // moduleDecl will be null if first node can't be casted to ModuleDeclaration.
      this.moduleDecl = Cast!(ModuleDeclaration)(root.children[0]);
      if (moduleDecl)
      {
        this.moduleName = moduleDecl.getName();
        this.packageName = moduleDecl.getPackageName(std.path.sep[0]);
      }
      else
      {
        auto str = getBaseName(getName(fileName));
        if (Lexer.isNonReservedIdentifier(str))
          this.moduleName = str;
      }

      this.imports = parser.imports;
    }
  }

  string[] getImports()
  {
    string[] result;
    foreach (import_; imports)
      result ~= import_.getModuleFQNs(std.path.sep[0]);
    return result;
  }

  string getFQN()
  {
    return packageName ~ std.path.sep ~ moduleName;
  }
}
