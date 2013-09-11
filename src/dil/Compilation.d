/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.Compilation;

import dil.semantic.Types;
import dil.String : hashOf;
import dil.Tables,
       dil.Diagnostics;
import common;

/// A group of settings relevant to the compilation process.
class CompilationContext
{
  alias CC = typeof(this);
  CC parent;
  cstring[] importPaths; /// Import paths.
  cstring[] includePaths; /// String include paths.
  uint debugLevel; /// The debug level.
  uint versionLevel; /// The version level.
  cstring[hash_t] debugIds; /// Set of debug identifiers.
  cstring[hash_t] versionIds; /// Set of version identifiers.
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

  void addDebugId(cstring id)
  {
    debugIds[hashOf(id)] = id;
  }

  void addVersionId(cstring id)
  {
    versionIds[hashOf(id)] = id;
  }

  bool findDebugId(cstring id)
  {
    if (auto pId = hashOf(id) in debugIds)
      return true;
    if (!isRoot())
      return parent.findDebugId(id);
    return false;
  }

  bool findVersionId(cstring id)
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
