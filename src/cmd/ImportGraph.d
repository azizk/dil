/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module cmd.ImportGraph;

import cmd.Command;
import dil.ast.Node,
       dil.ast.Declarations;
import dil.semantic.Module,
       dil.semantic.Package;
import dil.parser.ImportParser;
import dil.SourceText,
       dil.Compilation,
       dil.ModuleManager,
       dil.Diagnostics,
       dil.String;
import util.Path;
import Settings;
import common;

import tango.text.Regex : RegExp = Regex;
import tango.io.model.IFile;

alias dirSep = FileConst.PathSeparatorChar;

/// The importgraph command.
class IGraphCommand : Command
{
  /// Options for the command.
  enum Option
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
  alias Options = Option;

  Options options; /// Command options.
  cstring filePath; /// File path to the root module.
  cstring[] regexps; /// Regular expressions.
  cstring siStyle = "dashed"; /// Static import style.
  cstring piStyle = "bold";   /// Public import style.
  uint levels; /// How many levels to print.

  CompilationContext context;

  /// Adds o to the options.
  void add(Option o)
  {
    options |= o;
  }

  /// Executes the command.
  override void run()
  {
    // Init regular expressions.
    RegExp[] regexps;
    foreach (strRegexp; this.regexps)
      regexps ~= new RegExp(strRegexp);

    // Add the directory of the file to the import paths.
    auto filePath = Path(this.filePath);
    context.importPaths ~= filePath.folder();

    auto gbuilder = new GraphBuilder(context);

    gbuilder.options = options;
    gbuilder.filterPredicate = (cstring moduleFQNPath) {
      foreach (rx; regexps)
        // Replace slashes: dil/ast/Node -> dil.ast.Node
        if (rx.test(moduleFQNPath.replace(dirSep, '.')))
          return true;
      return false;
    };

    auto graph = gbuilder.start(filePath.name());

    if (options & (Option.PrintList | Option.PrintPaths))
    {
      if (options & Option.MarkCyclicModules)
        graph.detectCycles();

      if (options & Option.PrintPaths)
        printModulePaths(graph.vertices, levels+1, "");
      else
        printModuleList(graph.vertices, levels+1, "");
    }
    else
      printDotDocument(context, graph, siStyle, piStyle, options);
  }
}

/// Represents a module dependency graph.
class Graph
{
  Vertex[] vertices; /// The vertices or modules.
  Edge[] edges; /// The edges or import statements.

  /// Adds a vertex to the graph and sets its ID.
  void addVertex(Vertex vertex)
  {
    vertex.id = vertices.length;
    vertices ~= vertex;
  }

  /// Adds an edge between two vertices to the graph.
  Edge addEdge(Vertex from, Vertex to)
  {
    auto edge = new Edge(from, to);
    edges ~= edge;
    from.outgoing ~= to;
    return edge;
  }

  /// ditto
  Edge addEdge(size_t id1, size_t id2)
  {
    return addEdge(vertices[id1], vertices[id2]);
  }

  /// Walks the graph and marks cyclic vertices and edges.
  void detectCycles()
  {
    bool[Vertex][] vsets; // List of Set(sccs)

    bool isReflexive(Vertex v)
    {
      foreach (w; v.outgoing)
        if (w is v)
          return true;
      return false;
    }

    foreach (sccs; findTarjansSCCs())
    { // Ignore a component if it's alone and not connecting to itself.
      if (sccs.length == 1 && !isReflexive(sccs[0]))
        continue;

      bool[Vertex] vset;
      foreach (v; sccs)
        vset[v] = v.isCyclic = true;
      vsets ~= vset;
    }

    foreach (e; edges)
      foreach (vset; vsets)
        if (auto v = e.from in vset && e.to in vset)
        {
          e.isCyclic = true;
          break;
        }
  }

  /// Returns a list of strongly connected components using Tarjan's algorithm.
  Vertex[][] findTarjansSCCs()
  {
    size_t i = 1; // Start with 1, as the default of Vertex.index is 0.
    Vertex[] stack;
    Vertex[][] sccs;

    void recurse(Vertex v)
    {
      v.index = v.llink = i++;
      v.instack = true;
      stack ~= v;

      foreach (z; v.outgoing)
        if (z.index == 0)
        {
          recurse(z); // Depth-first search.
          if (z.llink < v.llink)
            v.llink = z.llink;
        }
        else if (z.instack && z.index < v.llink)
          v.llink = z.index;

      if (v.index == v.llink)
      {
        assert(stack.length);
        auto end = stack.ptr + stack.length;
        auto p = end; // Reverse iterator.
        Vertex z;
        do
        { // Search backwards until the root vertex is found.
          assert(p > stack.ptr);
          z = *--p;
          z.instack = false;
        } while (z !is v);
        assert(*p is v && v is z);
        sccs ~= p[0 .. end - p].dup;
        stack.length = p - stack.ptr;
      }
    }

    // Walk through the graph.
    foreach (v; vertices)
      if (v.index == 0)
        recurse(v);

    return sccs;
  }
}

