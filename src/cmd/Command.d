/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module cmd.Command;

import common;

/// Base class for all commands.
abstract class Command
{
  /// Verbose output.
  bool verbose;

  /// Logs messages to stdout.
  /// Params:
  ///  format = The format string.
  void log(string format, ...)
  { // TODO: use thread-safe logging classes of Tango?
    Printfln(Format(_arguments, _argptr, format));
  }

  /// Calls logfunc only when the verbose-flag is on.
  void lzy(lazy void logfunc)
  {
    if (verbose)
      logfunc();
  }

  /// Runs the command.
  void run();
}
