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
import std.stdio : writefln, writef;
import std.path : getDirName, dirSep = sep;
import std.file : exists;
import std.string : replace;
import std.regexp;

enum IGraphOption
{
  None,
  IncludeUnlocatableModules = 1,
  HighlightCyclicEdges      = 1<<1,
  HighlightCyclicVertices   = 1<<2,
  PrintDot                  = 1<<3,
  PrintPaths                = 1<<4,
  PrintList                 = 1<<5,
  GroupByPackageNames       = 1<<6,
  GroupByFullPackageName    = 1<<7,
}

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

class Edge
{
  Vertex outgoing;
  Vertex incoming;
  bool isCyclic;
  this(Vertex o, Vertex i)
  {
    this.outgoing = o;
    this.incoming = i;
  }
}

class Vertex : Module
{
  uint id;
  Vertex[] incoming;
  bool isCyclic; /// Whether this vertex is in a cyclic relationship with other vertices.

  this(string filePath)
  {
    super(filePath, true);
  }

  Vertex[] outgoing()
  {
    return cast(Vertex[])super.modules;
  }
}

void execute(string filePath, string[] importPaths, string[] strRegexps, uint levels, IGraphOption options)
{
  // Init regular expressions.
  RegExp[] regexps;
  foreach (strRegexp; strRegexps)
    regexps ~= new RegExp(strRegexp);

  // Add directory of file and global directories to import paths.
  auto fileDir = getDirName(filePath);
  if (fileDir.length)
    importPaths ~= fileDir;
  importPaths ~= GlobalSettings.importPaths;

  Vertex[string] loadedModules;
  Vertex[] loadedModulesList; // Ordered list of loaded modules.
  Edge edges[];

  Vertex loadModule(string moduleFQNPath)
  {
    auto mod_ = moduleFQNPath in loadedModules;
    if (mod_ !is null)
      return *mod_; // Return already loaded module.

    // Ignore module names matching regular expressions.
    foreach (rx; regexps)
      if (rx.test(replace(moduleFQNPath, dirSep, ".")))
        return null;

    auto modulePath = findModulePath(moduleFQNPath, importPaths);
    Vertex mod;
    if (modulePath is null)
    {
      if (options & IGraphOption.IncludeUnlocatableModules)
      {
        mod = new Vertex(null);
        mod.setFQN(replace(moduleFQNPath, dirSep, "."));
        loadedModules[moduleFQNPath] = mod;
        loadedModulesList ~= mod;
        mod.id = loadedModulesList.length -1;
      }
    }
    else
    {
// writefln(modulePath);
      mod = new Vertex(modulePath);
      mod.parse();

      loadedModules[moduleFQNPath] = mod;
      loadedModulesList ~= mod;
      mod.id = loadedModulesList.length -1;

      auto moduleFQNs = mod.getImports();

      foreach (moduleFQN_; moduleFQNs)
      {
        auto loaded_mod = loadModule(moduleFQN_);
        if (loaded_mod !is null)
        {
          edges ~= new Edge(mod, loaded_mod);
          mod.modules ~= loaded_mod;
          loaded_mod.incoming ~= mod;
        }
      }
    }
    return mod;
  }

  auto mod = new Vertex(filePath);
  mod.parse();

  auto moduleFQNs = mod.getImports();

  loadedModules[mod.getFQNPath()] = mod;
  loadedModulesList ~= mod;
  mod.id = 0; // loadedModulesList.length -1

  foreach (moduleFQN_; moduleFQNs)
  {
    auto loaded_mod = loadModule(moduleFQN_);
    if (loaded_mod !is null)
    {
      edges ~= new Edge(mod, loaded_mod);
      mod.modules ~= loaded_mod;
      loaded_mod.incoming ~= mod;
    }
  }
  // Finished loading modules.


  if (options & IGraphOption.PrintPaths)
    printPaths(loadedModulesList, levels+1, "");
  else if (options & IGraphOption.PrintList)
    printList(loadedModulesList, levels+1, "");
  else if (options & IGraphOption.PrintDot)
    printDot(loadedModulesList, edges, options);
}

