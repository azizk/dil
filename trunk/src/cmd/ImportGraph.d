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
import std.string : replace;

string findModulePath(string moduleFQN, string[] importPaths)
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

struct Edge
{
  Module outgoing;
  Module incoming;
  static Edge opCall(Module o, Module i)
  {
    Edge e;
    e.outgoing = o;
    e.incoming = i;
    return e;
  }
}

void execute(string fileName, string[] importPaths)
{
  // Add directory of file and global directories to import paths.
  auto fileDir = getDirName(fileName);
  if (fileDir.length)
    importPaths ~= fileDir;
  importPaths ~= GlobalSettings.importPaths;

  Module[string] loadedModules;
  Module[] loadedModulesList; // Ordered list of loaded modules.
  Edge edges[];

  Module loadModule(string moduleFQNPath)
  {
    auto mod_ = moduleFQNPath in loadedModules;
    if (mod_ !is null)
      return *mod_;
// writefln(moduleFQN);
    auto modulePath = findModulePath(moduleFQNPath, importPaths);
    Module mod;
    if (modulePath is null)
    {
// writefln("Warning: Module %s.d couldn't be found.", moduleFQNPath);
      mod = new Module(null, true);
      mod.setFQN(replace(moduleFQNPath, dirSep, "."));
      loadedModules[moduleFQNPath] = mod;
      loadedModulesList ~= mod;
    }
    else
    {
      mod = new Module(modulePath, true);
      mod.parse();

      loadedModules[moduleFQNPath] = mod;
      loadedModulesList ~= mod;

      auto moduleFQNs = mod.getImports();

      foreach (moduleFQN_; moduleFQNs)
      {
        auto loaded_mod = loadModule(moduleFQN_);
        edges ~= Edge(mod, loaded_mod);
        mod.modules ~= loaded_mod;
      }
      return mod;
    }
    return mod;
  }

  auto mod = new Module(fileName, true);
  mod.parse();

  auto moduleFQNs = mod.getImports();

  loadedModules[mod.getFQNPath()] = mod;
  loadedModulesList ~= mod;

  foreach (moduleFQN_; moduleFQNs)
  {
    auto loaded_mod = loadModule(moduleFQN_);
    edges ~= Edge(mod, loaded_mod);
    mod.modules ~= loaded_mod;
  }

  writefln("digraph module_dependencies\n{");
  foreach (edge; edges)
  {
    writefln(`  "%s" -> "%s"`, edge.outgoing.getFQN(), edge.incoming.getFQN());
  }
  writefln("}");
}

Edge[] findCyclicEdges(Module[] modules, Edge[] edges)
{
  foreach (module_; modules)
  {
    uint outgoing, incoming;
    foreach (edge; edges)
    {
      if (edge.outgoing == module_)
        outgoing++;
      if (edge.incoming == module_)
        incoming++;
    }

    if (outgoing == 0)
    {
      if (incoming != 0)
      {
        // sink
      }
      else
        assert(0); // orphaned vertex (module) in graph
    }
    else if (incoming == 0)
    {
      // source
    }
    else
    {
      // source && sink
    }
  }
  return null;
}