void testGraph()
{
  scope msg = new UnittestMsg("Testing class Graph.");

  // 1st test.
  {
    auto g = new Graph();
    auto v = new Vertex();
    g.addVertex(v);
    g.addEdge(v, v); // Connect the only vertex to itself.
    g.detectCycles();
    assert(g.vertices[0].isCyclic && g.edges[0].isCyclic);
  }

  // 2nd test.
  auto g = new Graph();

  auto connect = (size_t x, size_t y) => g.addEdge(x, y);

  foreach (i; 0..7)
    g.addVertex(new Vertex());

  connect(0, 1);
  connect(1, 3);
  connect(3, 2);
  connect(2, 0);

  connect(6, 5);
  connect(5, 3);
  connect(3, 4);
  connect(4, 6);

  g.detectCycles();

  foreach (v; g.vertices)
    assert(v.isCyclic);
  foreach (e; g.edges)
    assert(e.isCyclic);

  // 3rd test.
  g = new Graph();

  foreach (i; 0..6)
    g.addVertex(new Vertex());

  // First "triangle".
  connect(0, 1);
  connect(1, 2);
  connect(2, 0);
  // Second "triangle".
  connect(3, 4);
  connect(4, 5);
  connect(5, 3);
  // Connect the two triangles.
  connect(3, 0);

  g.detectCycles();

  foreach (e; g.edges[0..$-1])
    assert(e.isCyclic); // Edges of the triangles must be marked as cyclic.
  // The last edge, connecting both triangles, is not cyclic.
  assert(!g.edges[$-1].isCyclic);
}

/// Represents a directed connection between two vertices.
class Edge
{
  Vertex from;   /// Coming from vertex.
  Vertex to;     /// Going to vertex.
  bool isCyclic; /// Edge connects cyclic vertices.
  bool isPublic; /// Public import.
  bool isStatic; /// Static import.

  /// Constructs an Edge object between two vertices.
  this(Vertex from, Vertex to)
  {
    this.from = from;
    this.to = to;
  }

  override string toString()
  {
    return cast(string)Format("E({}, {})", from, to);
  }
}

/// Represents a module in the graph.
class Vertex
{
  Module modul;      /// The module represented by this vertex.
  size_t id;         /// The nth vertex in the graph.
  Vertex[] outgoing; /// Also called successors.
  bool isCyclic;     /// Whether this vertex is in a cyclic relationship
                     /// with other vertices.
  // Members specific to Tarjan's algorithm.
  size_t index; /// Greater than 0 means that this vertex has been visited.
  size_t llink; /// Aka. lowlink.
  bool instack; /// Is this in the Stack?

  override string toString()
  {
    return cast(string)Format("V({})", id);
  }
}

/// Builds a module dependency graph.
class GraphBuilder
{
  Graph graph; /// The graph object.
  IGraphCommand.Options options; /// The options.
  Vertex[hash_t] loadedModulesTable; /// Maps FQN paths to modules.
  bool delegate(cstring) filterPredicate;
  CompilationContext cc; /// The context.

  /// Constructs a GraphBuilder object.
  this(CompilationContext cc)
  {
    this.graph = new Graph;
    this.cc = cc;
  }

  /// Start building the graph and return that.
  /// Params:
  ///   fileName = The file name of the root module.
  Graph start(cstring fileName)
  {
    loadModule(fileName);
    return graph;
  }

