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

  final bool isFinal()
  {
    return !!(stc & StorageClass.Final);
  }

  final bool isAbstract()
  {
    return !!(stc & StorageClass.Abstract);
  }

  final bool isConst()
  {
    return !!(stc & StorageClass.Const);
  }

  final bool isAuto()
  {
    return !!(stc & StorageClass.Auto);
  }

  final bool isScope()
  {
    return !!(stc & StorageClass.Scope);
  }

  final bool isStatic()
  {
    return !!(stc & StorageClass.Static);
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
