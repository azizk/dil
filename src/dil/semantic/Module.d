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
import dil.i18n.Messages;
import dil.Compilation,
       dil.Location,
       dil.Diagnostics,
       dil.SourceText,
       dil.String;
import util.Path;
import common;

import tango.io.model.IFile,
       tango.io.device.File;

alias dirSep = FileConst.PathSeparatorChar;

/// Represents a semantic D module and a source file.
class Module : ModuleSymbol
{
  SourceText sourceText; /// The source file of this module.
  cstring moduleFQN; /// Fully qualified name of the module. E.g.: dil.ast.Node
  cstring packageName; /// E.g.: dil.ast
  cstring moduleName; /// E.g.: Node
  size_t ID; /// A unique 1-based ID. Useful for graph traversing.

  CompoundDecl root; /// The root of the parse tree.
  ImportDecl[] imports; /// ImportDeclarations found in this file.
  ModuleDecl moduleDecl; /// The optional ModuleDecl in this file.
  Parser parser; /// The parser used to parse this file.

  /// Indicates which passes have been run on this module.
  ///
  /// 0 = No pass.$(BR)
  /// 1 = Semantic pass 1.$(BR)
  /// 2 = Semantic pass 2.
  uint semanticPass;
  Module[] modules; /// The imported modules.

  bool failedLoading; /// True if loading the source file failed.

  CompilationContext cc; /// The compilation context.

  /// Set when the Lexer should load the tokens from a file.
  string dlxFilePath;

  this()
  {
    super();
  }

  /// Constructs a Module object.
  /// Params:
  ///   filePath = File path to the source text; loaded in the constructor.
  this(cstring filePath, CompilationContext cc)
  {
    this();
    this.cc = cc;
    this.sourceText = new SourceText(filePath);
    this.failedLoading = !this.sourceText.load(cc.diag);
  }

  /// Constructs from a ready-to-use SourceText instance.
  this(SourceText src, CompilationContext cc)
  {
    this();
    this.cc = cc;
    this.sourceText = src;
  }

  /// Returns the file path of the source text.
  cstring filePath()
  {
    return sourceText.filePath;
  }

  /// Returns filePath and escapes '/' or '\' with '_'.
  cstring filePathEsc()
  {
    return filePath().replace(dirSep, '_');
  }

  /// Returns the file extension: "d" or "di".
  cstring fileExtension()
  {
    auto i = String(filePath).findr('.');
    return i != -1 ? filePath[i..$] : "";
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
      this.parser = new Parser(sourceText, cc.tables.lxtables, cc.diag);

    if (this.dlxFilePath.length)
      this.parser.lexer.fromDLXFile(cast(ubyte[])File.get(dlxFilePath));

    this.root = parser.start();
    this.imports = parser.imports;

    // Set the fully qualified name of this module.
    if (this.root.children.length)
    { // moduleDecl will be null if first node isn't a ModuleDecl.
      this.moduleDecl = this.root.children[0].Is!(ModuleDecl);
      if (this.moduleDecl)
        this.setFQN(moduleDecl.getFQN()); // E.g.: dil.ast.Node
    }

    auto idtable = cc.tables.idents;

    if (!this.moduleFQN.length)
    { // Take the base name of the file as the module name.
      auto str = Path(filePath).name(); // E.g.: Node
      if (!idtable.isValidUnreservedIdentifier(str))
      {
        auto location = this.firstToken().getErrorLocation(filePath());
        auto msg = cc.diag.formatMsg(MID.InvalidModuleName, str);
        cc.diag ~= new LexerError(location, msg);
        str = idtable.genModuleID().str;
      }
      this.moduleFQN = this.moduleName = str;
    }
    assert(this.moduleFQN.length);

    // Set the symbol name.
    this.name = idtable.lookup(this.moduleName);
    // Set the symbol node.
    this.loc.n = this.root;
    this.loc.t = this.moduleDecl ? this.moduleDecl.begin : this.firstToken();
  }

  /// Returns the first token of the module's source text.
  Token* firstToken()
  {
    return parser.lexer.firstToken();
  }

  /// Returns true if there are errors in the source file.
  bool hasErrors()
  {
    assert(parser && parser.lexer);
    return parser.errors.length || parser.lexer.errors.length || failedLoading;
  }

  /// Returns a list of import paths.
  /// E.g.: ["dil/ast/Node", "dil/semantic/Module"]
  cstring[] getImportPaths()
  {
    cstring[] result;
    foreach (import_; imports)
      result ~= import_.getModuleFQNs(dirSep);
    return result;
  }

  /// Returns the fully qualified name of this module.
  /// E.g.: dil.ast.Node
  override cstring getFQN()
  {
    return moduleFQN;
  }

  /// Sets the module's FQN.
  void setFQN(cstring moduleFQN)
  {
    this.moduleFQN = moduleFQN;
    auto i = String(moduleFQN).findr('.');
    if (i != -1)
      this.packageName = moduleFQN[0..i];
    this.moduleName = moduleFQN[i+1..$];
  }

  /// Returns the module's FQN with slashes instead of dots.
  /// E.g.: dil.ast.Node -> dil/ast/Node
  cstring getFQNPath()
  {
    return moduleFQN.replace('.', dirSep);
  }
}
