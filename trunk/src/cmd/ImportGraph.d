/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.ImportGraph;

import dil.ast.Node;
import dil.ast.Declarations;
import dil.Token;
import dil.File;
import dil.Module;
import dil.Settings;
import tango.text.Regex : RegExp = Regex;
import tango.io.FilePath;
import tango.io.FileConst;
import tango.text.Util;
import common;

alias FileConst.PathSeparatorChar dirSep;

enum IGraphOption
{
  None,
  IncludeUnlocatableModules = 1,
  PrintDot                  = 1<<1,
  HighlightCyclicEdges      = 1<<2,
  HighlightCyclicVertices   = 1<<3,
  GroupByPackageNames       = 1<<4,
  GroupByFullPackageName    = 1<<5,
  PrintPaths                = 1<<6,
  PrintList                 = 1<<7,
  MarkCyclicModules         = 1<<8,
}

string findModulePath(string moduleFQN, string[] importPaths)
{
  string modulePath;
  foreach (path; importPaths)
  {
    modulePath = path ~ dirSep ~ moduleFQN ~ ".d";
    // TODO: also check for *.di?
    if ((new FilePath(modulePath)).exists())
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
  auto fileDir = (new FilePath(filePath)).folder();
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
      if (rx.test(replace(moduleFQNPath, dirSep, '.')))
        return null;

    auto modulePath = findModulePath(moduleFQNPath, importPaths);
    Vertex mod;
    if (modulePath is null)
    {
      if (options & IGraphOption.IncludeUnlocatableModules)
      {
        mod = new Vertex(null);
        mod.setFQN(replace(moduleFQNPath, dirSep, '.'));
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

  // Check that every module has at least one incoming or outgoing edge.
  assert(
    delegate {
      foreach (mod; loadedModulesList)
        if (mod.incoming.length == 0 && mod.outgoing.length == 0)
          throw new Exception("module "~mod.getFQN()~" has no edges in the graph.");
      return true;
    }() == true
  );

  if (options & (IGraphOption.PrintList | IGraphOption.PrintPaths))
  {
    if (options & IGraphOption.MarkCyclicModules)
      analyzeGraph(loadedModulesList, edges.dup);

    if (options & IGraphOption.PrintPaths)
      printPaths(loadedModulesList, levels+1, "");
    else
      printList(loadedModulesList, levels+1, "");
  }
  else 
    printDot(loadedModulesList, edges, options);
}

void printPaths(Vertex[] vertices, uint level, char[] indent)
{
  if (!level)
    return;
  foreach (vertex; vertices)
  {
    Stdout(indent)((vertex.isCyclic?"*":"")~vertex.filePath).newline;
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
    Stdout(indent)((vertex.isCyclic?"*":"")~vertex.getFQN()).newline;
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

  Stdout("Digraph ModuleDependencies\n{\n");

  if (options & IGraphOption.HighlightCyclicVertices)
    foreach (i, module_; loadedModulesList)
      Stdout.format(`  n{0} [label="{1}"{2}];`, i, module_.getFQN(), (module_.isCyclic ? ",style=filled,fillcolor=tomato" : "")).newline;
  else
    foreach (i, module_; loadedModulesList)
      Stdout.format(`  n{0} [label="{1}"];`, i, module_.getFQN()).newline;

  foreach (edge; edges)
    Stdout.format(`  n{0} -> n{1}{2};`, edge.outgoing.id, edge.incoming.id, (edge.isCyclic ? "[color=red]" : "")).newline;

  if (options & IGraphOption.GroupByFullPackageName)
    foreach (packageName, vertices; verticesByPckgName)
    {
      Stdout.format(`  subgraph "cluster_{0}" {`\n`    label="{1}";color=blue;`"\n    ", packageName, packageName);
      foreach (module_; vertices)
        Stdout.format(`n{0};`, module_.id);
      Stdout("\n  }\n");
    }

  Stdout("}\n");
}

void analyzeGraph(Vertex[] vertices_init, Edge[] edges)
{
  void recursive(Vertex[] vertices)
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
          recursive(vertices);
          return;
        }
        else
        {
          // Edges to this vertex were removed previously.
          // Only remove vertex now.
          vertices = vertices[0..idx] ~ vertices[idx+1..$];
          recursive(vertices);
          return;
        }
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
        recursive(vertices);
        return;
      }
//       else
//       {
//         // source && sink
//         // continue loop.
//       }
    }

    // When reaching this point it means only cylic edges and vertices are left.
    foreach (vertex; vertices)
      vertex.isCyclic = true;
    foreach (edge; edges)
      if (edge)
        edge.isCyclic = true;
  }
  recursive(vertices_init);
}
