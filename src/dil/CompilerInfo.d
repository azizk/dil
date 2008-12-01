/// Author: Aziz Köksal
/// License: GPL3
module dil.CompilerInfo;

public import dil.Version;

/// The global, default alignment size for struct fields.
const uint DEFAULT_ALIGN_SIZE = 4;

// TODO: this needs to be in CompilationContext, to make
//       cross-compiling possible.
version(DDoc)
  const uint PTR_SIZE; /// The pointer size depending on the platform.
else
version(X86_64)
  const uint PTR_SIZE = 8; // Pointer size on 64-bit platforms.
else
  const uint PTR_SIZE = 4; // Pointer size on 32-bit platforms.
