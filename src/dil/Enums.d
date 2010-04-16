/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.Enums;

import common;

/// Enumeration of storage classes.
enum StorageClass
{
  None         = 0,
  Abstract     = 1<<0,
  Auto         = 1<<1,
  Const        = 1<<2,
  Deprecated   = 1<<3,
  Extern       = 1<<4,
  Final        = 1<<5,
  Override     = 1<<6,
  Scope        = 1<<7,
  Static       = 1<<8,
  Synchronized = 1<<9,
  In           = 1<<10,
  Out          = 1<<11,
  Ref          = 1<<12,
  Lazy         = 1<<13,
  Variadic     = 1<<14,
  // D2:
  Immutable    = 1<<15,
  Manifest     = 1<<16,
  Nothrow      = 1<<17,
  Pure         = 1<<18,
  Shared       = 1<<19,
  Gshared      = 1<<20,
  Thread       = 1<<21,
  // Attributes:
  Disable      = 1<<22,
  Property     = 1<<23,
  Safe         = 1<<24,
  System       = 1<<25,
  Trusted      = 1<<26,
}

/// Enumeration of protection attributes.
enum Protection
{
  None,
  Private/+   = 1+/,
  Protected/+ = 1<<1+/,
  Package/+   = 1<<2+/,
  Public/+    = 1<<3+/,
  Export/+    = 1<<4+/
}

/// Enumeration of linkage types.
enum LinkageType
{
  None,
  C,
  Cpp,
  D,
  Windows,
  Pascal,
  System
}

/// Namespace for functions that return the string of an enum.
struct EnumString
{
static:

  /// List of Protection strings.
  string[] prots =
    ["","private","protected","package","public","export"];

  /// Returns the string for prot.
  string opCall(Protection prot)
  {
    return prots[prot];
  }

  /// List of StorageClass strings.
  string[] stcs = [
    "",
    "abstract",
    "auto",
    "const",
    "deprecated",
    "extern",
    "final",
    "override",
    "scope",
    "static",
    "synchronized",
    "in",
    "out",
    "ref",
    "lazy",
    "variadic",
    "immutable",
    "manifest",
    "nothrow",
    "pure",
    "shared",
    "gshared",
    "thread",
    "disable",
    "property",
    "safe",
    "system",
    "trusted",
  ];

  import tango.core.BitManip : bsf;

  /// Returns the string of a storage class. Only one bit may be set.
  string opCall(StorageClass stc)
  {
    int index = stc ? bsf(stc)+1 : 0;
    assert(index < stcs.length);
    return stcs[index];
  }

  /// Returns the strings for stcs. Any number of bits may be set.
  string[] all(StorageClass stcs)
  {
    string[] result;
    for (auto i = StorageClass.max; i; i >>= 1)
      if (stcs & i)
        result ~= EnumString(i);
    return result;
  }

  /// List of LinkageType strings.
  string[] ltypes = ["","C","C++","D","Windows","Pascal","System"];

  /// Returns the string for ltype.
  string opCall(LinkageType ltype)
  {
    return ltypes[ltype];
  }
}
