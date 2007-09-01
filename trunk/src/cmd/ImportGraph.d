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
import dil.Settings;
import std.stdio : writefln;
import std.path : getDirName, dirSep = sep;
import std.file : exists;

string findModule(string moduleFQN, string[] importPaths)
{
  string modulePath;
  foreach (path; importPaths)
  {
    modulePath = path ~ (path[$-1] == dirSep[0] ? "" : dirSep) ~ moduleFQN ~ ".d";
    if (exists(modulePath))
      return modulePath;
  }
  return null;
}

void execute(string fileName, string[] importPaths)
{
  // Add directory of file and global directories to import paths.
  importPaths ~= getDirName(fileName) ~ GlobalSettings.importPaths;

  Module[string] loadedModules;

  Module loadModule(string moduleFQN)
  {
    auto mod_ = moduleFQN in loadedModules;
    if (mod_ !is null)
      return *mod_;
// writefln(moduleFQN);
    auto modulePath = findModule(moduleFQN, importPaths);
    if (modulePath is null)
      writefln("Warning: Module %s.d couldn't be found.", moduleFQN);
    else
    {
      auto mod = new Module(modulePath, true);
      mod.parse();

      loadedModules[moduleFQN] = mod;

      auto moduleFQNs = mod.getImports();

      foreach (moduleFQN_; moduleFQNs)
        mod.modules ~= loadModule(moduleFQN_);
      return mod;
    }
    return null;
  }

  auto mod = new Module(fileName, true);
  mod.parse();

  auto moduleFQNs = mod.getImports();

  foreach (moduleFQN_; moduleFQNs)
    mod.modules ~= loadModule(moduleFQN_);
}
