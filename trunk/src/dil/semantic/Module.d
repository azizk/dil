/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Module;

import dil.ast.Node;
import dil.ast.Declarations;
import dil.parser.Parser;
import dil.parser.ImportParser;
import dil.lexer.Lexer;
import dil.File;
import dil.semantic.Scope;
import dil.semantic.Symbol;
import dil.semantic.Symbols;
import dil.Information;
import tango.io.FilePath;
import tango.io.FileConst;
import common;

alias FileConst.PathSeparatorChar dirSep;

class Module : ScopeSymbol
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

  InfoManager infoMan;

  this(string filePath, bool isLightweight = false)
  {
    this.sid = SYM.Module;

    this.filePath = filePath;
    this.isLightweight = isLightweight;
  }

  this(string filePath, InfoManager infoMan)
  {
    this(filePath, false);
    this.infoMan = infoMan;
  }

  void parse()
  {
    auto sourceText = loadFile(filePath);
    if (this.isLightweight)
      this.parser = new ImportParser(sourceText, filePath);
    else
      this.parser = new Parser(sourceText, filePath, infoMan);

    this.root = parser.start();

    if (root.children.length)
    {
      // moduleDecl will be null if first node isn't a ModuleDeclaration.
      this.moduleDecl = root.children[0].Is!(ModuleDeclaration);
      if (moduleDecl)
      {
        this.setFQN(moduleDecl.getFQN());
      }
      else
      {
        // Take base name of file path as module name.
        auto str = (new FilePath(filePath)).name();
        if (!Lexer.isReservedIdentifier(str))
        {
          this.moduleFQN = moduleName = str;
        }
        // else
        // TODO: error: file name has invalid identifier characters.
      }

      this.imports = parser.imports;
    }
  }

  /// Returns true if there are errors in the source file.
  bool hasErrors()
  {
    return parser.errors.length || parser.lexer.errors.length;
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
