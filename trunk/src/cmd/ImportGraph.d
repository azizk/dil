/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.ImportGraph;

import dil.ast.Node;
import dil.ast.Declarations;
import dil.semantic.Module;
import dil.parser.ImportParser;
import dil.File;
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

class Graph
{
  Vertex[] vertices;
  Edge[] edges;

  void addVertex(Vertex vertex)
  {
    vertex.id = vertices.length;
    vertices ~= vertex;
  }

  Edge addEdge(Vertex from, Vertex to)
  {
    auto edge = new Edge(from, to);
    edges ~= edge;
    from.outgoing ~= to;
    to.incoming ~= from;
    return edge;
  }

  /// Walks the graph and marks cyclic vertices and edges.
  void detectCycles()
  { // Cycles could also be detected in the GraphBuilder,
    // but having the code here makes things much clearer.

    // Returns true if the vertex is in status Visiting.
    bool visit(Vertex vertex)
    {
      switch (vertex.status)
      {
      case Vertex.Status.Visiting:
        vertex.isCyclic = true;
        return true;
      case Vertex.Status.None:
        vertex.status = Vertex.Status.Visiting; // Flag as visiting.
        foreach (outVertex; vertex.outgoing)    // Visit successors.
          vertex.isCyclic |= visit(outVertex);
        vertex.status = Vertex.Status.Visited;  // Flag as visited.
        break;
      case Vertex.Status.Visited:
        break;
      default:
        assert(0, "unknown vertex status");
      }
      return false; // return (vertex.status == Vertex.Status.Visiting);
    }
    // Start visiting vertices.
    visit(vertices[0]);

    foreach (edge; edges)
      if (edge.from.isCyclic && edge.to.isCyclic)
        edge.isCyclic = true;
  }
}

/// Represents a directed connection between two vertices.
class Edge
{
  Vertex from;   /// Coming from vertex.
  Vertex to;     /// Going to vertex.
  bool isCyclic; /// Edge connects cyclic vertices.
  bool isPublic; /// Public import.
  bool isStatic; /// Static import.

  this(Vertex from, Vertex to)
  {
    this.from = from;
    this.to = to;
  }
}

/// Represents a module in the graph.
class Vertex
{
  Module modul;      /// The module represented by this vertex.
  uint id;           /// The nth vertex in the graph.
  Vertex[] incoming; /// Also called predecessors.
  Vertex[] outgoing; /// Also called successors.
  bool isCyclic;     /// Whether this vertex is in a cyclic relationship with other vertices.

  enum Status : ubyte
  { None, Visiting, Visited }
  Status status; /// Used by the cycle detection algorithm.
}

string findModuleFilePath(string moduleFQNPath, string[] importPaths)
{
  auto filePath = new FilePath();
  foreach (importPath; importPaths)
  {
    filePath.set(importPath);
    filePath.append(moduleFQNPath);
    foreach (moduleSuffix; [".d", ".di"/*interface file*/])
    {
      filePath.suffix(moduleSuffix);
      if (filePath.exists())
        return filePath.toString();
    }
  }
  return null;
}

class GraphBuilder
{
  Graph graph;
  IGraphOption options;
  string[] importPaths; /// Where to look for modules.
  Vertex[string] loadedModulesTable; /// Maps FQN paths to modules.
  bool delegate(string) filterPredicate;

  this()
  {
    this.graph = new Graph;
  }

  /// Start building the graph and return that.
  Graph start(string fileName)
  {
    loadModule(fileName);
    return graph;
  }

  /++
    Loads all modules recursively and builds the graph at the same time.
    Params:
      moduleFQNPath = e.g.: dil/ast/Node (module FQN = dil.ast.Node)
  +/
  Vertex loadModule(string moduleFQNPath)
  {
    // Look up in table if the module is already loaded.
    auto pVertex = moduleFQNPath in loadedModulesTable;
    if (pVertex !is null)
      return *pVertex; // Returns null for filtered or unlocatable modules.

    // Filter out modules.
    if (filterPredicate && filterPredicate(moduleFQNPath))
    { // Store null for filtered modules.
      loadedModulesTable[moduleFQNPath] = null;
      return null;
    }

    // Locate the module in the file system.
    auto moduleFilePath = findModuleFilePath(moduleFQNPath, importPaths);

    Vertex vertex;

    if (moduleFilePath is null)
    { // Module not found.
      if (options & IGraphOption.IncludeUnlocatableModules)
      { // Include module nevertheless.
        vertex = new Vertex;
        vertex.modul = new Module("");
        vertex.modul.setFQN(replace(moduleFQNPath, dirSep, '.'));
        graph.addVertex(vertex);
      }
      // Store vertex in the table (vertex may be null.)
      loadedModulesTable[moduleFQNPath] = vertex;
    }
    else
    {
      auto modul = new Module(moduleFilePath);
      // Use lightweight ImportParser.
      modul.parser = new ImportParser(loadFile(moduleFilePath), moduleFilePath);
      modul.parse();

      vertex = new Vertex;
      vertex.modul = modul;

      graph.addVertex(vertex);
      loadedModulesTable[modul.getFQNPath()] = vertex;

      // Load the modules which this module depends on.
      foreach (importDecl; modul.imports)
      {
        foreach (moduleFQNPath2; importDecl.getModuleFQNs(dirSep))
        {
          auto loaded = loadModule(moduleFQNPath2);
          if (loaded !is null)
          {
            auto edge = graph.addEdge(vertex, loaded);
            edge.isPublic = importDecl.isPublic();
            edge.isStatic = importDecl.isStatic();
          }
        }
      }
    }
    return vertex;
  }
}

