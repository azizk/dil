/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.lexer.IDs;

import dil.lexer.Identifier,
       dil.lexer.IDsList,
       dil.lexer.IDsEnum,
       dil.lexer.TokensEnum;

/// The namespace for all Identifiers.
struct IDs
{
  alias T = TOK;
  alias I = Identifier;
static:
  /// The pre-compiled list of Identifier declarations.
  enum identifiers = (){
    char[] code = "I ".dup;
    foreach (xy; keywordIDs)
    {
      auto name = xy[0], id = xy[1];
      code ~= name~` = I("`~id~`", T.`~name~", IDK."~name~"),\n";
    }
    foreach (xy; specialIDs)
    {
      auto name = xy[0], id = xy[1];
      code ~= name~` = I("`~id~`", T.SpecialID, IDK.`~name~"),\n";
    }
    foreach (xy; predefinedIDs)
    {
      auto name = xy[0], id = xy[1];
      code ~= name~` = I("`~id~`", T.Identifier, IDK.`~name~"),\n";
    }
    code[$-2] = ';';
    return code;
  }();

  mixin(identifiers);

  /// Returns an array of Identifiers.
  Identifier[] getIDs(alias List, .size_t Len = List.length)()
  { // Take the address of the first ID and return a slice.
    return (&mixin(List[0][0]))[0 .. Len];
  }

  alias getKeywordIDs = getIDs!(keywordIDs);
  alias getSpecialIDs = getIDs!(specialIDs);
  alias getPredefinedIDs = getIDs!(predefinedIDs);
  alias getAllIDs = getIDs!(keywordIDs,
    keywordIDs.length + specialIDs.length + predefinedIDs.length);

  /// Returns true for assembler jump opcode identifiers.
  bool isJumpOpcode(IDK kind)
  {
    return IDK.ja <= kind && kind <= IDK.jz;
  }
}

/// E.g.: enum Identifier* Abstract = &IDs.Abstract
char[] generatePointersToIDs(string[2][] list)
{
  char[] code = "enum Identifier* ".dup;
  foreach (name; list)
    code ~= name[0] ~ " = &IDs." ~ name[0] ~ ",\n";
  code[$-2] = ';';
  return code;
}

/// A namespace for keyword identifiers.
struct Keyword
{
static:
  mixin(generatePointersToIDs(keywordIDs));
}

/// A namespace for special identifiers.
struct SpecialID
{
static:
  mixin(generatePointersToIDs(specialIDs));
}

/// A namespace for the predefined identifiers.
struct Ident
{
static:
  mixin(generatePointersToIDs(predefinedIDs));
  alias isJumpOpcode = IDs.isJumpOpcode;
}
