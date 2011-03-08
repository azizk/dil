/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.Compilation;

import dil.semantic.Types;
import dil.lexer.Funcs : hashOf;
import dil.Tables;
import dil.Diagnostics;
import common;

/// A group of settings relevant to the compilation process.
class CompilationContext
{
  alias typeof(this) CC;
  CC parent;
  string[] importPaths; /// Import paths.
  string[] includePaths; /// String include paths.
  uint debugLevel; /// The debug level.
  uint versionLevel; /// The version level.
  string[hash_t] debugIds; /// Set of debug identifiers.
  string[hash_t] versionIds; /// Set of version identifiers.
  bool releaseBuild; /// Build release version?
  bool unittestBuild; /// Include unittests?
  bool acceptDeprecated; /// Allow deprecated symbols/features?
  uint structAlign = 4;

  Tables tables; /// Tables used by the Lexer and the semantic phase.

  Diagnostics diag; /// Diagnostics object.

  /// Constructs a CompilationContext object.
  /// Params:
  ///   parent = Optional parent object. Members are copied or inherited.
  this(CC parent = null)
  {
    this.parent = parent;
    if (isRoot())
      (tables = new Tables()),
      (diag = new Diagnostics());
    else
    {
      this.importPaths = parent.importPaths.dup;
      this.includePaths = parent.includePaths.dup;
      this.debugLevel = parent.debugLevel;
      this.versionLevel = parent.versionLevel;
      this.releaseBuild = parent.releaseBuild;
      this.structAlign = parent.structAlign;
      this.tables = parent.tables;
      this.diag = parent.diag;
    }
  }

  /// Makes accessing the tables thread-safe.
  void threadsafeTables(bool safe)
  {
    tables.idents.setThreadsafe(safe);
  }

  void addDebugId(string id)
  {
    debugIds[hashOf(id)] = id;
  }

  void addVersionId(string id)
  {
    versionIds[hashOf(id)] = id;
  }

  bool findDebugId(string id)
  {
    if (auto pId = hashOf(id) in debugIds)
      return true;
    if (!isRoot())
      return parent.findDebugId(id);
    return false;
  }

  bool findVersionId(string id)
  {
    if (auto pId = hashOf(id) in versionIds)
      return true;
    if (!isRoot())
      return parent.findVersionId(id);
    return false;
  }

  bool isRoot()
  {
    return parent is null;
  }
}
