/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Messages;
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
  InvalidUnicodeEscapeSequence,
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
  ExpectedBaseClasses,
  BaseClassInForwardDeclaration,

  // Help messages:
  HelpMain,
  HelpGenerate,
  HelpImportGraph,
}

private string[] messages;

package void SetMessages(string[] msgs)
{
  assert(MID.max+1 == msgs.length);
  messages = msgs;
}

string GetMsg(MID mid)
{
  assert(mid < messages.length);
  return messages[mid];
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
