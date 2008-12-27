/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module cmd.Compile;

import dil.semantic.Module,
       dil.semantic.Package,
       dil.semantic.Pass1,
       dil.semantic.Pass2,
       dil.semantic.Symbol,
       dil.semantic.Symbols;
import dil.doc.Doc;
import dil.Compilation;
import dil.Diagnostics;
import dil.ModuleManager;
import common;

/// The compile command.
struct CompileCommand
{
  string[] filePaths; /// Explicitly specified modules (on the command line.)
  bool printSymbolTree; /// Whether to print the symbol tree.
  bool printModuleTree; /// Whether to print the module tree.
  ModuleManager moduleMan;
  SemanticPass1[] passes1;

  CompilationContext context;
  Diagnostics diag;

  /// Executes the compile command.
  void run()
  {
    // TODO: import object.d
    moduleMan = new ModuleManager(context.importPaths, diag);
    foreach (filePath; filePaths)
      moduleMan.loadModuleFile(filePath);

    foreach (modul; moduleMan.loadedModules)
    {
      runPass1(modul);
      if (printSymbolTree)
        printSymbolTable(modul, "");
    }

    foreach (modul; moduleMan.loadedModules)
    {
      auto pass2 = new SemanticPass2(modul);
      pass2.run();
    }

    if (printModuleTree)
    {
      moduleMan.sortPackageTree();
      printMTree2(moduleMan.rootPackage, "");
    }
    // foreach (mod; moduleMan.orderedModules)
    //   Stdout(mod.moduleFQN, mod.imports.length).newline;
  }

  /// Prints the package/module tree including the root.
  void printMTree(Package pckg, string indent)
  {
    Stdout(indent)(pckg.pckgName)("/").newline; // PackageName/
    foreach (p; pckg.packages)
      printMTree(p, indent ~ "  "); // Print the sub-packages.
    foreach (m; pckg.modules) // Print the modules.
      Stdout(indent ~ "  ")(m.moduleName)(".")(m.fileExtension()).newline;
  }

  /// Prints the package/module tree excluding the root.
  void printMTree2(Package pckg, string indent)
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
  Module importModule(string moduleFQNPath)
  {
    auto modul = moduleMan.loadModule(moduleFQNPath);
    modul && runPass1(modul);
    return modul;
  }

  /// Prints all symbols recursively (for debugging.)
  static void printSymbolTable(ScopeSymbol scopeSym, char[] indent)
  {
    foreach (member; scopeSym.members)
    {
      auto tokens = DDocUtils.getDocTokens(member.node);
      char[] docText;
      foreach (token; tokens)
        docText ~= token.srcText;
      Stdout(indent).formatln("Id:{}, Symbol:{}, DocText:{}",
                              member.name.str, member.classinfo.name,
                              docText);
      if (auto s = cast(ScopeSymbol)member)
        printSymbolTable(s, indent ~ "→ ");
    }
  }
}
