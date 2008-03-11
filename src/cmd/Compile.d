/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.Compile;

import dil.semantic.Module;
import dil.semantic.Pass1;
import dil.semantic.Pass2;
import dil.semantic.Symbols;
import dil.doc.Doc;
import dil.Compilation;
import dil.Information;
import dil.ModuleManager;
import common;

/// The compile command.
struct CompileCommand
{
  string[] filePaths; /// Explicitly specified modules (on the command line.)
  ModuleManager moduleMan;
  SemanticPass1[] passes1;

  CompilationContext context;
  InfoManager infoMan;

  /// Executes the compile command.
  void run()
  {
    moduleMan = new ModuleManager(context.importPaths, infoMan);
    foreach (filePath; filePaths)
    {
      auto modul = moduleMan.loadModuleFile(filePath);
      runPass1(modul);
      printSymbolTable(modul, "");
    }

    // foreach (modul; moduleMan.loadedModules)
    // {
    //   auto pass2 = new SemanticPass2(modul);
    //   pass2.run();
    // }
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
      auto tokens = getDocTokens(member.node);
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
