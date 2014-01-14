/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module util.Path;

import common;

import tango.io.FilePath;
import tango.sys.Environment;
import std.path;

enum dirSep = dirSeparator[0]; /// Dir separator character.
alias Environment = tango.sys.Environment.Environment;

/// This class is like FilePath, but adds additional
/// operators to make things easier.
class Path : FilePath
{
  /// Constructs from a string.
  this(cstring s)
  {
    super(s.dup);
  }

  /// Constructs an empty Path.
  this()
  {
    super();
  }

  /// Returns a new Path object.
  static Path opCall(cstring s)
  {
    return new Path(s);
  }

  /// ditto
  static Path opCall()
  {
    return new Path();
  }

  Path append(cstring s)
  {
    super.append(s);
    return this;
  }

  Path cat(cstring s)
  {
    super.cat(s);
    return this;
  }

  alias set = super.set;

  Path set(cstring s)
  {
    super.set(s);
    return this;
  }

  Path set(Path p)
  {
    super.set(p);
    return this;
  }

  Path dup()
  {
    return Path(toString());
  }

  /// The path without its extension. Returns a copy.
  Path noext()
  {
    auto ext_len = this.suffix().length;
    return Path(toString()[0..$-ext_len]);
  }

  /// Returns a normalized path, removing parts like "./" and "../".
  Path normalize()
  {
    //import tango.io.Path : normalize;
    //return Path(normalize(toString()));
    return Path(buildNormalizedPath(toString()));
  }

  /// Returns an absolute path relative to the current working directory.
  Path absolute()
  {
    return Path(Environment.toAbsolute(toString().dup));
  }

  cstring name()
  {
    return super.name();
  }

  cstring folder()
  {
    return super.folder();
  }

  /// Append s. p /= s
  Path opDivAssign(cstring s)
  {
    return this.append(s);
  }

  /// ditto
  Path opDivAssign(Path p)
  {
    return this.append(p.toString());
  }

  /// Concatenate s. path ~= s
  Path opCatAssign(cstring s)
  {
    return this.cat(s);
  }

  /// ditto
  Path opCatAssign(Path p)
  {
    return this.cat(p.toString());
  }

  /// Append s. Returns a copy.
  Path opDiv(cstring s)
  {
    return this.dup().append(s);
  }
  /// ditto
  Path opDiv(Path p)
  {
    return this.dup().append(p.toString());
  }

  /// Concatenate s. Returns a copy.
  Path opCat(cstring s)
  {
    return this.dup().cat(s);
  }
  /// ditto
  Path opCat(Path p)
  {
    return this.dup().cat(p.toString());
  }
}
