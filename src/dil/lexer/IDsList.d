/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.lexer.IDsList;

/// The list of keywords in D.
enum keywordIDs = (){
  enum words = [
    "__argTypes", // D2
    "__gshared", // D2
    "__overloadset", // D2
    "__parameters", // D2
    "__traits", // D2
    "__vector", // D2
    "abstract",
    "alias",
    "align",
    "asm",
    "assert",
    "auto",
    "body",
    "bool",
    "break",
    "byte",
    "case",
    "cast",
    "catch",
    "cdouble",
    "cent",
    "cfloat",
    "char",
    "class",
    "const",
    "continue",
    "creal",
    "dchar",
    "debug",
    "default",
    "delegate",
    "delete",
    "deprecated",
    "do",
    "double",
    "else",
    "enum",
    "export",
    "extern",
    "false",
    "final",
    "finally",
    "float",
    "for",
    "foreach",
    "foreach_reverse",
    "function",
    "goto",
    "idouble",
    "if",
    "ifloat",
    "immutable", // D2
    "import",
    "in",
    "inout",
    "int",
    "interface",
    "invariant",
    "ireal",
    "is",
    "lazy",
    "long",
    "macro", // D2
    "mixin",
    "module",
    "new",
    "nothrow", // D2
    "null",
    "out",
    "override",
    "package",
    "pragma",
    "private",
    "protected",
    "public",
    "pure", // D2
    "real",
    "ref",
    "return",
    "scope",
    "shared", // D2
    "short",
    "static",
    "struct",
    "super",
    "switch",
    "synchronized",
    "template",
    "this",
    "throw",
    "true",
    "try",
    "typedef",
    "typeid",
    "typeof",
    "ubyte",
    "ucent",
    "uint",
    "ulong",
    "union",
    "unittest",
    "ushort",
    "version",
    "void",
    "volatile",
    "wchar",
    "while",
    "with",
  ];

  auto list = new string[2][words.length];
  foreach (i, w; words)
  {
    auto n = w.dup;
    if (n[0] == '_')
      n = n[2..$]; // E.g.: "__gshared" -> "gshared"
    n[0] -= 0x20; // E.g.: "gshared" -> "Gshared"
    list[i] = [n.idup, w]; // E.g.: ["Gshared", "__gshared"]
  }
  return list;
}();

enum specialIDs = [
  ["FILE", "__FILE__"],
  ["LINE", "__LINE__"],
  ["DATE", "__DATE__"],
  ["TIME", "__TIME__"],
  ["TIMESTAMP", "__TIMESTAMP__"],
  ["VENDOR", "__VENDOR__"],
  ["VERSION", "__VERSION__"],
  ["MODULE", "__MODULE__"], // D2
  ["FUNCTION", "__FUNCTION__"], // D2
  ["PFUNCTION", "__PRETTY_FUNCTION__"], // D2
  ["EOF", "__EOF__"], // D2
];

