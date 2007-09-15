/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Messages;
import dil.Settings;
import common;

/// Index into table of compiler messages.
enum MID
{
  // Lexer messages:
  IllegalCharacter,
  InvalidUnicodeCharacter,
  InvalidUTF8Sequence,
  // ''
  UnterminatedCharacterLiteral,
  EmptyCharacterLiteral,
  // #line
  ExpectedIdentifierSTLine,
  ExpectedIntegerAfterSTLine,
  ExpectedFilespec,
  UnterminatedFilespec,
  UnterminatedSpecialToken,
  // ""
  UnterminatedString,
  // x""
  NonHexCharInHexString,
  OddNumberOfDigitsInHexString,
  UnterminatedHexString,
  // /* */ /+ +/
  UnterminatedBlockComment,
  UnterminatedNestedComment,
  // `` r""
  UnterminatedRawString,
  UnterminatedBackQuoteString,
  // \x \u \U
  UndefinedEscapeSequence,
  InsufficientHexDigits,
  // \&[a-zA-Z][a-zA-Z0-9]+;
  UndefinedHTMLEntity,
  UnterminatedHTMLEntity,
  InvalidBeginHTMLEntity,
  // integer overflows
  OverflowDecimalSign,
  OverflowDecimalNumber,
  OverflowHexNumber,
  OverflowBinaryNumber,
  OverflowOctalNumber,
  OverflowFloatNumber,
  OctalNumberHasDecimals,
  NoDigitsInHexNumber,
  NoDigitsInBinNumber,
  HexFloatExponentRequired,
  HexFloatExpMustStartWithDigit,
  FloatExpMustStartWithDigit,

  // Parser messages:
  ExpectedButFound,
  RedundantStorageClass,
  TemplateTupleParameter,
  InContract,
  OutContract,
  MissingLinkageType,
  UnrecognizedLinkageType,

  // Help messages:
  HelpMain,
  HelpGenerate,
  HelpImportGraph,
}

string GetMsg(MID mid)
{
  assert(mid < GlobalSettings.messages.length);
  return GlobalSettings.messages[mid];
}

char[] FormatMsg(MID mid, ...)
{
  return Format(_arguments, _argptr, GetMsg(mid));
}

/+
char[] FormatArray(char[] format_str, char[][] args)
{
  auto tiinfos = new TypeInfo[args.length];
  foreach (ref tiinfo; tiinfos)
    tiinfo = typeid(char[]);
  return Format(tiinfos, args.ptr, format_str);
}
+/
