/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module cmd.Compile;

import cmd.Command;
import dil.ast.Declarations;
import dil.lexer.Token;
import dil.semantic.Module,
       dil.semantic.Package,
       dil.semantic.Pass1,
       dil.semantic.Pass2,
       dil.semantic.Passes,
       dil.semantic.Symbol,
       dil.semantic.Symbols;
import dil.doc.Doc;
import dil.i18n.Messages;
import dil.Compilation,
       dil.Diagnostics,
       dil.ModuleManager,
       dil.String;
import common;

/// The compile command.
class CompileCommand : Command
{
  cstring[] filePaths; /// Explicitly specified modules (on the command line.)
  bool printSymbolTree; /// Whether to print the symbol tree.
  bool printModuleTree; /// Whether to print the module tree.
  bool m32; /// Emit 32bit code.
  bool m64; /// Emit 64bit code.

  cstring binOutput; /// Output destination.

  ModuleManager moduleMan;
  SemanticPass1[] passes1;

  CompilationContext context;
  Diagnostics diag;

  /// Executes the compile command.
  void run()
  {
    // TODO: import object.d
    moduleMan = new ModuleManager(context);
    foreach (filePath; filePaths)
      moduleMan.loadModuleFile(filePath);

    foreach (modul; moduleMan.loadedModules)
    {
      runPass1(modul);
      if (printSymbolTree)
        printSymbolTable(modul, "");
    }

    // foreach (modul; moduleMan.loadedModules)
    // {
    //   auto pass2 = new SemanticPass2(modul);
    //   pass2.run();
    // }

    if (printModuleTree)
    {
      moduleMan.sortPackageTree();
      printMTree2(moduleMan.rootPackage, "");
    }
    // foreach (mod; moduleMan.orderedModules)
    //   Stdout(mod.moduleFQN, mod.imports.length).newline;
  }

  /// Prints the package/module tree including the root.
  void printMTree(Package pckg, cstring indent)
  {
    Stdout(indent)(pckg.pckgName)("/").newline; // PackageName/
    foreach (p; pckg.packages)
      printMTree(p, indent ~ "  "); // Print the sub-packages.
    foreach (m; pckg.modules) // Print the modules.
      Stdout(indent ~ "  ")(m.moduleName)(".")(m.fileExtension()).newline;
  }

  /// Prints the package/module tree excluding the root.
  void printMTree2(Package pckg, cstring indent)
  {
    foreach (p; pckg.packages)
    {
      Stdout(indent)(p.pckgName)("/").newline; // PackageName/
      printMTree2(p, indent ~ "  "); // Print the sub-packages.
    }
    foreach (m; pckg.modules) // Print the modules.
      Stdout(indent)(m.moduleName)(".")(m.fileExtension()).newline;
  }

  /// Runs the first pass on modul.
  void runPass1(Module modul)
  {
    if (modul.hasErrors || modul.semanticPass != 0)
      return;
    auto pass1 = new SemanticPass1(modul, context);
    pass1.importModule = &importModule;
    pass1.run();
    passes1 ~= pass1;
  }

  /// Imports a module and runs the first pass on it.
  Module importModule(cstring moduleFQNPath)
  {
    auto modul = moduleMan.loadModule(moduleFQNPath);
    modul && runPass1(modul);
    return modul;
  }

  /// Prints all symbols recursively (for debugging.)
  static void printSymbolTable(ScopeSymbol scopeSym, cstring indent)
  {
    foreach (member; scopeSym.members)
    {
      auto tokens = DDocUtils.getDocTokens(member.loc.n);
      char[] docText;
      foreach (token; tokens)
        docText ~= token.text;
      Stdout(indent).formatln("Id:{}, Symbol:{}, DocText:{}",
                              member.name.str, typeid(member).name,
                              docText);
      if (auto s = cast(ScopeSymbol)member)
        printSymbolTable(s, indent ~ "→ ");
    }
  }
}