/// Table of common and often used identifiers.
///
/// $(BNF
////PredefinedIdentifier := SourceCodeName (":" IdText)?
////SourceCodeName := Identifier # The name to be used in the source code.
////IdText := Empty | Identifier # The actual text of the identifier.
////Empty := ""                  # IdText may be empty.
////Identifier := see module $(MODLINK dil.lexer.Identifier).
////)
/// NB: If IdText is not defined it defaults to SourceCodeName.
enum predefinedIDs = (){
  enum pairs = [
    // Special empty identifier:
    "Empty:",
    // Just "Identifier" (with '_' to avoid symbol conflicts):
    "Identifier_:Identifier",
    "SpecialID",
    // Predefined version identifiers:
    "DigitalMars", "X86", "X86_64",
    /*"Windows", */"Win32", "Win64",
    "Linux:linux", "LittleEndian", "BigEndian",
    "D_Coverage", "D_InlineAsm_X86", "D_Version2",
    "none", "all",
    // Variadic parameters:
    "Arguments:_arguments", "Argptr:_argptr",
    // scope(Identifier):
    "exit", "success", "failure",
    // pragma:
    "msg", "lib", "startaddress",
    // Linkage:
    "C", "D", "Windows", "Pascal", "System",
    // Con-/Destructor:
    "Ctor:__ctor", "Dtor:__dtor",
    // new() and delete() methods.
    "NewFn:__new", "DeleteFn:__delete",
    // Unittest and invariant.
    "UnittestFn:__unittest", "InvariantFn:__invariant",
    // Attributes (D2):
    "disable", "property", /+"safe", "system",+/ "trusted",
    // Operator overload names:
    "opNeg",    "opPos",    "opCom",
    "opEquals", "opCmp",    "opAssign",
    "opAdd",    "opAdd_r",  "opAddAssign",
    "opSub",    "opSub_r",  "opSubAssign",
    "opMul",    "opMul_r",  "opMulAssign",
    "opDiv",    "opDiv_r",  "opDivAssign",
    "opMod",    "opMod_r",  "opModAssign",
    "opAnd",    "opAnd_r",  "opAndAssign",
    "opOr",     "opOr_r",   "opOrAssign",
    "opXor",    "opXor_r",  "opXorAssign",
    "opShl",    "opShl_r",  "opShlAssign",
    "opShr",    "opShr_r",  "opShrAssign",
    "opUShr",   "opUShr_r", "opUShrAssign",
    "opCat",    "opCat_r",  "opCatAssign",
    "opIn",     "opIn_r",
    "opIndex",  "opIndexAssign",
    "opSlice",  "opSliceAssign",
    "opPostInc",
    "opPostDec",
    "opCall",
    "opCast",
    "opStar", // D2
    // foreach and foreach_reverse:
    "opApply", "opApplyReverse",
    // Entry functions:
    "main", "WinMain", "DllMain",
    // D2 module (system|safe)
    "system", "safe",
    // From object.d
    "object", "Object", "Interface_:Interface",
    "Throwable", "Exception", "Error",
    "ClassInfo", "TypeInfo", "OffsetTypeInfo",
    "ModuleInfo", "FrameInfo", "TraceInfo",
    "ptrdiff_t", "size_t", "ssize_t", "hash_t", "equals_t",
    // TypeInfo classes
    "TypeInfo_Pointer",
    "TypeInfo_Array",
    "TypeInfo_StaticArray",
    "TypeInfo_AssociativeArray",
    "TypeInfo_Function",
    "TypeInfo_Delegate",
    "TypeInfo_Enum",
    "TypeInfo_Class",
    "TypeInfo_Interface",
    "TypeInfo_Struct",
    "TypeInfo_Tuple",
    "TypeInfo_Typedef",
    "TypeInfo_Vector", // D2
    "TypeInfo_Const", // D2
    "TypeInfo_Invariant", // D2
    "TypeInfo_Shared", // D2
    "TypeInfo_Inout", // D2
    // Special properties
    "Sizeof:sizeof", "Alignof:alignof", "Mangleof:mangleof",
    // ASM identifiers:
    "near", "far", "word", "dword", "qword",
    "ptr", "offsetof", "seg", "__LOCAL_SIZE",
    "FS", "ST",
    "AL", "AH", "AX", "EAX",
    "BL", "BH", "BX", "EBX",
    "CL", "CH", "CX", "ECX",
    "DL", "DH", "DX", "EDX",
    "BP", "EBP", "SP", "ESP",
    "DI", "EDI", "SI", "ESI",
    "ES", "CS", "SS", "DS", "GS",
    "CR0", "CR2", "CR3", "CR4",
    "DR0", "DR1", "DR2", "DR3", "DR6", "DR7",
    "TR3", "TR4", "TR5", "TR6", "TR7",
    "MM0", "MM1", "MM2", "MM3",
    "MM4", "MM5", "MM6", "MM7",
    "XMM0", "XMM1", "XMM2", "XMM3",
    "XMM4", "XMM5", "XMM6", "XMM7",
    // ASM jump opcodes:
    "ja", "jae", "jb", "jbe", "jc",
    "jcxz", "je", "jecxz", "jg", "jge",
    "jl", "jle", "jmp", "jna", "jnae",
    "jnb", "jnbe", "jnc", "jne", "jng",
    "jnge", "jnl", "jnle", "jno", "jnp",
    "jns", "jnz", "jo", "jp", "jpe",
    "jpo", "js", "jz",
  ];
  /// Splits txt at ':' and returns a tuple.
  string[2] getPair(string txt)
  {
    foreach (i, c; txt)
      if (c == ':')
        return [txt[0..i], txt[i+1..txt.length]];
    return [txt, txt];
  }
  auto list = new string[2][pairs.length];
  foreach (i, pair; pairs)
    list[i] = getPair(pair);
  return list;
}();
