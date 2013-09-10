/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.lexer.IdentsGenerator;

import dil.String;

/// Table of predefined identifiers.
///
/// The format ('#' start comments):
/// $(BNF
////PredefinedIdentifier := SourceCodeName (":" IdText)?
////SourceCodeName := Identifier # The name to be used in the source code.
////IdText := Empty | Identifier # The actual text of the identifier.
////Empty := ""                  # IdText may be empty.
////Identifier := see module $(MODLINK dil.lexer.Identifier).
////)
/// If IdText is not defined it defaults to SourceCodeName.
enum string[] predefIdents = [
  // Special empty identifier:
  "Empty:",
  // Just "Identifier" (with '_' to avoid compiler errors):
  "Identifier_:Identifier",
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
  "New:__new", "Delete:__delete",
  // Unittest and invariant.
  "Unittest:__unittest", "Invariant:__invariant",
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
  "object", "Object", "Interface",
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

/// Splits idText at ':' and returns a tuple.
string[] getPair(string idText)
{
  foreach (i, c; idText)
    if (c == ':')
      return [idText[0..i], idText[i+1..idText.length]];
  return [idText, idText];
}

static assert(
  getPair("test") == ["test", "test"] &&
  getPair("test:tset") == ["test", "tset"] &&
  getPair("empty:") == ["empty", ""]
);


/// CTF for generating the members of the struct Ident and struct Keyword.
///
/// The resulting string looks similar to this:
/++
  ---
  alias Identifier I;
  enum TI = TOK.Identifier;
  private struct Ids_ {static const:
  I Empty = I("", TI, IDK.Empty),
  main = I("main", TI, IDK.main);
  // ...
  }
  I* Empty = &Ids_.Empty,
  main = &Ids_.main;
  // ...
  ---
+/
char[] generateIdentMembers(string[] identList, bool isKeywordList)
{
  char[] struct_literals = "I ".dup;
  char[] ident_pointers = "I* ".dup;
  auto len = identList.length;

  for (size_t i; i < len; i++)
  {
    auto name = identList[i], id = identList[++i];
    // auto name = I("id", TOK.name);
    // or:
    // auto name = I("id", TI, IDK.name);
    struct_literals ~=  isKeywordList ?
      name~` = I("`~id~`", TOK.`~name~"),\n" :
      name~` = I("`~id~`", TI, IDK.`~name~"),\n";
    // I* name = &Ids_.name;
    ident_pointers ~= name~" = &Ids_."~name~",\n";
  }
  // Terminate the variable lists with a semicolon.
  struct_literals[$-2] = ident_pointers[$-2] = ';';

  auto firstIdent = identList[0];

  auto code = "
alias Identifier I;
enum TI = TOK.Identifier;\n
private struct Ids_ {static const:\n" ~ struct_literals ~ "}\n
" ~ ident_pointers ~ "
Identifier*[] allIds()
{
  return (&" ~ firstIdent ~ ")[0.." ~ itoa(len/2) ~ "];
}";
  return code;
}

/// Parses the elements of identList and passes a flat list
/// to generateIdentMembers().
char[] generatePredefinedIdentMembers()
{
  auto list = new string[predefIdents.length * 2];
  foreach (i, identStr; predefIdents)
  {
    auto j = i * 2;
    auto pair = getPair(identStr);
    list[j]   = pair[0];
    list[j+1] = pair[1];
  }
  return generateIdentMembers(list, false);
}

/// Forwards flatList to generateIdentMembers().
char[] generateKeywordMembers(string[] flatList)
{
  return generateIdentMembers(flatList, true);
}

/// CTF for generating the members of the enum IDK.
char[] generateIDMembers()
{
  char[] members;
  foreach (ident; predefIdents)
    members ~= getPair(ident)[0] ~ ",\n";
  return members;
}

// pragma(msg, generatePredefinedIdentMembers());
// pragma(msg, generateIDMembers());
