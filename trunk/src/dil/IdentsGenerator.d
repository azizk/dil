/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.IdentsGenerator;

struct StrPair
{
const:
  char[] str;   /// Identifier string in code.
  char[] idStr; /// In table.
}

static const StrPair[] identPairs = [
  // Predefined version identifiers:
  {"DigitalMars"}, {"X86"}, {"X86_64"},
  /*{"Windows"}, */{"Win32"}, {"Win64"},
  {"linux"}, {"LittleEndian"}, {"BigEndian"},
  {"D_Coverage"}, {"D_InlineAsm_X86"}, {"D_Version2"},
  {"none"}, {"all"},
  // Variadic parameters:
  {"_arguments"}, {"_argptr"},
  // scope:
  {"exit"}, {"success"}, {"failure"},
  // pragma:
  {"msg"}, {"lib"},
  // Linkage:
  {"C"}, {"D"}, {"Windows"}, {"Pascal"}, {"System"},
  // Operator methods:
  {"opCall"},
  // ASM identifiers:
  {"near"}, {"far"}, {"word"}, {"dword"}, {"qword"},
  {"ptr"}, {"offset"}, {"seg"}, {"__LOCAL_SIZE"},
  {"FS"}, {"ST"},
  {"AL"}, {"AH"}, {"AX"}, {"EAX"},
  {"BL"}, {"BH"}, {"BX"}, {"EBX"},
  {"CL"}, {"CH"}, {"CX"}, {"ECX"},
  {"DL"}, {"DH"}, {"DX"}, {"EDX"},
  {"BP"}, {"EBP"}, {"SP"}, {"ESP"},
  {"DI"}, {"EDI"}, {"SI"}, {"ESI"},
  {"ES"}, {"CS"}, {"SS"}, {"DS"}, {"GS"},
  {"CR0"}, {"CR2"}, {"CR3"}, {"CR4"},
  {"DR0"}, {"DR1"}, {"DR2"}, {"DR3"}, {"DR6"}, {"DR7"},
  {"TR3"}, {"TR4"}, {"TR5"}, {"TR6"}, {"TR7"},
  {"MM0"}, {"MM1"}, {"MM2"}, {"MM3"},
  {"MM4"}, {"MM5"}, {"MM6"}, {"MM7"},
  {"XMM0"}, {"XMM1"}, {"XMM2"}, {"XMM3"},
  {"XMM4"}, {"XMM5"}, {"XMM6"}, {"XMM7"},
];

/++
  CTF for generating the members of the struct Ident.
  The resulting string could look like this:
  ---
  private struct Ids {static const:
    Identifier _str = {"str", TOK.Identifier, ID.str};
    // more ...
  }
  Identifier* str = &Ids._str;
  // more ...
  private Identifier*[] __allIds = [
    str,
    // more ...
  ]
  ---
+/
char[] generateIdentMembers(char[] private_members = "")
{
  private_members = "private struct Ids {static const:";

  char[] public_members = "";
  char[] array = "private Identifier*[] __allIds = [";
  foreach (pair; identPairs)
  {
    // NB: conditional makes function uneligible for CTE.
    // char[] idString = pair.idStr ? pair.idStr : pair.str;
    // Identifier _str = {"str", TOK.Identifier, ID.str};
    private_members ~= "Identifier _"~pair.str~` = {"`~pair.str~`", TOK.Identifier, ID.`~pair.str~"};\n";
    // Identifier* str = &_str;
    public_members ~= "Identifier* "~pair.str~" = &Ids._"~pair.str~";\n";
    array ~= pair.str~",";
  }

  private_members ~= "}"; // Close private {
  array ~= "];";

  return private_members ~ public_members ~ array;
}

/// CTF for generating the members of the enum ID.
char[] generateIDMembers(char[] members = "")
{
  foreach (pair; identPairs)
    members ~= pair.str ~ ",\n";
  return members;
}

// pragma(msg, generateIdentMembers());
// pragma(msg, generateIDMembers());