/// The compile command.
/// NOTE: The plan is to replace CompileCommand.
class CompileCommand2 : Command
{
  /// For finding and loading modules.
  ModuleManager mm;
  /// Context information.
  CompilationContext cc;
  /// Explicitly specified modules (on the command line.)
  cstring[] filePaths;
  /// Whether to print the symbol tree.
  bool printSymbolTree;
  /// Whether to print the module tree.
  bool printModuleTree;

  // Format strings for logging.
  auto LogPass1  = "pass1:  {}";
  auto LogPass2  = "pass2:  {}";
  auto LogDeps   = "deps:   {}";
  auto LogLoad   = "load:   {}";
  auto LogImport = "import: {} ({})";
  auto LogDiags  = "diagnostics:";

  /// Runs semantic pass 1 on a module. Also imports its dependencies.
  void runPass1(Module modul)
  {
    if (modul.hasErrors || modul.semanticPass != 0)
      return;

    lzy(log(LogPass1, modul.getFQN()));

    auto pass1 = new FirstSemanticPass(modul, cc);
    pass1.run();

    lzy({if (pass1.imports.length) log(LogDeps, modul.getFQN());}());

    // Load the module's imported modules.
    foreach (d; pass1.imports)
      importModuleByDecl(d, modul);
      // TODO: modul.modules ~= importedModule;
  }

  /// Runs semantic pass 2 on a module.
  void runPass2(Module modul)
  {
    if (modul.hasErrors || modul.semanticPass != 1)
      return;

    lzy(log(LogPass2, modul.getFQN()));

    auto pass2 = new SecondSemanticPass(modul, cc);
    pass2.run();
  }

  /// Loads a module by its file path and runs pass 1 on it.
  /// Params:
  ///   filePath = E.g.: src/main.d
  void importModuleByFile(cstring filePath)
  {
    if (mm.moduleByPath(filePath))
      return; // The module has already been loaded.

    lzy(log(LogLoad, filePath));

    if (auto modul = mm.loadModuleFile(filePath))
      runPass1(modul); // Load and run pass 1 on it.
    else
      mm.errorModuleNotFound(filePath);
  }

  /// Loads a module by its FQN path and runs pass 1 on it.
  /// Params:
  ///   modFQNPath = E.g.: dil/cmd/Compile
  ///   fqnTok = Identifier token in the import statement.
  ///   modul = Where the import statement is located.
  void importModuleByFQN(cstring modFQNPath,
    Token* fqnTok = null, Module modul = null)
  {
    if (mm.moduleByFQN(modFQNPath))
      return; // The module has already been loaded.
    if (auto modFilePath = mm.findModuleFile(modFQNPath))
    {
      lzy(log(LogImport, modFQNPath.replace('/', '.'), modFilePath));
      runPass1(mm.loadModule(modFQNPath)); // Load and run pass 1 on it.
    }
    else
      mm.errorModuleNotFound(modFQNPath ~ ".d",
        fqnTok ? fqnTok.getErrorLocation(modul.filePath()) : null);
  }

  void importModuleByDecl(ImportDecl d, Module modul)
  {
    foreach (i, fqnPath; d.getModuleFQNs(dirSep))
      importModuleByFQN(fqnPath, d.moduleFQNs[i][0], modul);
  }

  /// Runs the command.
  void run()
  {
    mm = new ModuleManager(cc);

    // Always implicitly import "object.d".
    importModuleByFQN("object");
    auto objectModule = mm.moduleByFQN("object");
    if (!objectModule)
    {} // error

    // Load modules specified on the command line.
    foreach (filePath; filePaths)
      importModuleByFile(filePath);

    // Run pass2 on all the loaded modules.
    foreach (m; mm.orderedModules)
    {
      runPass2(m);
    }

    lzy({if (cc.diag.hasInfo()) log(LogDiags);}());
    //lzy(cc.diag.hasInfo() && log(LogDiags)); // DMD bug: void has no value
  }
}