void printPaths(Vertex[] vertices, uint level, char[] indent)
{
  if (!level)
    return;
  foreach (vertex; vertices)
  {
    writefln(indent, vertex.filePath);
    if (vertex.outgoing.length)
      printPaths(vertex.outgoing, level-1, indent~"  ");
  }
}

void printList(Vertex[] vertices, uint level, char[] indent)
{
  if (!level)
    return;
  foreach (vertex; vertices)
  {
    writefln(indent, vertex.getFQN());
    if (vertex.outgoing.length)
      printList(vertex.outgoing, level-1, indent~"  ");
  }
}

void printDot(Vertex[] loadedModulesList, Edge[] edges, IGraphOption options)
{
  Vertex[][string] verticesByPckgName;
  if (options & IGraphOption.GroupByFullPackageName)
    foreach (module_; loadedModulesList)
      verticesByPckgName[module_.packageName] ~= module_;

  if (options & (IGraphOption.HighlightCyclicVertices |
                 IGraphOption.HighlightCyclicEdges))
    analyzeGraph(loadedModulesList, edges.dup);

  writefln("Digraph ModuleDependencies\n{");

  if (options & IGraphOption.HighlightCyclicVertices)
    foreach (i, module_; loadedModulesList)
      writefln(`  n%d [label="%s"%s];`, i, module_.getFQN(), (module_.isCyclic ? ",style=filled,fillcolor=tomato" : ""));
  else
    foreach (i, module_; loadedModulesList)
      writefln(`  n%d [label="%s"];`, i, module_.getFQN());

  foreach (edge; edges)
    writefln(`  n%d -> n%d%s;`, edge.outgoing.id, edge.incoming.id, (edge.isCyclic ? "[color=red]" : ""));

  if (options & IGraphOption.GroupByFullPackageName)
    foreach (packageName, vertices; verticesByPckgName)
    {
      writef(`  subgraph "cluster_%s" {`\n`    label="%s";color=blue;`"\n    ", packageName, packageName);
      foreach (module_; vertices)
        writef(`n%d;`, module_.id);
      writefln("\n  }");
    }

  writefln("}");
}

void analyzeGraph(Vertex[] vertices, Edge[] edges)
{
  void recursive(Vertex[] modules)
  {
    foreach (idx, vertex; vertices)
    {
      uint outgoing, incoming;
      foreach (j, edge; edges)
      {
        if (edge.outgoing is vertex)
          outgoing++;
        if (edge.incoming is vertex)
          incoming++;
      }

      if (outgoing == 0)
      {
        if (incoming != 0)
        {
          // Vertex is a sink.
          alias outgoing i; // Reuse
          alias incoming j; // Reuse
          // Remove edges.
          for (i=j=0; i < edges.length; i++)
            if (edges[i].incoming !is vertex)
              edges[j++] = edges[i];
          edges.length = j;
          vertices = vertices[0..idx] ~ vertices[idx+1..$];
          return recursive(modules);
        }
        else
          assert(0, "orphaned module: "~vertex.getFQN()~" (has no edges in graph)"); // orphaned vertex (module) in graph
      }
      else if (incoming == 0)
      {
        // Vertex is a source
        alias outgoing i; // Reuse
        alias incoming j; // Reuse
        // Remove edges.
        for (i=j=0; i < edges.length; i++)
          if (edges[i].outgoing !is vertex)
            edges[j++] = edges[i];
        edges.length = j;
        vertices = vertices[0..idx] ~ vertices[idx+1..$];
        return recursive(modules);
      }
//       else
//       {
//         // source && sink
//       }
    }

    // When reaching this point it means only cylic edges and vertices are left.
    foreach (vertex; vertices)
      vertex.isCyclic = true;
    foreach (edge; edges)
      if (edge)
        edge.isCyclic = true;
  }
  recursive(vertices);
}
