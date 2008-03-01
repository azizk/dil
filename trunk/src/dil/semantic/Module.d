/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.semantic.Module;

import dil.ast.Node;
import dil.ast.Declarations;
import dil.parser.Parser;
import dil.lexer.Lexer;
import dil.semantic.Symbol;
import dil.semantic.Symbols;
import dil.Information;
import dil.SourceText;
import common;

import tango.io.FilePath;
import tango.io.FileConst;

alias FileConst.PathSeparatorChar dirSep;

/// Represents a semantic D module and a source file.
class Module : ScopeSymbol
{
  SourceText sourceText; /// The source file of this module.
  string moduleFQN; /// Fully qualified name of the module. E.g.: dil.ast.Node
  string packageName; /// E.g.: dil.ast
  string moduleName; /// E.g.: Node

  CompoundDeclaration root; /// The root of the parse tree.
  ImportDeclaration[] imports; /// ImportDeclarations found in this file.
  ModuleDeclaration moduleDecl; /// The optional ModuleDeclaration in this file.
  Parser parser; /// The parser used to parse this file.

  // Module[] modules;

  InfoManager infoMan; /// Collects error messages.

  this()
  {
    super(SYM.Module, null, null);
  }

  /// Constructs a Module object.
  /// Params:
  ///   filePath = file path to the source text; loaded in the constructor.
  ///   infoMan = used for collecting error messages.
  this(string filePath, InfoManager infoMan = null)
  {
    this();
    this.sourceText = new SourceText(filePath);
    this.infoMan = infoMan;
    this.sourceText.load(infoMan);
  }

  /// Returns the file path of the source text.
  string filePath()
  {
    return sourceText.filePath;
  }

  /// Returns the file extension: "d" or "di".
  string fileExtension()
  {
    foreach_reverse(i, c; filePath)
      if (c == '.')
        return filePath[i+1..$];
    return "";
  }

  /// Sets the parser to be used for parsing the source text.
  void setParser(Parser parser)
  {
    this.parser = parser;
  }

  /// Parses the module.
  /// Throws:
  ///   An Exception if the there's no ModuleDeclaration and
  ///   the file name is an invalid or reserved D identifier.
  void parse()
  {
    if (this.parser is null)
      this.parser = new Parser(sourceText, infoMan);

    this.root = parser.start();
    this.imports = parser.imports;

    if (root.children.length)
    { // moduleDecl will be null if first node isn't a ModuleDeclaration.
      this.moduleDecl = root.children[0].Is!(ModuleDeclaration);
      if (this.moduleDecl)
        this.setFQN(moduleDecl.getFQN());
    }

    if (!this.moduleFQN.length)
    { // Take base name of file path as module name.
      auto str = (new FilePath(filePath)).name();
      if (Lexer.isReservedIdentifier(str))
        throw new Exception("'"~str~"' is not a valid module name; it's a reserved or invalid D identifier.");
      this.moduleFQN = this.moduleName = str;
    }
  }

  /// Returns the first token of the module's source text.
  Token* firstToken()
  {
    return parser.lexer.firstToken();
  }

  /// Returns true if there are errors in the source file.
  bool hasErrors()
  {
    return parser.errors.length || parser.lexer.errors.length;
  }

  /// Returns a list of import paths.
  /// E.g.: ["dil/ast/Node", "dil/semantic/Module"]
  string[] getImportPaths()
  {
    string[] result;
    foreach (import_; imports)
      result ~= import_.getModuleFQNs(dirSep);
    return result;
  }

  /// Returns the fully qualified name of this module.
  /// E.g.: dil.ast.Node
  string getFQN()
  {
    return moduleFQN;
  }

  /// Set's the module's FQN.
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

  /// Returns the module's FQN with slashes instead of dots.
  /// E.g.: dil/ast/Node
  string getFQNPath()
  {
    string FQNPath = moduleFQN.dup;
    foreach (i, c; FQNPath)
      if (c == '.')
        FQNPath[i] = dirSep;
    return FQNPath;
  }
}