  /// Loads all modules recursively and builds the graph at the same time.
  /// Params:
  ///   moduleFQNPath = The path version of the module FQN.$(BR)
  ///                   E.g.: FQN = dil.ast.Node -> FQNPath = dil/ast/Node
  Vertex loadModule(cstring moduleFQNPath)
  {
    // Look up in table if the module is already loaded.
    auto hash = hashOf(moduleFQNPath);
    auto pVertex = hash in loadedModulesTable;
    if (pVertex !is null)
      return *pVertex; // Returns null for filtered or unlocatable modules.

    // Filter out modules.
    if (filterPredicate && filterPredicate(moduleFQNPath))
    { // Store null for filtered modules.
      loadedModulesTable[hash] = null;
      return null;
    }

    // Locate the module in the file system.
    auto moduleFilePath = ModuleManager.findModuleFile(
      moduleFQNPath, cc.importPaths);

    Vertex vertex;

    if (moduleFilePath is null)
    { // Module not found.
      if (options & IGraphCommand.Option.IncludeUnlocatableModules)
      { // Include module nevertheless.
        vertex = new Vertex;
        vertex.modul = new Module("", cc);
        auto fqn = moduleFQNPath.replace(dirSep, '.');
        vertex.modul.setFQN(fqn);
        graph.addVertex(vertex);
      }
      // Store vertex in the table (vertex may be null.)
      loadedModulesTable[hash] = vertex;
    }
    else
    {
      auto modul = new Module(moduleFilePath, cc);
      // Use lightweight ImportParser.
      modul.setParser(new ImportParser(modul.sourceText, cc.tables.lxtables));
      modul.parse();

      vertex = new Vertex;
      vertex.modul = modul;

      graph.addVertex(vertex);
      loadedModulesTable[hashOf(modul.getFQNPath())] = vertex;

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

/// Prints the file paths to the modules.
void printModulePaths(Vertex[] vertices, uint level, cstring indent)
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

/// Prints a list of module FQNs.
void printModuleList(Vertex[] vertices, uint level, cstring indent)
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

/// Prints the graph as a graphviz dot document.
void printDotDocument(CompilationContext cc, Graph graph,
  cstring siStyle, cstring piStyle, IGraphCommand.Options options)
{
  // Needed for grouping by package names.
  ModuleManager mm;
  uint groupModules = options & (IGraphCommand.Option.GroupByFullPackageName |
                                 IGraphCommand.Option.GroupByPackageNames);

  if (groupModules)
  {
    mm = new ModuleManager(cc);
    foreach (vertex; graph.vertices)
      mm.addModule(vertex.modul);
  }

  if (options & (IGraphCommand.Option.HighlightCyclicVertices |
                 IGraphCommand.Option.HighlightCyclicEdges))
    graph.detectCycles();

  // Output header of the dot document.
  Stdout("Digraph ImportGraph\n{\n");
  Stdout("  fontname = Verdana; /*fontsize = 10;*/\n");
  // Output nodes.
  // 'i' and vertex.id should be the same.
  foreach (i, vertex; graph.vertices)
    Stdout.formatln(`  n{} [label="{}"{}];`, i, //, URL="{}.html"
                    groupModules ? vertex.modul.moduleName :
                                   vertex.modul.getFQN(),
                    (vertex.isCyclic ? ",style=filled,fillcolor=tomato" : ""));

  // Output edges.
  foreach (edge; graph.edges)
  {
    cstring edgeStyles = "";
    if (edge.isStatic || edge.isPublic)
    {
      edgeStyles = `[style="`;
      edge.isStatic && (edgeStyles ~= siStyle ~ ",");
      edge.isPublic && (edgeStyles ~= piStyle);
      if (edgeStyles[$-1] == ',')
        edgeStyles = edgeStyles[0..$-1]; // Remove last comma.
      edgeStyles ~= `"]`;
    }
    edge.isCyclic && (edgeStyles ~= "[color=red]");
    Stdout.formatln(`  n{} -> n{} {};`, edge.from.id, edge.to.id, edgeStyles);
  }

  if (options & IGraphCommand.Option.GroupByFullPackageName)
  {
    Vertex[][cstring] verticesByPckgName;
    foreach (vertex; graph.vertices)
      verticesByPckgName[vertex.modul.packageName] ~= vertex;
    foreach (packageFQN, vertices; verticesByPckgName)
    { // Output nodes in a cluster.
      Stdout.format(`  subgraph "cluster_{0}" {{`"\n"
                    `    label="{0}";color=blue;`"\n    ",
                    packageFQN);
      foreach (vertex; vertices)
        Stdout.format(`n{};`, vertex.id);
      Stdout("\n  }\n");
    }
  }
  else if (options & IGraphCommand.Option.GroupByPackageNames)
  {
    Stdout("  // Warning: some nested clusters may crash dot.\n");
    size_t[Module] idTable;
    foreach (vertex; graph.vertices)
      idTable[vertex.modul] = vertex.id;
    void printSubgraph(Package pckg, cstring indent)
    { // Output nodes in a cluster.
      foreach (p; pckg.packages)
      {
        Stdout.format(`{0}subgraph "cluster_{1}" {{`"\n"
                      `{0}  label="{2}";color=blue;`"\n"
                      "{0}  ",
                      indent, p.getFQN(), p.pckgName);
        foreach (modul; p.modules)
          Stdout.format(`n{};`, idTable[modul]);
        if (p.packages) {
          Stdout.newline;
          printSubgraph(p, indent~"  "); // Output nested clusters.
        }
        Stdout("\n  }\n");
      }
    }
    printSubgraph(mm.rootPackage, "  ");
  }

  Stdout("}\n");
}
