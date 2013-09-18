/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.semantic.Pass;

import dil.ast.DefaultVisitor,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;

/// Groups values and flags that provide (hierarchical) context
/// to the evaluation of a symbol.
class Scope
{

}

/// The Solver drives the semantic analysis.
/// It can register nodes whose analysis have been postponed.
class Solver
{
  Node[Node] deps; /// Dependency set between nodes.
  size_t doneCounter; /// The number of nodes resolved in this iteration.

  void run()
  {
    while (1) // The main loop.
    {
      doneCounter = 0;
      // TODO: call visit() on nodes.
      // Break if no more nodes could be resolved.
      if (doneCounter == 0)
        break;
    }
  }

  /// Node a waits for Node b to be resolved.
  void depends(Node a, Node b, Scope sc)
  { // TODO: save "sc" as well.
    deps[a] = b;
  }

  /// Called when a node has been resolved.
  void onDone(Node n)
  {
    doneCounter++;
  }
}

/// Walks the tree and registers possible symbol declarations.
/// I.e.: functions/variables/aggregates/static if/is()
class DeclarationPass : DefaultVisitor
{

}

class MainSemanticPass : DefaultVisitor2
{
  Solver sv;

  /// This function implements the core logic of the semantic evaluation.
  ///
  /// A node in the syntax tree may be revisited several times,
  /// as it may have dependencies which have to be resolved first.
  /// Every node has a state variable and depending on it
  /// its analysis is deferred, stopped or finished.
  ///
  /// 1. If the node is already done or has an error the function returns.
  /// 2. Otherwise every sub-node is visited.
  /// 3. The evaluation stops prematurely if one of the sub-nodes has an error.
  /// 4. When all sub-nodes are done, the node itself can be finished.
  ///
  /// Returns: true if n is in the Error or Done state.
  bool errorOrWait(N)(N n)
  {
    if (n.error || n.done)
      return true;

    bool hasError(Node child)
    {
      if (child.wait || child.finish)
        visitN(child);
      if (!child.error)
        return false;
      n.seterror(); // Propagate Error state to parent node.
      return true;
    }

    foreach (i, T; N.CTTI_Types)
    { // auto child = n.memberName;
      auto child = __traits(getMember, n, N.CTTI_Members[i]);
      static if (is(T : Node)) // A Node?
      { // Optionally check for null pointer. Return
        if ((!CTTI_MayBeNull[i] || child !is null) && child.hasError())
          return true;
      }
      else
      static if (is(T : E[], E : Node)) // A Node array?
      {
        foreach (x; child)
          if ((!CTTI_MayBeNull[i] || x !is null) && x.hasError())
            return true;
      }
    }
    n.setfinish();
    return false; // No errors. The Node can be finished.
  }

  override void visit(IntExpr n)
  {
    if (errorOrWait(n))
      return;
    // ...
    if (0)
      n.seterror(); // Error.
    // ...
    n.setdone();
    sv.onDone(n);
  }
}

