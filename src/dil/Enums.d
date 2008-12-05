/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.Enums;

import common;

/// Enumeration of storage classes.
enum StorageClass
{
  None         = 0,
  Abstract     = 1,
  Auto         = 1<<2,
  Const        = 1<<3,
  Deprecated   = 1<<4,
  Extern       = 1<<5,
  Final        = 1<<6,
  Invariant    = 1<<7,
  Override     = 1<<8,
  Scope        = 1<<9,
  Static       = 1<<10,
  Synchronized = 1<<11,
  In           = 1<<12,
  Out          = 1<<13,
  Ref          = 1<<14,
  Lazy         = 1<<15,
  Variadic     = 1<<16,
  Manifest     = 1<<17, // D 2.0 manifest using enum.
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

/// Returns the string for prot.
string toString(Protection prot)
{
  switch (prot)
  { alias Protection P;
  case P.None:      return "";
  case P.Private:   return "private";
  case P.Protected: return "protected";
  case P.Package:   return "package";
  case P.Public:    return "public";
  case P.Export:    return "export";
  default:
    assert(0);
  }
}

/// Returns the string of a storage class. Only one bit may be set.
string toString(StorageClass stc)
{
  switch (stc)
  { alias StorageClass SC;
  case SC.Abstract:     return "abstract";
  case SC.Auto:         return "auto";
  case SC.Const:        return "const";
  case SC.Deprecated:   return "deprecated";
  case SC.Extern:       return "extern";
  case SC.Final:        return "final";
  case SC.Invariant:    return "invariant";
  case SC.Override:     return "override";
  case SC.Scope:        return "scope";
  case SC.Static:       return "static";
  case SC.Synchronized: return "synchronized";
  case SC.In:           return "in";
  case SC.Out:          return "out";
  case SC.Ref:          return "ref";
  case SC.Lazy:         return "lazy";
  case SC.Variadic:     return "variadic";
  case SC.Manifest:     return "manifest";
  default:
    assert(0);
  }
}

/// Returns the strings for stc. Any number of bits may be set.
string[] toStrings(StorageClass stc)
{
  string[] result;
  for (auto i = StorageClass.max; i; i >>= 1)
    if (stc & i)
      result ~= toString(i);
  return result;
}

/// Returns the string for ltype.
string toString(LinkageType ltype)
{
  switch (ltype)
  { alias LinkageType LT;
  case LT.None:    return "";
  case LT.C:       return "C";
  case LT.Cpp:     return "Cpp";
  case LT.D:       return "D";
  case LT.Windows: return "Windows";
  case LT.Pascal:  return "Pascal";
  case LT.System:  return "System";
  default:
    assert(0);
  }
}
