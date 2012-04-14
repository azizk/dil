/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.Diagnostics;

import dil.i18n.ResourceBundle,
       dil.i18n.Messages;
import common;

public import dil.Information;

import tango.core.Vararg;

/// Collects diagnostic information about the compilation process.
class Diagnostics
{
  Information[] info; /// List of info objects.
  ResourceBundle bundle; /// Used to retrieve messages.
  Layout!(char) format; /// Used to format messages.

  this()
  {
    this.bundle = new ResourceBundle();
    this.format = new Layout!(char)();
  }

  /// Returns true if there are info objects.
  bool hasInfo()
  {
    return info.length != 0;
  }

  /// Appends an info object.
  void opCatAssign(Information info)
  {
    this.info ~= info;
  }

  /// Appends info objects.
  void opCatAssign(Information[] info)
  {
    this.info ~= info;
  }

  /// Returns a formatted msg.
  char[] formatMsg(MID mid, ...)
  {
    return formatMsg(mid, _arguments, _argptr);
  }

  /// ditto
  char[] formatMsg(MID mid, TypeInfo[] _arguments, va_list _argptr)
  {
    return format(_arguments, _argptr, bundle.msg(mid));
  }
}
