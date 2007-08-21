/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Messages;
import dil.Settings;
import std.stdarg;

/// Index into table of compiler messages.
enum MID
{
  // Lexer messages:
  InvalidUnicodeCharacter,
  InvalidUTF8Sequence,
  // ''
  UnterminatedCharacterLiteral,
  EmptyCharacterLiteral,
  // #line
  ExpectedIdentifierSTLine,
  ExpectedNumberAfterSTLine,
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
  HexFloatMissingExpDigits,
  FloatExponentDigitExpected,

  // Parser messages:
  ExpectedButFound,
  RedundantStorageClass,

  // Help messages:
  HelpMain,
}

string GetMsg(MID mid)
{
  assert(mid < GlobalSettings.messages.length);
  return GlobalSettings.messages[mid];
}

char[] format(MID mid, ...)
{
  auto args = arguments(_arguments, _argptr);
  return format_args(GetMsg(mid), args);
}

char[] format(char[] format_str, ...)
{
  auto args = arguments(_arguments, _argptr);
  return format_args(format_str, args);
}

char[] format_args(char[] format_str, char[][] args)
{
  char[] result = format_str;

  foreach (i, arg; args)
    result = std.string.replace(result, std.string.format("{%s}", i+1), arg);

  return result;
}

char[][] arguments(TypeInfo[] tinfos, void* argptr)
{
  char[][] args;
  foreach (ti; tinfos)
  {
    if (ti == typeid(char[]))
      args ~= va_arg!(char[])(argptr);
    else if (ti == typeid(int))
      args ~= std.string.format(va_arg!(int)(argptr));
    else if (ti == typeid(dchar))
      args ~= std.string.format(va_arg!(dchar)(argptr));
    else
      assert(0, "argument type not supported yet.");
  }
  return args;
}
