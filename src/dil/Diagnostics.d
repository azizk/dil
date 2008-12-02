/// Author: Aziz Köksal
/// License: GPL3
module dil.Diagnostics;

public import dil.Information;

/// Collects diagnostic information about the compilation process.
class Diagnostics
{
  Information[] info;

  bool hasInfo()
  {
    return info.length != 0;
  }

  void opCatAssign(Information info)
  {
    this.info ~= info;
  }

  void opCatAssign(Information[] info)
  {
    this.info ~= info;
  }
}
