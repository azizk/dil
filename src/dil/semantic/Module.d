/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.semantic.Module;

import dil.ast.Node,
       dil.ast.Declarations;
import dil.parser.Parser;
import dil.lexer.Lexer,
       dil.lexer.IdTable;
import dil.semantic.Symbol,
       dil.semantic.Symbols;
import dil.Location;
import dil.Messages;
import dil.Diagnostics;
import dil.SourceText;
import util.Path;
import common;

import tango.io.model.IFile;

alias FileConst.PathSeparatorChar dirSep;

/// Represents a semantic D module and a source file.
class Module : ScopeSymbol
{
  SourceText sourceText; /// The source file of this module.
  string moduleFQN; /// Fully qualified name of the module. E.g.: dil.ast.Node
  string packageName; /// E.g.: dil.ast
  string moduleName; /// E.g.: Node
  uint ID; /// A unique 1-based ID. Useful for graph traversing.

  CompoundDeclaration root; /// The root of the parse tree.
  ImportDeclaration[] imports; /// ImportDeclarations found in this file.
  ModuleDeclaration moduleDecl; /// The optional ModuleDeclaration in this file.
  Parser parser; /// The parser used to parse this file.

  /// Indicates which passes have been run on this module.
  ///
  /// 0 = no pass$(BR)
  /// 1 = semantic pass 1$(BR)
  /// 2 = semantic pass 2
  uint semanticPass;
  Module[] modules; /// The imported modules.

  Diagnostics diag; /// Collects error messages.
  bool failedLoading; /// True if loading the source file failed.

  this()
  {
    super(SYM.Module, null, null);
  }

  /// Constructs a Module object.
  /// Params:
  ///   filePath = file path to the source text; loaded in the constructor.
  ///   diag = used for collecting error messages.
  this(string filePath, Diagnostics diag = null)
  {
    this();
    this.sourceText = new SourceText(filePath);
    this.diag = diag is null ? new Diagnostics() : diag;
    this.failedLoading = !this.sourceText.load(diag);
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
  void parse()
  {
    if (this.parser is null)
      this.parser = new Parser(sourceText, diag);

    this.root = parser.start();
    this.imports = parser.imports;

    // Set the fully qualified name of this module.
    if (this.root.children.length)
    { // moduleDecl will be null if first node isn't a ModuleDeclaration.
      this.moduleDecl = this.root.children[0].Is!(ModuleDeclaration);
      if (this.moduleDecl)
        this.setFQN(moduleDecl.getFQN()); // E.g.: dil.ast.Node
    }

    if (!this.moduleFQN.length)
    { // Take the base name of the file as the module name.
      auto str = Path(filePath).name(); // E.g.: Node
      if (!Lexer.isValidUnreservedIdentifier(str))
      {
        auto location = this.firstToken().getErrorLocation();
        auto msg = Format(MSG.InvalidModuleName, str);
        diag ~= new LexerError(location, msg);
        str = IdTable.genModuleID().str;
      }
      this.moduleFQN = this.moduleName = str;
    }
    assert(this.moduleFQN.length);

    // Set the symbol name.
    this.name = IdTable.lookup(this.moduleName);
  }

  /// Returns the first token of the module's source text.
  Token* firstToken()
  {
    return parser.lexer.firstToken();
  }

  /// Returns the begin token of the module declaration
  /// or, if it doesn't exist, the first token in the source text.
  Token* getModuleDeclToken()
  {
    return moduleDecl ? moduleDecl.begin : firstToken();
  }

  /// Returns true if there are errors in the source file.
  bool hasErrors()
  {
    return parser.errors.length || parser.lexer.errors.length || failedLoading;
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
    if (i == 0)
      this.moduleName = moduleFQN; // No dot found.
    else
    {
      this.packageName = moduleFQN[0..i];
      this.moduleName = moduleFQN[i+1..$];
    }
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
