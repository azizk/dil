/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Compilation;

import common;

/// A group of settings relevant to the compilation process.
class CompilationContext
{
  string[] importPaths;
  uint debugLevel;
  uint versionLevel;
  bool[string] debugIds;
  bool[string] versionIds;
  bool releaseBuild;
  uint structAlign;
}
