/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module util.Path;

import tango.io.FilePath;
import common;

/// This class is like FilePath, but adds additional
/// operators to make things easier.
class Path : FilePath
{
  /// Constructs from a string.
  this(cstring s)
  {
    super(s.dup);
  }
  /// Constructs from a FilePath.
  this(FilePath s)
  {
    super(s.toString().dup);
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
  static Path opCall(FilePath p)
  {
    return new Path(p);
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
