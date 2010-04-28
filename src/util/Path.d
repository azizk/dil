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
  this(string s)
  {
    super(s);
  }
  /// Constructs from a FilePath.
  this(FilePath s)
  {
    super(s.toString());
  }
  /// Constructs an empty Path.
  this()
  {
    super();
  }

  /// Returns a new Path object.
  static Path opCall(string s)
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
    return new Path("");
  }

  Path append(string s)
  {
    super.append(s);
    return this;
  }

  Path cat(string s)
  {
    super.cat(s);
    return this;
  }

  Path dup()
  {
    return Path(toString());
  }


  /// Append s. p /= s
  Path opDivAssign(string s)
  {
    return this.append(s);
  }

  /// ditto
  Path opDivAssign(Path p)
  {
    return this.append(p.toString());
  }

  /// Concatenate s. path ~= s
  Path opCatAssign(string s)
  {
    return this.cat(s);
  }

  /// ditto
  Path opCatAssign(Path p)
  {
    return this.cat(p.toString());
  }

  /// Append s. Returns a copy.
  Path opDiv(string s)
  {
    return this.dup().append(s);
  }
  /// ditto
  Path opDiv(Path p)
  {
    return this.dup().append(p.toString());
  }

  /// Concatenate s. Returns a copy.
  Path opCat(string s)
  {
    return this.dup().cat(s);
  }
  /// ditto
  Path opCat(Path p)
  {
    return this.dup().cat(p.toString());
  }
}
