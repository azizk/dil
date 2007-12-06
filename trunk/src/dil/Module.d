/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Module;
import dil.SyntaxTree;
import dil.Declarations;
import dil.Parser;
import dil.ImportParser;
import dil.Lexer;
import dil.File;
import tango.io.FilePath;
import tango.io.FileConst;
import common;

alias FileConst.PathSeparatorChar dirSep;

class Module
{
  bool isLightweight; /// If true an ImportParser is used instead of a full Parser.
  string filePath; /// Path to the source file.
  string moduleFQN; /// Fully qualified name of the module.
  string packageName;
  string moduleName;
  Declarations root; /// The root of the AST.
  ImportDeclaration[] imports;
  ModuleDeclaration moduleDecl;
  private Parser parser;

  Module[] modules;

  this(string filePath, bool isLightweight = false)
  {
    this.filePath = filePath;
    this.isLightweight = isLightweight;
  }

  void parse()
  {
    auto sourceText = loadFile(filePath);
    if (this.isLightweight)
      this.parser = new ImportParser(sourceText, filePath);
    else
      this.parser = new Parser(sourceText, filePath);

    this.root = parser.start();

    if (root.children.length)
    {
      // moduleDecl will be null if first node can't be cast to ModuleDeclaration.
      this.moduleDecl = Cast!(ModuleDeclaration)(root.children[0]);
      if (moduleDecl)
      {
        this.setFQN(moduleDecl.getFQN());
      }
      else
      {
        // Take base name of file path as module name.
        auto str = (new FilePath(filePath)).name();
        if (Lexer.isNonReservedIdentifier(str))
        {
          this.moduleFQN = moduleName = str;
        }
        // else
        // TODO: error: file name has invalid identifier characters.
      }

      this.imports = parser.imports;
    }
  }

  string[] getImports()
  {
    string[] result;
    foreach (import_; imports)
      result ~= import_.getModuleFQNs(dirSep);
    return result;
  }

  string getFQN()
  {
    return moduleFQN;
  }

  void setFQN(string moduleFQN)
  {
    uint i = moduleFQN.length;
    if (i != 0) // Don't decrement if string has zero length.
      i--;
    // Find last dot.
    for (; i != 0 && moduleFQN[i] != '.'; i--)
    {}
    this.moduleFQN = moduleFQN;
    this.packageName = moduleFQN[0..i];
    this.moduleName = moduleFQN[(i == 0 ? 0 : i+1) .. $];
  }

  string getFQNPath()
  {
    if (packageName.length)
      return packageName ~ dirSep ~ moduleName;
    else
      return moduleName;
  }
}
