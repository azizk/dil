/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.ast.Declaration;

import dil.ast.Node;
import dil.Enums;

/// The root class of all declarations.
abstract class Declaration : Node
{
  bool hasBody;
  this()
  {
    super(NodeCategory.Declaration);
  }

  // Members relevant to semantic phase.
  StorageClass stc; /// The storage classes of this declaration.
  Protection prot;  /// The protection attribute of this declaration.

  final bool isStatic()
  {
    return !!(stc & StorageClass.Static);
  }

  final bool isConst()
  {
    return !!(stc & StorageClass.Const);
  }

  final bool isPublic()
  {
    return !!(prot & Protection.Public);
  }

  final void setStorageClass(StorageClass stc)
  {
    this.stc = stc;
  }

  final void setProtection(Protection prot)
  {
    this.prot = prot;
  }

  override abstract Declaration copy();
}