void execute(string filePathString, string[] importPaths, string[] strRegexps,
             uint levels, string siStyle, string piStyle, IGraphOption options)
{
  // Init regular expressions.
  RegExp[] regexps;
  foreach (strRegexp; strRegexps)
    regexps ~= new RegExp(strRegexp);

  // Add directory of file and global directories to import paths.
  auto filePath = new FilePath(filePathString);
  auto fileDir = filePath.folder();
  importPaths ~= fileDir;
  importPaths ~= GlobalSettings.importPaths;

  auto gbuilder = new GraphBuilder;

  gbuilder.importPaths = importPaths;
  gbuilder.options = options;
  gbuilder.filterPredicate = (string moduleFQNPath) {
    foreach (rx; regexps)
      // Replace slashes: dil/ast/Node -> dil.ast.Node
      if (rx.test(replace(moduleFQNPath.dup, dirSep, '.')))
        return true;
    return false;
  };

  auto graph = gbuilder.start(filePath.name());

  if (options & (IGraphOption.PrintList | IGraphOption.PrintPaths))
  {
    if (options & IGraphOption.MarkCyclicModules)
      graph.detectCycles();

    if (options & IGraphOption.PrintPaths)
      printModulePaths(graph.vertices, levels+1, "");
    else
      printModuleList(graph.vertices, levels+1, "");
  }
  else
    printDotDocument(graph, siStyle, piStyle, options);
}

void printModulePaths(Vertex[] vertices, uint level, char[] indent)
{
  if (level == 0)
    return;
  foreach (vertex; vertices)
  {
    Stdout(indent)((vertex.isCyclic?"*":"")~vertex.modul.filePath).newline;
    if (vertex.outgoing.length)
      printModulePaths(vertex.outgoing, level-1, indent~"  ");
  }
}

void printModuleList(Vertex[] vertices, uint level, char[] indent)
{
  if (level == 0)
    return;
  foreach (vertex; vertices)
  {
    Stdout(indent)((vertex.isCyclic?"*":"")~vertex.modul.getFQN()).newline;
    if (vertex.outgoing.length)
      printModuleList(vertex.outgoing, level-1, indent~"  ");
  }
}

void printDotDocument(Graph graph, string siStyle, string piStyle,
                      IGraphOption options)
{
  Vertex[][string] verticesByPckgName;
  if (options & IGraphOption.GroupByFullPackageName)
    foreach (vertex; graph.vertices)
      verticesByPckgName[vertex.modul.packageName] ~= vertex;

  if (options & (IGraphOption.HighlightCyclicVertices |
                 IGraphOption.HighlightCyclicEdges))
    graph.detectCycles();

  // Output header of the dot document.
  Stdout("Digraph ImportGraph\n{\n");
  // Output nodes.
  // 'i' and vertex.id should be the same.
  foreach (i, vertex; graph.vertices)
    Stdout.formatln(`  n{} [label="{}"{}];`, i, vertex.modul.getFQN(), (vertex.isCyclic ? ",style=filled,fillcolor=tomato" : ""));

  // Output edges.
  foreach (edge; graph.edges)
  {
    string edgeStyles = "";
    if (edge.isStatic || edge.isPublic)
    {
      edgeStyles = `[style="`;
      edge.isStatic && (edgeStyles ~= siStyle ~ ",");
      edge.isPublic && (edgeStyles ~= piStyle);
      edgeStyles[$-1] == ',' && (edgeStyles = edgeStyles[0..$-1]); // Remove last comma.
      edgeStyles ~= `"]`;
    }
    edge.isCyclic && (edgeStyles ~= "[color=red]");
    Stdout.formatln(`  n{} -> n{} {};`, edge.from.id, edge.to.id, edgeStyles);
  }

  if (options & IGraphOption.GroupByFullPackageName)
    foreach (packageName, vertices; verticesByPckgName)
    { // Output nodes in a cluster.
      Stdout.format(`  subgraph "cluster_{}" {`\n`    label="{}";color=blue;`"\n    ", packageName, packageName);
      foreach (vertex; vertices)
        Stdout.format(`n{};`, vertex.id);
      Stdout("\n  }\n");
    }

  Stdout("}\n");
}

/+
// This is the old algorithm that was used to detect cycles in a directed graph.
void analyzeGraph(Vertex[] vertices_init, Edge[] edges)
{
  void recursive(Vertex[] vertices)
  {
    foreach (idx, vertex; vertices)
    {
      uint outgoing, incoming;
      foreach (j, edge; edges)
      {
        if (edge.from is vertex)
          outgoing++;
        if (edge.to is vertex)
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
            if (edges[i].to !is vertex)
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
          if (edges[i].from !is vertex)
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
+/
