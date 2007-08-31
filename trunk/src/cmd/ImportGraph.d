/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.ImportGraph;
import dil.SyntaxTree;
import dil.Declarations;
import dil.Token;
import dil.Parser, dil.Lexer;
import dil.File;
import dil.Module;

void execute(string fileName)
{
  auto mod = new Module(fileName);
  mod.parse();
  auto root = mod.root;

  Module[] modules;

  foreach (decl; root.children)
  {

  }
}
