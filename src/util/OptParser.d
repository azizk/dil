/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module util.OptParser;

import common;

/// A command line option parser.
class OptParser
{
  cstring[] argv; /// The argument vector.
  bool delegate()[] parseDgs; /// Option parsing delegates.
  cstring error; /// Holds the error message if an error occurred.
  /// The format of the error message.
  cstring errorMessageFormat = "missing argument for option ‘{}’";

  /// Constructs an OptParser object.
  this(cstring[] argv)
  {
    this.argv = argv;
  }
  /// ditto
  this(string[] argv)
  {
    this.argv = cast(cstring[])argv;
  }

  /// Parses all arguments.
  bool parseArgs()
  {
    cstring[] remArgs; // Remaining arguments.
    while (hasArgs())
    {
      auto n = argv.length; // Remember number of args.
      foreach (parseOption; parseDgs)
        if (!hasArgs() || parseOption())
          break;
        else if (error)
          goto Lerr;
      if (argv.length == n) // No arguments consumed?
        remArgs ~= getArg(); // Append to remaining args.
    }
    argv = remArgs;
    return true;
  Lerr:
    argv = remArgs ~ argv;
    return false;
  }

  /// Adds a parser delegate.
  void add()(bool delegate() parseDg)
  {
    parseDgs ~= parseDg;
  }

  /// A dummy variable used to force the compiler to create a closure.
  private bool delegate() closureDelegate;

  /// Adds a delegate for parsing an option.
  void add(T)(cstring param, ref T out_arg, void delegate() cb = null)
  { // Have to assign to outer variable first to create a closure.
    add(closureDelegate =
      { return parse(param, out_arg) && (cb && cb(), true); });
  }

  /// Adds a delegate accepting any option.
  void addDefault(void delegate() defaultDg)
  {
    add(closureDelegate = { defaultDg(); return true; });
  }

  /// Parses a parameter.
  bool parse(cstring param, ref cstring out_arg)
  {
    if (!hasArgs()) return false;
    auto arg0 = argv[0];
    auto n = param.length;
    if (strbeg(arg0, param))
    {
      if (arg0.length == n) // arg0 == param
      { // Eg: -I /include/path
        if (argv.length <= 1)
          goto Lerr;
        out_arg = argv[1];
        n = 2;
      }
      else
      { // Eg: -I/include/path
        auto skipEqualSign = arg0[n] == '=';
        out_arg = arg0[n + skipEqualSign .. $];
        n = 1;
      }
      consume(n); // Consume n arguments.
      return true;
    }
    return false;
  Lerr:
    error = Format(errorMessageFormat, param);
    return false;
  }

  /// Parses a flag.
  bool parse(cstring flag, ref bool out_arg)
  {
    if (hasArgs() && argv[0] == flag) {
      out_arg = true;
      consume(1);
      return true;
    }
    return false;
  }

  /// Slices off n elements from argv.
  void consume(size_t n)
  {
    argv = argv[n..$];
  }

  bool hasArgs()
  {
    return argv.length != 0;
  }

  cstring getArg()
  {
    auto arg = argv[0];
    consume(1);
    return arg;
  }

  /// Returns true if str starts with s.
  static bool strbeg(cstring str, cstring s)
  {
    return str.length >= s.length && str[0 .. s.length] == s;
  }
}
