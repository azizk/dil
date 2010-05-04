/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.Compilation;

import dil.semantic.Types;
import dil.lexer.Funcs : hashOf;
import common;

/// A group of settings relevant to the compilation process.
class CompilationContext
{
  alias typeof(this) CC;
  CC parent;
  string[] importPaths;
  uint debugLevel;
  uint versionLevel;
  bool[hash_t] debugIds;
  bool[hash_t] versionIds;
  bool releaseBuild;
  bool unittestBuild;
  bool acceptDeprecated;
  uint structAlign = 4;
  TypeTable typeTable;

  this(CC parent = null)
  {
    this.parent = parent;
    if (parent)
    {
      this.importPaths = parent.importPaths.dup;
      this.debugLevel = parent.debugLevel;
      this.versionLevel = parent.versionLevel;
      this.releaseBuild = parent.releaseBuild;
      this.structAlign = parent.structAlign;
      this.typeTable = parent.typeTable;
    }

    if (isRoot())
    {
      typeTable = new TypeTable();
    }
  }

  void addDebugId(string id)
  {
    debugIds[hashOf(id)] = true;
  }

  void addVersionId(string id)
  {
    versionIds[hashOf(id)] = true;
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
